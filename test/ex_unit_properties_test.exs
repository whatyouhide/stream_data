defmodule ExUnitPropertiesTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  test "gen all" do
    data =
      gen all list <- list_of(integer(), min_length: 1),
              elem <- member_of(list),
              elem != 5,
              elem_not_five = elem do
        {Integer.to_string(elem_not_five), list}
      end

    check all {string, list} <- data do
      assert is_binary(string)
      assert is_list(list)
      assert String.to_integer(string) != 5
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

      check all i <- integer(),
                string_i = Integer.to_string(i),
                max_runs: 10 do
        Agent.update(counter, &(&1 + 1))
        assert String.to_integer(string_i) == i
      end

      assert Agent.get(counter, &(&1)) == 10
    end

    property "runs the number of specified times" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all :ok <- :ok, max_runs: 10 do
        Agent.update(counter, &(&1 + 1))
        :ok
      end

      assert Agent.get(counter, &(&1)) == 10
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
end
