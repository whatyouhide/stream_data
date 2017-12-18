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
  end

  describe "error handling" do
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

      # I'm explicitly passing max_runs: :not_set to override the project-wide
      # config in the `mix.exs` file of `max_runs: 100`.
      check all :ok <- :ok, max_runs: :not_set, max_run_time: 250 do
        :timer.sleep(1)
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      total_runs = Agent.get(counter, & &1)
      # I want to make sure there are more than 100 executions since that's the
      # default number of runs. Because of variation of runtimes of the other
      # code in that property, we shouldn't make assertions that are too
      # specific.
      assert total_runs > 100
      assert total_runs < 250
    end

    property "ends at either max_runs or max_run_time, whichever is first" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all :ok <- :ok, max_runs: 5, max_run_time: 100 do
        :timer.sleep(1)
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      # Because the `max_runs` is less than `max_run_time`, we should only
      # execute the property test 5 times.
      assert Agent.get(counter, & &1) == 5

      check all :ok <- :ok, max_runs: 25, max_run_time: 10 do
        :timer.sleep(1)
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      # Because `max_run_time` is less than `max_runs` in this case because
      # we're sleeping for 1ms every run, we should stop at that `max_run_time`.
      total_runs = Agent.get(counter, & &1)
      assert total_runs > 5
      assert total_runs <= 15
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
