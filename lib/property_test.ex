defmodule PropertyTest do
  @moduledoc """
  Provides macros for property testing.
  """

  alias StreamData.Random

  defmodule RunOptions do
    @moduledoc false

    defstruct test_count: 100,
              max_shrink_depth: 50
  end

  defmodule Error do
    defexception [:original_failure, :shrinked_failure]

    def message(%{original_failure: original_failure, shrinked_failure: shrinked_failure}) do
      formatted_original = Exception.format_banner(:error, original_failure.exception, original_failure.stacktrace)
      formatted_original_indented = "  " <> String.replace(formatted_original, "\n", "\n  ")

      formatted_shrinked = Exception.format_banner(:error, shrinked_failure.failure.exception, shrinked_failure.failure.stacktrace)
      formatted_shrinked_indented = "  " <> String.replace(formatted_shrinked, "\n", "\n  ")

      formatted_values = "  " <> Enum.map_join(shrinked_failure.failure.generated_values, "\n\n  ", fn {gen_string, value} ->
        gen_string <> "\n  #=> " <> inspect(value)
      end)

      """
      property failed. Original failure:

      #{formatted_original_indented}

      Failure from shrinked data:

      #{formatted_shrinked_indented}

      Shrinked generated values:

      #{formatted_values}

      (visited a total of #{shrinked_failure.nodes_visited}, #{shrinked_failure.current_depth} level(s) deep)
      """
    end
  end

  # TODO: docs
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
      %Property.Failure{} = original_failure ->
        shrinked_failure = shrink_failure(tree.children, _smallest = original_failure, _nodes_visited = 0, _current_depth = 0, options.max_shrink_depth)
        raise Error, original_failure: original_failure, shrinked_failure: shrinked_failure
    end
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
