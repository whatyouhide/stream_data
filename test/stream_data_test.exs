# TODO: test shrinking

defmodule StreamDataTest do
  use ExUnit.Case, async: true

  import StreamData

  alias StreamData.LazyTree

  test "implementation of the Enumerable protocol" do
    values = Enum.take(Stream.zip(integer(), boolean()), 10)
    Enum.each(values, fn {int, boolean} ->
      assert is_integer(int)
      assert is_boolean(boolean)
    end)
  end

  test "terms used as generators" do
    for_many(map(:foo, &(&1)), fn term ->
      assert term == :foo
    end)

    data = map({integer(), boolean()}, &(&1))
    for_many(data, fn {int, boolean} ->
      assert is_integer(int)
      assert is_boolean(boolean)
    end)

    data = map({:ok, integer()}, &(&1))
    for_many(data, fn {atom, int} ->
      assert atom == :ok
      assert is_integer(int)
    end)
  end

  test "constant/1" do
    for_many(constant(:term), fn term ->
      assert term == :term
    end)
  end

  test "map/1" do
    data = map(integer(1..5), &(-&1))
    for_many(data, fn int ->
      assert int in -1..-5
    end)
  end

  test "bind_filter/2" do
    require Integer

    data =
      bind_filter(integer(1..5), fn int ->
        if Integer.is_even(int) do
          {:cont, constant(int)}
        else
          :skip
        end
      end, 1000)

    for_many(data, fn int ->
      assert int in 1..5
      assert Integer.is_even(int)
    end)
  end

  test "bind/2" do
    data = bind(integer(1..5), &constant(-&1))
    for_many(data, fn int ->
      assert int in -1..-5
    end)
  end

  test "filter/2,3" do
    values =
      integer(0..10_000)
      |> filter(&(&1 > 0))
      |> Enum.take(1000)

    assert length(values) <= 1000

    Enum.each(values, fn value ->
      assert value in 0..10_000
    end)

    data = filter(constant(:term), &is_binary/1, 10)
    assert_raise StreamData.FilterTooNarrowError, ~r/too many \(10\) consecutive elements were filtered out/, fn ->
      Enum.take(data, 1)
    end

    data = filter(constant(:term), &is_binary/1, 2)
    assert_raise StreamData.FilterTooNarrowError, ~r/too many \(2\) consecutive elements were filtered out/, fn ->
      Enum.take(data, 1)
    end
  end

  test "integer/1" do
    for_many(integer(-10..10), fn int ->
      assert int in -10..10
    end)
  end

  test "resize/2" do
    generator = fn seed, size ->
      case :rand.uniform_s(2, seed) do
        {1, _seed} -> LazyTree.constant(size)
        {2, _seed} -> LazyTree.constant(-size)
      end
    end

    for_many(resize(%StreamData{generator: generator}, 10), fn int ->
      assert int in [-10, 10]
    end)
  end

  test "sized/1" do
    data =
      sized(fn size ->
        bind(boolean(), fn bool ->
          if bool do
            constant(size)
          else
            constant(-size)
          end
        end)
      end)

    for_many(data, fn int ->
      assert is_integer(int)
    end)
  end

  test "scale/2" do
    size_data = sized(&constant(&1))
    data = scale(size_data, fn size -> size + 1000 end)
    for_many(data, fn int ->
      assert int >= 1000
    end)
  end

  test "frequency/1" do
    data =
      frequency([
        {1, constant(:small_chance)},
        {100, constant(:big_chance)},
      ])

    values = Enum.take(data, 1000)

    assert :small_chance in values
    assert :big_chance in values
    assert Enum.count(values, &(&1 == :small_chance)) < Enum.count(values, &(&1 == :big_chance))
  end

  test "one_of/1" do
    data = one_of([integer(1..5), integer(-1..-5)])

    for_many(data, fn int ->
      assert int in 1..5 or int in -1..-5
    end)
  end

  test "member_of/1" do
    for_many(member_of([1, 2, 3]), fn elem ->
      assert elem in [1, 2, 3]
    end)

    for_many(member_of(MapSet.new([1, 2, 3])), fn elem ->
      assert elem in [1, 2, 3]
    end)

    assert_raise RuntimeError, "cannot generate elements from an empty enumerable", fn ->
      Enum.take(member_of([]), 1)
    end
  end

  test "boolean/0" do
    for_many(boolean(), fn bool ->
      assert is_boolean(bool)
    end)
  end

  test "integer/0" do
    for_many(integer(), fn int ->
      assert is_integer(int)
      assert abs(int) < 1000
    end)
  end

  test "uniform_float/0" do
    for_many(uniform_float(), fn float ->
      assert is_float(float)
      assert float >= 0.0 and float <= 1.0
    end)
  end

  test "byte/0" do
    for_many(byte(), fn value ->
      assert value in 0..255
    end)
  end

  test "binary/1" do
    for_many(resize(binary(), 10), fn value ->
      assert is_binary(value)
      assert byte_size(value) in 0..10
    end)

    for_many(binary(length: 3), fn value ->
      assert is_binary(value)
      assert byte_size(value) == 3
    end)
  end

  test "bitstring/0" do
    for_many(resize(bitstring(), 10), fn value ->
      assert is_bitstring(value)
      assert bit_size(value) in 0..10
    end)

    for_many(bitstring(length: 3), fn value ->
      assert is_bitstring(value)
      assert bit_size(value) == 3
    end)
  end

  describe "list_of/2" do
    test "generates lists" do
      for_many(list_of(constant(:term)), fn value ->
        assert is_list(value)
        assert Enum.all?(value, &(&1 == :term))
      end)
    end

    test "with the :length option as a integer" do
      for_many(list_of(constant(:term), length: 10), fn value ->
        assert value == List.duplicate(:term, 10)
      end)
    end

    test "with the :length option as a min..max range" do
      for_many(list_of(constant(:term), length: 5..10), fn value ->
        assert Enum.all?(value, &(&1 == :term))
        assert length(value) in 5..10
      end)

      for_many(resize(list_of(constant(:term), length: 5..10), 4), fn value ->
        assert value == List.duplicate(:term, 5)
      end)
    end

    test "with the :min_length option set" do
      for_many(list_of(constant(:term), min_length: 5), fn value ->
        assert Enum.all?(value, &(&1 == :term))
        assert length(value) >= 5
      end)
    end

    test "with the :max_length option set" do
      for_many(list_of(constant(:term), max_length: 5), fn value ->
        assert Enum.all?(value, &(&1 == :term))
        assert length(value) <= 5
      end)
    end

    test "with invalid options" do
      data = constant(:term)

      message = ":length must be a positive integer or a range of positive integers, got: :oops"
      assert_raise ArgumentError, message, fn -> list_of(data, length: :oops) end

      message = ":min_length must be a positive integer, got: :oops"
      assert_raise ArgumentError, message, fn -> list_of(data, min_length: :oops) end

      message = ":max_length must be a positive integer, got: :oops"
      assert_raise ArgumentError, message, fn -> list_of(data, max_length: :oops) end
    end
  end

  test "uniq_list_of/1" do
    for_many(uniq_list_of(integer(), max_tries: 1000), fn list ->
      assert Enum.uniq(list) == list
    end)

    int = scale(integer(), &(&1 * 2))
    for_many(uniq_list_of(int, uniq_fun: &abs/1, max_tries: 1000), fn list ->
      assert Enum.uniq_by(list, &abs/1) == list
    end)

    for_many(uniq_list_of(integer(), min_length: 3, max_tries: 1000), fn list ->
      assert Enum.uniq(list) == list
      assert length(list) >= 3
    end)

    assert_raise StreamData.TooManyDuplicatesError, fn ->
      Enum.take(resize(uniq_list_of(boolean(), max_tries: 0), 10), 10)
    end
  end

  test "nonempty_improper_list_of/2" do
    for_many(nonempty_improper_list_of(integer(), constant("")), fn list ->
      assert list != []
      each_improper_list(list, &assert(is_integer(&1)), &assert(&1 == ""))
    end)
  end

  test "maybe_improper_list_of/2" do
    for_many(maybe_improper_list_of(integer(), constant("")), fn list ->
      each_improper_list(list, &assert(is_integer(&1)), &assert(&1 == "" or is_integer(&1)))
    end)
  end

  test "tuple/1" do
    for_many(tuple({integer(-1..-10), integer(1..10)}), fn value ->
      assert {int1, int2} = value
      assert int1 in -1..-10
      assert int2 in 1..10
    end)
  end

  test "map_of/2" do
    for_many(map_of(binary(), integer()), 50, fn map ->
      assert is_map(map)
      Enum.each(map, fn {key, value} ->
        assert is_binary(key)
        assert is_integer(value)
      end)
    end)
  end

  test "fixed_map/1" do
    data =
      fixed_map(%{
        integer: integer(),
        binary: binary(),
      })

    for_many(data, fn map ->
      assert map_size(map) == 2
      assert is_integer(Map.fetch!(map, :integer))
      assert is_binary(Map.fetch!(map, :binary))
    end)
  end

  test "keyword_of/1" do
    for_many(keyword_of(integer()), 50, fn keyword ->
      assert Keyword.keyword?(keyword)
      assert Enum.all?(Keyword.values(keyword), &is_integer/1)
    end)
  end

  test "nonempty/1" do
    data = nonempty(list_of(constant(:term)))
    for_many(data, fn list ->
      assert length(list) > 0
    end)
  end

  test "tree/2" do
    data = tree(boolean(), &list_of/1)
    for_many(data, 100, fn
      tree when is_list(tree) ->
        assert Enum.all?(List.flatten(tree), &is_boolean/1)
      other ->
        assert is_boolean(other)
    end)
  end

  test "string/1" do
    for_many(string([?a..?z, ?A..?K, ?_]), fn string ->
      assert is_binary(string)
      Enum.each(String.to_charlist(string), fn char ->
        assert char in ?a..?z or char in ?A..?K or char == ?_
      end)
    end)

    for_many(string(?a..?f, min_length: 1), fn string ->
      assert string =~ ~r/\A[a-f]+\z/
    end)

    for_many(string(:ascii), fn string ->
      assert is_binary(string)
      Enum.each(String.to_charlist(string), fn char ->
        assert char in ?\s..?~
      end)
    end)

    for_many(string(:alphanumeric), fn string ->
      assert string =~ ~r/\A[a-zA-Z0-9]*\z/
    end)

    for_many(string(:printable), fn string ->
      assert String.printable?(string)
    end)

    for_many(string(:alphanumeric, length: 3), fn value ->
      assert String.length(value) == 3
    end)
  end

  test "unquoted_atom/0" do
    for_many(unquoted_atom(), fn atom ->
      assert is_atom(atom)
      refute String.starts_with?(inspect(atom), ":\"")
    end)
  end

  test "iolist/0" do
    for_many(iolist(), fn iolist ->
      assert :erlang.iolist_size(iolist) >= 0
    end)
  end

  test "iodata/0" do
    for_many(iodata(), fn iodata ->
      assert IO.iodata_length(iodata) >= 0
    end)
  end

  test "check_all/3" do
    options = [initial_seed: :os.timestamp()]

    property = fn list ->
      if 5 in list do
        {:error, list}
      else
        {:ok, nil}
      end
    end

    assert {:error, info} = check_all(list_of(integer()), options, property)
    assert is_list(info.original_failure) and 5 in info.original_failure
    assert info.shrunk_failure == [5]
    assert is_integer(info.nodes_visited) and info.nodes_visited >= 0

    assert check_all(list_of(boolean()), options, property) == {:ok, %{}}
  end

  test "gen all" do
    data =
      gen all list <- list_of(integer(), min_length: 1),
              elem <- member_of(list),
              elem != 5,
              elem_not_five = elem do
        {Integer.to_string(elem_not_five), list}
      end

    for_many(data, fn {string, list} ->
      assert is_binary(string)
      assert is_list(list)
      assert String.to_integer(string) != 5
    end)
  end

  defp for_many(data, count \\ 200, fun) do
    data
    |> Stream.take(count)
    |> Enum.each(fun)
  end

  defp each_improper_list([], _head_fun, _tail_fun) do
    :ok
  end

  defp each_improper_list([elem], _head_fun, tail_fun) do
    tail_fun.(elem)
  end

  defp each_improper_list([head | tail], head_fun, tail_fun) do
    head_fun.(head)
    if is_list(tail) do
      each_improper_list(tail, head_fun, tail_fun)
    else
      tail_fun.(tail)
    end
  end
end
