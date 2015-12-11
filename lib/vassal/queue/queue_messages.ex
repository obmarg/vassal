defmodule Vassal.Queue.QueueMessages do
  @moduledoc """
  This module provides an Agent process that a queue can use to manage it's
  messages.

  It is basically a wrapper around a list that contains message PIDs.

  When a message is queued, it can be added to the list, and when it is being
  received it can be dropped from the list.

  Note that this module won't hold _all_ messages in a queue, only the ones that
  are not hidden by a delay/visibility timeout.
  """

  def start_link do
    Agent.start_link(fn -> [] end)
  end

  @doc """
  Adds a message process into the queue.
  """
  def enqueue(queue_messages_pid, message_pid) do
    Agent.update(queue_messages_pid, &(List.insert_at(&1, -1, message_pid)))
  end

  @doc """
  Removes some message processes from the queue.
  """
  def dequeue(queue_messages_pid, max_to_receive) do
    Agent.get_and_update(queue_messages_pid, &(Enum.split(&1, max_to_receive)))
  end

end
