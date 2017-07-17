ExUnit.start()

defmodule StdlibSamplesTest do
  use ExUnit.Case, async: true

  import StreamData
  import PropertyTest

  test "my_starts_with?/1" do
    check all bin1 <- binary(),
              bin2 <- binary() do
      assert my_starts_with?(bin1 <> bin2, bin1)
    end
  end

  test "element not in list" do
    check all list <- list_of(int()) do
      assert 22 not in list
    end
  end

  test "something with filter" do
    check all a <- int(),
              b <- int(),
              a + b >= 0,
              sum = a + b do
      assert sum > 0
    end
  end

  test "non-assertion error" do
    check all tuple <- tuple({constant(:ok), int()}) do
      {:ok, :not_an_int} = tuple
    end
  end

  defp my_starts_with?(a, "") when byte_size(a) > 0, do: false
  defp my_starts_with?(_, _), do: true
end
