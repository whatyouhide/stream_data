defmodule Stream.Data do
  alias Stream.Data.Random

  defstruct [
    :generator,
  ]

  def new(generator) when is_function(generator, 2) do
    %__MODULE__{generator: generator}
  end

  def call(%__MODULE__{generator: generator}, seed, size) do
    generator.(seed, size)
  end

  def fixed(term) do
    new(fn _seed, _size -> term end)
  end

  def fmap(%__MODULE__{} = data, fun) when is_function(fun, 1) do
    new(fn seed, size ->
      data
      |> call(seed, size)
      |> fun.()
    end)
  end

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
    frequencies = Enum.sort(frequencies, &elem(&1, 0))
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

  ## Combinators

  def one_of([_ | _] = datas) do
    new(fn seed, size ->
      {seed1, seed2} = Random.split(seed)
      index = Random.uniform_in_range(0..length(datas) - 1, seed1)
      datas
      |> Enum.fetch!(index)
      |> call(seed2, size)
    end)
  end

  def member(enum) do
    enum_length = Enum.count(enum)

    new(fn seed, _size ->
      index = Random.uniform_in_range(0..enum_length - 1, seed)
      Enum.fetch!(enum, index)
    end)
  end

  ## Simple data types

  def boolean() do
    new(fn seed, _size -> Random.uniform_in_range(0..1, seed) == 1 end)
  end

  def int(_lower.._upper = range) do
    new(fn seed, _size -> Random.uniform_in_range(range, seed) end)
  end

  def int() do
    new(fn seed, size -> Random.uniform_in_range(-size..size, seed) end)
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

  def list(%__MODULE__{} = data) do
    new(fn seed, size ->
      {seed1, seed2} = Random.split(seed)

      case Random.uniform_in_range(0..size, seed1) do
        0 ->
          []
        length ->
          {result, _seed} = Enum.map_reduce(1..length, seed2, fn _i, acc ->
            {s1, s2} = Random.split(acc)
            {call(data, s1, size), s2}
          end)
          result
      end
    end)
  end

  def tuple(tuple_datas) when is_tuple(tuple_datas) do
    datas = Tuple.to_list(tuple_datas)

    new(fn seed, size ->
      {elems, _seed} = Enum.map_reduce(datas, seed, fn data, acc ->
        {seed1, seed2} = Random.split(acc)
        next = call(data, seed1, size)
        {next, seed2}
      end)
      List.to_tuple(elems)
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
      next = @for.call(data, seed1, size)
      size = if(size < @max_size, do: size + 1, else: size)
      reduce(data, fun.(next, acc), fun, seed2, size)
    end

    def count(_data), do: {:error, __MODULE__}

    def member?(_data, _term), do: {:error, __MODULE__}
  end
end
