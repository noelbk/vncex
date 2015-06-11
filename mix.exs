defmodule VncEx.Mixfile do
  use Mix.Project

  def project do
    [app: :vncex,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
				mod: { Http.Routes, [] },
				applications: [:cowboy, :ranch, :logger] 
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [ 
				{ :cowboy, git: "https://github.com/ninenines/cowboy", tag: "2.0.0-pre.1" },
				{ :poison, "~> 1.4.0" },
				#{ :sqlite_ecto, "~> 0.1.0" }
				{ :esqlite, "~> 0.1.0" }
		]    
  end
end
