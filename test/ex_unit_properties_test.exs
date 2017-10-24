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

  describe "fail_eventually" do

    # test fail_eventually
    property "all integers are positive" do
      fail_eventually do
        check all n <- integer() do
          assert n >= 0
        end
      end
    end

    # test fail_eventually
    property "all lists have a head" do
      fail_eventually do
        check all l <- list_of(positive_integer()) do
          assert length(l) >= 0
          n = hd(l)
          assert n >= 0
        end
      end
    end

    # test fail_eventually will fail, because nothing fails inside
    property "all non negative integers are positive" do
      assert_raise(ExUnitProperties.NoGeneratedDataWithFailuresError, fn ->
        fail_eventually do
          check all n <- positive_integer() do
            assert n >= 0
          end
        end
      end)
    end

    # test fail_eventually, because nothing fails inside
    property "all nonempty lists have a head" do
      assert_raise(ExUnitProperties.NoGeneratedDataWithFailuresError, fn ->
        fail_eventually do
          check all l <- nonempty(list_of(positive_integer())) do
            assert length(l) >= 0
            n = hd(l)
            assert n >= 0
          end
        end
      end)
    end

  end
end
