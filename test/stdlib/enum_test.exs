defmodule StreamData.EnumTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :stdlib

  # TODO: Make this unconditional when we depend on Elixir 1.13+.
  if function_exported?(Enum, :slide, 3) do
    describe "Enum.slide/3" do
      property "handles negative indices" do
        check all(
                list <- StreamData.list_of(StreamData.integer(), max_length: 100),
                {range, insertion_idx} <- slide_spec(list)
              ) do
          length = length(list)

          # TODO: When we depend on 1.12+, rewrite as:
          # negative_range = (range.first - length)..(range.last - length)//1
          negative_range = %Range{
            first: range.first - length,
            last: range.last - length,
            step: 1
          }

          assert Enum.slide(list, negative_range, insertion_idx) ==
                   Enum.slide(list, range, insertion_idx)
        end
      end

      property "matches behavior for lists, ranges, and sets" do
        range = 0..31
        list = Enum.to_list(range)
        set = MapSet.new(list)

        check all({slide_range, insertion_idx} <- slide_spec(list)) do
          # As of Elixir 1.13, the map implementation underlying a MapSet
          # maintains the pairs in order below 32 elements.
          # If this ever stops being true, we can keep the test for
          # list vs. range but drop the test for list vs. set.
          slide = &Enum.slide(&1, slide_range, insertion_idx)
          assert slide.(list) == slide.(range)
          assert slide.(list) == slide.(set)
        end
      end

      property "matches behavior for lists of pairs and maps" do
        # As of Elixir 1.13, the map implementation maintains the pairs
        # in order below 32 elements.
        # If this ever stops being true, we can drop this test.
        range = 0..31
        zipped_list = Enum.zip(range, range)
        map = Map.new(zipped_list)

        check all({slide_range, insertion_idx} <- slide_spec(zipped_list)) do
          slide = &Enum.slide(&1, slide_range, insertion_idx)
          assert slide.(zipped_list) == slide.(map)
        end
      end

      # Generator for valid slides on the input list
      # Generates values of the form:
      #   {range_to_slide, insertion_idx}
      # ...such that the two arguments are always valid on the given list.
      defp slide_spec(list) do
        max_idx = max(0, length(list) - 1)

        StreamData.bind(StreamData.integer(0..max_idx), fn first ->
          StreamData.bind(StreamData.integer(first..max_idx), fn last ->
            allowable_insertion_idxs_at_end =
              if last < max_idx do
                [StreamData.integer((last + 1)..max_idx)]
              else
                []
              end

            allowable_insertion_idxs =
              [StreamData.integer(0..first)] ++ allowable_insertion_idxs_at_end

            StreamData.bind(one_of(allowable_insertion_idxs), fn insertion_idx ->
              StreamData.constant({first..last, insertion_idx})
            end)
          end)
        end)
      end
    end
  end
end
