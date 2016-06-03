defmodule Vassal.Queue do
  @moduledoc """
  Implements all the actions for a Queue using the various other components.
  """
  use GenServer

  alias Vassal.QueueStore

  alias Vassal.Queue.{Receiver, ReceiptHandles, Config}

  alias Vassal.Actions.{CreateQueue, GetQueueUrl, SendMessage, ReceiveMessage,
                        DeleteMessage, ChangeMessageVisibility, DeleteQueue,
                        SetQueueAttributes, GetQueueAttributes, ListQueues}

  alias Vassal.Errors.SQSError
  alias Vassal.{Message, Utils}


  @doc """
  Runs a queue action.
  """
  @spec run_action(Vassal.Actions.action) :: Vassal.Actions.result
  def run_action(action)

  def run_action(%CreateQueue{queue_name: queue_name, attributes: attrs}) do
    true = QueueStore.add_queue(queue_name,
                                Config.from_incoming_attrs(attrs))

    :ok = Vassal.QueuesSupervisor.add_queue(queue_name)
    %CreateQueue.Result{queue_url: queue_url(queue_name)}
  end

  def run_action(%GetQueueUrl{queue_name: queue_name}) do
    unless QueueStore.queue_exists?(queue_name) do
      raise SQSError, "AWS.SimpleQueueService.NonExistentQueue"
    end
    %GetQueueUrl.Result{queue_url: queue_url(queue_name)}
  end

  def run_action(%SetQueueAttributes{queue_name: queue_name,
                                     attributes: attrs}) do
    unless QueueStore.queue_exists?(queue_name) do
      raise SQSError, "AWS.SimpleQueueService.NonExistentQueue"
    end

    QueueStore.queue_config(queue_name, Config.from_incoming_attrs(attrs))

    %SetQueueAttributes.Result{}
  end

  def run_action(%GetQueueAttributes{queue_name: queue_name,
                                     attributes: requested_attrs}) do
    unless QueueStore.queue_exists?(queue_name) do
      raise SQSError, "AWS.SimpleQueueService.NonExistentQueue"
    end

    attrs =
      queue_name
        |> QueueStore.queue_config
        |> Config.to_outgoing_attrs
        |> Dict.merge(%{"QueueArn" => Utils.make_arn(queue_name)})

    attrs =
      if "All" in requested_attrs do
        attrs
      else
        attrs |> Dict.take(requested_attrs)
      end

    %GetQueueAttributes.Result{attributes: attrs}
  end

  @spec run_action(ReceiveMessage.t) :: ReceiveMessage.Result.t
  def run_action(%ReceiveMessage{} = action) do
    receipt_handles = action.queue_name |> ReceiptHandles.for_queue

    action =
      if action.wait_time_ms && action.visibility_timeout_ms do
        action
      else
        config = QueueStore.queue_config(action.queue_name)
        vis_timeout = action.visibility_timeout_ms || config.visibility_timeout_ms
        wait_time = action.wait_time_ms || config.recv_wait_time_ms

        %{action | wait_time_ms: wait_time,
                   visibility_timeout_ms: vis_timeout}
      end

    messages =
      action.queue_name
        |> Receiver.for_queue
        |> Receiver.receive_messages(action)
        |> Enum.map(&(recv_message_from_pid &1, receipt_handles, action))
        |> Enum.filter(fn (x) -> x end)

    %ReceiveMessage.Result{messages: messages}
  end

  def run_action(%SendMessage{} = action) do
    message_id = UUID.uuid4

    send_message(action.queue_name,
                 %Vassal.Message.MessageInfo{delay_ms: action.delay_ms,
                                             message_id: message_id,
                                             body: action.message_body})

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
    QueueStore.remove_queue(action.queue_name)

    :ok = Vassal.QueuesSupervisor.delete_queue(action.queue_name)

    %DeleteQueue.Result{}
  end

  def run_action(%ListQueues{prefix: prefix}) do
    queues =
      if prefix != nil and String.length(prefix) > 0 do
        QueueStore.list_queues |> Enum.filter(&(String.starts_with? &1, prefix))
      else
        QueueStore.list_queues
      end

    %ListQueues.Result{queue_urls: queues |> Enum.map(&queue_url/1)}
  end

  @doc """
  Sends a message to a queue.

  This function is provided so queues can provide the dead letter functionality.
  Usually messages will be sent by calling run_action with a SendMessage action.
  """
  @spec send_message(String.t, Message.MessageInfo.t) :: :ok
  def send_message(queue_name, message_info) do
    config = QueueStore.queue_config(queue_name)
    message_info = %Message.MessageInfo{
      message_info | delay_ms: message_info.delay_ms || config.delay_ms,
                     max_receives: config.max_receives,
                     dead_letter_queue: config.dead_letter_queue
    }

    {:ok, _} = Supervisor.start_child(
      Vassal.Queue.MessageSupervisor.for_queue(queue_name),
      [message_info]
    )
    :ok
  end

  @attr_conversions %{sent_timestamp: "SentTimestamp",
                      approx_receive_count: "ApproximateReceiveCount",
                      approx_first_receive: "ApproximateFirstReceiveTimestamp"}

  @spec recv_message_from_pid(pid,
                              pid,
                              Vassal.Actions.action) :: ReceiveMessage.Message.t
  defp recv_message_from_pid(message_pid, receipt_handles_pid, action) do
    message_info = Message.receive_message(message_pid,
                                           action.visibility_timeout_ms)
    if message_info != nil do
      attributes = Enum.map message_info.attributes, fn ({k, v}) ->
        {@attr_conversions[k], v}
      end
      attributes = Enum.into %{}, attributes

      attributes =
        if "All" in action.attributes do
          attributes
        else
          Dict.take(attributes, action.attributes)
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
