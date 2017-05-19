defmodule Stream.DataTest do
  use ExUnit.Case, async: true

  alias Stream.Data

  test "map/2" do
    elements =
      Data.int()
      |> Data.map(&abs/1)
      |> Enum.take(10_000)

    assert Enum.all?(elements, &(is_integer(&1) and &1 >= 0))
  end

  test "one_of/1" do
    elements =
      [Data.int(), Data.binary()]
      |> Data.one_of()
      |> Enum.take(10_000)

    assert Enum.any?(elements, &is_binary/1)
    assert Enum.any?(elements, &is_integer/1)
  end

  test "filter/2" do
    data = Data.new(generator(), validator())

    filter = fn elem ->
      elem > 0 && {:ok, Integer.to_string(elem)}
    end

    data = Data.filter(data, filter)
    for elem <- Enum.take(data, 3) do
      assert String.to_integer(elem) > 0
    end
  end

  defp generator() do
    fn seed, size ->
      {next, seed} = :rand.uniform_s(size * 2, seed)
      {next - size, seed}
    end
  end

  defp validator() do
    &(&1 in -10..10)
  end
end
