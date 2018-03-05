defmodule StreamData.KeywordTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :stdlib

  # From https://github.com/elixir-lang/elixir/issues/7420
  property "Keyword.merge/2 and Keyword.merge/3 keeps duplicate entries from rhs" do
    check all list <- list_of({atom(:alphanumeric), integer()}) do
      double = list ++ list
      assert Keyword.merge(double, list) == list
      assert Keyword.merge(list, double) == double
      assert Keyword.merge(double, list, fn _, _, v2 -> v2 end) == list
      assert Keyword.merge(list, double, fn _, _, v2 -> v2 end) == double
    end
  end
end
