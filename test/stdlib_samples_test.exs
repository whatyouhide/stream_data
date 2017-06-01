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
      assert my_starts_with?(bin1 <> bin2, bin1)
    end)
  end

  test "reverse/1" do
    for_all(with bin <- binary() do
      assert bin == String.reverse(String.reverse(bin))
    end)
  end

  defp my_starts_with?(_, ""), do: false
  defp my_starts_with?(_, _), do: true
end
