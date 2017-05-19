defmodule GeneratorsTest do
  use ExUnit.Case, async: true

  alias Stream.Data

  test "int" do
    assert (Data.int() |> Enum.take(10) |> Enum.all?(&is_integer/1))
  end

  test "binary" do
    assert (Data.binary() |> Enum.take(10) |> Enum.all?(&is_binary/1))
  end
end
