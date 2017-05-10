defmodule Stream.Data do
  # * A set of values that can be generated,
  # * A probability distribution on that set,
  # * A way of shrinking generated values to similar,
  #   smaller values---used after a test fails, to enable
  #   QuickCheck to search for a similar, but simpler failing case.

  defstruct [
    :generator,
    :validator,
    :state,
  ]

  def new(generator, validator, options \\ []) when is_function(generator, 1) do
    state = %{
      size: options[:size] || 10,
      seed: options[:seed] || :rand.seed(:exs64),
    }

    %__MODULE__{generator: generator, validator: validator, state: state}
  end

  def filter(%__MODULE__{} = data, validator) do
    filtered_generator = fn state ->
      filter_generator(state, data.generator, validator)
    end
    filtered_validator = Saul.all_of([data.validator, validator])

    %{data | generator: filtered_generator, validator: filtered_validator}
  end

  defp filter_generator(state, generator, validator) do
    {next_elem, new_state} = generator.(state)
    case Saul.validate(next_elem, validator) do
      {:ok, transformed} -> {transformed, new_state}
      _other -> filter_generator(new_state, generator, validator)
    end
  end

  ## Generators

  def int() do
    generator = fn state ->
      {next, seed} = :rand.uniform_s(state.size * 2, state.seed)
      {next - state.size, %{state | seed: seed}}
    end

    new(generator, &is_integer/1)
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
    {next_elem, new_state} = data.generator.(data.state)
    reduce(%{data | state: new_state}, fun.(next_elem, acc), fun)
  end

  def count(_data) do
    {:error, __MODULE__}
  end

  def member?(_data, _elem) do
    {:error, __MODULE__}
  end
end
