defmodule Vassal.Queue.MessageSupervisor do
  @moduledoc """
  A simple-one-for-one supervisor for message processes.

  Each queue should have it's own MessageSupervisor.
  """
  use Supervisor

  @doc """
  Starts a MessageSupervisor as part of a supervision tree.
  """
  def start_link(queue_name) do
    Supervisor.start_link(__MODULE__, queue_name)
  end

  @doc """
  Initialises a MessageSupervisor
  """
  def init(queue_name) do
    queue_name |> to_gproc_name |> :gproc.reg

    children = [worker(Vassal.Message, [queue_name], restart: :transient)]
    supervise(children, strategy: :simple_one_for_one)
  end

  @doc """
  Returns the PID of a MessageSupervisor process when given the queue name.
  """
  def for_queue(queue_name, timeout \\ 50) do
    {pid, _} = queue_name |> to_gproc_name |> :gproc.await(timeout)
    pid
  end

  defp to_gproc_name(queue_name) do
    {:n, :l, "queue.#{queue_name}.message_supervisor"}
  end

end
