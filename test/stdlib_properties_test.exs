defmodule StdlibPropertiesTets do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :stdlib_properties

  # From https://github.com/elixir-lang/elixir/pull/6559
  property "String.replace* functions replace the whole string" do
    check all string <- string(:printable),
              replacement <- string(:printable) do
      assert String.replace(string, string, replacement) == replacement
      assert String.replace_prefix(string, string, replacement) == replacement
      assert String.replace_suffix(string, string, replacement) == replacement
    end
  end
end
