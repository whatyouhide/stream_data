defmodule StreamData.LazyTree do
  @moduledoc false

  # A lazy tree structure.
  #
  # A lazy tree has a root (which is always a realized term) and a possibly lazy
  # enumerable of children (which are in turn lazy trees). This allows to create
  # infinitely deep trees where the children are a lazy stream that can be
  # realized on demand.

  defstruct [:root, :children]

  @type t(node) :: %__MODULE__{
    root: node,
    children: Enumerable.t, # of t(node)
  }

  @doc """
  Creates a new lazy tree from the given `root` and enumerable of `children`.

  ## Examples

      StreamData.LazyTree.new(1, Stream.map([StreamData.LazyTree.constant(2)], &(&1 * 2)))

  """
  @spec new(a, Enumerable.t) :: t(a) when a: term
  def new(root, children) do
    %__MODULE__{root: root, children: children}
  end

  @doc """
  Creates a "constant" tree where `term` is the root and there are no children.

  ## Examples

      StreamData.LazyTree.constant(:some_term)

  """
  @spec constant(a) :: t(a) when a: term
  def constant(term) do
    new(term, [])
  end

  @doc """
  Maps the given `fun` over the given `lazy_tree`.

  The given function `fun` is applied eagerly to the root of the given tree,
  and then lazily to the children of such tree. This means that mapping over a tree
  is a cheap operation because it only actually calls `fun` once until children
  are realized.

  ## Examples

      tree = StreamData.LazyTree.new(1, [])
      StreamData.LazyTree.map(tree, &(-&1))

  """
  @spec map(t(a), (a -> b)) :: t(b) when a: term, b: term
  def map(%__MODULE__{root: root, children: children}, fun) when is_function(fun, 1) do
    new(fun.(root), Stream.map(children, &map(&1, fun)))
  end

  @doc """
  Maps and filters the given `lazy_tree` in one go using the given function `fun`.

  `fun` can return either `{:cont, mapped_term}` or `:skip`. If it returns
  `{:cont, mapped_term}`, then `mapped_term` will replace the original item passed
  to `fun` in the given tree. If it returns `:skip`, the tree the item passed to
  `fun` belongs to is filtered out of the resulting tree (the whole tree is filtered
  out, not just the root).

  ## Examples

      tree = StreamData.LazyTree.new(1, [])
      StreamData.LazyTree.filter_map(tree, fn integer ->
        if rem(integer, 2) == 0 do
          {:cont, -integer}
        else
          :skip
        end
      end)

  """
  @spec filter_map(t(a), (a -> {:cont, b} | :skip)) ::
        {:ok, t(b)} | :error when a: term, b: term
  def filter_map(%__MODULE__{} = tree, fun) when is_function(fun, 1) do
    %__MODULE__{root: root} = tree = map(tree, fun)

    case root do
      {:cont, _} ->
        tree =
          tree
          |> filter(&match?({:cont, _}, &1))
          |> map(fn {:cont, elem} -> elem end)
        {:ok, tree}
      :skip ->
        :error
    end
  end

  @doc """
  Takes a tree of trees and flattens it to a tree of elements in those trees.

  The tree is flattened so that the root and its children always come "before"
  (as in higher or more towards the left in the tree) the children of `tree.`

  ## Examples

      StreamData.LazyTree.new(1, [])
      |> StreamData.LazyTree.map(&StreamData.LazyTree.constant/1)
      |> StreamData.LazyTree.flatten()

  """
  @spec flatten(t(t(a))) :: t(a) when a: term
  def flatten(%__MODULE__{root: %__MODULE__{}} = tree) do
    new(tree.root.root, Stream.concat(tree.root.children, Stream.map(tree.children, &flatten/1)))
  end

  @doc """
  Filters element out of `tree` that don't satisfy the given `predicate`.

  When an element of `tree` doesn't satisfy `predicate`, the whole tree whose
  root is that element is filtered out of the original `tree`.

  Note that this function does not apply `predicate` to the root of `tree`, just
  to its children (and recursively down). This behaviour exists because if the
  root of `tree` did not satisfy `predicate`, the return value couldn't be a
  tree at all.

  ## Examples

      tree = StreamData.LazyTree.new(1, [])
      StreamData.LazyTree.filter(tree, &(rem(&1, 2) == 0))

  """
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

  @doc """
  Zips a list of trees into a single tree.

  Each element in the resulting tree is a list of as many elements as there are
  trees in `trees`. Each of these elements is going to be a list where each element
  comes from the corresponding tree in `tree`. All permutations of children are
  generated (lazily).

  ## Examples

      trees = [StreamData.LazyTree.new(1, []), StreamData.LazyTree.new(2, [])]
      StreamData.LazyTree.zip(trees).root
      #=> [1, 2]


  """
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
