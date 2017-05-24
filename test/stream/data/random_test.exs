defmodule Stream.Data.RandomTest do
  use ExUnit.Case, async: true

  alias Stream.Data.Random

  test "split/1" do
    seed = :rand.seed_s(:exs64)
    assert {_seed1, _seed2} = Random.split(seed)
  end

  test "uniform_in_range/2" do
    Enum.each(1..1_000, fn _ ->
      seed = :rand.seed_s(:exs64)
      int1 = Random.uniform_in_range(-100..100, seed)
      int2 = Random.uniform_in_range(100..-100, seed)
      assert int1 in -100..100
      assert int1 == int2
    end)
  end

  test "boolean/1" do
    Enum.each(1..1_000, fn _ ->
      seed = :rand.seed_s(:exs64)
      assert is_boolean(Random.boolean(seed))
    end)
  end
end
