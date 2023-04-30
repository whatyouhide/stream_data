defmodule StreamData.KernelTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :stdlib

  if Version.match?(System.version(), "~> 1.14") do
    # From https://github.com/elixir-lang/elixir/pull/12045.
    property "binary_slice/2 is always consistent with Enum.slice/2" do
      check all binary <- binary(),
                start <- integer(),
                stop <- integer(),
                step <- positive_integer() do
        expected =
          binary
          |> :binary.bin_to_list()
          |> Enum.slice(start..stop//step)
          |> :binary.list_to_bin()

        assert binary_slice(binary, start..stop//step) == expected
      end
    end

    property "binary_slice/3 is always consistent with Enum.slice/3" do
      check all binary <- binary(), start <- integer(), amount <- non_negative_integer() do
        expected =
          binary
          |> :binary.bin_to_list()
          |> Enum.slice(start, amount)
          |> :binary.list_to_bin()

        assert binary_slice(binary, start, amount) == expected
      end
    end
  end
end
