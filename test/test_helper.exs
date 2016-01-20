ExUnit.start()
ExUnit.configure(capture_log: true)
:erlcloud.start()
ExUnitFixtures.start()
HTTPoison.start()
ExAws.start(nil, nil)

Code.load_file("test/integration_tests/sqs_client.exs")
