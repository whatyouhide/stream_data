defmodule Stream.Data do
  alias Stream.Data.Random

  defstruct [
    :generator,
    :validator,
  ]

  def new(generator, validator) when is_function(generator, 2) do
    %__MODULE__{
      generator: generator,
      validator: validator,
    }
  end

  def filter(%__MODULE__{} = data, validator) do
    filtered_generator = fn seed, size ->
      filter_generator(seed, size, data.generator, validator)
    end
    filtered_validator = Saul.all_of([data.validator, validator])
    new(filtered_generator, filtered_validator)
  end

  # TODO: this doesn't work because it can keep trying forever, we
  # need a mechanism to make it try N times tops.
  defp filter_generator(seed, size, generator, validator) do
    {next, seed} = generator.(seed, size)
    case Saul.validate(next, validator) do
      {:ok, transformed} -> {transformed, seed}
      _other -> filter_generator(seed, size, generator, validator)
    end
  end

  def map(data, fun) when is_function(fun, 1) do
    generator = fn seed, size ->
      {next, seed} = data.generator.(seed, size)
      {fun.(next), seed}
    end

    validator = Saul.all_of([data.validator, Saul.transform(fun)])

    new(generator, validator)
  end

  def resize(data, new_size) do
    generator = fn seed, _size -> data.generator.(seed, new_size) end
    %{data | generator: generator}
  end

  ## Combinators

  def one_of([_ | _] = datas) do
    generator = fn seed, size ->
      {index, seed} = Random.uniform_in_range(0..(length(datas) - 1), seed)
      data = Enum.fetch!(datas, index)
      data.generator.(seed, size)
    end

    validator =
      datas
      |> Enum.map(&(&1.validator))
      |> Saul.one_of()

    new(generator, validator)
  end

  ## Generators

  def fixed(term) do
    generator = fn seed, _size -> {term, seed} end
    validator = Saul.lit(term)
    new(generator, validator)
  end

  def boolean() do
    generator = fn seed, _size -> Random.boolean(seed) end
    validator = &is_boolean/1
    new(generator, validator)
  end

  def int(lower..upper) when lower > upper do
    int(upper..lower)
  end

  def int(_lower.._upper = range) do
    generator = fn seed, _size -> Random.uniform_in_range(range, seed) end
    new(generator, &(is_integer(&1) and &1 in range))
  end

  def int() do
    generator = fn seed, size -> Random.uniform_in_range(-size..size, seed) end
    new(generator, &is_integer/1)
  end

  def byte() do
    int(0..255)
  end

  def binary() do
    byte()
    |> list()
    |> map(&IO.iodata_to_binary/1)
    |> Map.put(:validator, &is_binary/1)
  end

  def list(%__MODULE__{} = data) do
    generator = fn seed, size ->
      case Random.uniform_in_range(0..size, seed) do
        {0, seed} ->
          {[], seed}
        {length, seed} ->
          Enum.map_reduce(1..length, seed, fn _i, acc ->
            data.generator.(acc, size)
          end)
      end
    end

    validator = Saul.list_of(data.validator)

    new(generator, validator)
  end

  def member(enum) do
    generator = fn seed, _size ->
      enum_length = Enum.copunt(enum)
      {random_index, seed} = Random.uniform_in_range(0..(enum_length - 1), seed)
      {Enum.fetch!(enum, random_index), seed}
    end
    validator = Saul.member(enum)
    new(generator, validator)
  end
end
