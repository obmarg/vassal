defmodule Vassal.Stats do
  @moduledoc """
  Asynchronous wrapper around elixometer w/ helpers for setting vassal stats.
  """
  use Elixometer

  for name <- [:update_histogram, :update_spiral, :update_gauge,
               :update_counter] do
    def unquote(name)(stat, val) do
      Task.Supervisor.start_child(Vassal.Stats.Supervisor,
                                  Elixometer, unquote(name), [stat, val])
    end
  end
end
