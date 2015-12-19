defmodule Vassal.QueueStore.Queues do
  @moduledoc """
  Ecto schema for persisting queue config.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "queues" do
    field :name
    field :delay_ms, :integer
    field :max_message_bytes, :integer
    field :retention_secs, :integer
    field :recv_wait_time_ms, :integer
    field :max_receives, :integer
    field :dead_letter_queue
  end

  def insert_changeset(params \\ :empty) do
    %__MODULE__{}
    |> cast(params,
            ~w(name delay_ms max_message_bytes retention_secs
               recv_wait_time_ms),
            ~w(max_receives dead_letter_queue))
    |> unique_constraint(:name)
  end

  def update_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(), ~w(delay_ms max_message_bytes retention_secs
                             recv_wait_time_ms max_receives
                             dead_letter_queue))
  end
end
