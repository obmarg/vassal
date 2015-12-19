defmodule Vassal.Repo.Migrations.CreateQueue do
  use Ecto.Migration

  def change do
    create table(:queues) do
      add :name, :string, null: false
      add :delay_ms, :integer, null: false
      add :max_message_bytes, :integer, null: false
      add :retention_secs, :integer, null: false
      add :recv_wait_time_ms, :integer, null: false
      add :max_receives, :integer
      add :dead_letter_queue, :string
    end

    create unique_index(:queues, [:name])
  end
end
