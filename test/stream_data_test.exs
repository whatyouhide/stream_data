# TODO: test shrinking

defmodule StreamDataTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  test "implementation of the Enumerable protocol" do
    values = Enum.take(Stream.zip(integer(), boolean()), 10)

    Enum.each(values, fn {int, boolean} ->
      assert is_integer(int)
      assert is_boolean(boolean)
    end)
  end

  test "implementation of the Inspect protocol" do
    data = constant(:foo)
    assert inspect(data) =~ ~r/\A#StreamData<\d{2}\./
  end

  describe "terms used as generators" do
    property "atoms" do
      check all term <- :foo do
        assert term == :foo
      end
    end

    property "tuples" do
      check all {integer, boolean} <- {integer(), boolean()} do
        assert is_integer(integer)
        assert is_boolean(boolean)
      end
    end

    property "nested generator terms" do
      check all {atom, boolean} <- {:ok, boolean()} do
        assert atom == :ok
        assert is_boolean(boolean)
      end
    end
  end

  test "error message on invalid generators" do
    message = ~r/expected a generator, which can be a %StreamData{} struct/

    assert_raise ArgumentError, message, fn ->
      Enum.take(one_of([1, 2, 3]), 1)
    end
  end

  property "constant/1" do
    check all term <- constant(:term) do
      assert term == :term
    end
  end

  property "map/1" do
    data = map(integer(1..5), &(-&1))

    check all int <- data do
      assert int in -1..-5
    end
  end

  describe "bind_filter/2" do
    property "with a function of arity 1" do
      require Integer

      bind_filter_fun = fn int ->
        if Integer.is_even(int), do: {:cont, constant(int)}, else: :skip
      end

      data = bind_filter(integer(1..5), bind_filter_fun, 1000)

      check all int <- data do
        assert int in 1..5
        assert Integer.is_even(int)
      end
    end

    property "with a function of arity 2" do
      require Integer

      bind_filter_fun = fn _term, tries_left when is_integer(tries_left) ->
        raise "tries_left = #{tries_left}"
      end

      data = bind_filter(boolean(), bind_filter_fun, _tries = 5)

      assert_raise RuntimeError, "tries_left = 5", fn ->
        Enum.take(data, 1)
      end
    end
  end

  property "bind/2" do
    data = bind(integer(1..5), &constant(-&1))

    check all int <- data do
      assert int in -1..-5
    end
  end

  describe "filter/2,3" do
    test "filters out terms that fail the predicate" do
      values =
        integer(0..10000)
        |> filter(&(&1 > 0))
        |> Enum.take(1000)

      assert length(values) <= 1000

      Enum.each(values, fn value ->
        assert value in 0..10000
      end)
    end

    test "raises an error when too many consecutive elements fail the predicate" do
      data = filter(constant(:term), &is_binary/1, 10)

      exception =
        assert_raise StreamData.FilterTooNarrowError, fn ->
          Enum.take(data, 1)
        end

      message = Exception.message(exception)

      assert message =~ "too many consecutive elements (10 elements in this case)"
      assert message =~ "The last element to be filtered out was: :term."
    end
  end

  property "integer/1 for ranges without steps" do
    check all int <- integer(-10..10) do
      assert int in -10..10
    end
  end

  # Range step syntax was introduced in Elixir v1.12.0
  unless Version.compare(System.version(), "1.12.0") == :lt do
    property "integer/1 for a range with an even step only produces even numbers" do
      check all int <- integer(%Range{first: 0, last: 100, step: 2}) do
        require Integer
        assert Integer.is_even(int)
      end
    end

    property "integer/1 for descending ranges with negative steps" do
      check all int <- integer(%Range{first: 100, last: 5, step: -10}) do
        require Integer
        assert int in 10..100
        assert rem(int, 10) == 0
      end
    end

    property "integer/1 raises on empty ranges" do
      check all lower <- positive_integer(),
                offset <- positive_integer() do
        assert_raise(RuntimeError, fn ->
          StreamData.integer(%Range{first: lower + offset, last: lower, step: 1})
        end)
      end
    end
  end

  property "resize/2" do
    generator = fn seed, size ->
      case :rand.uniform_s(2, seed) do
        {1, _seed} -> %StreamData.LazyTree{root: size}
        {2, _seed} -> %StreamData.LazyTree{root: -size}
      end
    end

    check all int <- resize(%StreamData{generator: generator}, 10) do
      assert int in [-10, 10]
    end
  end

  property "sized/1" do
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

    check all int <- data do
      assert is_integer(int)
    end
  end

  test "seeded/2" do
    data = seeded(integer(), _seed = 1)
    assert Enum.take(data, 100) == Enum.take(data, 100)
  end

  property "scale/2" do
    size_data = sized(&constant(&1))
    data = scale(size_data, fn size -> size + 1000 end)

    check all int <- data do
      assert int >= 1000
    end
  end

  test "frequency/1" do
    data =
      frequency([
        {1, constant(:small_chance)},
        {100, constant(:big_chance)}
      ])

    values = Enum.take(data, 1000)

    assert :small_chance in values
    assert :big_chance in values
    assert Enum.count(values, &(&1 == :small_chance)) < Enum.count(values, &(&1 == :big_chance))
  end

  property "one_of/1" do
    check all int <- one_of([integer(1..5), integer(-1..-5)]) do
      assert int in 1..5 or int in -1..-5
    end
  end

  property "member_of/1" do
    check all elem <- member_of([1, 2, 3]) do
      assert elem in [1, 2, 3]
    end

    check all elem <- member_of(MapSet.new([1, 2, 3])) do
      assert elem in [1, 2, 3]
    end

    assert_raise RuntimeError, "cannot generate elements from an empty enumerable", fn ->
      Enum.take(member_of([]), 1)
    end
  end

  property "boolean/0" do
    check all bool <- boolean() do
      assert is_boolean(bool)
    end
  end

  property "integer/0" do
    check all int <- integer() do
      assert is_integer(int)
      assert abs(int) < 1000
    end
  end

  describe "positive_integer/0" do
    property "without bounds" do
      check all int <- positive_integer() do
        assert is_integer(int)
        assert int in 1..1000
      end
    end

    property "works when resized to 0" do
      check all int <- resize(positive_integer(), 0), max_runs: 3 do
        assert int == 1
      end
    end
  end

  describe "non_negative_integer/0" do
    property "without bounds" do
      check all int <- non_negative_integer() do
        assert is_integer(int)
        assert int in 0..1000
      end
    end

    property "works when resized to 0" do
      check all int <- resize(non_negative_integer(), 0), max_runs: 3 do
        assert int == 0
      end
    end
  end

  describe "float/1" do
    property "without bounds" do
      check all float <- float() do
        assert is_float(float)
      end
    end

    property "with a :min option" do
      check all float <- float(min: 1.23) do
        assert is_float(float)
        assert float >= 1.23
      end

      check all float <- float(min: -10.0) do
        assert is_float(float)
        assert float >= -10.0
      end
    end

    property "with a :max option" do
      check all float <- float(max: 1.23) do
        assert is_float(float)
        assert float <= 1.23
      end

      check all float <- float(max: -10.0) do
        assert is_float(float)
        assert float <= -10.0
      end
    end

    property "with both a :min and a :max option" do
      check all float <- float(min: -1.12, max: 4.01) do
        assert is_float(float)
        assert float >= -1.12 and float <= 4.01
      end
    end
  end

  property "byte/0" do
    check all value <- byte() do
      assert value in 0..255
    end
  end

  describe "binary/1" do
    property "generates binaries" do
      check all value <- resize(binary(), 10) do
        assert is_binary(value)
        assert byte_size(value) in 0..10
      end
    end

    property "with length-related options" do
      check all value <- binary(length: 3) do
        assert is_binary(value)
        assert byte_size(value) == 3
      end
    end
  end

  describe "bitstring/1" do
    property "generates bitstrings" do
      check all value <- resize(bitstring(), 10) do
        assert is_bitstring(value)
        assert bit_size(value) in 0..10
      end
    end

    property "with length-related options" do
      check all value <- bitstring(length: 3) do
        assert is_bitstring(value)
        assert bit_size(value) == 3
      end
    end
  end

  describe "list_of/2" do
    property "generates lists" do
      check all value <- list_of(constant(:term)) do
        assert is_list(value)
        assert Enum.all?(value, &(&1 == :term))
      end
    end

    property "with the :length option as a integer" do
      check all value <- list_of(constant(:term), length: 10) do
        assert value == List.duplicate(:term, 10)
      end
    end

    property "with the :length option as a min..max range" do
      check all value <- list_of(constant(:term), length: 5..10) do
        assert Enum.all?(value, &(&1 == :term))
        assert length(value) in 5..10
      end

      check all value <- resize(list_of(constant(:term), length: 5..10), 4) do
        assert value == List.duplicate(:term, 5)
      end
    end

    property "with the :min_length option set" do
      check all value <- list_of(constant(:term), min_length: 5) do
        assert Enum.all?(value, &(&1 == :term))
        assert length(value) >= 5
      end
    end

    property "with the :max_length option set" do
      check all value <- list_of(constant(:term), max_length: 5) do
        assert Enum.all?(value, &(&1 == :term))
        assert length(value) <= 5
      end
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

  describe "uniq_list_of/1" do
    property "without options" do
      check all list <- uniq_list_of(integer(1..10000)) do
        assert Enum.uniq(list) == list
      end
    end

    property "with the :uniq_fun option" do
      check all list <- uniq_list_of(integer(-10000..10000), uniq_fun: &abs/1) do
        assert Enum.uniq_by(list, &abs/1) == list
      end
    end

    property "with length-related options" do
      check all list <- uniq_list_of(integer(), min_length: 3, max_tries: 1000) do
        assert Enum.uniq(list) == list
        assert length(list) >= 3
      end
    end

    test "raises an error when :max_tries are reached" do
      assert_raise StreamData.TooManyDuplicatesError, fn ->
        integer()
        |> uniq_list_of(max_tries: 0, min_length: 1)
        |> Enum.take(1)
      end
    end
  end

  property "nonempty_improper_list_of/2" do
    check all list <- nonempty_improper_list_of(integer(), constant("")) do
      assert list != []
      refute match?([_], list)
      each_improper_list(list, &assert(is_integer(&1)), &assert(&1 == ""))
    end
  end

  property "maybe_improper_list_of/2" do
    check all list <- maybe_improper_list_of(integer(), constant("")) do
      assert list != [""]
      each_improper_list(list, &assert(is_integer(&1)), &assert(&1 == "" or is_integer(&1)))
    end
  end

  property "tuple/1" do
    check all value <- tuple({integer(-1..-10), integer(1..10)}) do
      assert {int1, int2} = value
      assert int1 in -1..-10
      assert int2 in 1..10
    end
  end

  property "map_of/2" do
    check all map <- map_of(integer(), boolean()), max_runs: 50 do
      assert is_map(map)

      Enum.each(map, fn {key, value} ->
        assert is_integer(key)
        assert is_boolean(value)
      end)
    end
  end

  property "map_of/3" do
    check all map <- map_of(integer(), boolean(), max_length: 5), max_runs: 50 do
      assert is_map(map)

      assert map_size(map) <= 5

      Enum.each(map, fn {key, value} ->
        assert is_integer(key)
        assert is_boolean(value)
      end)
    end
  end

  property "fixed_map/1" do
    data_with_map = fixed_map(%{integer: integer(), binary: binary()})
    data_with_keyword = fixed_map(integer: integer(), binary: binary())

    Enum.each([data_with_map, data_with_keyword], fn data ->
      check all map <- data do
        assert map_size(map) == 2
        assert is_integer(Map.fetch!(map, :integer))
        assert is_binary(Map.fetch!(map, :binary))
      end
    end)
  end

  property "optional_map/1" do
    data_with_map = optional_map(%{integer: integer(), binary: binary()})
    data_with_keyword = optional_map(integer: integer(), binary: binary())

    Enum.each([data_with_map, data_with_keyword], fn data ->
      check all map <- data do
        assert map_size(map) <= 2

        assert map
               |> Map.keys()
               |> MapSet.new()
               |> MapSet.subset?(MapSet.new([:integer, :binary]))

        if Map.has_key?(map, :integer) do
          assert is_integer(Map.fetch!(map, :integer))
        end

        if Map.has_key?(map, :binary) do
          assert(is_binary(Map.fetch!(map, :binary)))
        end
      end
    end)
  end

  property "optional_map/2" do
    data_with_map = optional_map(%{integer: integer(), binary: binary()}, [:integer])
    data_with_keyword = optional_map([integer: integer(), binary: binary()], [:integer])

    Enum.each([data_with_map, data_with_keyword], fn data ->
      check all map <- data do
        assert map_size(map) in [1, 2]

        assert map
               |> Map.keys()
               |> MapSet.new()
               |> MapSet.subset?(MapSet.new([:integer, :binary]))

        if Map.has_key?(map, :integer) do
          assert is_integer(Map.fetch!(map, :integer))
        end

        assert(is_binary(Map.fetch!(map, :binary)))
      end
    end)

    assert Enum.any?(Stream.take(data_with_map, 100), fn data ->
             Map.has_key?(data, :integer) && is_integer(data.integer)
           end)
  end

  property "keyword_of/1" do
    check all keyword <- keyword_of(boolean()), max_runs: 50 do
      assert Keyword.keyword?(keyword)

      Enum.each(keyword, fn {_key, value} ->
        assert is_boolean(value)
      end)
    end
  end

  describe "mapset_of/1" do
    property "without options" do
      check all set <- mapset_of(integer(1..10000)) do
        assert %MapSet{} = set

        if MapSet.size(set) > 0 do
          assert Enum.all?(set, &is_integer/1)
        end
      end
    end

    test "raises an error when :max_tries are reached" do
      assert_raise StreamData.TooManyDuplicatesError, fn ->
        integer()
        |> mapset_of(max_tries: 0)
        |> filter(&(MapSet.size(&1) > 0))
        |> Enum.take(1)
      end
    end
  end

  property "nonempty/1" do
    check all list <- nonempty(list_of(:term)) do
      assert length(list) > 0
    end
  end

  property "tree/2" do
    check all tree <- tree(boolean(), &list_of/1), max_runs: 100 do
      if is_list(tree) do
        assert Enum.all?(List.flatten(tree), &is_boolean/1)
      else
        assert is_boolean(tree)
      end
    end
  end

  describe "string/1" do
    property "with a list of ranges and codepoints" do
      check all string <- string([?a..?z, ?A..?K, ?_]) do
        assert is_binary(string)

        Enum.each(String.to_charlist(string), fn char ->
          assert char in ?a..?z or char in ?A..?K or char == ?_
        end)
      end
    end

    property "with a range" do
      check all string <- string(?a..?f, min_length: 1) do
        assert string =~ ~r/\A[a-f]+\z/
      end
    end

    property "with :ascii" do
      check all string <- string(:ascii) do
        assert is_binary(string)

        Enum.each(String.to_charlist(string), fn char ->
          assert char in ?\s..?~
        end)
      end
    end

    property "with :alphanumeric" do
      check all string <- string(:alphanumeric) do
        assert string =~ ~r/\A[a-zA-Z0-9]*\z/
      end
    end

    property "with :printable" do
      check all string <- string(:printable) do
        assert String.printable?(string)
      end
    end

    property "with a fixed length" do
      check all string <- string(:alphanumeric, length: 3) do
        assert String.length(string) == 3
      end
    end
  end

  describe "atom/1" do
    property ":alphanumeric" do
      check all atom <- atom(:alphanumeric) do
        assert is_atom(atom)
        refute String.starts_with?(inspect(atom), ":\"")
      end
    end

    property ":alias" do
      check all module <- atom(:alias), max_runs: 50 do
        assert is_atom(module)
        assert String.starts_with?(Atom.to_string(module), "Elixir.")
      end
    end
  end

  property "iolist/0" do
    check all iolist <- iolist(), max_runs: 50 do
      assert :erlang.iolist_size(iolist) >= 0
    end
  end

  property "iodata/0" do
    check all iodata <- iodata(), max_runs: 50 do
      assert IO.iodata_length(iodata) >= 0
    end
  end

  property "term/0" do
    check all term <- term(), max_runs: 25 do
      assert is_boolean(term) or is_integer(term) or is_float(term) or is_binary(term) or
               is_atom(term) or is_reference(term) or is_list(term) or is_map(term) or
               is_tuple(term)
    end
  end

  test "check_all/3 with :os.timestamp" do
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
    assert is_integer(info.successful_runs) and info.successful_runs >= 0

    assert check_all(list_of(boolean()), options, property) == {:ok, %{}}
  end

  test "check_all/3 with :rand.export_seed()" do
    seed = :rand.seed_s(:exs64)
    options = [initial_seed: :rand.export_seed_s(seed)]

    property = fn list ->
      if 5 in list do
        {:error, list}
      else
        {:ok, nil}
      end
    end

    assert check_all(list_of(boolean()), options, property) == {:ok, %{}}
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
