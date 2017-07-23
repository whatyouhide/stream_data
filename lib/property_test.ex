defmodule PropertyTest do
  @moduledoc """
  Provides macros for property testing.
  """

  # TODO: moduledoc (overview of ptesting, shrinking)

  defmodule Error do
    defexception [:message]

    def exception(test_result) when is_map(test_result) do
      %__MODULE__{message: format_message(test_result)}
    end

    defp format_message(%{original_failure: original_failure, shrinked_failure: shrinked_failure, nodes_visited: nodes_visited}) do
      formatted_original = Exception.format_banner(:error, original_failure.exception, original_failure.stacktrace)
      formatted_original_indented = "  " <> String.replace(formatted_original, "\n", "\n  ")

      formatted_shrinked = Exception.format_banner(:error, shrinked_failure.exception, shrinked_failure.stacktrace)
      formatted_shrinked_indented = "  " <> String.replace(formatted_shrinked, "\n", "\n  ")

      formatted_values = "  " <> Enum.map_join(shrinked_failure.generated_values, "\n\n  ", fn {gen_string, value} ->
        gen_string <> "\n  #=> " <> inspect(value)
      end)

      """
      property failed. Original failure:

      #{formatted_original_indented}

      Failure from shrinked data:

      #{formatted_shrinked_indented}

      Shrinked generated values:

      #{formatted_values}

      (visited a total of #{nodes_visited} nodes)
      """
    end
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
      name = ExUnit.Case.register_test(__ENV__, :property, message, [])
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

  ### Clauses

  As seen in the example above, clauses can be of three types:

    * value generation - they have the form `pattern <- generator` where
      `generator` must be a `StreamData` struct. These clauses take a value out
      of `generator` on each run and match it against `pattern`. Variables bound
      in `pattern` can be then used throughout subsequent clauses and in the
      `do` body.

    * binding - they have the form `pattern = expression`. They are exactly like
      assignment through the `=` operator: if `pattern` doesn't match
      `expression`, an error is raised. They can be used to bind values for use
      in subsequent clauses and in the `do` block.

    * filtering - they have the form `expression`. If a filtering clause returns
      a truthy value, then the set of generated values that appear before the
      filtering clause is considered valid and the execution of the current run
      is continued. If the filtering clause returns a falsey value, then the
      current run is considered invalid and a new run is started. Note that
      filtering clauses should not filter out too many times; in case they do, a
      `StreamData.FilterTooNarrowError` error is raised.

  ### Body

  The body passed in the `do` block is where you test that the property holds
  for the generated values. The body is just like the body of a test: use
  `ExUnit.Assertions.assert/2` (and friends) to assert whatever you want.

  ## Shrinking

  See the module documentation for more information on shrinking. Clauses affect
  shrinking in the following way:

    * binding clauses don't affect shrinking
    * filtering clauses affect shrinking like `StreamData.filter/3`
    * value generation clauses affect shrinking similarly to `StreamData.bind/2`

  ## Examples

  Check that all values generated by the `StreamData.int/0` generator are
  integers:

      check all int <- int() do
        assert is_integer(int)
      end

  Check that `String.starts_with?/2` and `String.ends_with?/2` always holds for
  concatenated strings:

      check all start <- binary(),
                end <- binary(),
                concat = start <> end do
        assert String.starts_with?(concat, start)
        assert String.ends_with?(concat, end)
      end

  Check that `Kernel.in/2` returns `true` when checking if an element taken out
  of a list is in that same list:

      check all list <- list_of(int()),
                member <- member_of(list) do
        assert member in list
      end

  """
  defmacro check({:all, _meta, clauses} = _generation_clauses, [do: body] = _block) when is_list(clauses) do
    quote do
      options = [
        initial_seed: {0, 0, ExUnit.configuration()[:seed]},
      ]

      case StreamData.check_all(_property = unquote(compile(clauses, body)), options, &(&1.())) do
        {:ok, _result} -> :ok
        {:error, result} -> raise Error, result
      end
    end
  end

  defp compile(clauses, body) do
    quote do
      var!(generated_values) = []
      {:cont, data} = unquote(compile_clauses(clauses, body))
      data
    end
  end

  defp compile_clauses([], body) do
    quote do
      generated_values = Enum.reverse(var!(generated_values))

      data = StreamData.constant(fn ->
        try do
          unquote(body)
        rescue
          exception ->
            {:error, %{exception: exception, stacktrace: System.stacktrace(), generated_values: generated_values}}
        else
          _result ->
            {:ok, nil}
        end
      end)

      {:cont, data}
    end
  end

  defp compile_clauses([{:<-, _meta, [pattern, generator]} = clause | rest], body) do
    quote do
      data = StreamData.bind_filter(unquote(generator), fn unquote(pattern) = generated_value ->
        var!(generated_values) = [{unquote(Macro.to_string(clause)), generated_value} | var!(generated_values)]
        unquote(compile_clauses(rest, body))
      end)

      {:cont, data}
    end
  end

  defp compile_clauses([{:=, _meta, [_left, _right]} = assignment | rest], body) do
    quote do
      unquote(assignment)
      unquote(compile_clauses(rest, body))
    end
  end

  defp compile_clauses([clause | rest], body) do
    quote do
      if unquote(clause) do
        unquote(compile_clauses(rest, body))
      else
        :skip
      end
    end
  end
end
