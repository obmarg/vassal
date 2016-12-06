defmodule Vassal.Mixfile do
  use Mix.Project

  def project do
    [app: :vassal,
     version: "0.3.2",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :cowboy, :plug, :gproc, :poison, :uuid, :exactor,
                    :fsm, :mix, :ecto, :sqlite_ecto, :sqlitex, :esqlite],
     mod: {Vassal, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.2"},
     {:uuid, "~> 1.1"},
     {:fsm, "~> 0.2.0"},
     {:gproc, "~> 0.5.0"},
     {:exactor, "~> 2.2.0"},
     {:poison, "~> 1.5.0"},
     {:ecto, "~> 1.1.0"},
     {:sqlite_ecto, "~> 1.1.0"},

     # For building releases
     {:distillery, "~> 0.10"},

     # For testing
     {:erlcloud, "~> 0.13", only: [:test]},
     {:httpoison, "~> 0.9", only: [:test]},
     {:ex_unit_fixtures, "~> 0.3", only: [:test]},

     # For linting etc.
     {:credo, "~> 0.4", only: [:dev, :test], warn_missing: false},
   ]
  end
end
