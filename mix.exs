defmodule StreamData.Mixfile do
  use Mix.Project

  @version "0.5.0"
  @repo_url "https://github.com/whatyouhide/stream_data"

  def project() do
    [
      app: :stream_data,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Tests
      test_coverage: [tool: ExCoveralls],

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
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => @repo_url, "Sponsor" => "https://github.com/sponsors/whatyouhide"}
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
      {:excoveralls, "~> 0.16.0", only: :test},
      {:ssl_verify_fun, "~> 1.1", only: :test, manager: :rebar3, override: true}
    ]
  end
end
