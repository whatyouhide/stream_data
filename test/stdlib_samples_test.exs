defmodule StdlibSamplesTest do
  use ExUnit.Case, async: true

  import Stream.Data
  import PropertyTest

  test "my_starts_with?/1" do
    for_all(with bin1 <- binary(),
                 bin2 <- binary() do
      assert my_starts_with?(bin1 <> bin2, bin1)
    end)
  end

  defp my_starts_with?(a, "") when byte_size(a) > 0, do: false
  defp my_starts_with?(_, _), do: true
end
