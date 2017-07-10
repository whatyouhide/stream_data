defmodule StreamData.LazyTree do
  @moduledoc """
  A lazy tree structure.

  A lazy tree has a root (which is always a realized term) and a possibly lazy
  enumerable of children (which are in turn lazy trees). This allows to create
  infinitely deep trees where the children are a lazy stream that can be
  realized on demand.
  """

  defstruct [:root, :children]

  @type t(node) :: %__MODULE__{
    root: node,
    children: Enumerable.t, # of t(node)
  }

  @spec new(a, Enumerable.t) :: t(a) when a: term
  def new(root, children) do
    %__MODULE__{root: root, children: children}
  end

  @spec constant(a) :: t(a) when a: term
  def constant(term) do
    new(term, [])
  end

  @spec map(t(a), (a -> b)) :: t(b) when a: term, b: term
  def map(%__MODULE__{root: root, children: children}, fun) when is_function(fun, 1) do
    new(fun.(root), Stream.map(children, &map(&1, fun)))
  end

  @spec map_filter(t(a), (a -> {:pass, b} | :skip)) ::
        {:ok, t(b)} | :error when a: term, b: term
  def map_filter(%__MODULE__{} = tree, fun) when is_function(fun, 1) do
    tree = map(tree, fun)

    case tree.root do
      {:pass, _} ->
        tree =
          tree
          |> filter(&match?({:pass, _}, &1))
          |> map(fn {:pass, elem} -> elem end)
        {:ok, tree}
      :skip ->
        :error
    end
  end

  @spec flatten(t(t(a))) :: t(a) when a: term
  def flatten(%__MODULE__{root: %__MODULE__{}} = tree) do
    new(tree.root.root, Stream.concat(tree.root.children, Stream.map(tree.children, &flatten/1)))
  end

  @spec filter(t(a), (a -> as_boolean(term))) :: t(a) when a: term
  def filter(%__MODULE__{} = tree, predicate) when is_function(predicate, 1) do
    children = Stream.flat_map(tree.children, fn child ->
      if predicate.(child.root) do
        [filter(child, predicate)]
      else
        []
      end
    end)

    %{tree | children: children}
  end

  @spec zip([t(a)]) :: t([a]) when a: term
  def zip(trees) do
    root = Enum.map(trees, &(&1.root))
    children =
      trees
      |> permutations()
      |> Stream.map(&zip/1)

    new(root, children)
  end

  defp permutations(trees) when is_list(trees) do
    trees
    |> Stream.with_index()
    |> Stream.flat_map(fn {tree, index} -> Enum.map(tree.children, &List.replace_at(trees, index, &1)) end)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(tree, options) do
      children = if Enum.empty?(tree.children), do: "[]", else: "[...]"
      concat(["#LazyTree<", to_doc(tree.root, options), ", #{children}>"])
    end
  end
end
