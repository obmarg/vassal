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

## Implemented Actions

- CreateQueue
- GetQueueUrl
- DeleteQueue
- SendMessage
- ReceiveMessage
- DeleteMessage
- ChangeMessageVisibility
- SetQueueAttributes
- GetQueueAttributes

## Missing Features

Some of these may be implemented in the near future:

- User defined message attributes.
- Getting non-config queue attributes (other than ARN).
  ApproximateNumberOfMessages etc. are not supported.
- Listing queues
- Authentication / permissions, or anything related.
- MD5 checksums.
- SenderId Attribute on messages.
- Persistence.  All data & queues will be lost on restart.

## Existing Works

This is not the first queing server to implement an SQS interface.  There is
also:

- [Fake SQS](https://github.com/iain/fake_sqs)
- [ElasticMQ](https://github.com/adamw/elasticmq)
