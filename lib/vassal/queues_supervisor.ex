defmodule Vassal.QueuesSupervisor do
  @moduledoc """
  A superivisor that supervises all of the invidual queue supervisors.
  """
  use Supervisor

  @doc """
  Adds a queue to the QueuesSupervisor.
  """
  @spec add_queue(String.t) :: :ok
  def add_queue(queue_name) do
    {:ok, _pid} = Supervisor.start_child(__MODULE__, [queue_name])
    :ok
  end

  @doc """
  Deletes a queue from the supervisor.
  """
  @spec delete_queue(String.t) :: :ok
  def delete_queue(queue_name) do
    queue_sup = Vassal.Queue.Supervisor.for_queue(queue_name)
    :ok = Supervisor.terminate_child(__MODULE__, queue_sup)

    :ok
  end

  @doc """
  Starts the QueuesSupervisor as part of a supervision tree.
  """
  @spec start_link() :: {:ok, pid}
  def start_link do
    {:ok, pid} = Supervisor.start_link(__MODULE__, [], name: __MODULE__)

    Vassal.QueueStore.list_queues |> Enum.each(&add_queue/1)

    {:ok, pid}
  end

  @doc """
  Initialises the queues supervisor.
  """
  def init([]) do
    children = [supervisor(Vassal.Queue.Supervisor, [], restart: :transient)]

    supervise(children, strategy: :simple_one_for_one)
  end

end
