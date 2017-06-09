defmodule Stream.Data.Random do
  @algorithm :exs1024

  def split(seed) do
    {int1, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int2, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int3, seed} = :rand.uniform_s(1_000_000_000, seed)
    new_seed = :rand.seed_s(@algorithm, {int1, int2, int3})
    {new_seed, seed}
  end

  def uniform_in_range(left..right, seed) when left > right do
    uniform_in_range(right..left, seed)
  end

  def uniform_in_range(left..right, seed) do
    width = right - left
    {random_int, _seed} = :rand.uniform_s(width + 1, seed)
    random_int - 1 + left
  end
end
