# Vassal

A Fake SQS server to aid in SQS development.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add vassal to your list of dependencies in `mix.exs`:

        def deps do
          [{:vassal, "~> 0.0.1"}]
        end

  2. Ensure vassal is started before your application:

        def application do
          [applications: [:vassal]]
        end

## Existing Works

This is not the first queing server to implement an SQS interface.  There is
also:

- [Fake SQS](https://github.com/iain/fake_sqs)
- [ElasticMQ](https://github.com/adamw/elasticmq)
