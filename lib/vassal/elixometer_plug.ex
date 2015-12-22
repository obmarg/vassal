defmodule Vassal.ElixometerPlug do
  @moduledoc """
  A plug that records response time & count using Elixometer.
  """
  use Elixometer

  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]

  def init(config), do: nil

  def call(conn, config) do
    before_time = :os.timestamp()

    register_before_send conn, fn conn ->
      after_time = :os.timestamp()
      diff = :timer.now_diff after_time, before_time

      :ok = Elixometer.update_histogram("resp_time", diff)
      :ok = Elixometer.update_spiral("resp_count", 1)

      conn
    end
  end
end
