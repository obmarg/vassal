defmodule Vassal.QueueStore do
  @moduledoc """
  This module provides a store for queue configuration.
  """
  use ExActor.GenServer, export: __MODULE__

  @ets_table __MODULE__

  alias Vassal.QueueStore.Queues

  defstart start_link do
    :ets.new(@ets_table, [:named_table, read_concurrency: true])
    Enum.each get_db_queues, fn {queue_name, config} ->
      true = :ets.insert_new(@ets_table, {queue_name, config})
    end
    initial_state(nil)
  end

  @doc """
  Adds a queue to the store.  Errors if it already exists
  """
  @spec add_queue(String.t, Vassal.Queue.Config.t) :: boolean | {:error, term}
  defcall add_queue(queue_name, config) do
    changeset =
      config
        |> Map.from_struct
        |> Map.put(:name, queue_name)
        |> Queues.insert_changeset

    case Vassal.Repo.insert(changeset) do
      {:ok, _model} ->
        true = :ets.insert_new(@ets_table, {queue_name, config})
        reply(true)
      {:error, _changeset} ->
        reply(false)
    end
  end

  @doc """
  Removes a queue from the store.
  """
  @spec remove_queue(String.t) :: :ok | {:error, term}
  defcall remove_queue(queue_name) do
    case Vassal.Repo.delete(get_queue(queue_name)) do
      {:ok, _} ->
        true = :ets.delete(@ets_table, queue_name)
        reply(:ok)
      {:error, _changeset} ->
        reply({:error, :db})
    end
  end

  @doc """
  Returns true if a queue exists.
  """
  @spec queue_exists?(String.t) :: boolean
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
  @spec list_queues() :: [String.t]
  def list_queues do
    func = fn({queue_name, _}, names) ->
      [queue_name|names]
    end

    :ets.foldr func, [], @ets_table
  end

  @doc """
  Gets a queues configuration
  """
  @spec queue_config(String.t) :: Vassal.Queue.Config.t | nil
  def queue_config(queue_name) do
    case :ets.lookup(@ets_table, queue_name) do
      [{^queue_name, config}] -> config
      [] -> nil
    end
  end

  @doc """
  Sets a queues configuration.
  """
  @spec queue_config(String.t, Vassal.Queue.Config.t) :: :ok | {:error, term}
  defcall queue_config(queue_name, config) do
    db_config = Map.from_struct(config)
    changeset = queue_name |> get_queue |> Queues.update_changeset(db_config)

    case Vassal.Repo.update(changeset) do
      {:ok, _model} ->
        true = :ets.insert(@ets_table, {queue_name, config})
        reply(:ok)
      {:error, _changeset} ->
        reply({:error, :db})
    end
  end

  @spec get_db_queues() :: [{String.t, Vassal.Queue.Config.t}]
  defp get_db_queues do
    import Ecto.Query

    query = from q in Queues, select: q
    for queue <- Vassal.Repo.all(query) do
      config_map = queue |> Map.from_struct |> Map.drop([:name])

      {queue.name, struct(Vassal.Queue.Config, config_map)}
    end
  end

  @spec get_queue(String.t) :: %Queues{}
  defp get_queue(queue_name) do
    Vassal.Repo.get_by(Queues, name: queue_name)
  end
end
