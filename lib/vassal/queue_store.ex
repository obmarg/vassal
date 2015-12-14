defmodule Vassal.QueueStore do
  @moduledoc """
  This module provides a store for queue configuration.
  """
  use ExActor.GenServer, export: __MODULE__

  @ets_table __MODULE__

  defstart start_link do
    :ets.new(@ets_table, [:named_table, read_concurrency: true])
    initial_state(nil)
  end

  @doc """
  Adds a queue to the store.  Errors if it already exists
  """
  defcall add_queue(queue_name, config) do
    reply(:ets.insert_new(@ets_table, {queue_name, config}))
  end

  @doc """
  Removes a queue from the store.
  """
  defcall remove_queue(queue_name) do
    reply(:ets.delete(@ets_table, queue_name))
  end

  @doc """
  Returns true if a queue exists.
  """
  def queue_exists?(queue_name) do
    case :ets.lookup(@ets_table, queue_name) do
      [{^queue_name, _}] -> true
      [] -> false
    end
  end

  @doc """
  Lists all the queues.

  Note that if there are too many queues this _could_ return too many results...
  """
  def list_queues do
    :ets.traverse @ets_table, fn({queue_name, _}) ->
      {:continue, queue_name}
    end
  end

  @doc """
  Gets a queues configuration
  """
  def queue_config(queue_name) do
    case :ets.lookup(@ets_table, queue_name) do
      [{^queue_name, config}] -> config
      [] -> nil
    end
  end

  @doc """
  Sets a queues configuration.
  """
  defcall queue_config(queue_name, config) do
    reply(:ets.insert(@ets_table, {queue_name, config}))
  end
end
