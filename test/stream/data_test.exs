defmodule Stream.DataTest do
  use ExUnit.Case, async: true

  import Stream.Data

  alias Stream.Data.{
    LazyTree,
    Random,
  }

  defp for_many(data, count \\ 1000, fun) do
    data
    |> Stream.take(count)
    |> Enum.each(fun)
  end


  test "implementation of the Enumerable protocol" do
    integers = Enum.take(int(), 10)
    assert Enum.all?(integers, &is_integer/1)
  end

  test "new/1" do
    assert_raise FunctionClauseError, fn -> new(%{}) end
  end

  test "fixed/1" do
    for_many(fixed(:term), fn term ->
      assert term == :term
    end)
  end

  test "map/1" do
    data = map(int(1..5), &(-&1))
    for_many(data, fn int ->
      assert int in -1..-5
    end)
  end

  test "bind/2" do
    data = bind(int(1..5), &fixed(-&1))
    for_many(data, fn int ->
      assert int in -1..-5
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
      Enum.take(data, 1)
    end
  end

  test "int/1" do
    for_many(int(-10..10), fn int ->
      assert int in -10..10
    end)
  end

  test "resize/2" do
    data = new(fn seed, size ->
      case Random.uniform_in_range(1..2, seed) do
        1 -> LazyTree.pure(size)
        2 -> LazyTree.pure(-size)
      end
    end)

    for_many(resize(data, 10), fn int ->
      assert int in [-10, 10]
    end)
  end

  test "sized/1" do
    data = sized(fn size ->
      bind(boolean(), fn bool ->
        if bool do
          fixed(size)
        else
          fixed(-size)
        end
      end)
    end)

    for_many(data, fn int ->
      assert is_integer(int)
    end)
  end

  test "scale/2" do
    size_data = sized(&fixed(&1))
    data = scale(size_data, fn size -> size + 1000 end)
    for_many(data, fn int ->
      assert int >= 1000
    end)
  end

  test "frequency/1" do
    data = frequency([
      {1, fixed(:small_chance)},
      {100, fixed(:big_chance)},
    ])

    values = Enum.take(data, 1000)

    assert :small_chance in values
    assert :big_chance in values
    assert Enum.count(values, &(&1 == :small_chance)) < Enum.count(values, &(&1 == :big_chance))
  end

  test "one_of/1" do
    data = one_of([int(1..5), int(-1..-5)])

    for_many(data, fn int ->
      assert int in 1..5 or int in -1..-5
    end)
  end

  test "member_of/1" do
    for_many(member_of([1, 2, 3]), fn elem ->
      assert elem in [1, 2, 3]
    end)

    for_many(member_of(MapSet.new([1, 2, 3])), fn elem ->
      assert elem in [1, 2, 3]
    end)

    assert_raise RuntimeError, "cannot generate elements from an empty enumerable", fn ->
      Enum.take(member_of([]), 1)
    end
  end

  test "boolean/0" do
    for_many(boolean(), fn bool ->
      assert is_boolean(bool)
    end)
  end

  # TODO: int/0

  test "byte/0" do
    for_many(byte(), fn value ->
      assert value in 0..255
    end)
  end

  test "binary/0" do
    for_many(resize(binary(), 10), fn value ->
      assert is_binary(value)
      assert byte_size(value) in 0..10
    end)
  end

  test "list_of/1" do
    for_many(list_of(fixed(:term)), fn value ->
      assert is_list(value)
      assert Enum.all?(value, &(&1 == :term))
    end)
  end

  test "tuple/1" do
    for_many(tuple({int(-1..-10), int(1..10)}), fn value ->
      assert {int1, int2} = value
      assert int1 in -1..-10
      assert int2 in 1..10
    end)
  end

  # TODO: map_of/2
end
