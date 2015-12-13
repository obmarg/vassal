defmodule VassalMessageTest do
  use ExUnit.Case, async: true

  alias Vassal.Queue.QueueMessages
  alias Vassal.Message

  setup do
    {:ok, q_pid} = QueueMessages.start_link()

    # Really wish I had py.test style fixtures in elixir...

    {:ok, %{queue: q_pid}}
  end

  test "should add to queue immediately when no delay", context do
    {:ok, pid} = Message.start_link(context.queue,
                                    %Message.MessageInfo{delay_ms: 0})
    :timer.sleep(10)

    assert_in_queue context, 1
  end

  test "should add to queue after delay", context do
    {:ok, pid} = Message.start_link(context.queue,
                                    %Message.MessageInfo{delay_ms: 100})
    :timer.sleep(10)

    assert_in_queue context, 0

    :timer.sleep(150)
    assert_in_queue context, 1
  end

  test "message can be received while in queue", context do
    message = %Message.MessageInfo{default_visibility_timeout_ms: 100}
    {:ok, pid} = Message.start_link(context.queue, message)

    :timer.sleep(10)
    ^message = Message.receive_message(pid, nil)
  end

  test "should be re-inserted to queue after visibility timeout", context do
    message = %Message.MessageInfo{default_visibility_timeout_ms: 100}
    {:ok, pid} = Message.start_link(context.queue, message)

    :timer.sleep(10)
    [_] = QueueMessages.dequeue(context.queue, 1)
    ^message = Message.receive_message(pid, nil)
    :timer.sleep(80)

    assert_in_queue(context, 0)

    :timer.sleep(30)
    assert_in_queue(context, 1)
  end

  test "changing visibility timeout should change re-insert time", context do
    message = %Message.MessageInfo{default_visibility_timeout_ms: 100}
    {:ok, pid} = Message.start_link(context.queue, message)

    :timer.sleep(10)
    [_] = QueueMessages.dequeue(context.queue, 1)
    ^message = Message.receive_message(pid, nil)
    Message.change_visibility_timeout(pid, 100)

    :timer.sleep(180)
    assert_in_queue(context, 0)

    :timer.sleep(30)
    assert_in_queue(context, 1)
  end

  test "should shutdown on delete when not in queue", context do
    message = %Message.MessageInfo{default_visibility_timeout_ms: 10}
    {:ok, pid} = GenServer.start(Message, [context.queue, message])

    :timer.sleep(10)
    ^message = Message.receive_message(pid, nil)
    :ok = Message.delete_message(pid)
    :timer.sleep(5)

    refute Process.alive?(pid)
  end

  test "should shutdown on send_data when in queue", context do
    message = %Message.MessageInfo{default_visibility_timeout_ms: 10}
    {:ok, pid} = GenServer.start(Message, [context.queue, message])

    :timer.sleep(10)
    ^message = Message.receive_message(pid, nil)

    # Wait until we have been re-added to the queue...
    :timer.sleep(30)
    :ok = Message.delete_message(pid)

    :timer.sleep(5)

    assert Process.alive?(pid)

    nil = Message.receive_message(pid, nil)
    :timer.sleep(10)

    refute Process.alive?(pid)
  end

  defp assert_in_queue(context, num) do
    queue_contents = Agent.get(context.queue, fn (x) -> x end)
    assert length(queue_contents) == num
  end
end
