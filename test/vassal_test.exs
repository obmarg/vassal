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
end
