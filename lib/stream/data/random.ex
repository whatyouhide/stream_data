defmodule Stream.Data.Random do
  @moduledoc false

  @algorithm :exs1024

  @type seed :: :rand.state

  @spec new_seed(integer) :: seed
  def new_seed(int) when is_integer(int) do
    :rand.seed_s(@algorithm, {0, 0, int})
  end

  @spec split(seed) :: {seed, seed}
  def split(seed) do
    {int1, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int2, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int3, seed} = :rand.uniform_s(1_000_000_000, seed)
    new_seed = :rand.seed_s(@algorithm, {int1, int2, int3})
    {new_seed, seed}
  end

  @spec uniform_in_range(Range.t(integer, integer), seed) :: integer
  def uniform_in_range(range, seed)

  def uniform_in_range(left..right, seed) when left > right do
    uniform_in_range(right..left, seed)
  end

  def uniform_in_range(left..right, seed) do
    width = right - left
    {random_int, _seed} = :rand.uniform_s(width + 1, seed)
    random_int - 1 + left
  end
end
