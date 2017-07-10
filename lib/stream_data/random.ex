defmodule StreamData.Random do
  @moduledoc false

  @algorithm :exs1024

  @type seed :: :rand.state

  @doc """
  Returns a new random seed from the given `int`.

  If passed the same `int` this function will return the same seed.
  """
  # TODO: is {0, 0, ex_unit_seed} good?
  @spec new_seed(integer) :: seed
  def new_seed(int) when is_integer(int) do
    :rand.seed_s(@algorithm, {0, 0, int})
  end

  @doc """
  Takes a random `seed` and splits it into two different seeds.

  Returns `{seed1, seed2}`. Splitting is deterministic, so when given the same
  `seed` twice, this function will split it into the same two seeds.
  """
  @spec split(seed) :: {seed, seed}
  def split(seed) do
    {int1, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int2, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int3, seed} = :rand.uniform_s(1_000_000_000, seed)
    new_seed = :rand.seed_s(@algorithm, {int1, int2, int3})
    {new_seed, seed}
  end

  @doc """
  Returns a random integer in the (inclusive) range `range`.

  The order of `range` (ascending or descending) doesn't matter.
  """
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
