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

  def start_link(queue_name) do
    Agent.start_link fn ->
      queue_name |> to_gproc_name |> :gproc.reg
      []
    end
  end

  @doc """
  Returns the PID of a QueueMessages process when given the queue name.
  """
  def for_queue(queue_name, timeout \\ 50) do
    {pid, _} = queue_name |> to_gproc_name |> :gproc.await(timeout)
    pid
  end

  @doc """
  Adds a message process into the queue.
  """
  def enqueue(queue_messages_pid, message_pid) do
    Vassal.Stats.update_counter("message.enqueue", 1)
    Agent.update(queue_messages_pid, &(List.insert_at(&1, -1, message_pid)))
  end

  @doc """
  Re-adds messages to the head of the queue.

  This should only be used when some messages were de-queued, but failed to
  actually be processed.
  """
  def requeue(queue_messages_pid, message_pids) do
    Vassal.Stats.update_counter("message.requeue", 1)
    Agent.update queue_messages_pid, fn (list) ->
      Enum.reduce(message_pids, list, &(List.insert_at &2, 0, &1))
    end
  end

  @doc """
  Removes some message processes from the queue.
  """
  def dequeue(queue_messages_pid, max_to_receive) do
    Vassal.Stats.update_counter("message.dequeue", 1)
    Agent.get_and_update(queue_messages_pid, &(Enum.split(&1, max_to_receive)))
  end

  defp to_gproc_name(queue_name) do
    {:n, :l, "queue.#{queue_name}.queue_messages"}
  end
end
