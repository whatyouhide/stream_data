defmodule Property do
  @moduledoc false

  defmodule Failure do
    @moduledoc false
    defstruct [:exception, :stacktrace, :generated_values]
  end

  defmodule Success do
    @moduledoc false
    defstruct [:generated_values]
  end

  @doc """
  Takes the AST of a list of clauses and the AST for a block of code and returns
  a property generator.

  A property generator is a `StreamData` generator that generates either
  `Property.Failure` or `Property.Success` structs.

  Each clause in `clauses` can be:

    * `pattern <- generator`: combines basically to
      `StreamData.bind(generator, fn pattern -> ... end)`.

    * `pattern = expression`: works exactly like `=` works, binding variables
      and possibly failing with a `MatchError`.

    * `expression`: works as a filter, that is, if it returns a truthy value then
      the whole chain of generated values is considered valid, otherwise it's
      not.

  """
  def compile(clauses, block) do
    quote do
      var!(generated_values) = []
      {:pass, data} = unquote(compile_clauses(clauses, block) |> (fn x -> IO.puts(Macro.to_string(x)); x end).())
      data
    end
  end

  defp compile_clauses(clauses, block)

  defp compile_clauses([], block) do
    quote do
      generated_values = Enum.reverse(var!(generated_values))

      data = StreamData.constant(fn ->
        try do
          unquote(block)
        rescue
          exception ->
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
      data = StreamData.bind_filter(unquote(generator), fn unquote(pattern) = generated_value ->
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
