defmodule Stream.Data.Random do
  def uniform_in_range(left..right, seed) when left > right do
    uniform_in_range(right..left, seed)
  end

  def uniform_in_range(left..right, seed) do
    width = right - left
    {random_int, seed} = :rand.uniform_s(width + 1, seed)
    {random_int - 1 + left, seed}
  end

  def boolean(seed) do
    {random_int, seed} = :rand.uniform_s(2, seed)
    {random_int == 2, seed}
  end
end
