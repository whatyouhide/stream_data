defmodule Stream.Data.LazyTreeTest do
  use ExUnit.Case

  alias Stream.Data.LazyTree

  test "new/2" do
    assert %LazyTree{} = tree = LazyTree.new(:root, [:child1, :child2])
    assert tree.root == :root
    assert tree.children == [:child1, :child2]
  end

  test "constant/1" do
    assert %LazyTree{} = tree = LazyTree.constant(:term)
    assert realize_tree(tree).children == []
  end

  test "map/2" do
    import LazyTree, only: [new: 2, constant: 1]
    tree = new(1, [constant(2), constant(3)])
    mapped_tree = LazyTree.map(tree, &Integer.to_string/1)
    expected = new("1", [constant("2"), constant("3")])

    assert realize_tree(mapped_tree) == realize_tree(expected)
  end

  test "map_filter/2" do
    import LazyTree, only: [new: 2, constant: 1]
    require Integer

    tree = new(1, [constant(2), constant(3)])
    {:ok, mapped_tree} = LazyTree.map_filter(tree, fn int ->
      if Integer.is_odd(int) do
        {:pass, Integer.to_string(int)}
      else
        :skip
      end
    end)
    expected = new("1", [constant("3")])

    assert realize_tree(mapped_tree) == realize_tree(expected)
  end

  test "flatten/1" do
    import LazyTree, only: [new: 2, constant: 1]

    tree1 = new(:root1, [constant(:child1_a), constant(:child1_b)])
    tree2 = new(:root2, [constant(:child2_a), constant(:child2_b)])
    tree = new(tree1, [constant(tree2)])

    assert %LazyTree{} = joined_tree = LazyTree.flatten(tree)

    expected = new(:root1, [
      constant(:child1_a),
      constant(:child1_b),
      new(:root2, [constant(:child2_a), constant(:child2_b)]),
    ])

    assert realize_tree(joined_tree) == realize_tree(expected)
  end

  test "filter/2" do
    import LazyTree, only: [new: 2, constant: 1]

    tree = new(1, [
      new(1, [constant(-1), constant(2)]), # here only an inner child is removed since it doesn't pass the filter
      new(-1, [constant(1), constant(2)]), # this whole branch is cut since the root doesn't pass the filter
    ])

    filtered_tree = LazyTree.filter(tree, &(&1 > 0))

    expected = new(1, [
      new(1, [constant(2)]),
    ])

    assert realize_tree(filtered_tree) == realize_tree(expected)
  end

  test "zip/1" do
    import LazyTree, only: [new: 2, constant: 1]
    tree1 = new(11, [new(13, [constant(14)])])
    tree2 = new(21, [constant(22), constant(23)])

    assert %LazyTree{} = zipped_tree = LazyTree.zip([tree1, tree2])

    assert realize_tree(zipped_tree).root == [11, 21]
  end

  test "implementation of the Inspect protocol" do
    assert inspect(LazyTree.constant(:root)) == "#LazyTree<:root, []>"
    assert inspect(LazyTree.new(:root, [1, 2, 3])) == "#LazyTree<:root, [...]>"
  end

  defp realize_tree(tree) do
    %{tree | children: Enum.map(tree.children, &realize_tree/1)}
  end
end
