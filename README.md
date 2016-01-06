# Vassal

A Fake SQS server to aid in SQS development.

## Installation

Vassal is released in 2 forms - a docker container and a packaged release.

### Running via Docker

Installing & running Vassal via docker is the simplest option:

    docker run -p 4567:4567 -d obmarg/vassal:0.2.0

### Installing & Running from Release

To install a release:

- Download the relevant release from [github
  releases](https://github.com/obmarg/vassal/releases).
- Untar it.
- Run the server in the background with `bin/vassal start`.

For example:

    mkdir vassal
    cd vassal
    wget https://github.com/obmarg/vassal/releases/download/v0.2.0/vassal-0.2.0-osx.tar.gz
    tar -xf vassal-0.2.0-osx.tar.gz
    bin/vassal start

### Configuration

By default, Vassal assumes that it will be accessed via localhost.  If that is
not the case, then you should provide the correct url in the `URL` environment
variable.

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
- ListQueues

## Missing Features

Some of these may be implemented in the near future:

- Batch sends/changes/deletes
- User defined message attributes.
- Getting non-config queue attributes (other than ARN).
  ApproximateNumberOfMessages etc. are not supported.
- Listing queues
- Authentication / permissions, or anything related.
- MD5 checksums.
- SenderId Attribute on messages.
- MessageRetentionPeriod is currently ignored.

## Existing Works

This is not the first queing server to implement an SQS interface.  There is
also:

- [Fake SQS](https://github.com/iain/fake_sqs)
- [ElasticMQ](https://github.com/adamw/elasticmq)
