defmodule Vassal.QueueManager do
  @moduledoc """
  This module is responsible for managing queues.
  """
  use GenServer

  alias Vassal.Actions.CreateQueue
  alias Vassal.Results.CreateQueueResult

  @doc """
  Start the queue manager GenServer.
  """
  def start_link(queue_store) do
    GenServer.start_link(__MODULE__, queue_store, name: __MODULE__)
  end

  @doc """
  Gets the QueueManager to handle the provided action
  """
  def do_action(action) do
    GenServer.call(__MODULE__, action)
  end

  @doc """
  Initialises the GenServer.

  This should load a list of queues from somewhere, start a simple_one_for_one
  supervisor and then initialise a worker for each of the defined queues.
  """
  def init(queue_store) do
    {:ok, %{supervisor: start_queue_supervisor(queue_store)}}
  end

  @doc """
  Creates a queue, or returns an existing queue if it exists.
  """
  def handle_call(%CreateQueue{queue_name: queue_name, attributes: attrs},
                  _from, state) do
    start_child(queue_name, attrs, state.supervisor)
    {:reply, %CreateQueueResult{queue_name: queue_name}, state}
  end

  defp start_queue_supervisor(queue_store) do
    import Supervisor.Spec
    alias Vassal.QueueWorker

    children = [
      worker(QueueWorker, [queue_store], restart: :transient)
    ]

    {:ok, sup} = Supervisor.start_link(children, strategy: :simple_one_for_one)
    sup
  end

  defp start_child(queue_name, attrs, supervisor) do
    {:ok, _pid} = Supervisor.start_child(supervisor, [queue_name, attrs])
  end
end
