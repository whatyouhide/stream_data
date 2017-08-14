defmodule PropertyTestTest do
  use ExUnit.Case, async: true

  import PropertyTest

  property "shrinking" do
    assert_raise ExUnit.AssertionError, fn ->
      check all list <- list_of(int()) do
        assert 5 not in list
      end
    end
  end

  property "works with errors that are not assertion errors" do
    assert_raise PropertyTest.Error, fn ->
      check all tuple <- {:ok, nil} do
        :ok = tuple
      end
    end
  end

  property "runs the number of specified times" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    check all :ok <- :ok, max_runs: 10 do
      Agent.update(counter, &(&1 + 1))
      :ok
    end

    assert Agent.get(counter, &(&1)) == 10
  end

  describe "check all" do
    property "can do assignment" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      check all i <- int(),
                string_i = Integer.to_string(i),
                max_runs: 10 do
        Agent.update(counter, &(&1 + 1))
        assert String.to_integer(string_i) == i
      end

      assert Agent.get(counter, &(&1)) == 10
    end
  end
end
