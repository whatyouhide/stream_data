defmodule PropertyTest do
  @moduledoc """
  Provides macros for property testing.

  This module provides two main macros that can be used for property testing.
  The core is `check/3`, which allows to execute arbitrary tests on many pieces
  of generated data. The other macro that is provided is `property/3`, which is
  meant as a utility to replace the `ExUnit.Case.test/3` macro when writing
  properties. Generators to be used when writing properties can be found in the
  `StreamData` module.

  ## Overview of property testing

  One of the most common ways of writing tests (in Elixir and many other
  languages) is to write tests by hand. For example, say that we want to write a
  `starts_with?/2` function that takes two binaries and returns `true` if the
  first starts with the second and `false` otherwise. We would likely test such
  function with something like this:

      test "starts_with?/2" do
        assert starts_with?("foo", "f")
        refute starts_with?("foo", "b")
        assert starts_with?("foo", "")
        assert starts_with?("", "")
        refute starts_with?("", "something")
      end

  This test  highlights the method used to write such kind of tests: they're
  written from the developer by hand. The process usually consists in testing an
  expected output on a set of expected inputs. This works especially well for
  edge cases but the robustness of this test could be improved. This is what
  property testing aims to solve. Property testing is based on two ideas:

    * specify a set of **properties** that a piece of code should satisfy
    * test those properties on a very large number of randomly generated data

  The point of specifying **properties** instead of testing manual scenarios is
  that properties should hold for all the data that the piece of code should be
  able to deal with, and in turn this plays well with generating data at random.
  Writing properties has the added benefit of forcing the programmer to think
  about their code differently: they have to think about which are invariant
  properties that their code satisfies.

  To go back to the `starts_with?/2` example above, let's come up with a
  property that this function should hold. Since we know that the `Kernel.<>/2`
  operator concatenates two binaries, we can say that a property of
  `starts_with?/2` is that the concatenation of binaries `a` and `b` always
  starts with `a`. This is easy to model as a property using the `check/3` macro
  from this module and generators taken from the `StreamData` module:

      test "starts_with?/2" do
        check all a <- StreamData.binary(),
                  b <- StreamData.binary() do
          assert starts_with?(a <> b, a)
        end
      end

  When run, this piece of code will generate a random binary and assign it to
  `a`, do the same for `b`, and then run the assertion. This step will be
  repeated for a large number of times (`100` by default, but it's
  configurable), hence generating many combinations of random `a` and `b`. If
  the body passes for all the generated data, then we consider the property to
  hold. If a combination of random generated terms fails the body of the
  property, then `PropertyTest` tries to find the smallest set of random
  generated terms that still fails the property and reports that; this step is
  called shrinking.

  ### Shrinking

  Say that our `starts_with?/2` function blindly returns false when the second
  argument is the empty binary (such as `starts_with?("foo", "")`). It's likely
  that in 100 runs an empty binary will be generated and bound to `b`. When that
  happens, the body of the property fails but `a` is a random generated binary
  and this might be inconvenient: for example, `a` could be `<<0, 74, 192, 99,
  24, 26>>`. In this case, the `check/3` macro tries to **shrink** `a` to the
  smallest term that still fails the property (`b` is not shrunk because `""` is
  the smallest binary possible). Doing so will lead to `a = ""` and `b = ""`
  which is the "minimal" failing case for our function.

  The example above is a contrived example but shrinking is a very powerful tool
  that aims at taking the noise out of the failing data.

  For detailed information on shrinking, see also the "Shrinking" section in the
  documentation for `StreamData`.

  ## Resources on property testing

  There are many resources available online on property testing. An interesting
  read is the original paper that introduced QuickCheck, ["QuickCheck: A
  Lightweight Tool for Random Testing of Haskell
  Programs"](http://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf), a
  property-testing tool for the Haskell programming language. Another very
  useful resource especially geared towards Erlang and the BEAM is
  [propertesting.com](http://propertesting.com), a website created by Fred
  Hebert: it's a great explanation of property testing that includes many
  examples. Fred's website uses an Erlang property testing tool called
  [PropEr](https://github.com/manopapad/proper) but many of the things he talks
  about apply to `PropertyTest` as well.
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
    {clauses, options} = split_clauses_and_options(clauses_and_options)

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

  defp choose_error_and_raise(_original_failure, shrunk_failure, nodes_visited) do
    formatted = indent(Exception.format_banner(:error, shrunk_failure.exception, shrunk_failure.stacktrace), "    ")
    message =
      "failed with generated values (after #{nodes_visited} attempt(s)):\n\n" <>
      "#{format_generated_values(shrunk_failure.generated_values)}\n\n" <>
      formatted
    reraise Error, [message: message], shrunk_failure.stacktrace
  end

  defp enrich_assertion_error(%{exception: exception, generated_values: generated_values}, nodes_visited) do
    message =
      "Failed with generated values (after #{nodes_visited} attempt(s)):\n\n" <>
      indent(format_generated_values(generated_values), "    ") <>
      if(is_binary(exception.message), do: "\n\n" <> exception.message, else: "")

    %{exception | message: message}
  end

  defp format_generated_values(values) do
    Enum.map_join(values, "\n\n", fn {gen_string, value} ->
      gen_string <> "\n#=> " <> inspect(value)
    end)
  end

  defp indent(string, indentation) do
    indentation <> String.replace(string, "\n", "\n" <> indentation)
  end

  defp split_clauses_and_options(clauses_and_options) do
    case Enum.split_while(clauses_and_options, &match?({:<-, _, _}, &1)) do
      {_clauses, []} = result ->
        result
      {clauses, [options]} ->
        {clauses, options}
    end
  end
end
