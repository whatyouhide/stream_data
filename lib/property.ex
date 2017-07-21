defmodule Property do
  @moduledoc false

  # QUESTION: This can probably be moved inside PropertyTest?

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
  def compile(clauses, body) do
    quote do
      var!(generated_values) = []
      {:cont, data} = unquote(compile_clauses(clauses, body))
      data
    end
  end

  defp compile_clauses(clauses, body)

  defp compile_clauses([], body) do
    quote do
      generated_values = Enum.reverse(var!(generated_values))

      data = StreamData.constant(fn ->
        try do
          unquote(body)
        rescue
          exception ->
            stacktrace = System.stacktrace()
            %Failure{exception: exception, stacktrace: stacktrace, generated_values: generated_values}
        else
          _result ->
            %Success{generated_values: generated_values}
        end
      end)

      {:cont, data}
    end
  end

  defp compile_clauses([{:<-, _meta, [pattern, generator]} = clause | rest], body) do
    quote do
      data = StreamData.bind_filter(unquote(generator), fn unquote(pattern) = generated_value ->
        var!(generated_values) = [{unquote(Macro.to_string(clause)), generated_value} | var!(generated_values)]
        unquote(compile_clauses(rest, body))
      end)

      {:cont, data}
    end
  end

  defp compile_clauses([{:=, _meta, [_left, _right]} = assignment | rest], body) do
    quote do
      unquote(assignment)
      unquote(compile_clauses(rest, body))
    end
  end

  defp compile_clauses([clause | rest], body) do
    quote do
      if unquote(clause) do
        unquote(compile_clauses(rest, body))
      else
        :skip
      end
    end
  end
end
