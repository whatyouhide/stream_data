defmodule GeneratorsTest do
  use ExUnit.Case, async: true

  alias Stream.Data

  test "int" do
    assert (Data.int() |> Enum.take(10) |> Enum.all?(&is_integer/1))
  end
end
