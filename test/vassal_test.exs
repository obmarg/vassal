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
    :erlcloud_sqs.create_queue('test', config)
  end

  defp config do
    aws_config(sqs_host: 'localhost',
               sqs_protocol: 'http',
               sqs_port: 4567,
               access_key_id: 'test',
               secret_access_key: 'test')
  end
end
