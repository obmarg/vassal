defmodule Vassal do
  @moduledoc """
  A simple message queue with an SQS interface.
  """
  use Application

  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    conn_details = [port: Application.get_env(:vassal, :port),
                    ip: Application.get_env(:vassal, :ip)]

    children = [
      worker(Vassal.QueueStore, []),
      supervisor(
        Supervisor,
        [[supervisor(Vassal.Queue.Supervisor, [], restart: :transient)],
         [strategy: :simple_one_for_one, name: Vassal.QueueSupervisor]]
      ),
      Plug.Adapters.Cowboy.child_spec(
        :http, Vassal.WebRouter, [], conn_details
      )
    ]

    Logger.info("Config: #{inspect conn_details}")

    opts = [strategy: :one_for_one, name: Vassal.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
