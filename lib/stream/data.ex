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

  def fmap(%__MODULE__{} = data, fun) when is_function(fun, 1) do
    new(fn seed, size ->
      {next, seed} = call(data, seed, size)
      {fun.(next), seed}
    end)
  end

  def resize(%__MODULE__{} = data, new_size) when is_integer(new_size) and new_size >= 0 do
    new(fn seed, _size ->
      call(data, seed, new_size)
    end)
  end

  ## Combinators

  def one_of([_ | _] = datas) do
    new(fn seed, size ->
      {index, seed} = Random.uniform_in_range(0..length(datas) - 1, seed)
      datas
      |> Enum.fetch!(index)
      |> call(seed, size)
    end)
  end

  ## Generators

  def fixed(term) do
    new(fn seed, _size -> {term, seed} end)
  end

  def member(enum) do
    enum_length = Enum.count(enum)

    new(fn seed, _size ->
      {index, seed} = Random.uniform_in_range(0..enum_length - 1, seed)
      {Enum.fetch!(enum, index), seed}
    end)
  end

  ## Simple data types

  def boolean() do
    new(fn seed, _size -> Random.boolean(seed) end)
  end

  def int(lower..upper) when lower > upper do
    int(upper..lower)
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
      case Random.uniform_in_range(0..size, seed) do
        {0, seed} ->
          {[], seed}
        {length, seed} ->
          Enum.map_reduce(1..length, seed, fn _i, acc ->
            data.generator.(acc, size)
          end)
      end
    end)
  end

  ## Enumerable

  defimpl Enumerable do
    @initial_size 1

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
      {next, seed} = @for.call(data, seed, size)
      reduce(data, fun.(next, acc), fun, seed, size + 1)
    end

    def count(_data), do: {:error, __MODULE__}

    def member?(_data, _term), do: {:error, __MODULE__}
  end
end
