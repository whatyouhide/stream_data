defmodule Stream.DataTest do
  use ExUnit.Case, async: true

  alias Stream.Data

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
