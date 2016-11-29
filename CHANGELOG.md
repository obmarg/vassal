v0.3.0 (29/11/16)
---

- Fix a mistaken call to Logger.warning in an unhandled message handler.
- SendMessage now rejects messages of 256kb or more, similar actual AWS.
- ChangeMessageVisibility now correctly sets the visibility timeout to the
  provided value, similar to actual AWS. Previously it would add the new
  visibility timeout on to the old visibility timeout.
- Upgraded some dependencies.
- ReceiveMessage calls no longer wait around for at least 500ms when no
  WaitTimeSeconds is provided and there are no messages. They should return as
  fast as possible.
- Updated to Elixir 1.3
- Tested against Elixir 1.4.0-rc.0

v0.2.2 (21/5/16)
---

- Use `:erlang.send_after` instead of `:timer.send_interval` in Receiver.
  `:timer` functions use a central server and aren't recommended for heavy
  usage.
- Receiver only polls QueueMessages when it has waiting requests.  This
  (combined with the `send_after` change) should reduce the idle CPU load when
  a server has lots of queues registered.
- Updated a bunch of dependencies.

v0.2.1 (6/1/16)
----

- Added missing applications to mix.exs
- Load migration files from correct path.

v0.2.0 (6/1/16)
----

- Queues persist across restarts using ecto & sqlite.
- ListQueues action supported.
- Some other misc internal changes.

v0.1.2
----

- Fixed support for SetQueueAttributes via pythons aiobotocore.

v0.1.1
-----

- Fixed a configuration error in v0.1.0
- Fixed a bunch of compiler warnings.

v0.1.0
-----

Initial release.  Many things implemented.  Enough to support Liege v0.5.0.
