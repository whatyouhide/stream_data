defmodule ExUnitPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  describe "gen all" do
    test "supports generation and filtering clauses" do
      data =
        gen all [_ | _] = list <- list_of(integer()),
                elem <- member_of(list),
                elem != 5,
                elem_not_five = elem do
          {Integer.to_string(elem_not_five), list}
        end

      # Let's make sure that "5" isn't common at all by making the smallest size for this generator
      # be 10.
      data = scale(data, &max(&1, 10))

      check all {string, list} <- data do
        assert is_binary(string)
        assert is_list(list)
        assert String.to_integer(string) != 5
      end
    end

    test "treats non-matching patterns in <- clauses as filters" do
      data =
        gen all :non_boolean <- boolean() do
          :ok
        end

      assert_raise StreamData.FilterTooNarrowError, fn ->
        Enum.take(data, 1)
      end
    end

    test "supports do keyword syntax" do
      gen(all _boolean <- boolean(), do: :ok)

      data =
        gen(
          all string <- binary(),
              list <- list_of(integer()),
              do: {string, list}
        )

      check all {string, list} <- data do
        assert is_binary(string)
        assert is_list(list)
      end
    end

    test "errors out if the first clause is not a generator" do
      message =
        "\"gen all\" and \"check all\" clauses must start with a generator (<-) clause, " <>
          "got: a = 1"

      assert_raise ArgumentError, message, fn ->
        Code.compile_quoted(
          quote do
            gen(all a = 1, _ <- integer, do: :ok)
          end
        )
      end

      message =
        "\"gen all\" and \"check all\" clauses must start with a generator (<-) clause, " <>
          "got: true"

      assert_raise ArgumentError, message, fn ->
        Code.compile_quoted(
          quote do
            gen(all true, _ <- integer, do: :ok)
          end
        )
      end
    end
  end

  describe "property" do
    property "supports rescue" do
      raise "some error"
    rescue
      exception in [RuntimeError] ->
        assert Exception.message(exception) == "some error"
    end

    property "supports catch" do
      throw(:some_error)
    catch
      :throw, term ->
        assert term == :some_error
    end
  end

  describe "check all" do
    property "can do assignment" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all i <- integer(), string_i = Integer.to_string(i), max_runs: 10 do
        Agent.update(counter, &(&1 + 1))
        assert String.to_integer(string_i) == i
      end

      assert Agent.get(counter, & &1) == 10
    end

    property "runs the number of specified times" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all :ok <- :ok, max_runs: 10 do
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      assert Agent.get(counter, & &1) == 10
    end

    property "runs for the specified number of milliseconds" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all :ok <- :ok, max_runs: :infinity, max_run_time: 100 do
        Process.sleep(25)
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      assert Agent.get(counter, & &1) in 3..5
    end

    property "ends at :max_runs if it ends before :max_run_time" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all :ok <- :ok, max_runs: 5, max_run_time: 500 do
        Process.sleep(1)
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      assert Agent.get(counter, & &1) == 5
    end

    property "ends at :max_run_time if it ends before :max_runs" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all :ok <- :ok, max_runs: 100_000, max_run_time: 100 do
        Process.sleep(25)
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      assert Agent.get(counter, & &1) in 3..5
    end

    test "raises an error instead of running an infinite loop" do
      message = ~r/both the :max_runs and :max_run_time options are set to :infinity/

      assert_raise ArgumentError, message, fn ->
        check all :ok <- :ok, max_runs: :infinity, max_run_time: :infinity do
          :ok
        end
      end
    end

    property "works with errors that are not assertion errors" do
      assert_raise ExUnitProperties.Error, fn ->
        check all tuple <- {:ok, nil} do
          :ok = tuple
        end
      end
    end

    property "shrinking" do
      assert_raise ExUnit.AssertionError, fn ->
        check all list <- list_of(integer()) do
          assert 5 not in list
        end
      end
    end

    test "supports do keyword syntax" do
      check all int <- integer(), do: assert(is_integer(int))

      check all a <- binary(),
                b <- binary(),
                do: assert(String.starts_with?(a <> b, a))

      check all int1 <- integer(),
                int2 <- integer(),
                sum = abs(int1) + abs(int2),
                max_runs: 25,
                do: assert(sum >= int1)
    end

    test "do keyword syntax passes in options" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all int <- integer(),
                max_runs: 25,
                do: Agent.update(counter, &(&1 + 1)) && assert(is_integer(int))

      assert Agent.get(counter, & &1) == 25
    end

    test "errors out if the first clause is not a generator" do
      message =
        "\"gen all\" and \"check all\" clauses must start with a generator (<-) clause, " <>
          "got: a = 1"

      assert_raise ArgumentError, message, fn ->
        Code.compile_quoted(
          quote do
            gen(all a = 1, _ <- integer, do: :ok)
          end
        )
      end

      message =
        "\"gen all\" and \"check all\" clauses must start with a generator (<-) clause, " <>
          "got: true"

      assert_raise ArgumentError, message, fn ->
        Code.compile_quoted(
          quote do
            gen(all true, _ <- integer, do: :ok)
          end
        )
      end
    end
  end

  if Version.compare(System.version(), "1.6.0-dev") in [:eq, :gt] do
    describe "pick/1" do
      test "when there's a random seed thanks to ExUnit setting it up" do
        integer = ExUnitProperties.pick(integer())
        assert is_integer(integer)
        assert integer in -100..100
      end

      test "raises when there's no random seed in the process dictionary" do
        {_pid, ref} =
          spawn_monitor(fn ->
            message = ~r/the random seed is not set in the current process/

            assert_raise RuntimeError, message, fn ->
              ExUnitProperties.pick(integer())
            end
          end)

        assert_receive {:DOWN, ^ref, _, _, _}
      end
    end
  end
end
