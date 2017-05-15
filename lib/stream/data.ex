defmodule Stream.Data do
  # * A set of values that can be generated,
  # * A probability distribution on that set,
  # * A way of shrinking generated values to similar,
  #   smaller values---used after a test fails, to enable
  #   QuickCheck to search for a similar, but simpler failing case.

  @type size :: non_neg_integer
  @type generator(result) :: (:rand.state, size -> {result, :rand.state})

  defstruct [
    :generator,
    :validator,
    :size,
    :seed,
  ]

  def new(generator, validator) do
    %__MODULE__{
      generator: generator,
      validator: validator,
      size: 10,
      seed: :rand.seed(:exs64),
    }
  end

  def bind(generator, fun) when is_function(fun, 1) do
    fn seed, size ->
      {next, seed} = generator.(seed, size)
      fun.(next).(seed, size)
    end
  end

  def filter(%__MODULE__{} = data, validator) do
    filtered_generator = fn seed, size ->
      filter_generator(seed, size, data.generator, validator)
    end
    filtered_validator = Saul.all_of([data.validator, validator])

    %{data | generator: filtered_generator, validator: filtered_validator}
  end

  defp filter_generator(seed, size, generator, validator) do
    {next, seed} = generator.(seed, size)
    case Saul.validate(next, validator) do
      {:ok, transformed} -> {transformed, seed}
      _other -> filter_generator(seed, size, generator, validator)
    end
  end

  ## Generators

  def int() do
    generator = fn seed, size ->
      {next, seed} = :rand.uniform_s(size * 2, seed)
      {next - size, seed}
    end

    new(generator, &is_integer/1)
  end

  def list(%__MODULE__{} = data) do
    generator = fn seed, size ->
      {length, seed} = :rand.uniform_s(size + 1, seed)
      length = length - 1

      if length > 0 do
        Enum.map_reduce(1..length, seed, fn _i, acc ->
          data.generator.(acc, size)
        end)
      else
        {[], seed}
      end
    end

    validator = Saul.list_of(data.validator)

    new(generator, validator)
  end

  def binary() do
    generator = fn seed, size ->
      {length, seed} = :rand.uniform_s(size + 1, seed)
      length = length - 1

      if length > 0 do
        {bytes, seed} = Enum.map_reduce(1..length, seed, fn _, acc ->
          {byte, seed} = :rand.uniform_s(256, acc)
          {byte - 1, seed}
        end)
        {IO.iodata_to_binary(bytes), seed}
      else
        {<<>>, seed}
      end
    end

    new(generator, &is_binary/1)
  end
end

defimpl Enumerable, for: Stream.Data do
  def reduce(_data, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  def reduce(data, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(data, &1, fun)}
  end

  def reduce(data, {:cont, acc}, fun) do
    {next_elem, new_seed} = data.generator.(data.seed, data.size)
    reduce(%{data | seed: new_seed}, fun.(next_elem, acc), fun)
  end

  def count(_data) do
    {:error, __MODULE__}
  end

  def member?(_data, _elem) do
    {:error, __MODULE__}
  end
end
