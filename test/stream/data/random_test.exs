defmodule Stream.Data.RandomTest do
  use ExUnit.Case, async: true

  alias Stream.Data.Random

  test "new_seed/1" do
    assert Random.new_seed(1) == Random.new_seed(1)
  end

  test "split/1" do
    seed = Random.new_seed(1)
    assert {_seed1, _seed2} = Random.split(seed)
  end

  test "uniform_in_range/2" do
    Enum.each(1..1_000, fn _ ->
      seed = Random.new_seed(1)
      int1 = Random.uniform_in_range(-100..100, seed)
      int2 = Random.uniform_in_range(100..-100, seed)
      assert int1 in -100..100
      assert int1 == int2
    end)
  end
end
