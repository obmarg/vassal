defmodule Vassal do
  @moduledoc """
  A simple message queue with an SQS interface.
  """

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(
        Supervisor,
        [[supervisor(Vassal.Queue.Supervisor, [], restart: :transient)],
         [strategy: :simple_one_for_one, name: Vassal.QueueSupervisor]]
      ),
      Plug.Adapters.Cowboy.child_spec(
        :http, Vassal.WebRouter, [],
        [port: Application.get_env(:vassal, :port),
         ip:   Application.get_env(:vassal, :ip)]
      )
    ]

    opts = [strategy: :one_for_one, name: Vassal.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
