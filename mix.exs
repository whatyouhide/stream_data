defmodule StreamData.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :stream_data,
      version: "0.1.0",
      elixir: "~> 1.5-rc.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [],
      env: [
        initial_size: 1,
        total_runs: 100,
        max_shrinking_steps: 100,
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:ex_doc, "~> 0.15", only: :dev},
    ]
  end
end
