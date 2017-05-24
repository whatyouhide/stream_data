defmodule PropertyTest do
  defmacro for_all({:with, _meta, options}) when is_list(options) do
    [[do: block] | reverse_clauses] = Enum.reverse(options)
    clauses = Enum.reverse(reverse_clauses)

    quote do
      property = unquote(Property.compile(clauses, block))

      initial_state = %{size: 10, seed: :rand.seed_s(:exs64)}

      {:rand.seed_s(:exs64), _size = 10}
      |> Stream.unfold(fn {seed, size} ->
        {seed1, seed2} = Stream.Data.Random.split(seed)
        next = property.(seed1, size)
        {next, {seed2, size}}
      end)
      |> Stream.filter(&match?({:success, _}, &1))
      |> Stream.take(100)
      |> Stream.run()
    end
  end
end
