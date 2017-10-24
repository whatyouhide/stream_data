defmodule ExUnitProperties do
  @moduledoc """
  Provides macros for property-based testing.

  This module provides a few macros that can be used for property-based testing. The core is `check/3`,
  which allows executing arbitrary tests on many pieces of generated data. Another one is
  `property/3`, which is meant as a utility to replace the `ExUnit.Case.test/3` macro when writing
  properties. The last one is `gen/3`, which can be used as syntactic sugar to build generators
  (see `StreamData` for other ways of building generators and for core generators).

  ## Overview of property-based testing

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

  This test highlights the method used to write such kind of tests: they're
  written by hand. The process usually consists of testing an expected output on
  a set of expected inputs. This works especially well for edge cases, but the
  robustness of this test could be improved. This is what property-based testing aims
  to solve. Property testing is based on two ideas:

    * specify a set of **properties** that a piece of code should satisfy
    * test those properties on a very large number of randomly generated data

  The point of specifying **properties** instead of testing manual scenarios is
  that properties should hold for all the data that the piece of code should be
  able to deal with, and in turn, this plays well with generating data at
  random. Writing properties has the added benefit of forcing the programmer to
  think about their code differently: they have to think about which are
  invariant properties that their code satisfies.

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
  hold. If a combination of randomly generated terms fails the body of the
  property, then `ExUnitProperties` tries to find the smallest set of random
  generated terms that still fails the property and reports that; this step is
  called shrinking.

  ### Shrinking

  Say that our `starts_with?/2` function blindly returns false when the second
  argument is the empty binary (such as `starts_with?("foo", "")`). It's likely
  that in 100 runs an empty binary will be generated and bound to `b`. When that
  happens, the body of the property fails but `a` is a randomly generated binary
  and this might be inconvenient: for example, `a` could be `<<0, 74, 192, 99,
  24, 26>>`. In this case, the `check/3` macro tries to **shrink** `a` to the
  smallest term that still fails the property (`b` is not shrunk because `""` is
  the smallest binary possible). Doing so will lead to `a = ""` and `b = ""`
  which is the "minimal" failing case for our function.

  The example above is a contrived example but shrinking is a very powerful tool
  that aims at taking the noise out of the failing data.

  For detailed information on shrinking, see also the "Shrinking" section in the
  documentation for `StreamData`.

  ## Resources on property-based testing

  There are many resources available online on property-based testing. An interesting
  read is the original paper that introduced QuickCheck, ["QuickCheck: A
  Lightweight Tool for Random Testing of Haskell
  Programs"](http://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf), a
  property-testing tool for the Haskell programming language. Another very
  useful resource especially geared towards Erlang and the BEAM is
  [propertesting.com](http://propertesting.com), a website created by Fred
  Hebert: it's a great explanation of property-based testing that includes many
  examples. Fred's website uses an Erlang property-based testing tool called
  [PropEr](https://github.com/manopapad/proper) but many of the things he talks
  about apply to `ExUnitProperties` as well.
  """

  alias ExUnit.AssertionError

  defmodule Error do
    defexception [:message]
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [property: 2, property: 3, check: 2, gen: 2,
          fail_eventually: 1]
      import StreamData
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

      use ExUnitProperties

      property "reversing a list doesn't change its length" do
        check all list <- list_of(integer()) do
          assert length(list) == length(:lists.reverse(list))
        end
      end

  """
  defmacro property(message, context \\ quote(do: _), contents) do
    ExUnit.plural_rule("property", "properties")

    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
            :ok
          end

        _ ->
          quote do
            try(unquote(contents))
            :ok
          end
      end

    context = Macro.escape(context)
    contents = Macro.escape(contents, unquote: true)

    quote bind_quoted: [context: context, contents: contents, message: message] do
      name = ExUnit.Case.register_test(__ENV__, :property, message, [:property])
      def unquote(name)(unquote(context)), do: unquote(contents)
    end
  end

  @doc """
  Syntactic sugar to create generators.

  This macro provides ad hoc syntax to write complex generators. Let's see a
  quick example to get a feel of how it works. Say we have a `User` struct:

      defmodule User do
        defstruct [:name, :email]
      end

  We can create a generator of users like this:

      email_generator = map({binary(), binary()}, fn left, right -> left <> "@" <> right end)
      gen all name <- binary(),
              email <- email_generator do
        %User{name: name, email: email}
      end

  Everything between `gen all` and `do` is referred to as **clauses**. Clauses
  are used to specify the values to generate to be used in the body. The newly
  created generator will generated values that are the return value of the
  `do` body for the generated values from the clauses.

  ### Clauses

  As seen in the example above, clauses can be of the following types:

    * value generation - they have the form `pattern <- generator` where `generator` must be a
      generator. These clauses take a value out of `generator` on each run and match it against
      `pattern`. Variables bound in `pattern` can be then used throughout subsequent clauses and
      in the `do` body. If `pattern` doesn't match a generated value, it's treated like a filter
      (see the "filtering" clauses described below).

    * filtering and binding - they have the form `expression`. If a filtering clause returns
      a truthy value, then the set of generated values that appear before the
      filtering clause is considered valid and generation continues. If the
      filtering clause returns a falsey value, then the current value is
      considered invalid and a new value is generated. Note that filtering
      clauses should not filter out too many times; in case they do, a
      `StreamData.FilterTooNarrowError` error is raised (same as `StreamData.filter/3`).
      Filtering clauses can be used also to assign variables: for example, `a = :foo` is a valid
      clause.

  The behaviour of the clauses above is similar to the behaviour of clauses in
  `Kernel.SpecialForms.for/1`.

  ### Body

  The return value of the body passed in the `do` block is what is ultimately
  generated by the generator return by this macro.

  ## Shrinking

  See the module documentation for more information on shrinking. Clauses affect
  shrinking in the following way:

    * filtering clauses affect shrinking like `filter/3`
    * value generation clauses affect shrinking similarly to `bind/2`

  """
  defmacro gen({:all, _meta, clauses} = _generation_clauses, [do: body] = _block) do
    compile(clauses, body)
  end

  defp compile(clauses, body) do
    quote do
      var!(generated_values, unquote(__MODULE__)) = []
      {:cont, data} = unquote(compile_clauses(clauses, body, _line = nil))
      data
    end
  end

  defp compile_clauses([], body, _line) do
    quote do
      var!(generated_values, unquote(__MODULE__)) =
        Enum.reverse(var!(generated_values, unquote(__MODULE__)))

      {:cont, StreamData.constant(unquote(body))}
    end
  end

  defp compile_clauses([{:<-, meta, [pattern, generator]} = clause | rest], body, _line) do
    line = meta[:line]

    quote generated: true, line: line do
      data =
        StreamData.bind_filter(unquote(generator), fn
          # TODO: support when
          unquote(pattern) = generated_value, tries_left ->
            var!(generated_values, unquote(__MODULE__)) =
              [
                {unquote(Macro.to_string(clause)), generated_value}
                | var!(generated_values, unquote(__MODULE__))
              ]

            unquote(compile_clauses(rest, body, line))

          other, _tries_left = 1 ->
            raise StreamData.FilterTooNarrowError, last_generated_value: {:value, other}

          _other, _tries_left ->
            :skip
        end)

      {:cont, data}
    end
  end

  defp compile_clauses([clause | rest], body, parent_line) do
    line =
      with {_, meta, _} when is_list(meta) <- clause,
           line when is_integer(line) <- Keyword.get(meta, :line) do
        line
      else
        _ -> parent_line
      end

    quote line: line do
      cond do
        unquote(clause) ->
          unquote(compile_clauses(rest, body, line))

        tries_left == 1 ->
          raise "foo"

        true ->
          :skip
      end
    end
  end

  @doc """
  Runs tests for a property.

  This macro provides ad hoc syntax to write properties. Let's see a quick
  example to get a feel of how it works:

      check all int1 <- integer(),
                int2 <- integer(),
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

  Check that all values generated by the `StreamData.integer/0` generator are
  integers:

      check all int <- integer() do
        assert is_integer(int)
      end

  Check that `String.starts_with?/2` and `String.ends_with?/2` always hold for
  concatenated strings:

      check all start <- binary(),
                finish <- binary(),
                concat = start <> finish do
        assert String.starts_with?(concat, start)
        assert String.ends_with?(concat, finish)
      end

  Check that `Kernel.in/2` returns `true` when checking if an element taken out
  of a list is in that same list (changing the number of runs):

      check all list <- list_of(integer()),
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
        # TODO: Use :rand.export_seed in Elixir master.
        # The value may be :undefined in a new process
        # though, which means we may need to generate one.
        initial_seed: {0, 0, ExUnit.configuration()[:seed]},
        initial_size: options[:initial_size] ||
          Application.fetch_env!(:stream_data, :initial_size),
        max_runs: options[:max_runs] || Application.fetch_env!(:stream_data, :max_runs),
        max_shrinking_steps: options[:max_shrinking_steps] ||
          Application.fetch_env!(:stream_data, :max_shrinking_steps)
      ]

      property =
        ExUnitProperties.gen all unquote_splicing(clauses) do
          fn ->
            try do
              unquote(body)
            rescue
              exception ->
                result = %{
                  exception: exception,
                  stacktrace: System.stacktrace(),
                  generated_values: var!(generated_values, unquote(__MODULE__))
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

      case StreamData.check_all(property, options, & &1.()) do
        {:ok, _result} ->
          :ok

        {:error, test_result} ->
          unquote(__MODULE__).__raise__(test_result)
      end
    end
  end

  def __raise__(test_result) do
    %{
      original_failure: original_failure,
      shrunk_failure: shrunk_failure,
      nodes_visited: nodes_visited
    } = test_result

    choose_error_and_raise(original_failure, shrunk_failure, nodes_visited)
  end

  defp choose_error_and_raise(_, %{exception: %AssertionError{}} = shrunk_failure, nodes_visited) do
    reraise enrich_assertion_error(shrunk_failure, nodes_visited), shrunk_failure.stacktrace
  end

  defp choose_error_and_raise(
         %{exception: %AssertionError{}} = original_failure,
         _,
         nodes_visited
       ) do
    reraise enrich_assertion_error(original_failure, nodes_visited), original_failure.stacktrace
  end

  defp choose_error_and_raise(_original_failure, shrunk_failure, nodes_visited) do
    formatted =
      indent(
        Exception.format_banner(:error, shrunk_failure.exception, shrunk_failure.stacktrace),
        "    "
      )

    message =
      "failed with generated values (after #{nodes_visited} attempt(s)):\n\n" <>
        "#{format_generated_values(shrunk_failure.generated_values)}\n\n" <> formatted

    reraise Error, [message: message], shrunk_failure.stacktrace
  end

  defp enrich_assertion_error(
         %{exception: exception, generated_values: generated_values},
         nodes_visited
       ) do
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
    case Enum.split_while(clauses_and_options, &(not Keyword.keyword?(&1))) do
      {_clauses, []} = result ->
        result

      {clauses, [options]} ->
        {clauses, options}
    end
  end

  @doc """
  Picks a random element generated by the `StreamData` generator `data`.

  This function uses the current ExUnit seed to generate a random term from `data`. The generation
  size (see the "Generation size" section in the documentation for `StreamData`) is chosen at
  random between in `1..100`. If you want finer control over the generation size, you can use
  functions like `StreamData.resize/2` to resize `data` or `StreamData.scale/2` to scale the
  generation size.

  ## Examples

      ExUnitProperties.pick(StreamData.integer())
      #=> -21

  """
  @spec pick(StreamData.t(a)) :: a when a: term()
  def pick(data) do
    exported_seed =
      case :rand.export_seed() do
        :undefined ->
          raise "the random seed is not set in the current process. Make sure to only call " <>
                  "pick/1 inside ExUnit tests"

        seed ->
          seed
      end

    seed = :rand.seed_s(exported_seed)
    {size, seed} = :rand.uniform_s(100, seed)
    %StreamData.LazyTree{root: root} = StreamData.__call__(data, seed, size)
    root
  end

  defmodule NoGeneratedDataWithFailuresError do
    defexception [:message]
  end

  @doc """
  The `fail_eventually` macro is used for negative testing and states that
  the property will fail eventually.

  For negative testing, we want to show that the system under test behaves properly
  when tested with illegal data. If we want to prove that the data will fail
  in every case, then it is sufficient to negate the assertions. But if only
  some of the data does not satify the assertions, then `fail_eventually` will
  ensure that at least once in each run of the property the assertions are not satisfied.

  `fail_eventually` detects all errors of `ExUnitProperties` and all ExUnit
  assertion errors.

  ## Examples

  The first examples shows that some integers are negative.

      property "all integers are positive" do
        fail_eventually do
          check all n <- integer() do
            assert n >= 0
          end
        end
      end

  The second example shows that some lists have no heads. In this case,
  the assignment `n = hd(l)` raises an exception and `l` is empty: the
  `ArgumentError` exception is caught during executing the property check, resulting
  in an `ExUnitProperties.Error`. This exception is caught by `fail_eventually`
  and lets the entire property succeed.

      property "not all lists have a head" do
        fail_eventually do
          check all l <- list_of(positive_integer()) do
            n = hd(l)
            assert n > 0
          end
        end
      end

  The third example shows a failing property because all generated values
  will satisfy the assertion: Positive integers are always greater
  or equal to 0.

      property "all positive integers are positive" do
        fail_eventually do
          check all n <- positive_integer() do
            assert n >= 0
          end
        end
      end
      #=>     ** (ExUnitProperties.NoGeneratedDataWithFailuresError) all tests succeeded, but should eventually fail
      #=> code: fail_eventually do
      #=> stacktrace:
      #=>   test/ex_unit_properites_test.exs:95: (test)

  """

  defmacro fail_eventually(block) do
    quote do
      try do
        unquote(block)
        raise NoGeneratedDataWithFailuresError, message: "all tests succeeded, but should eventually fail"
      rescue
        ExUnit.AssertionError -> {:ok, %{}}
        ExUnitProperties.Error -> {:ok, %{}}
      end
    end
  end

end
