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

  test "String.starts_with?/1" do
    for_all(with bin1 <- binary(),
                 bin2 <- binary() do
      assert String.starts_with?(bin1 <> bin2, bin1)
    end)
  end
end
