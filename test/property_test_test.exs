defmodule PropertyTestTest do
  use ExUnit.Case, async: true

  import PropertyTest

  alias Stream.Data

  test "assert with" do
    for_all(with int1 <- Data.int(1..10),
                 int2 <- Data.int(1..10),
                 sum = int1 + int2 do
      assert sum > int1
      assert sum > int2
    end)
  end
end
