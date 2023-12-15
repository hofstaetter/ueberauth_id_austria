defmodule UeberauthIdAustria.MixProject do
  use Mix.Project

  @source_url "https://github.com/hofstaetter/ueberauth_id_austria"
  @version "0.2.0"

  def project do
    [
      app: :ueberauth_id_austria,
      version: @version,
      name: "Überauth IDAustria",
      package: package(),
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: @source_url,
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {UeberauthIdAustria, []},
      extra_applications: [:logger, :ueberauth, :oauth2]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oauth2, "~> 1.0 or ~> 2.0"},
      {:ueberauth, "~> 0.7"},
      {:jose, "~> 1.8"},

      # dev/test dependencies
      {:ex_doc, "~> 0.18", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end

  defp package do
    [
      description: "An Uberauth strategy for ID Austria (eIDAS) authentication.",
      files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Martin Bürgmann <martin.buergmann@hofstaetter.io>"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url
      }
    ]
  end
end
