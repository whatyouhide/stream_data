defmodule Stream.DataTest do
  use ExUnit.Case, async: true

  test "new/1" do
    assert_raise FunctionClauseError, fn -> Stream.Data.new(%{}) end
  end

  test "implementation of the Enumerable protocol" do
    integers = Enum.take(Stream.Data.int(), 10)
    assert Enum.all?(integers, &is_integer/1)
  end

  test "resize/2" do
    data = Stream.Data.new(fn seed, size ->
      case :rand.uniform_s(2, seed) do
        {1, _seed} -> size
        {2, _seed} -> -size
      end
    end)
    values = Enum.take(Stream.Data.resize(data, 10), 1000)

    assert Enum.all?(values, &(&1 in [-10, 10]))
  end

  test "fmap/1" do
    [integer] =
      data(1..5)
      |> Stream.Data.fmap(&(-&1))
      |> Enum.take(1)

    assert integer in -1..-5
  end

  test "one_of/1" do
    data = Stream.Data.one_of([data(1..5), Stream.Data.fmap(data(1..5), &(-&1))])
    values = Enum.take(data, 10_000)
    Enum.each(values, fn value ->
      assert value in 1..5 or value in -1..-5
    end)
  end

  test "fixed/1" do
    values = Enum.take(Stream.Data.fixed(:term), 1_000)
    Enum.each(values, fn value ->
      assert value == :term
    end)
  end

  test "boolean/0" do
    values = Enum.take(Stream.Data.boolean(), 1_000)
    Enum.each(values, fn value ->
      assert is_boolean(value)
    end)
  end

  test "member/1" do
    values = Enum.take(Stream.Data.member([1, 2, 3]), 1_000)
    Enum.each(values, fn value ->
      assert value in [1, 2, 3]
    end)

    values = Enum.take(Stream.Data.member(MapSet.new([1, 2, 3])), 1_000)
    Enum.each(values, fn value ->
      assert value in [1, 2, 3]
    end)
  end

  defp data(range) do
    Stream.Data.new(fn seed, _size -> Stream.Data.Random.uniform_in_range(range, seed) end)
  end
end
