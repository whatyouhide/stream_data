defmodule StreamData.Mixfile do
  use Mix.Project

  @version "0.4.3"
  @repo_url "https://github.com/whatyouhide/stream_data"

  def project() do
    [
      app: :stream_data,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # Docs
      name: "StreamData",
      docs: [
        source_ref: "v#{@version}",
        main: "StreamData",
        source_url: @repo_url
      ],

      # Hex
      description: "Data generation and property-based testing for Elixir",
      package: [
        maintainers: ["Andrea Leopardi"],
        licenses: ["Apache 2.0"],
        links: %{"GitHub" => @repo_url}
      ]
    ]
  end

  def application() do
    [
      extra_applications: [],
      env: [
        initial_size: 1,
        max_runs: 100,
        max_run_time: :infinity,
        max_shrinking_steps: 100
      ]
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.19", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer() do
    [
      plt_add_deps: :apps_direct,
      plt_add_apps: ~w(
        ex_unit
        mix
      )a,
      flags: ~w(
        error_handling
        race_conditions
        unmatched_returns
        underspecs
      )a
    ]
  end
end
