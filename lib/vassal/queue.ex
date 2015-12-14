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

  alias Vassal.Actions.CreateQueue
  alias Vassal.Actions.GetQueueUrl
  alias Vassal.Actions.SendMessage
  alias Vassal.Actions.ReceiveMessage
  alias Vassal.Actions.DeleteMessage
  alias Vassal.Actions.ChangeMessageVisibility
  alias Vassal.Actions.DeleteQueue

  alias Vassal.Errors.SQSError
  alias Vassal.Message

  @doc """
  Runs a queue action.
  """
  def run_action(action)

  def run_action(%CreateQueue{queue_name: queue_name}) do
    {:ok, _pid} = Supervisor.start_child(Vassal.QueueSupervisor, [queue_name])
    %CreateQueue.Result{queue_url: queue_url(queue_name)}
  end

  def run_action(%GetQueueUrl{queue_name: queue_name}) do
    try do
      Vassal.Queue.Supervisor.for_queue(queue_name)
    rescue
      e in ErlangError ->
        raise SQSError, "AWS.SimpleQueueService.NonExistentQueue"
    end

    %GetQueueUrl.Result{queue_url: queue_url(queue_name)}
  end

  def run_action(%ReceiveMessage{} = action) do
    receipt_handles = action.queue_name |> ReceiptHandles.for_queue

    messages =
      action.queue_name
        |> Receiver.for_queue
        |> Receiver.receive_messages(action)
        |> Enum.map(&(recv_message_from_pid &1, receipt_handles, action))
        |> Enum.filter(fn (x) -> x end)

    %ReceiveMessage.Result{messages: messages}
  end

  def run_action(%SendMessage{} = send_message) do
    message_id = UUID.uuid4

    {:ok, _} = Supervisor.start_child(
      Vassal.Queue.MessageSupervisor.for_queue(send_message.queue_name),
      [%Vassal.Message.MessageInfo{delay_ms: send_message.delay_ms,
                                   message_id: message_id,
                                   body: send_message.message_body}]
    )

    %SendMessage.Result{message_id: message_id, body_md5: "todo"}
  end

  def run_action(%DeleteMessage{} = delete_message) do
    receipt_handles_pid = delete_message.queue_name |> ReceiptHandles.for_queue

    receipt_handles_pid
    |> ReceiptHandles.get_pid_from_handle(delete_message.receipt_handle)
    |> Message.delete_message

    ReceiptHandles.delete_handle(receipt_handles_pid,
                                 delete_message.receipt_handle)

    %DeleteMessage.Result{}
  end

  def run_action(%ChangeMessageVisibility{} = action) do
    action.queue_name
    |> ReceiptHandles.for_queue
    |> ReceiptHandles.get_pid_from_handle(action.receipt_handle)
    |> Message.change_visibility_timeout(action.visibility_timeout_ms)

    %ChangeMessageVisibility.Result{}
  end

  def run_action(%DeleteQueue{} = action) do
    queue_sup = Vassal.Queue.Supervisor.for_queue(action.queue_name)
    :ok = Supervisor.terminate_child(Vassal.QueueSupervisor, queue_sup)

    %DeleteQueue.Result{}
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

  defp queue_url(queue_name) do
    "#{Application.get_env(:vassal, :url)}/#{queue_name}"
  end
end
