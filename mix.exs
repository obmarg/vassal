defmodule Vassal.Mixfile do
  use Mix.Project

  def project do
    [app: :vassal,
     version: "0.1.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :cowboy, :plug, :gproc, :poison, :uuid, :exactor,
                    :fsm, :mix],
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
     {:plug, "~> 1.0"},
     {:uuid, "~> 1.1"},
     {:fsm, "~> 0.2.0"},
     {:gproc, "~> 0.5.0"},
     {:exactor, "~> 2.2.0"},
     {:poison, "~> 1.5"},

     # For building releases
     {:exrm, "~> 1.0.0-rc7"},
     {:edip, "~> 0.4.3", only: [:dev], warn_missing: false},

     # For testing
     {:erlcloud, "~> 0.12.0", only: [:test]},
     {:httpoison, "~> 0.8.0", only: [:test]},

     # For linting etc.
     {:credo, "~> 0.2.0", only: [:dev, :test], warn_missing: false},
   ]
  end
end
