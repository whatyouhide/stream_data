defmodule EQC do
  use ExUnit.Case
  use EQC.ExUnit

  property "naturals are >= 0" do
    gen = let [l <- list(nat()), sl <- sublist(l)], do: sl ++ sl

    forall n <- nat() do
      ensure n >= 0
    end
  end
end
