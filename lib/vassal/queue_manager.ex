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
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Gets the QueueManager to handle the provided action
  """
  def run_action(%GetQueueUrl{queue_name: queue_name}) do
    try do
      Vassal.Queue.Supervisor.for_queue(queue_name)
    rescue
      e in ErlangError ->
        raise SQSError, "AWS.SimpleQueueService.NonExistentQueue"
    end

    %GetQueueUrl.Result{queue_url: queue_url(queue_name)}
  end

  @doc """
  Gets the QueueManager to handle the provided action
  """
  def run_action(action) do
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
  def init(_) do
    {:ok, {}}
  end

  @doc """
  Creates a queue, or returns an existing queue if it exists.
  """
  def handle_call(%CreateQueue{queue_name: queue_name, attributes: attrs},
                  _from, state) do
    start_child(queue_name, attrs)
    {:reply, %CreateQueue.Result{queue_url: queue_url(queue_name)}, state}
  end

  defp start_child(queue_name, attrs) do
    {:ok, _pid} = Supervisor.start_child(Vassal.QueueSupervisor, [queue_name])
  end

  defp queue_url(queue_name) do
    "#{Application.get_env(:vassal, :url)}/#{queue_name}"
  end
end
