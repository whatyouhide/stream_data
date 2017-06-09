defmodule PropertyTest do
  defmodule RunOptions do
    defstruct test_count: 100
  end

  defmacro for_all({:with, _meta, options}) when is_list(options) do
    [[do: block] | reverse_clauses] = Enum.reverse(options)
    clauses = Enum.reverse(reverse_clauses)

    quote do
      property = unquote(Property.compile(clauses, block))
      PropertyTest.run_property(property, :rand.seed_s(:exs64), _initial_size = 2, %RunOptions{})
    end
  end

  @doc false
  def run_property(property, initial_seed, initial_size, %RunOptions{} = run_options) do
    state = %{
      successes: 0,
      filtered_out: 0,
    }
    run_property(property, initial_seed, initial_size, state, run_options)
  end

  defp run_property(_property, _seed, _size, %{successes: n}, %RunOptions{test_count: n}) do
    :ok
  end

  defp run_property(_property, _seed, _size, %{filtered_out: n}, %RunOptions{test_count: test_count})
      when n >= round(test_count * 0.75) do
    raise "failed because of too many filtered out tests"
  end

  defp run_property(property, seed, size, state, options) do
    {seed1, seed2} = Stream.Data.Random.split(seed)

    {result, generated_values} = property.(seed1, size)

    case result do
      {:success, _result} ->
        state = Map.update!(state, :successes, &(&1 + 1))
        run_property(property, seed2, size + 5, state, options)
      :filtered_out ->
        state = Map.update!(state, :filtered_out, &(&1 + 1))
        run_property(property, seed2, size, state, options)
      {:failure, %ExUnit.AssertionError{} = error, stacktrace} ->
        message = error.message <> format_generated_values(generated_values)
        reraise %{error | message: message}, stacktrace
    end
  end

  defp format_generated_values(values) do
    "\n\nGenerators:\n\n  " <>
      Enum.map_join(values, "\n  ", fn {clause, value} -> "#{clause} #=> #{inspect(value)}" end) <>
      "\n"
  end
end
