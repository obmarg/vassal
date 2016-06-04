defmodule VassalTest do
  use ExUnitFixtures
  use ExUnit.Case
  doctest Vassal

  @moduletag fixtures: [:queue]

  @tag fixtures: []
  test "can create queue", %{config: config} do
    :erlcloud_sqs.create_queue(random_queue_name, config)
  end

  test "can get queue url", %{queue: queue} do
    # GRR, erlcloud has no get_queue_url.
    # Let's hack it together!
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=GetQueueUrl&QueueName=#{queue}"
    )
    assert resp.status_code == 200
    assert String.contains?(resp.body, "http://localhost:4567/#{queue}")
  end

  @tag fixtures: []
  test "getting queue url for non existent queue" do
    # GRR, erlcloud has no get_queue_url.
    # Let's hack it together!
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=GetQueueUrl&QueueName=missing_queue"
    )
    assert resp.status_code == 400
    assert String.contains?(resp.body,
                            "AWS.SimpleQueueService.NonExistentQueue")
  end

  @tag fixtures: []
  test "invalid action" do
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=What"
    )
    assert resp.status_code == 400
    assert String.contains?(resp.body,
                            "AWS.SimpleQueueService.InvalidAction")
  end

  test "sending a message", %{queue: queue, config: config} do
    :erlcloud_sqs.send_message(queue, 'abcd', config)
  end

  test "receiving a message", %{queue: queue, config: config} do
    send_resp = :erlcloud_sqs.send_message(queue, 'abcd', config)
    [messages: [message]] = :erlcloud_sqs.receive_message(queue, [], 2, config)
    assert message[:message_id] == send_resp[:message_id]
    assert message[:body] == 'abcd'
  end

  test "receiving no messages", %{queue: queue, config: config} do
    [messages: []] = :erlcloud_sqs.receive_message(queue, [], 2, config)
  end

  test "receiving messages with wait", %{queue: queue, config: config} do
    spawn_link(fn ->
      :timer.sleep(500)
      :erlcloud_sqs.send_message(queue, 'abcd', config)
      :erlcloud_sqs.send_message(queue, 'abcd', config)
    end)

    [messages: [message1, message2]] = :erlcloud_sqs.receive_message(
      queue, [], 2, 30, 1, config
    )
    assert message1[:body] == 'abcd'
    assert message2[:body] == 'abcd'
    assert message1[:message_id] != message2[:message_id]
  end

  test "re-receive message after visibility timeout", %{queue: queue, config: config} do
    send_resp = :erlcloud_sqs.send_message(queue, 'abcd', config)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      queue, [], 2, 1, config
    )

    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
    :timer.sleep(1000)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      queue, [], 2, 1, config
    )
    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
  end

  test "deleting a message", %{queue: queue, config: config} do
    send_resp = :erlcloud_sqs.send_message(queue, 'abcd', config)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      queue, [], 2, 1, config
    )

    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
    :erlcloud_sqs.delete_message(queue, message[:receipt_handle], config)
    :timer.sleep(1000)

    [messages: []] = :erlcloud_sqs.receive_message(queue, [], 2, 1, config)
  end

  test "changing message visibility", %{queue: queue, config: config} do
    send_resp = :erlcloud_sqs.send_message(queue, 'abcd', config)

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

  test "deleting a queue", %{queue: queue, config: config} do
    :erlcloud_sqs.delete_queue(queue, config)

    :timer.sleep(100)
    assert_raise ErlangError, fn ->
      :erlcloud_sqs.send_message(queue, 'abcd', config)
    end
  end

  test "receiving with attributes", %{queue: queue, config: config} do
    send_resp = :erlcloud_sqs.send_message(queue, 'abcd', config)
    [messages: [message]] = :erlcloud_sqs.receive_message(
      queue, [:all], 2, config
    )

    assert message[:message_id] == send_resp[:message_id]
    assert message[:body] == 'abcd'

    assert message[:attributes][:approximate_receive_count] == 1
    assert message[:attributes][:sent_timestamp]
    assert message[:attributes][:approximate_first_receive_timestamp]
  end

  test "getting all attributes", %{queue: queue, config: config} do
    attrs = :erlcloud_sqs.get_queue_attributes(queue, config)
    assert attrs[:delay_seconds] == 0
    assert attrs[:visibility_timeout] == 30
    refute :redrive_policy in attrs
    arn = attrs[:queue_arn] |> List.to_string
    q_str = List.to_string queue
    assert String.ends_with?(arn, q_str)
  end

  test "getting specific attributes", %{queue: queue, config: config} do
    [visibility_timeout: 30] = :erlcloud_sqs.get_queue_attributes(
      queue, [:visibility_timeout], config
    )
  end

  test "setting attributes", %{queue: queue, config: config} do
    redrive_policy = build_redrive_policy(1, "test_arn")
    attributes = [visibility_timeout: 40,
                  delay_seconds: 50,
                  redrive_policy: redrive_policy]
    :erlcloud_sqs.set_queue_attributes(queue, attributes, config)

    result_attrs = :erlcloud_sqs.get_queue_attributes(
      queue, Dict.keys(attributes), config
    )
    assert result_attrs[:visibility_timeout] == attributes[:visibility_timeout]
    assert result_attrs[:delay_seconds] == attributes[:delay_seconds]
    str_redrive = List.to_string(result_attrs[:redrive_policy])
    assert str_redrive == attributes[:redrive_policy]
  end

  test "max receives", %{queue: queue, config: config} do
    attrs = [visibility_timeout: 1, redrive_policy: build_redrive_policy(2)]
    :erlcloud_sqs.set_queue_attributes(queue, attrs, config)

    :erlcloud_sqs.send_message(queue, 'abcd', config)
    [messages: [_message]] = :erlcloud_sqs.receive_message(queue, config)

    :timer.sleep(1000)
    [messages: [_message]] = :erlcloud_sqs.receive_message(queue, config)

    :timer.sleep(1000)
    [messages: []] = :erlcloud_sqs.receive_message(queue, config)
  end

  test "dead letter queues", %{queue: queue, config: config} do
    dlq_name = random_queue_name
    :erlcloud_sqs.create_queue(dlq_name, config)
    attrs = [visibility_timeout: 1,
             redrive_policy: build_redrive_policy(1, dlq_name)]
    :erlcloud_sqs.set_queue_attributes(queue, attrs, config)

    :erlcloud_sqs.send_message(queue, 'abcd', config)
    [messages: [message]] = :erlcloud_sqs.receive_message(queue, config)

    :timer.sleep(1000)
    [messages: [dlq_message]] = :erlcloud_sqs.receive_message(dlq_name, config)
    assert dlq_message[:body] == message[:body]
    assert dlq_message[:message_id] == message[:message_id]

    [messages: []] = :erlcloud_sqs.receive_message(queue, config)
  end

  test "list queues", %{queue: queue, config: config} do
    queues = :erlcloud_sqs.list_queues(config)
    assert 'http://localhost:4567/#{queue}' in queues
  end

  test "list queues with prefix", %{queue: queue, config: config} do
    queues = :erlcloud_sqs.list_queues(queue, config)
    assert queues == ['http://localhost:4567/#{queue}']
  end

  defp random_queue_name do
    UUID.uuid4() |> to_char_list
  end

  defp build_redrive_policy(max_receives, dead_letter_name \\ nil) do
    policy =
      if dead_letter_name do
        %{"maxReceiveCount" => max_receives,
          "deadLetterTargetArn" => Vassal.Utils.make_arn(dead_letter_name)}
      else
        %{"maxReceiveCount" => max_receives}
      end

    Poison.encode!(policy)
  end
end
