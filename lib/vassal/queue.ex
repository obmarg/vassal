defmodule Vassal.Queue do
  @moduledoc """
  The module that manages queues.

  This module itself defines a GenServer that manages all the processes related
  to a Queue and it's messages.
  """
  use GenServer

  alias Vassal.Queue.QueueMessages
  alias Vassal.Queue.Receiver
  alias Vassal.Queue.ReceiptHandles
  alias Vassal.Actions.SendMessage
  alias Vassal.Actions.ReceiveMessage
  alias Vassal.Actions.DeleteMessage
  alias Vassal.Actions.ChangeMessageVisibility
  alias Vassal.Actions.DeleteQueue
  alias Vassal.Errors.SQSError
  alias Vassal.Message

  @doc """
  Finds the PID of a queue process from it's name.

  Returns nil if the queue does not exist.
  """
  def lookup_queue(queue_name) do
    try do
      :gproc.lookup_pid({:n, :l, "queue.#{queue_name}"})
    rescue
      e in ArgumentError -> nil
    end
  end

  @doc """
  Like `lookup_queue/1` but raises an SQSError if the queue is missing.
  """
  def lookup_queue!(queue_name) do
    pid = lookup_queue(queue_name)
    if pid == nil do
      raise %SQSError{code: "AWS.SimpleQueueService.NonExistentQueue"}
    end
    pid
  end

  @doc """
  Routes a queue action to the appropriate process, which will carry it out.
  """
  def do_action(action)

  def do_action(%ReceiveMessage{} = action) do
    {receiver, receipt_handles} =
      action.queue_name
        |> lookup_queue!
        |> GenServer.call(:get_receiving_pids)

    messages =
      receiver
        |> Receiver.receive_messages(action)
        |> Enum.map(&(recv_message_from_pid &1, receipt_handles, action))
        |> Enum.filter(fn (x) -> x end)

    %ReceiveMessage.Result{messages: messages}
  end

  def do_action(action) do
    action.queue_name |> lookup_queue! |> GenServer.call(action)
  end

  @doc """
  Starts a Queue process as part of a supervision tree

  ### Params

  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def start_link(queue_name, attrs) do
    GenServer.start_link(__MODULE__, [queue_name, attrs])
  end

  @doc """
  Initialises a Queue process.

  ### Params

  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def init([queue_name, attrs]) do
    :gproc.reg({:n, :l, "queue.#{queue_name}"}, :ignored)

    {:ok, queue_messages_pid} = QueueMessages.start_link()

    message_supervisor = start_message_supervisor(queue_messages_pid)

    {:ok, receiver} = Receiver.start_link(queue_messages_pid)

    {:ok, receipt_handles} = ReceiptHandles.start_link


    {:ok, %{name: queue_name,
            attrs: attrs,
            queue_messages: queue_messages_pid,
            message_supervisor: message_supervisor,
            receiver: receiver,
            receipt_handles: receipt_handles}}
  end

  def handle_call(%SendMessage{} = send_message, _from, state) do
    message_id = UUID.uuid4

    {:ok, _} = Supervisor.start_child(
      state.message_supervisor,
      [%Vassal.Message.MessageInfo{delay_ms: send_message.delay_ms,
                                   message_id: message_id,
                                   body: send_message.message_body}]
    )
    result = %SendMessage.Result{message_id: message_id, body_md5: "todo"}
    {:reply, result, state}
  end

  def handle_call(%DeleteMessage{} = delete_message, _from, state) do
    state.receipt_handles
    |> ReceiptHandles.get_pid_from_handle(delete_message.receipt_handle)
    |> Message.delete_message

    ReceiptHandles.delete_handle(state.receipt_handles,
                                 delete_message.receipt_handle)

    {:reply, %DeleteMessage.Result{}, state}
  end

  def handle_call(%ChangeMessageVisibility{} = action, _from, state) do
    state.receipt_handles
    |> ReceiptHandles.get_pid_from_handle(action.receipt_handle)
    |> Message.change_visibility_timeout(action.visibility_timeout_ms)

    {:reply, %ChangeMessageVisibility.Result{}, state}
  end

  def handle_call(%DeleteQueue{}, _from, state) do
    {:stop, :shutdown, %DeleteQueue.Result{}, state}
  end

  def handle_call(:get_receiving_pids, _from, state) do
    {:reply, {state.receiver, state.receipt_handles}, state}
  end

  defp start_message_supervisor(queue_messages_pid) do
    import Supervisor.Spec

    children = [worker(Vassal.Message,
                       [queue_messages_pid],
                       restart: :transient)]
    {:ok, pid} = Supervisor.start_link(children, strategy: :simple_one_for_one)

    pid
  end

  @attr_conversions %{sent_timestamp: "SentTimestamp",
                      approx_receive_count: "ApproximateReceiveCount",
                      approx_first_receive: "ApproximateFirstReceiveTimestamp"}

  defp recv_message_from_pid(message_pid, receipt_handles_pid, action) do
    message_info = Message.receive_message(message_pid,
                                           action.visibility_timeout_ms)
    if message_info != nil do
      attributes = Enum.map message_info.attributes, fn ({k, v}) ->
        {@attr_conversions[k], v}
      end
      attributes = Enum.into %{}, attributes

      unless "All" in action.attributes do
        attributes = Dict.take(attributes, action.attributes)
      end

      %ReceiveMessage.Message{
        message_id: message_info.message_id,
        receipt_handle: ReceiptHandles.create_receipt(receipt_handles_pid,
                                                      message_pid),
        body_md5: message_info.body_md5,
        body: message_info.body,
        attributes: attributes
      }
    else
      nil
    end
  end
end
