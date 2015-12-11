defmodule Vassal.Queue do
  @moduledoc """
  The module that manages queues.

  This module itself defines a GenServer that manages all the processes related
  to a Queue and it's messages.
  """
  use GenServer

  alias Vassal.QueueProcessStore
  alias Vassal.Queue.QueueMessages

  @doc """
  Starts a Queue process as part of a supervision tree

  ### Params

  - `queue_store` - A QueueProcessStore to register with.
  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def start_link(queue_store, queue_name, attrs) do
    GenServer.start_link(__MODULE__, [queue_store, queue_name, attrs])
  end

  @doc """
  Initialises a Queue process.

  ### Params

  - `queue_store` - A QueueProcessStore to register with.
  - `queue_name` - The name of the queue this worker represents
  - `attrs` - The Queue attributes
  """
  def init([queue_store, queue_name, attrs]) do
    :ok = QueueProcessStore.add(queue_store, queue_name, self)

    {:ok, queue_messages_pid} = QueueMessages.start_link()

    {:ok, %{name: queue_name,
            attrs: attrs,
            queue_messages: queue_messages_pid}}
  end

end
