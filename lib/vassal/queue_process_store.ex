defmodule Vassal.QueueProcessStore do
  @moduledoc """
  Stores the PIDs of running queue processes and allows them to be queried.

  Will monitor the queue PIDs and remove them on failure.
  """
  use GenServer

  @doc """
  Starts a QueueProcessStore process as part of a supervision tree.
  """
  def start_link(name \\ Vassal.QueueProcessStore) do
    GenServer.start_link(__MODULE__, [name], name: name)
  end

  @doc """
  Adds a queue process to the store.
  """
  def add(store, queue_id, pid) do
    GenServer.call(store, {:add, queue_id, pid})
  end

  @doc """
  Removes a queue process from the store
  """
  def remove(store, queue_id) do
    GenServer.call(store, {:remove, queue_id})
  end

  @doc """
  Looks up a queue process in the store.
  """
  def lookup(store, queue_id) do
    case :ets.lookup(store, queue_id) do
      [{^queue_id, pid}] -> pid
      [] -> nil
    end
  end

  @doc """
  Initialises the QueueProcessStore processs.
  """
  def init([name]) do
    :ets.new(name, [:named_table, read_concurrency: true])
    {:ok, %{name: name, queues_by_pid: %{}}}
  end

  def handle_call({:add, queue_name, pid}, _from, state) do
    :ets.insert(state.name, {queue_name, pid})
    Process.monitor(pid)
    queues_by_pid = Dict.put(state.queues_by_pid, pid, queue_name)
    {:reply, :ok, %{state | queues_by_pid: queues_by_pid}}
  end

  def handle_info({'DOWN', _, _, pid, _down_info}, state) do
    # Technically this can happen on timeout, so we should maybe be careful...
    :ets.delete(state.name, state.queues_by_pid[pid])
    queues_by_pid = Dict.delete(state.queues_by_pid, pid)
    {:noreply, %{state | queues_by_pid: queues_by_pid}}
  end
end
