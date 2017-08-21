# Changelog

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
