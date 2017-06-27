defmodule Stream.Data.LazyTree do
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

  @spec pure(a) :: t(a) when a: term
  def pure(term) do
    new(term, [])
  end

  @spec fmap(t(a), (a -> b)) :: t(b) when a: term, b: term
  def fmap(%__MODULE__{} = tree, fun) when is_function(fun, 1) do
    new(fun.(tree.root), Stream.map(tree.children, &fmap(&1, fun)))
  end

  @spec join(t(t(a))) :: t(a) when a: term
  def join(%__MODULE__{root: %__MODULE__{}} = tree) do
    new(tree.root.root, Stream.concat(tree.root.children, Stream.map(tree.children, &join/1)))
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
end
