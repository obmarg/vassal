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
    assert String.contains?(resp.body, "http://localhost:4567/1234/#{q_name}")
  end

  test "getting queue url for non existent queue" do
    q_name = random_queue_name
    # GRR, erlcloud has no get_queue_url.
    # Let's hack it together!
    HTTPoison.start
    resp = HTTPoison.get!(
      "http://localhost:4567/?Action=GetQueueUrl&QueueName=#{q_name}"
    )
    assert resp.status_code == 200
    assert String.contains?(resp.body,
                            "AWS.SimpleQueueService.NonExistentQueue")
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
