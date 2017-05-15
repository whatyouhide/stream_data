defmodule PropertyTest do
  defmacro for_all({:with, _meta, options}) when is_list(options) do
    [[do: block] | reverse_clauses] = Enum.reverse(options)
    clauses = Enum.reverse(reverse_clauses)

    quote do
      iteration_fun = unquote(compile_iteration_fun(clauses, block))
      initial_state = %{size: 10, seed: :rand.seed_s(:exs64)}

      initial_state
      |> Stream.unfold(iteration_fun)
      |> Stream.filter(&match?({:iteration_completed, _}, &1))
      |> Stream.take(100)
      |> Enum.each(fn _ -> IO.write("≈") end)
    end
  end

  # Returns the quoted code for an "iteration function", which is just a fn that
  # represents an iteration of the test: basically, this fn takes a state (a
  # random seed) and returns the result of the test (for example, if a pattern
  # failed it will be :pattern_failed) alongside a new state.
  defp compile_iteration_fun(clauses, block) when is_list(clauses) do
    quote do
      fn(var!(state)) ->
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
  # exceptions are raised (by assertions for example) we return {:ok,
  # final_state}.
  defp compile_clauses([], block) do
    quote do
      result = unquote(block)
      {{:iteration_completed, result}, var!(state)}
    end
  end

  # "var <- generator" clauses. We compile this to just a pattern matching since
  # if we compiled this to a case (like "pattern <- generator") the first clause
  # of that case will always match, thus leaving us with warnings all over the
  # place.
  defp compile_clauses([{:<-, _meta, [{var_name, _, context} = var, generator]} | rest], block)
      when is_atom(var_name) and is_atom(context) do
    quote do
      seed = var!(state).seed
      size = var!(state).size
      {unquote(var), new_seed} = unquote(generator).generator.(seed, size)
      var!(state) = %{var!(state) | seed: new_seed}
      unquote(compile_clauses(rest, block))
    end
  end

  # "pattern <- generator" clauses. We compile this to a case that keeps going
  # with the other clauses if the pattern matches, otherwise returns
  # {:pattern_failed, new_state}.
  defp compile_clauses([{:<-, _meta, [pattern, generator]} | rest], block) do
    quote do
      case unquote(generator).generator.(var!(state)) do
        {unquote(pattern), new_state} ->
          var!(state) = new_state
          unquote(compile_clauses(rest, block))
        {_other, new_state} ->
          {:pattern_failed, new_state}
      end
    end
  end

  defp compile_clauses([expression | rest], block) do
    quote do
      unquote(expression)
      unquote(compile_clauses(rest, block))
    end
  end
end
