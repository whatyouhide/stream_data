defmodule Stream.Data do
  alias Stream.Data.{
    LazyTree,
    Random,
  }

  defstruct [
    :generator,
  ]

  defmodule FilterTooNarrowError do
    defexception [:message]

    def exception(options) do
      %__MODULE__{message: "too many failures: #{inspect(options)}"}
    end
  end

  ### Minimal interface

  ## Helpers

  def new(generator) when is_function(generator, 2) do
    %__MODULE__{generator: generator}
  end

  def call(%__MODULE__{generator: generator}, seed, size) do
    %LazyTree{} = generator.(seed, size)
  end

  ## Generators

  def fixed(term) do
    new(fn _seed, _size -> LazyTree.pure(term) end)
  end

  ## Combinators

  def fmap(%__MODULE__{} = data, fun) when is_function(fun, 1) do
    new(fn seed, size ->
      data
      |> call(seed, size)
      |> LazyTree.fmap(fun)
    end)
  end

  def bind(%__MODULE__{} = data, fun) when is_function(fun, 1) do
    new(fn seed, size ->
      {seed1, seed2} = Random.split(seed)
      lazy_tree = call(data, seed1, size)

      bound_data = new(fn seed, size ->
        lazy_tree
        |> LazyTree.fmap(fn term -> call(_bound_data = fun.(term), seed, size) end) # tree of rose trees
        |> LazyTree.join()
      end)

      call(bound_data, seed2, size)
    end)
  end

  def filter(%__MODULE__{} = data, predicate, max_consecutive_failures \\ 10)
      when is_function(predicate, 1) and is_integer(max_consecutive_failures) and max_consecutive_failures >= 0 do
    new(fn seed, size ->
      case filter(seed, size, data, predicate, max_consecutive_failures) do
        {:ok, lazy_tree} ->
          lazy_tree
        :no_tries_left ->
          raise FilterTooNarrowError, data: data, max_consecutive_failures: max_consecutive_failures
      end
    end)
  end

  defp filter(_seed, _size, _data, _predicate, _tries_left = 0) do
    :no_tries_left
  end

  defp filter(seed, size, data, predicate, tries_left) do
    {seed1, seed2} = Random.split(seed)
    lazy_tree = call(data, seed1, size)

    if predicate.(lazy_tree.root) do
      {:ok, LazyTree.filter(lazy_tree, predicate)}
    else
      filter(seed2, size, data, predicate, tries_left - 1)
    end
  end

  ### Rich API

  ## Generator modifiers

  def resize(%__MODULE__{} = data, new_size) when is_integer(new_size) and new_size >= 0 do
    new(fn seed, _size ->
      call(data, seed, new_size)
    end)
  end

  def sized(fun) when is_function(fun, 1) do
    new(fn seed, size ->
      new_data = fun.(size)
      call(new_data, seed, size)
    end)
  end

  def scale(%__MODULE__{} = data, size_changer) when is_function(size_changer, 1) do
    sized(fn size ->
      resize(data, size_changer.(size))
    end)
  end

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

  def one_of([_ | _] = datas) do
    bind(int(0..length(datas) - 1), fn index ->
      Enum.fetch!(datas, index)
    end)
  end

  # Shrinks towards earlier elements in the enumerable.
  def member(enum) do
    enum_length = Enum.count(enum)
    bind(int(0..enum_length - 1), fn index ->
      fixed(Enum.fetch!(enum, index))
    end)
  end

  def boolean() do
    member([false, true])
  end

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

  def int() do
    sized(fn size -> int(-size..size) end)
  end

  def byte() do
    int(0..255)
  end

  def binary() do
    byte()
    |> list()
    |> fmap(&IO.iodata_to_binary/1)
  end

  ## Compound data types

  # Shrinks by removing elements from the list.
  def list(%__MODULE__{} = data) do
    new(fn seed, size ->
      {seed1, seed2} = Random.split(seed)

      case Random.uniform_in_range(0..size, seed1) do
        0 ->
          LazyTree.pure([])
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

  defp list_lazy_tree(list) do
    children =
      (0..length(list) - 1)
      |> Stream.map(&List.delete_at(list, &1))
      |> Stream.map(&list_lazy_tree/1)

    LazyTree.new(list, children)
  end

  def tuple(tuple_datas) when is_tuple(tuple_datas) do
    datas = Tuple.to_list(tuple_datas)

    new(fn seed, size ->
      {trees, _seed} = Enum.map_reduce(datas, seed, fn data, acc ->
        {seed1, seed2} = Random.split(acc)
        {call(data, seed1, size), seed2}
      end)

      trees
      |> LazyTree.zip()
      |> LazyTree.fmap(&List.to_tuple/1)
    end)
  end

  def map(%__MODULE__{} = key_data, %__MODULE__{} = value_data) do
    {key_data, value_data}
    |> tuple()
    |> list()
    |> fmap(&Map.new/1)
  end

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
