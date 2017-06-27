defmodule Stream.DataTest do
  use ExUnit.Case, async: true

  import Stream.Data

  alias Stream.Data.LazyTree

  test "new/1" do
    assert_raise FunctionClauseError, fn -> new(%{}) end
  end

  test "implementation of the Enumerable protocol" do
    integers = Enum.take(int(), 10)
    assert Enum.all?(integers, &is_integer/1)
  end

  test "resize/2" do
    data = new(fn seed, size ->
      case :rand.uniform_s(2, seed) do
        {1, _seed} -> LazyTree.pure(size)
        {2, _seed} -> LazyTree.pure(-size)
      end
    end)

    values =
      data
      |> resize(10)
      |> Enum.take(1000)

    assert Enum.all?(values, &(&1 in [-10, 10]))
  end

  test "fmap/1" do
    values =
      int(1..5)
      |> fmap(&(-&1))
      |> Enum.take(1000)

    Enum.each(values, fn value ->
      assert value in -1..-5
    end)
  end

  test "filter/2,3" do
    values =
      int(-5..5)
      |> filter(&(&1 > 0), 990)
      |> Enum.take(1000)

    assert length(values) <= 1000

    Enum.each(values, fn value ->
      assert value in 1..5
    end)

    data = filter(fixed(:term), &is_binary/1, 10)
    assert_raise Stream.Data.FilterTooNarrowError, fn ->
      Enum.take(data, 10)
    end
  end

  test "one_of/1" do
    data = one_of([int(1..5), int(-1..-5)])
    values = Enum.take(data, 1000)
    Enum.each(values, fn value ->
      assert value in 1..5 or value in -1..-5
    end)
  end

  test "fixed/1" do
    values = Enum.take(fixed(:term), 1000)
    Enum.each(values, fn value ->
      assert value == :term
    end)
  end

  test "boolean/0" do
    values = Enum.take(boolean(), 1000)
    Enum.each(values, fn value ->
      assert is_boolean(value)
    end)
  end

  test "int/1" do
    values = Enum.take(int(-10..10), 1_000)
    Enum.each(values, fn value ->
      assert is_integer(value)
      assert value in -10..10
    end)
  end

  test "byte/0" do
    values = Enum.take(byte(), 1000)
    Enum.each(values, fn value ->
      assert value in 0..255
    end)
  end

  test "binary/0" do
    values =
      binary()
      |> resize(10)
      |> Enum.take(1000)

    Enum.each(values, fn value ->
      assert is_binary(value)
      assert byte_size(value) in 0..10
    end)
  end

  test "list/1" do
    values = Enum.take(list(fixed(:term)), 1000)
    Enum.each(values, fn value ->
      assert is_list(value)
      assert Enum.all?(value, &(&1 == :term))
    end)
  end

  test "tuple/1" do
    values = Enum.take(tuple({int(-1..-10), int(1..10)}), 1000)
    Enum.each(values, fn value ->
      assert {int1, int2} = value
      assert int1 in -1..-10
      assert int2 in 1..10
    end)
  end

  test "member/1" do
    values = Enum.take(member([1, 2, 3]), 1_000)
    Enum.each(values, fn value ->
      assert value in [1, 2, 3]
    end)

    values = Enum.take(member(MapSet.new([1, 2, 3])), 1_000)
    Enum.each(values, fn value ->
      assert value in [1, 2, 3]
    end)
  end
end
