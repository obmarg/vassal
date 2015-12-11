defmodule Vassal.QueueManager do
  @moduledoc """
  This module is responsible for managing queues.
  """
  use GenServer

  alias Vassal.Actions.CreateQueue
  alias Vassal.Actions.GetQueueUrl
  alias Vassal.Errors.SQSError

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
    case GenServer.call(__MODULE__, action) do
      %SQSError{} = error -> raise error
      result -> result
    end
  end

  @doc """
  Initialises the GenServer.

  This should load a list of queues from somewhere, start a simple_one_for_one
  supervisor and then initialise a worker for each of the defined queues.
  """
  def init(queue_store) do
    {:ok, %{supervisor: start_queue_supervisor(queue_store),
            queue_store: queue_store}}
  end

  @doc """
  Creates a queue, or returns an existing queue if it exists.
  """
  def handle_call(%CreateQueue{queue_name: queue_name, attributes: attrs},
                  _from, state) do
    start_child(queue_name, attrs, state.supervisor)
    {:reply, %CreateQueue.Result{queue_url: queue_url(queue_name)}, state}
  end

  @doc """
  Gets the URL of a Queue if it exists.
  """
  def handle_call(%GetQueueUrl{queue_name: queue_name}, _from, state) do
    queue_pid = Vassal.QueueProcessStore.lookup(state.queue_store, queue_name)
    result = if queue_pid != nil do
      %GetQueueUrl.Result{queue_url: queue_url(queue_name)}
    else
      %SQSError{code: "AWS.SimpleQueueService.NonExistentQueue"}
    end
    {:reply, result, state}
  end

  defp start_queue_supervisor(queue_store) do
    import Supervisor.Spec
    alias Vassal.Queue

    children = [
      worker(Queue, [queue_store], restart: :transient)
    ]

    {:ok, sup} = Supervisor.start_link(children, strategy: :simple_one_for_one)
    sup
  end

  defp start_child(queue_name, attrs, supervisor) do
    {:ok, _pid} = Supervisor.start_child(supervisor, [queue_name, attrs])
  end

  defp queue_url(queue_name) do
    "#{Application.get_env(:vassal, :url)}/1234/#{queue_name}"
  end
end
