defmodule StreamData.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :stream_data,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  def application() do
    [
      extra_applications: [],
      env: [
        initial_size: 1,
        max_runs: 100,
        max_shrinking_steps: 100,
      ],
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.15", only: :dev},
    ]
  end
end
