defmodule StdlibSamplesTest do
  use ExUnit.Case, async: true

  import Stream.Data
  import PropertyTest

  test ":lists.reverse/1" do
    for_all(with list <- list(int()) do
      assert length(:lists.reverse(list)) == length(list)
      assert List.first(list) == List.last(:lists.reverse(list))
    end)
  end
end
