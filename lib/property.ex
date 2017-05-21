defmodule Property do
  def compile(clauses, block) do
    quote do
      fn var!(seed), var!(size) ->
        unquote(compile_clauses(clauses, block))
      end
    end
  end

  # Compiles the list of clauses to code that will execute those clauses. Note
  # that in the returned code, the "state" variable is available in the bindings
  # (as var!(state)). This is also valid for updating the state, which can be
  # done by assigning var!(state) = to_something.
  defp compile_clauses(clauses, block)

  # We finished to compile all clauses, so we just execute the block and if no
  # exceptions are raised (by assertions for example) we return.
  defp compile_clauses([], block) do
    quote do
      result = unquote(block)
      {{:success, result}, var!(seed)}
    end
  end

  # "pattern <- generator" clauses. We compile this to a case that keeps going
  # with the other clauses if the pattern matches, otherwise returns
  # {:pattern_failed, new_state}.
  defp compile_clauses([{:<-, _meta, [pattern, generator]} | rest], block) do
    quote generated: true do
      case unquote(generator).generator.(var!(seed), var!(size)) do
        {unquote(pattern), new_seed} ->
          var!(seed) = new_seed
          unquote(compile_clauses(rest, block))
        {_other, new_seed} ->
          {:filtered_out, new_seed}
      end
    end
  end

  defp compile_clauses([{:=, _meta, [_left, _right]} = assignment | rest], block) do
    quote do
      unquote(assignment)
      unquote(compile_clauses(rest, block))
    end
  end

  defp compile_clauses([expression | rest], block) do
    quote do
      if unquote(expression) do
        unquote(compile_clauses(rest,  block))
      else
        {:filtered_out, var!(seed)}
      end
    end
  end
end
