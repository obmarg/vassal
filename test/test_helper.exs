ExUnit.start()
ExUnit.configure(capture_log: true)
:erlcloud.start()
ExUnitFixtures.start()

# TODO: Check if this is needed.
Code.load_file("test/integration_tests/common.exs")
