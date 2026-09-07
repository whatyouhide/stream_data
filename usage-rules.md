# StreamData Usage Rules

## Overview

StreamData is an Elixir library for lazy, composable data generation and property-based testing. Build generators with `StreamData`, exercise invariants with `ExUnitProperties`, and preserve each generator's shrinking behavior so failures reduce to small, reproducible examples.

## Setup

- Require Elixir 1.14 or later and add StreamData as a test dependency:

  ```elixir
  defp deps do
    [{:stream_data, "~> 1.0", only: :test}]
  end
  ```

- Run `mix deps.get`, then `use ExUnitProperties` in property-test modules; this imports both `ExUnitProperties` macros and `StreamData` generators.
- To format `property`, `check all`, and `gen all` syntax, make the dependency available in `[:dev, :test]` and set `import_deps: [:stream_data]` in `.formatter.exs`.

## Core Usage Patterns

- Treat generators as lazy, infinite enumerables when sampling outside property tests; bound enumeration with calls such as `Enum.take/2`.
- Use `constant/1` for a fixed arbitrary term. Only atoms and tuples containing generators are converted implicitly during generator composition.
- Prefer `StreamData.map/2`, `bind/2`, `filter/3`, or `gen all` over `Stream`/`Enum` transformations when shrinking must be retained; ordinary stream transformations discard shrinking information.
- Use `map/2` when every input can be transformed into a valid output; reserve `filter/3` for predicates that reject only a small fraction of the generation space.
- Use `bind/2` or later `gen all` clauses for dependent data, such as selecting `member_of/1` only after generating a non-empty list.
- Start every `gen all` and `check all` expression with a `pattern <- generator` clause. Later bare expressions may filter values or bind derived values.
- Expect a non-matching pattern in a generation clause to act as a filter and potentially raise `StreamData.FilterTooNarrowError`.
- Use `one_of/1` for equal choice and `frequency/1` for weighted choice; put simpler generators first because both combinators shrink toward earlier entries.
- Pass only non-empty, finite enumerables to `member_of/1`; values shrink toward entries earlier in the enumerable.
- Use `list_of/2`, `binary/1`, `bitstring/1`, and `uniq_list_of/2` with `:length`, `:min_length`, or `:max_length`. `:length` takes precedence over both bounds.
- Use `uniq_list_of/2` with `:uniq_fun` for `Enum.uniq_by/2` semantics and increase `:max_tries` only when the underlying generation space is genuinely large enough.
- Use `fixed_list/1` or `fixed_map/1` when structure must remain present while values shrink; use `optional_map/2` to identify removable keys, with every unlisted key remaining required.
- Use `map_of/3`, `mapset_of/2`, and `uniq_list_of/2` only with generators capable of producing enough unique values at small generation sizes.
- Use `nonempty/1` only for generated enumerables. Prefer a native minimum-length option, such as `list_of(data, min_length: 1)`, when available.
- Use `string/2` with `:ascii`, `:alphanumeric`, `:printable`, `:utf8`, a codepoint range, or a list of ranges/codepoints. Set `count: :graphemes` when length constraints must match `String.length/1`; the default is `:codepoints`.
- Use `date/1` with either `:origin`, `:min`/`:max`, or a `Date.Range`; range values honor the range step and shrink toward its first date.
- Use `tree/2` for recursive data: supply a leaf generator and a function that builds an inner-node generator from the provided child generator.
- Use `nullable/2` to include `nil`; `ratio: 0.0..1.0` controls how often `nil` is selected and defaults to `0.5`.
- Use `sized/1` to derive a generator from the current generation size, `resize/2` to force a non-negative size, and `scale/2` to transform size growth.
- Use `seeded/2` when direct generator enumeration must be repeatable. In property tests, prefer ExUnit's default seed or pass `initial_seed:` to `check all` to replay a failure.
- Use `repeatedly/1` for values produced by side-effectful zero-arity functions and `unshrinkable/1` only when losing all shrink candidates is intentional.

## Configuration

- Configure property defaults under the `:stream_data` application:

  ```elixir
  config :stream_data,
    initial_size: 1,
    max_runs: 100,
    max_run_time: :infinity,
    max_shrinking_steps: 100,
    inspect_opts: []
  ```

- Override `:initial_size`, `:max_runs`, `:max_run_time`, and `:max_shrinking_steps` per `check all`; per-check values take precedence over application configuration.
- Use `:max_generation_size` only as a `check all` option to cap the otherwise unbounded size increase.
- When both `:max_runs` and `:max_run_time` are finite, checking stops at whichever limit is reached first; never set both to `:infinity`.
- Set `:inspect_opts` in application configuration to control how generated values appear in failure reports, for example `inspect_opts: [limit: :infinity]`.

## Common Mistakes to Avoid

- Do not pass raw integers, lists, maps, or other arbitrary terms where a generator is expected; wrap them with `constant/1`. The implicit exceptions are atoms and tuples of generators.
- Do not use a narrow filter to construct a common domain such as even integers; map integers with `&(&1 * 2)` so generation remains efficient and cannot exhaust consecutive attempts.
- Do not request unique collections whose minimum length exceeds the generator's small-size value space; apply `resize/2` or `scale/2`, or redesign the element generator.
- Do not assume generation size shrinks. Constraints derived in `sized/1`, such as `min_length: size`, remain fixed while a generated value shrinks.
- Do not expect `:min_length` or exact `:length` collections to shrink below that bound; structural shrinking always respects length options.
- Do not combine `date(origin: ...)` with `:min` or `:max`, and ensure a bounded date's `:max` is not before its `:min`.
- Do not call `ExUnitProperties.pick/1` outside an ExUnit test process; it requires the random seed installed by ExUnit.
- Do not use `StreamData.check_all/3` without `:initial_seed`; unlike `check all`, the lower-level function requires it.

## Testing

- Define property-only tests with `property/3`, then generate inputs with `check all`; this tags and reports the test as a property and returns `:ok` on success.

  ```elixir
  property "reversing preserves length" do
    check all list <- list_of(integer()) do
      assert length(Enum.reverse(list)) == length(list)
    end
  end
  ```

- Keep hand-picked examples for known edge cases and use properties for invariants over broad generated domains.
- Let `check all` inherit ExUnit's seed so `mix test --seed <seed>` reproduces generation; set `initial_seed:` explicitly only when a property needs its own deterministic sequence.
- Use `max_runs:` to control iteration count and `max_run_time:` for a time budget; configure larger CI runs through `config :stream_data` when desired.
- In doctests, call `use ExUnitProperties` in the module that invokes `doctest/1`, and show `:ok` as the result of `check all`.
- Use `ExUnitProperties.pick/1` inside an ExUnit test when one generated sample is sufficient; use `resize/2` or `scale/2` first when the random size range of `1..100` is unsuitable.
