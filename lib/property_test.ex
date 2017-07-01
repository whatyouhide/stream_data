defmodule PropertyTest do
  alias Stream.{
    Data,
    Data.LazyTree,
    Data.Random,
  }

  defmodule RunOptions do
    defstruct test_count: 100,
              max_shrink_depth: 25
  end

  defmacro for_all({:with, _meta, options}) when is_list(options) do
    {clauses, [[do: block]]} = Enum.split(options, -1)

    quote do
      property = unquote(Property.compile(clauses, block))
      PropertyTest.run_property(property, Random.new_seed(), _initial_size = 2, %RunOptions{})
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

    case Data.call(property, seed1, size) do
      %LazyTree{root: %Property.Success{}} ->
        state = Map.update!(state, :successes, &(&1 + 1))
        run_property(property, seed2, size + 5, state, options)
      %LazyTree{root: %Property.Failure{}} = failure_tree ->
        smallest_failure = find_smallest_failure(failure_tree, options.max_shrink_depth)
        %Property.Failure{exception: exception, stacktrace: stacktrace} = smallest_failure
        reraise(enrich_message(exception, smallest_failure), stacktrace)
    end
  end

  defp enrich_message(exception, %Property.Failure{} = smallest_failure) do
    message = exception.message <> "\n\n" <> inspect(smallest_failure)
    %{exception | message: message}
  end

  defp find_smallest_failure(tree, max_depth) do
    find_smallest_failure(tree.children, _smallest = tree.root, max_depth)
  end

  defp find_smallest_failure(_nodes, smallest, _max_depth = 0) do
    smallest
  end

  defp find_smallest_failure(nodes, smallest, max_depth) do
    if Enum.empty?(nodes) do
      smallest
    else
      case Enum.take(nodes, 1) do
        [%LazyTree{root: %Property.Success{}}] ->
          find_smallest_failure(Stream.drop(nodes, 1), smallest, max_depth)
        [first_child] ->
          if Enum.empty?(first_child.children) do
            find_smallest_failure(Stream.drop(nodes, 1), first_child.root, max_depth)
          else
            find_smallest_failure(first_child.children, first_child.root, max_depth - 1)
          end
      end
    end
  end
end
