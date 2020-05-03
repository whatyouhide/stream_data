# Changelog

## v0.5.0

  * Slightly improve the shrinking algorigthm.
  * Add `StreamData.map_of/2`.
  * Fix a bug around the `:max_shrinking_steps` option.
  * Fix a runtime warning with Elixir 1.10.

## v0.4.3

  * Improve the frequency of terms in `StreamData.term/0`
  * Fix a bug in `StreamData.positive_integer/0` that would crash with a genration size of `0`.
  * Support inline `, do:` in `gen all` and `check all`.
  * Support `:initial_seed` in `check all`.
  * Export formatter configuration for `check all` and `gen all`.
  * Add `StreamData.seeded/2`.

## v0.4.2

  * Fix a bug when shrinking boolean values generated with `StreamData.boolean/0`

## v0.4.1

  * Import all functions/macros from `ExUnitProperties` when `use`d
  * Various optimizations
  * Add the `:max_run_time` configuration option to go together with `:max_runs`
  * Add support for `:do` syntax in `gen all`/`check all`

## v0.4.0

  * Add a `StreamData.term/0` generator
  * Bump the number of allowed consecutive failures in `StreamData.filter/3` and `StreamData.bind_filter/3`
  * Improve error message for `StreamData.filter/3`
  * Add `ExUnitProperties.pick/1`
  * Add `Enumerable.slice/1` to `StreamData` structs
  * Improve the performance of `StreamData.bitstring/1`

#### Breaking changes

  * Remove `StreamData.unquoted_atom/0` in favour of `StreamData.atom(:unquoted | :alias)`
  * Start behaving like filtering when patterns don't match in `check all` or `gen all`
  * Remove special casing of `=` clauses in `check all` and `gen all`
  * Introduce `StreamData.float/1` replacing `StreamData.uniform_float/0`

## v0.3.0

  * Add length-related options to `StreamData.string/2`
  * Introduce `StreamData.positive_integer/0`
  * Raise a better error message on invalid generators
  * Fix the `StreamData.t/0` type
  * Add support for `rescue/catch/after` in `ExUnitProperties.property/2,3`
  * Introduce `StreamData.optional_map/1`
  * Add support for keyword lists as argument to `StreamData.fixed_map/1`

#### Breaking changes

  * Change the arguments to `StreamData.string/2` so that it can take `:ascii`, `:alphanumeric`, `:printable`, a range, or a list of ranges or single codepoints
  * Rename `PropertyTest` to `ExUnitProperties` and introduce `use ExUnitProperties` to use in tests that use property-based testing

## v0.2.0

  * Add length-related options to `StreamData.list_of/2`, `StreamData.uniq_list_of/1`, `StreamData.binary/1`
  * Add a `StreamData.bitstring/1` generator

#### Breaking changes

  * Remove `StreamData.string_from_chars/1`, `StreamData.ascii_string/0`, and `StreamData.alphanumeric_string/0` in favour of `StreamData.string/1`
  * Rename `StreamData.non_empty/1` to `StreamData.nonempty/1`
  * Rename `StreamData.int/0,1` to `StreamData.integer/0,1`
  * Rename `StreamData.no_shrink/` to `StreamData.unshrinkable/1`
  * Remove `StreamData.uniq_list_of/3` in favour of `StreamData.uniq_list_of/2` (which takes options)

## v0.1.1

  * Fix a bug with `check all` syntax where it wouldn't work with assignments in the clauses.
