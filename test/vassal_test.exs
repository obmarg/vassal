defmodule VassalTest do
  use ExUnit.Case
  doctest Vassal

  require Record
  Record.defrecord(
    :aws_config,
    Record.extract(:aws_config,
                   from_lib: "erlcloud/include/erlcloud_aws.hrl")
  )

  test "can create queue" do
    :erlcloud_sqs.create_queue(random_queue_name, config)
  end

  test "can get queue url" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    # GRR, erlcloud has no get_queue_url.
    # Let's hack it together!
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=GetQueueUrl&QueueName=#{q_name}"
    )
    assert resp.status_code == 200
    assert String.contains?(resp.body, "http://localhost:4567/#{q_name}")
  end

  test "getting queue url for non existent queue" do
    q_name = random_queue_name
    # GRR, erlcloud has no get_queue_url.
    # Let's hack it together!
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=GetQueueUrl&QueueName=#{q_name}"
    )
    assert resp.status_code == 400
    assert String.contains?(resp.body,
                            "AWS.SimpleQueueService.NonExistentQueue")
  end

  test "invalid action" do
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=What"
    )
    assert resp.status_code == 400
    assert String.contains?(resp.body,
                            "AWS.SimpleQueueService.InvalidAction")
  end

  test "sending a message" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    :erlcloud_sqs.send_message(q_name, 'abcd', config)
  end

  test "receiving a message" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    send_resp = :erlcloud_sqs.send_message(q_name, 'abcd', config)
    [messages: [message]] = :erlcloud_sqs.receive_message(q_name, [], 2, config)
    assert message[:message_id] == send_resp[:message_id]
    assert message[:body] == 'abcd'
  end

  test "receiving no messages" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    [messages: []] = :erlcloud_sqs.receive_message(q_name, [], 2, config)
  end

  test "receiving messages with wait" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    spawn_link(fn ->
      :timer.sleep(500)
      :erlcloud_sqs.send_message(q_name, 'abcd', config)
      :erlcloud_sqs.send_message(q_name, 'abcd', config)
    end)

    [messages: [message1, message2]] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 30, 1, config
    )
    assert message1[:body] == 'abcd'
    assert message2[:body] == 'abcd'
    assert message1[:message_id] != message2[:message_id]
  end

  test "re-receive message after visibility timeout" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    send_resp = :erlcloud_sqs.send_message(q_name, 'abcd', config)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 1, config
    )

    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
    :timer.sleep(1000)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 1, config
    )
    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
  end

  test "deleting a message" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    send_resp = :erlcloud_sqs.send_message(q_name, 'abcd', config)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 1, config
    )

    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
    :erlcloud_sqs.delete_message(q_name, message[:receipt_handle], config)
    :timer.sleep(1000)

    [messages: []] = :erlcloud_sqs.receive_message(q_name, [], 2, 1, config)
  end

  test "changing message visibility" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    send_resp = :erlcloud_sqs.send_message(q_name, 'abcd', config)

    [messages: [message]] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 1, config
    )

    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
    :erlcloud_sqs.change_message_visibility(q_name, message[:receipt_handle],
                                            1, config)
    :timer.sleep(1000)

    [messages: []] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 1, config
    )

    :timer.sleep(1100)
    [messages: [message]] = :erlcloud_sqs.receive_message(
      q_name, [], 2, 1, config
    )
    assert message[:body] == 'abcd'
    assert message[:message_id] == send_resp[:message_id]
  end

  test "deleting a queue" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    :erlcloud_sqs.delete_queue(q_name, config)

    :timer.sleep(100)
    assert_raise ErlangError, fn ->
      :erlcloud_sqs.send_message(q_name, 'abcd', config)
    end
  end

  test "receiving with attributes" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    send_resp = :erlcloud_sqs.send_message(q_name, 'abcd', config)
    [messages: [message]] = :erlcloud_sqs.receive_message(
      q_name, [:all], 2, config
    )

    assert message[:message_id] == send_resp[:message_id]
    assert message[:body] == 'abcd'

    assert message[:attributes][:approximate_receive_count] == 1
    assert message[:attributes][:sent_timestamp]
    assert message[:attributes][:approximate_first_receive_timestamp]
  end

  test "getting all attributes" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    attrs = :erlcloud_sqs.get_queue_attributes(q_name, config)
    assert attrs[:delay_seconds] == 0
    assert attrs[:visibility_timeout] == 30
    refute :redrive_policy in attrs
    arn = attrs[:queue_arn] |> List.to_string
    q_str = List.to_string q_name
    assert String.ends_with?(arn, q_str)
  end

  test "getting specific attributes" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    [visibility_timeout: 30] = :erlcloud_sqs.get_queue_attributes(
      q_name, [:visibility_timeout], config
    )
  end

  test "setting attributes" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)

    redrive_policy = build_redrive_policy(1, "test_arn")
    attributes = [visibility_timeout: 40,
                  delay_seconds: 50,
                  redrive_policy: redrive_policy]
    :erlcloud_sqs.set_queue_attributes(q_name, attributes, config)

    result_attrs = :erlcloud_sqs.get_queue_attributes(
      q_name, Dict.keys(attributes), config
    )
    assert result_attrs[:visibility_timeout] == attributes[:visibility_timeout]
    assert result_attrs[:delay_seconds] == attributes[:delay_seconds]
    str_redrive = List.to_string(result_attrs[:redrive_policy])
    assert str_redrive == attributes[:redrive_policy]
  end

  test "max receives" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    attrs = [visibility_timeout: 1, redrive_policy: build_redrive_policy(2)]
    :erlcloud_sqs.set_queue_attributes(q_name, attrs, config)

    :erlcloud_sqs.send_message(q_name, 'abcd', config)
    [messages: [_message]] = :erlcloud_sqs.receive_message(q_name, config)

    :timer.sleep(1000)
    [messages: [_message]] = :erlcloud_sqs.receive_message(q_name, config)

    :timer.sleep(1000)
    [messages: []] = :erlcloud_sqs.receive_message(q_name, config)
  end

  test "dead letter queues" do
    q_name = random_queue_name
    dlq_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)
    :erlcloud_sqs.create_queue(dlq_name, config)
    attrs = [visibility_timeout: 1,
             redrive_policy: build_redrive_policy(1, dlq_name)]
    :erlcloud_sqs.set_queue_attributes(q_name, attrs, config)

    :erlcloud_sqs.send_message(q_name, 'abcd', config)
    [messages: [message]] = :erlcloud_sqs.receive_message(q_name, config)

    :timer.sleep(1000)
    [messages: [dlq_message]] = :erlcloud_sqs.receive_message(dlq_name, config)
    assert dlq_message[:body] == message[:body]
    assert dlq_message[:message_id] == message[:message_id]

    [messages: []] = :erlcloud_sqs.receive_message(q_name, config)
  end

  test "list queues" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)

    queues = :erlcloud_sqs.list_queues(config)
    assert 'http://localhost:4567/#{q_name}' in queues
  end

  test "list queues with prefix" do
    q_name = random_queue_name
    :erlcloud_sqs.create_queue(q_name, config)

    queues = :erlcloud_sqs.list_queues(q_name, config)
    assert queues == ['http://localhost:4567/#{q_name}']
  end

  defp config do
    aws_config(sqs_host: 'localhost',
               sqs_protocol: 'http',
               sqs_port: 4567,
               access_key_id: 'test',
               secret_access_key: 'test')
  end

  defp random_queue_name do
    UUID.uuid4() |> to_char_list
  end

  defp build_redrive_policy(max_receives, dead_letter_name \\ nil) do
    policy = %{"maxReceiveCount" => max_receives}
    if dead_letter_name do
      policy = Dict.put(policy, "deadLetterTargetArn",
                        Vassal.Utils.make_arn(dead_letter_name))
    end
    Poison.encode!(policy)
  end
end
