defmodule IntegrationTestFixtures do
  use ExUnitFixtures.FixtureModule

  require Record
  Record.defrecord(
    :aws_config,
    Record.extract(:aws_config,
                   from_lib: "erlcloud/include/erlcloud_aws.hrl")
  )

  deffixture config, autouse: true do
    aws_config(sqs_host: 'localhost',
               sqs_protocol: 'http',
               sqs_port: 4567,
               access_key_id: 'test',
               secret_access_key: 'test')
  end

  deffixture queue(config) do
    name = random_queue_name
    [queue_url: _] = :erlcloud_sqs.create_queue(name, config)

    on_exit fn ->
      try do
        :erlcloud_sqs.delete_queue(name, config)
      rescue
        _ -> nil # Ignore errors, the test may have deleted the queue.
      end
    end

    name
  end

  defp random_queue_name do
    UUID.uuid4() |> to_char_list
  end
end
