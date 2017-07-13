defmodule PropertyTest do
  alias StreamData.Random

  defmodule RunOptions do
    @moduledoc false

    defstruct test_count: 100,
              max_shrink_depth: 50
  end

  defmacro for_all({:with, _meta, options}) when is_list(options) do
    {clauses, [[do: block]]} = Enum.split(options, -1)

    quote do
      property = unquote(Property.compile(clauses, block))
      starting_seed = Random.new_seed(ExUnit.configuration()[:seed])
      PropertyTest.run_property(property, starting_seed, _initial_size = 0, %RunOptions{})
    end
  end

  @doc false
  def run_property(property, initial_seed, initial_size, %RunOptions{} = run_options) do
    state = %{successes: 0}
    run_property(property, initial_seed, initial_size, state, run_options)
  end

  defp run_property(_property, _seed, _size, %{successes: n}, %RunOptions{test_count: n}) do
    :ok
  end

  defp run_property(property, seed, size, state, options) do
    {seed1, seed2} = Random.split(seed)

    tree = StreamData.call(property, seed1, size)

    case tree.root.() do
      %Property.Success{} ->
        state = Map.update!(state, :successes, &(&1 + 1))
        run_property(property, seed2, size + 1, state, options)
      %Property.Failure{} ->
        shrinked_failure = shrink_failure(tree, options.max_shrink_depth)
        %{failure: %Property.Failure{exception: exception, stacktrace: stacktrace}} = shrinked_failure
        reraise(enrich_message(exception, shrinked_failure), stacktrace)
    end
  end

  defp enrich_message(exception, shrinked_failure) do
    message = exception.message <> "\n\n" <> format_shrinked_failure(shrinked_failure)
    %{exception | message: message}
  end

  defp format_shrinked_failure(%{failure: failure, nodes_visited: nodes_visited, current_depth: current_depth}) do
    formatted_values = Enum.map_join(failure.generated_values, "\n\n  ", fn {gen_string, value} ->
      gen_string <> "\n  #=> " <> inspect(value)
    end)

    "Shrinked generated values:\n\n  " <>
      formatted_values <>
      "\n\n" <>
      "(visited a total of #{nodes_visited} nodes, #{current_depth} level(s) deep)"
  end

  defp shrink_failure(tree, max_depth) do
    shrink_failure(tree.children, _smallest = tree.root.(), _nodes_visited = 0, _current_depth = 0, max_depth)
  end

  defp shrink_failure(nodes, smallest, nodes_visited, current_depth, max_depth) do
    if current_depth == max_depth or Enum.empty?(nodes) do
      %{failure: smallest, nodes_visited: nodes_visited, current_depth: current_depth}
    else
      [first_child] = Enum.take(nodes, 1)

      case first_child.root.() do
        %Property.Success{} ->
          shrink_failure(Stream.drop(nodes, 1), smallest, nodes_visited + 1, current_depth, max_depth)
        %Property.Failure{} = failure ->
          if Enum.empty?(first_child.children) do
            shrink_failure(Stream.drop(nodes, 1), failure, nodes_visited + 1, current_depth, max_depth)
          else
            shrink_failure(first_child.children, failure, nodes_visited + 1, current_depth + 1, max_depth)
          end
      end
    end
  end
end
