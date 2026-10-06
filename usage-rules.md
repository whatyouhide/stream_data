# StreamData Usage Rules

StreamData provides lazy, composable data generators (`StreamData`) and property-based testing (`ExUnitProperties`). Installation, formatter setup, and introductory examples live in the package README (`deps/stream_data/README.md`); these rules only cover what is easy to get wrong.

## Looking Up Docs

The module docs are the reference for every generator's options and shrinking behavior. Don't guess options — look them up:

```sh
mix usage_rules.search_docs "shrinking" -p stream_data
mix usage_rules.search_docs "max_runs" -p stream_data
mix usage_rules.search_docs "ExUnitProperties.check" -p stream_data --query-by title
```

StreamData is usually a test-only dependency, so `mix usage_rules.docs StreamData` can't load it in the dev env. Use `search_docs` instead.

Read the `StreamData` moduledoc sections "Generation size" and "Shrinking", and the `ExUnitProperties.check/1` "Options" section, before tuning sizes or run limits.

## Generators

- Keep shrinking: compose with `StreamData.map/2`, `bind/2`, `filter/3`, or `gen all`. Piping a generator through `Stream`/`Enum` functions discards shrinking.
- Only atoms and tuples of generators are implicitly converted to generators. Wrap any other fixed term with `constant/1`.
- Prefer `map/2` over `filter/3` (e.g. even integers: `map(integer(), &(&1 * 2))`). Narrow filters, and non-matching patterns in `gen all`/`check all` clauses, raise `StreamData.FilterTooNarrowError`.
- Use `bind/2` or later `gen all` clauses for dependent data (e.g. pick `member_of/1` from a previously generated non-empty list).
- `one_of/1`, `frequency/1`, and `member_of/1` shrink toward earlier entries — list the simplest choices first.
- Prefer native length options (`list_of(x, min_length: 1)`) over `nonempty/1`.
- `uniq_list_of/2`, `map_of/3`, and `mapset_of/2` need element generators with enough distinct values at small sizes; otherwise use `resize/2`/`scale/2` or a richer generator.
- Generation size does not shrink: constraints derived inside `sized/1` stay fixed while the value shrinks, and collections never shrink below `:min_length`/`:length`.
- Generators are infinite; outside properties, bound them (`Enum.take/2`) and use `seeded/2` for repeatable output.

## Properties

- Write properties with `property/2,3` + `check all`, and start every `check all`/`gen all` with a `pattern <- generator` clause.
- Let `check all` inherit ExUnit's seed so `mix test --seed <seed>` reproduces failures. The lower-level `StreamData.check_all/3` requires an explicit `:initial_seed`.
- `ExUnitProperties.pick/1` only works inside an ExUnit test process.
- Per-`check all` options override `config :stream_data`; never set both `:max_runs` and `:max_run_time` to `:infinity`.
- In doctests, `use ExUnitProperties` in the module calling `doctest/1`, and expect `check all` to return `:ok`.
