defmodule Property do
  defmodule Failure do
    defstruct [:exception, :stacktrace, :binding, :generated_values]
  end

  defmodule Success do
    defstruct [:result, :binding, :generated_values]
  end

  @doc false
  def __property_generator__(fun, binding, generated_values) do
    import Stream.Data.LazyTree, only: [pure: 1]

    Stream.Data.new(fn _seed, _size ->
      try do
        fun.()
      rescue
        exception in [ExUnit.AssertionError, ExUnit.MultiError] ->
          stacktrace = System.stacktrace()
          pure(%Failure{exception: exception, stacktrace: stacktrace, binding: binding, generated_values: generated_values})
      else
        result ->
          pure(%Success{result: result, binding: binding, generated_values: generated_values})
      end
    end)
  end

  def compile(clauses, block) do
    quote do
      var!(generated_values) = []
      unquote(compile_clauses(clauses, block))
    end
  end

  # Compiles the list of clauses to code that will execute those clauses. Note
  # that in the returned code, the "state" variable is available in the bindings
  # (as var!(state)). This is also valid for updating the state, which can be
  # done by assigning var!(state) = to_something.
  defp compile_clauses(clauses, block)

  defp compile_clauses([], block) do
    quote do
      generated_values = Enum.reverse(var!(generated_values))
      Property.__property_generator__(fn -> unquote(block) end, binding(), generated_values)
    end
  end

  defp compile_clauses([{:<-, _meta, [pattern, generator]} = clause | rest], block) do
    quote do
      Stream.Data.bind(unquote(generator), fn unquote(pattern) = generated_value ->
        var!(generated_values) = [{unquote(Macro.to_string(clause)), generated_value} | var!(generated_values)]
        unquote(compile_clauses(rest, block))
      end)
    end
  end

  defp compile_clauses([{:=, _meta, [_left, _right]} = assignment | rest], block) do
    quote do
      unquote(assignment)
      unquote(compile_clauses(rest, block))
    end
  end
end
