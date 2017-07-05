defmodule Stream.Data do
  alias Stream.Data.{
    LazyTree,
    Random,
  }

  @type size :: non_neg_integer

  @type generator_fun(a) :: (Random.seed, size -> LazyTree.t(a))

  @type t(a) :: %__MODULE__{
    generator: generator_fun(a),
  }

  defstruct [:generator]

  defmodule FilterTooNarrowError do
    defexception [:message]

    def exception(options) do
      %__MODULE__{message: "too many failures: #{inspect(options)}"}
    end
  end

  ### Minimal interface

  ## Helpers

  @spec new(generator_fun(a)) :: t(a) when a: term
  def new(generator) when is_function(generator, 2) do
    %__MODULE__{generator: generator}
  end

  @spec call(t(a), Random.seed, non_neg_integer) :: a when a: term
  def call(%__MODULE__{generator: generator}, seed, size) do
    %LazyTree{} = generator.(seed, size)
  end

  ## Generators

  @spec constant(a) :: t(a) when a: var
  def constant(term) do
    new(fn _seed, _size -> LazyTree.constant(term) end)
  end

  ## Combinators

  @spec map(t(a), (a -> b)) :: t(b) when a: term, b: term
  def map(%__MODULE__{} = data, fun) when is_function(fun, 1) do
    new(fn seed, size ->
      data
      |> call(seed, size)
      |> LazyTree.map(fun)
    end)
  end

  @spec bind_filter(t(a), (a -> {:pass, t(b)} | :skip), non_neg_integer) :: t(b) when a: term, b: term
  def bind_filter(%__MODULE__{} = data, fun, max_consecutive_failures \\ 10)
      when is_function(fun, 1) and is_integer(max_consecutive_failures) and max_consecutive_failures >= 0 do
    new(fn seed, size ->
      case bind_filter(seed, size, data, fun, max_consecutive_failures) do
        {:ok, lazy_tree} ->
          lazy_tree
        :too_many_failures ->
          raise FilterTooNarrowError, max_consecutive_failures: max_consecutive_failures
      end
    end)
  end

  defp bind_filter(_seed, _size, _data, _mapper, _tries_left = 0) do
    :too_many_failures
  end

  defp bind_filter(seed, size, data, mapper, tries_left) do
    {seed1, seed2} = Random.split(seed)
    lazy_tree = call(data, seed1, size)

    case LazyTree.map_filter(lazy_tree, mapper) do
      {:ok, map_filtered_tree} ->
        tree =
          map_filtered_tree
          |> LazyTree.map(&call(&1, seed2, size))
          |> LazyTree.flatten()
        {:ok, tree}
      :error ->
        bind_filter(seed2, size, data, mapper, tries_left - 1)
    end
  end

  @spec bind(t(a), (a -> t(b))) :: t(b) when a: term, b: term
  def bind(%__MODULE__{} = data, fun) when is_function(fun, 1) do
    bind_filter(data, fn generated_term -> {:pass, fun.(generated_term)} end)
  end

  @spec filter(t(a), (a -> as_boolean(term)), non_neg_integer) :: t(a) when a: term
  def filter(%__MODULE__{} = data, predicate, max_consecutive_failures \\ 10)
      when is_function(predicate, 1) and is_integer(max_consecutive_failures) and max_consecutive_failures >= 0 do
    bind_filter(data, fn term ->
      if predicate.(term) do
        {:pass, constant(term)}
      else
        :skip
      end
    end)
  end

  ### Rich API

  @spec int(Range.t) :: t(integer)
  def int(_lower.._upper = range) do
    new(fn seed, _size ->
      int = Random.uniform_in_range(range, seed)
      int_lazy_tree(int)
    end)
  end

  defp int_lazy_tree(int) do
    children =
      int
      |> Stream.iterate(&div(&1, 2))
      |> Stream.take_while(&(&1 != 0))
      |> Stream.map(&(int - &1))
      |> Stream.map(&int_lazy_tree/1)

    LazyTree.new(int, children)
  end

  ## Generator modifiers

  @spec resize(t(a), size) :: t(a) when a: term
  def resize(%__MODULE__{} = data, new_size) when is_integer(new_size) and new_size >= 0 do
    new(fn seed, _size ->
      call(data, seed, new_size)
    end)
  end

  @spec sized((size -> t(a))) :: t(a) when a: term
  def sized(fun) when is_function(fun, 1) do
    new(fn seed, size ->
      new_data = fun.(size)
      call(new_data, seed, size)
    end)
  end

  @spec scale(t(a), (size -> size)) :: t(a) when a: term
  def scale(%__MODULE__{} = data, size_changer) when is_function(size_changer, 1) do
    sized(fn size ->
      resize(data, size_changer.(size))
    end)
  end

  @spec no_shrink(t(a)) :: t(a) when a: term
  def no_shrink(%__MODULE__{} = data) do
    new(fn seed, size ->
      %LazyTree{root: root} = call(data, seed, size)
      LazyTree.constant(root)
    end)
  end

  # TODO: tackle shrinking
  @spec frequency([{pos_integer, t(a)}]) :: t(a) when a: term
  def frequency(frequencies) when is_list(frequencies) do
    frequencies = Enum.sort_by(frequencies, &elem(&1, 0))
    sum = frequencies |> Enum.map(&elem(&1, 0)) |> Enum.sum()

    new(fn seed, size ->
      {seed1, seed2} = Random.split(seed)
      frequencies
      |> find_frequency(Random.uniform_in_range(1..sum, seed1))
      |> call(seed2, size)
    end)
  end

  defp find_frequency([{frequency, data} | _], int) when int <= frequency,
    do: data
  defp find_frequency([{frequency, _data} | rest], int),
    do: find_frequency(rest, frequency - int)

  @spec one_of([t(a)]) :: t(a) when a: term
  def one_of([_ | _] = datas) do
    bind(int(0..length(datas) - 1), fn index ->
      Enum.fetch!(datas, index)
    end)
  end

  # Shrinks towards earlier elements in the enumerable.
  @spec member_of(Enumerable.t) :: t(term)
  def member_of(enum) do
    enum_length = Enum.count(enum)

    if enum_length == 0 do
      raise "cannot generate elements from an empty enumerable"
    end

    bind(int(0..enum_length - 1), fn index ->
      constant(Enum.fetch!(enum, index))
    end)
  end

  ## Compound data types

  # Shrinks by removing elements from the list.
  @spec list_of(t(a)) :: t([a]) when a: term
  def list_of(%__MODULE__{} = data) do
    new(fn seed, size ->
      {seed1, seed2} = Random.split(seed)

      case Random.uniform_in_range(0..size, seed1) do
        0 ->
          LazyTree.constant([])
        length ->
          {list, _final_seed} =
            Enum.map_reduce(1..length, seed2, fn _i, acc ->
              {s1, s2} = Random.split(acc)
              %LazyTree{root: next} = call(data, s1, size)
              {next, s2}
            end)

          list_lazy_tree(list)
      end
    end)
  end

  # TODO: improve
  defp list_lazy_tree(list) do
    children =
      (0..length(list) - 1)
      |> Stream.map(&List.delete_at(list, &1))
      |> Stream.map(&list_lazy_tree/1)

    LazyTree.new(list, children)
  end

  @spec tuple(tuple) :: t(tuple)
  def tuple(tuple_datas) when is_tuple(tuple_datas) do
    datas = Tuple.to_list(tuple_datas)

    new(fn seed, size ->
      {trees, _seed} = Enum.map_reduce(datas, seed, fn data, acc ->
        {seed1, seed2} = Random.split(acc)
        {call(data, seed1, size), seed2}
      end)

      trees
      |> LazyTree.zip()
      |> LazyTree.map(&List.to_tuple/1)
    end)
  end

  @spec map_of(t(key), t(value)) :: t(%{optional(key) => value}) when key: term, value: term
  def map_of(%__MODULE__{} = key_data, %__MODULE__{} = value_data) do
    key_value_pairs = tuple({key_data, value_data})
    map(list_of(key_value_pairs), &Map.new/1)
  end

  @spec non_empty(t(Enumerable.t)) :: t(Enumerable.t)
  def non_empty(enum_data) do
    filter(enum_data, &not(Enum.empty?(&1)))
  end

  @spec tree((t(a) -> t(b)), t(a)) :: t(a | b) when a: term, b: term
  def tree(subtree_fun, leaf_data) do
    new(fn seed, size ->
      leaf_data = resize(leaf_data, size)
      {seed1, seed2} = Random.split(seed)
      nodes_on_each_level = random_pseudofactors(trunc(:math.pow(size, 1.1)), seed1)
      data = Enum.reduce(nodes_on_each_level, leaf_data, fn nodes_on_this_level, data_acc ->
        frequency([
          {1, data_acc},
          {2, resize(subtree_fun.(data_acc), nodes_on_this_level)},
        ])
      end)

      call(data, seed2, size)
    end)
  end

  defp random_pseudofactors(n, _seed) when n < 2 do
    [n]
  end

  defp random_pseudofactors(n, seed) do
    {seed1, seed2} = Random.split(seed)
    {factor, _seed} = :rand.uniform_s(trunc(:math.log2(n)), seed1)

    if factor == 1 do
      [n]
    else
      [factor | random_pseudofactors(div(n, factor), seed2)]
    end
  end

  ## Data types

  @spec boolean() :: t(boolean)
  def boolean() do
    member_of([false, true])
  end

  @spec int() :: t(integer)
  def int() do
    sized(fn size -> int(-size..size) end)
  end

  @spec byte() :: t(byte)
  def byte() do
    int(0..255)
  end

  @spec binary() :: t(binary)
  def binary() do
    map(list_of(byte()), &IO.iodata_to_binary/1)
  end

  @spec string_from_chars([Enumerable.t]) :: t(String.t)
  def string_from_chars(char_ranges) when is_list(char_ranges) do
    char_ranges
    |> Enum.concat()
    |> member_of()
    |> list_of()
    |> map(&List.to_string/1)
  end

  @spec ascii_string() :: t(String.t)
  def ascii_string() do
    string_from_chars([?\s..?~])
  end

  @spec alphanumeric_string() :: t(String.t)
  def alphanumeric_string() do
    string_from_chars([?a..?z, ?A..?Z, ?0..?9])
  end

  @spec unquoted_atom() :: t(atom)
  def unquoted_atom() do
    member_of(Enum.concat([?a..?z, ?A..?Z, [?_]]))
    |> bind(fn first_char ->
      map(string_from_chars([?a..?z, ?A..?Z, ?0..?9, [?_, ?@]]), &(<<first_char>> <> &1))
    end)
    |> map(&String.to_atom/1)
  end

  # TODO: floats
  # TODO: keyword lists
  # TODO: iodata (very interesting because recursive)
  # TODO: specific map

  ## Enumerable

  defimpl Enumerable do
    @initial_size 1
    @max_size 100

    def reduce(data, acc, fun) do
      reduce(data, acc, fun, :rand.seed_s(:exs64), @initial_size)
    end

    defp reduce(_data, {:halt, acc}, _fun, _seed, _size) do
      {:halted, acc}
    end

    defp reduce(data, {:suspend, acc}, fun, seed, size) do
      {:suspended, acc, &reduce(data, &1, fun, seed, size)}
    end

    defp reduce(data, {:cont, acc}, fun, seed, size) do
      {seed1, seed2} = Random.split(seed)
      %LazyTree{root: next} = @for.call(data, seed1, size)
      size = if(size < @max_size, do: size + 1, else: size)
      reduce(data, fun.(next, acc), fun, seed2, size)
    end

    def count(_data), do: {:error, __MODULE__}

    def member?(_data, _term), do: {:error, __MODULE__}
  end
end
