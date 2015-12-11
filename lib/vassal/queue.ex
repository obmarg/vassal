defmodule Vassal.Queue do
  @moduledoc """
  The module that manages queues.

  This module itself defines a GenServer that manages all the processes related
  to a Queue and it's messages.
  """
  use GenServer

  alias Vassal.QueueProcessStore
  alias Vassal.Queue.QueueMessages
  alias Vassal.Actions.SendMessage
  alias Vassal.Errors.SQSError

  @doc """
  Routes a queue action to the appropriate process, which will carry it out.
  """
  def do_action(action, queue_process_store \\ Vassal.QueueProcessStore) do
    action.queue_name
    |> lookup_queue_worker(queue_process_store)
    |> GenServer.call(action)
  end

  @doc """
  Starts a Queue process as part of a supervision tree

  ### Params

  - `queue_store` - A QueueProcessStore to register with.
  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def start_link(queue_store, queue_name, attrs) do
    GenServer.start_link(__MODULE__, [queue_store, queue_name, attrs])
  end

  @doc """
  Initialises a Queue process.

  ### Params

  - `queue_store` - A QueueProcessStore to register with.
  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def init([queue_store, queue_name, attrs]) do
    :ok = QueueProcessStore.add(queue_store, queue_name, self)

    {:ok, queue_messages_pid} = QueueMessages.start_link()

    message_supervisor = start_message_supervisor(queue_messages_pid)

    {:ok, %{name: queue_name,
            attrs: attrs,
            queue_messages: queue_messages_pid,
            message_supervisor: message_supervisor}}
  end

  def handle_call(%SendMessage{} = send_message, _from, state) do
    {:ok, _} = Supervisor.start_child(
      state.message_supervisor,
      [%Vassal.Message.MessageInfo{delay_ms: send_message.delay_ms}]
    )
    result = %SendMessage.Result{message_id: UUID.uuid4, body_md5: "todo"}
    {:reply, result, state}
  end

  defp start_message_supervisor(queue_messages_pid) do
    import Supervisor.Spec

    children = [worker(Vassal.Message,
                       [queue_messages_pid],
                       restart: :transient)]
    {:ok, pid} = Supervisor.start_link(children, strategy: :simple_one_for_one)

    pid
  end

  defp lookup_queue_worker(queue_name, queue_process_store) do
    pid = Vassal.QueueProcessStore.lookup(queue_process_store, queue_name)
    if pid == nil do
      raise %SQSError{code: "AWS.SimpleQueueService.NonExistentQueue"}
    end
    pid
  end

end
