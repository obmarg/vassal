defmodule Vassal.Queue.Supervisor do
  @moduledoc """
  A Supervisor for a single queues processes.
  """
  use Supervisor

  alias Vassal.Queue.MessageSupervisor
  alias Vassal.Queue.QueueMessages
  alias Vassal.Queue.ReceiptHandles
  alias Vassal.Queue.Receiver

  @doc """
  Returns the PID of a queue supervisor process when given the queue name.
  """
  def for_queue(queue_name, timeout \\ 50) do
    {pid, _} = queue_name |> to_gproc_name |> :gproc.await(timeout)
    pid
  end

  @doc """
  Starts our queue supervisor.
  """
  def start_link(queue_name) do
    Supervisor.start_link(__MODULE__, queue_name)
  end

  @doc """
  Initialises our queue supervisor.
  """
  def init(queue_name) do
    queue_name |> to_gproc_name |> :gproc.reg

    children = [
      supervisor(MessageSupervisor, [queue_name]),
      supervisor(Supervisor, [[worker(QueueMessages, [queue_name]),
                               worker(ReceiptHandles, [queue_name]),
                               worker(Receiver, [queue_name])],
                              [strategy: :one_for_one]])
    ]

    supervise(children, strategy: :rest_for_one)
  end

  defp to_gproc_name(queue_name) do
    {:n, :l, "queue.#{queue_name}.supervisor"}
  end

end
