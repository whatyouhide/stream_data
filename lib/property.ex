defmodule Property do
  defmodule Failure do
    defstruct [:exception, :stacktrace, :generated_values]
  end

  defmodule Success do
    defstruct [:generated_values]
  end

  def compile(clauses, block) do
    quote do
      var!(generated_values) = []
      {:pass, data} = unquote(compile_clauses(clauses, block) |> (fn x -> IO.puts(Macro.to_string(x)); x end).())
      data
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

      data = Stream.Data.fixed(fn ->
        try do
          unquote(block)
        rescue
          exception in [ExUnit.AssertionError, ExUnit.MultiError] ->
            stacktrace = System.stacktrace()
            %Failure{exception: exception, stacktrace: stacktrace, generated_values: generated_values}
        else
          _result ->
            %Success{generated_values: generated_values}
        end
      end)

      {:pass, data}
    end
  end

  defp compile_clauses([{:<-, _meta, [pattern, generator]} = clause | rest], block) do
    quote do
      data = Stream.Data.bind_filter(unquote(generator), fn unquote(pattern) = generated_value ->
        var!(generated_values) = [{unquote(Macro.to_string(clause)), generated_value} | var!(generated_values)]
        unquote(compile_clauses(rest, block))
      end)

      {:pass, data}
    end
  end

  defp compile_clauses([{:=, _meta, [_left, _right]} = assignment | rest], block) do
    quote do
      unquote(assignment)
      unquote(compile_clauses(rest, block))
    end
  end

  defp compile_clauses([clause | rest], block) do
    quote do
      if unquote(clause) do
        unquote(compile_clauses(rest, block))
      else
        :skip
      end
    end
  end
end
