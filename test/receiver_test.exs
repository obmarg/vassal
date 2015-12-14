defmodule VassalQueueReceiverTest do

  use ExUnit.Case, async: true

  alias Vassal.Queue.QueueMessages
  alias Vassal.Queue.Receiver
  alias Vassal.Actions.ReceiveMessage

  setup do
    q_name = UUID.uuid1
    {:ok, q_pid} = QueueMessages.start_link(q_name)
    {:ok, receiver} = Receiver.start_link(q_name)

    {:ok, %{queue: q_pid, receiver: receiver}}
  end

  test "receive on empty queue with no wait", context do
    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 1,
                                        wait_time_ms: 0}
    )
    assert messages == []
  end

  test "receive on empty queue with wait", context do
    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 1,
                                        wait_time_ms: 1000}
    )
    assert messages == []
  end

  test "receive on queue with data and no wait", context do
    QueueMessages.enqueue(context.queue, {:a})
    QueueMessages.enqueue(context.queue, {:b})
    QueueMessages.enqueue(context.queue, {:c})

    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 2,
                                        wait_time_ms: 0}
    )
    assert messages == [{:a}, {:b}]
    assert_in_queue context, 1
    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 2,
                                        wait_time_ms: 0}
    )
    assert messages = [{:c}]
    assert_in_queue context, 0
  end

  test "receive on queue with data and wait", context do
    QueueMessages.enqueue(context.queue, {:a})
    QueueMessages.enqueue(context.queue, {:b})
    QueueMessages.enqueue(context.queue, {:c})

    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 2,
                                        wait_time_ms: 1000}
    )
    assert messages == [{:a}, {:b}]
    assert_in_queue context, 1
    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 2,
                                        wait_time_ms: 1000}
    )
    assert messages = [{:c}]
    assert_in_queue context, 0
  end

  test "receive on empty queue that gets items", context do
    spawn_link fn ->
      :timer.sleep(500)
      QueueMessages.enqueue(context.queue, {:a})
      QueueMessages.enqueue(context.queue, {:b})
    end
    messages = Receiver.receive_messages(
      context.receiver, %ReceiveMessage{max_messages: 2,
                                        wait_time_ms: 1000}
    )
    assert messages == [{:a}, {:b}]
    assert_in_queue context, 0
  end

  test "receive that isn't acked", context do
    QueueMessages.enqueue(context.queue, {:a})
    QueueMessages.enqueue(context.queue, {:b})
    action = %ReceiveMessage{max_messages: 2, wait_time_ms: 1000}

    GenServer.cast(context.receiver,
                   %Receiver.ReceiveRequest{action: action, from: self})
    assert_receive {:response, _, _}
    assert_in_queue context, 0

    :timer.sleep(5500)
    assert_in_queue context, 2
  end

  defp assert_in_queue(context, num) do
    queue_contents = Agent.get(context.queue, fn (x) -> x end)
    assert length(queue_contents) == num
  end
end
