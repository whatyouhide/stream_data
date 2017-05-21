defmodule EQC do
  use ExUnit.Case
  use EQC.ExUnit

  property "naturals are >= 0" do
    forall n <- nat() do
      ensure n >= 0
    end
  end
end
