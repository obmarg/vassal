defmodule Vassal.QueueWorker do
  @moduledoc """
  The main worker process for a Queue.

  Handles any incoming messages related to this queue.
  """
  use GenServer

  @doc """
  Starts a QueueWorker process as part of a supervision tree

  ### Params

  - `queue_store` - A QueueProcessStore to register with.
  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def start_link(queue_store, queue_name, attrs) do
    GenServer.start_link(__MODULE__, [queue_store, queue_name, attrs])
  end

  @doc """
  Initialises a QueueWorker process.

  ### Params

  - `queue_store` - A QueueProcessStore to register with.
  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def init(queue_store, queue_name, attrs) do
    :ok = QueueProcessStore.add(queue_store, queue_name, self)
    {:ok, %{name: queue_name, attrs: attrs}}
  end
end
