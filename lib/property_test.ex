defmodule PropertyTest do
  @moduledoc """
  Provides macros for property testing.

  TODO: better overview of property testing and shrinking.
  """

  alias ExUnit.AssertionError

  defmodule Error do
    defexception [:message]
  end

  @doc """
  Defines a property and imports property-testing facilities in the body.

  This macro is very similar to `ExUnit.Case.test/3`, except that it denotes a
  "property". In the given body, all the functions exposed by `StreamData` are
  imported as well as `check/2`.

  When defining a test whose body only consists of one or more `check/2` calls,
  it's advised to use `property/3` so as to clearly denote and scope properties.
  Doing so will also improve reporting.

  ## Examples

    import PropertyTest

    property "reversing a list doesn't change its length" do
      check all list <- list_of(int()) do
        assert length(list) == length(:lists.reverse(list))
      end
    end

  """
  # TODO: is it fine to not support rescue/after stuff?
  defmacro property(message, context \\ quote(do: _), [do: block] = _body) do
    ExUnit.plural_rule("property", "properties")

    block =
      quote do
        import StreamData
        import unquote(__MODULE__), only: [check: 2]
        unquote(block)
      end

    context = Macro.escape(context)
    contents = Macro.escape(block, unquote: true)

    quote bind_quoted: [context: context, contents: contents, message: message] do
      name = ExUnit.Case.register_test(__ENV__, :property, message, [:property])
      def unquote(name)(unquote(context)), do: unquote(contents)
    end
  end

  @doc """
  Runs tests for a property.

  This macro provides ad hoc syntax to write properties. Let's see a quick
  example to get a feel of how it works:

      check all int1 <- int(),
                int2 <- int(),
                int1 > 0 and int2 > 0,
                sum = int1 + int2 do
        assert sum > int1
        assert sum > int2
      end

  Everything between `check all` and `do` is referred to as **clauses**. Clauses
  are used to specify the values to generate in order to test the properties.
  The actual tests that the properties hold live in the `do` block.

  Clauses work exactly like they work in the `StreamData.gen/2` macro.

  The body passed in the `do` block is where you test that the property holds
  for the generated values. The body is just like the body of a test: use
  `ExUnit.Assertions.assert/2` (and friends) to assert whatever you want.

  ## Options

    * `:initial_size` - (non-negative integer) the initial generation size used
      to start generating values. The generation size is then incremented by `1`
      on each iteration. See the "Generation size" section of the `StreamData`
      documentation for more information on generation size. Defaults to `1`.

    * `:max_runs` - (non-negative integer) the total number of generations to
      run. Defaults to `100`.

    * `:max_shrinking_steps` - (non-negative integer) the maximum numbers of
      shrinking steps to perform in case a failing case is found. Defaults to
      `100`.

    * `:max_generation_size` - (non-negative integer) the maximum generation
      size to reach. Note that the size is increased by one on each run. By
      default, the generation size is unbounded.

  ## Examples

  Check that all values generated by the `StreamData.int/0` generator are
  integers:

      check all int <- int() do
        assert is_integer(int)
      end

  Check that `String.starts_with?/2` and `String.ends_with?/2` always hold for
  concatenated strings:

      check all start <- binary(),
                end <- binary(),
                concat = start <> end do
        assert String.starts_with?(concat, start)
        assert String.ends_with?(concat, end)
      end

  Check that `Kernel.in/2` returns `true` when checking if an element taken out
  of a list is in that same list (changing the number of runs):

      check all list <- list_of(int()),
                member <- member_of(list),
                max_runs: 50 do
        assert member in list
      end

  """
  defmacro check({:all, _meta, clauses_and_options} = _generation_clauses, [do: body] = _block)
           when is_list(clauses_and_options) do
    {options, clauses} = Enum.split_with(clauses_and_options, &match?({key, _value} when is_atom(key), &1))

    quote do
      options = unquote(options)
      options = [
        initial_seed: {0, 0, ExUnit.configuration()[:seed]},
        initial_size: options[:initial_size] || Application.fetch_env!(:stream_data, :initial_size),
        max_runs: options[:max_runs] || Application.fetch_env!(:stream_data, :max_runs),
        max_shrinking_steps: options[:max_shrinking_steps] || Application.fetch_env!(:stream_data, :max_shrinking_steps),
      ]

      property =
        StreamData.gen all unquote_splicing(clauses) do
          fn ->
            try do
              unquote(body)
            rescue
              exception ->
                result = %{
                  exception: exception,
                  stacktrace: System.stacktrace(),
                  generated_values: var!(generated_values, StreamData),
                }
                {:error, result}
            else
              _result ->
                {:ok, nil}
            end
          end
        end

      property =
        if max_size = options[:max_generation_size] do
          StreamData.scale(property, &min(max_size, &1))
        else
          property
        end

      case StreamData.check_all(property, options, &(&1.())) do
        {:ok, _result} ->
          :ok
        {:error, test_result} ->
          PropertyTest.__raise__(test_result)
      end
    end
  end

  def __raise__(test_result) do
    %{original_failure: original_failure,
      shrunk_failure: shrunk_failure,
      nodes_visited: nodes_visited} = test_result
    choose_error_and_raise(original_failure, shrunk_failure, nodes_visited)
  end

  defp choose_error_and_raise(_, %{exception: %AssertionError{}} = shrunk_failure, nodes_visited) do
    reraise enrich_assertion_error(shrunk_failure, nodes_visited), shrunk_failure.stacktrace
  end

  defp choose_error_and_raise(%{exception: %AssertionError{}} = original_failure, _, nodes_visited) do
    reraise enrich_assertion_error(original_failure, nodes_visited), original_failure.stacktrace
  end

  defp choose_error_and_raise(_original_failure, shrunk_failure, _nodes_visited) do
    formatted = indent(Exception.format(:error, shrunk_failure.exception, shrunk_failure.stacktrace))
    message = "failed with generated values:\n\n#{format_generated_values(shrunk_failure.generated_values)}\n\n#{formatted}"
    raise Error, message: message
  end

  defp enrich_assertion_error(%{exception: exception, generated_values: generated_values}, _nodes_visited) do
    message =
      "Failed with generated values:\n\n#{format_generated_values(generated_values)}" <>
      if(is_binary(exception.message), do: "\n\n" <> exception.message, else: "")

    %{exception | message: message}
  end

  defp format_generated_values(values) do
    formatted =
      Enum.map_join(values, "\n\n  ", fn {gen_string, value} ->
        gen_string <> "\n  #=> " <> inspect(value)
      end)
    "  " <> formatted
  end

  defp indent(string), do: "  " <> String.replace(string, "\n", "\n" <> "  ")
end
