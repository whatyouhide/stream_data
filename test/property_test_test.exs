defmodule PropertyTestTest do
  use ExUnit.Case, async: true

  import PropertyTest

  alias Stream.Data

  test "assert with" do
    for_all(with int1 <- pos_int(),
                 int2 <- pos_int(),
                 sum = int1 + int2 do
      assert sum > int1
      assert sum > int2
    end)
  end

  defp pos_int() do
    Data.filter(Data.int(), &(&1 > 0))
  end
end
