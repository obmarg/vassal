defmodule VassalMessageVisibilityTest do
  use ExUnit.Case

  @tag fixtures: [:queue]
  test "changing message visibility", %{queue: queue, config: config} do
    # TODO: Ok, so this shite doesn't even do parsing.  FFS!
    send_resp = ExAws.SQS.send_message(queue, "abcd")

    [messages: [message]] = :erlcloud_sqs.receive_message(
      queue, [], 2, 1, config
    )

    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
    :erlcloud_sqs.change_message_visibility(queue, message[:receipt_handle],
                                            1, config)
    :timer.sleep(1000)

    [messages: []] = :erlcloud_sqs.receive_message(
      queue, [], 2, 1, config
    )

    :timer.sleep(1100)
    [messages: [message]] = :erlcloud_sqs.receive_message(
      queue, [], 2, 1, config
    )
    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
  end
end
