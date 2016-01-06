defmodule Vassal.Repo do
  @moduledoc """
  Ecto Repo for Vassal.
  """
  use Ecto.Repo, otp_app: :vassal

  defmodule Migrator do
    @moduledoc """
    A Simple GenServer that runs a migration on our repo then stops.
    """
    use ExActor.GenServer

    defstart start_link do
      migration_dir = Application.app_dir(:vassal, "priv/repo/migrations")
      Ecto.Migrator.run(Vassal.Repo, migration_dir, :up, all: true)
      initial_state(nil, 100)
    end

    def handle_info(:timeout, state) do
      {:stop, :shutdown, state}
    end
  end
end
