defmodule Stream.Data.Random do
  def split(seed) do
    {int_tuple1, seed} = triple_of_ints(seed)
    {int_tuple2, _seed} = triple_of_ints(seed)

    seed1 = :rand.seed_s(:exs64, int_tuple1)
    seed2 = :rand.seed_s(:exs64, int_tuple2)

    {seed1, seed2}
  end

  def uniform_in_range(left..right, seed) when left > right do
    uniform_in_range(right..left, seed)
  end

  def uniform_in_range(left..right, seed) do
    width = right - left
    {random_int, _seed} = :rand.uniform_s(width + 1, seed)
    random_int - 1 + left
  end

  defp triple_of_ints(seed) do
    {int1, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int2, seed} = :rand.uniform_s(1_000_000_000, seed)
    {int3, seed} = :rand.uniform_s(1_000_000_000, seed)
    {{int1, int2, int3}, seed}
  end
end
