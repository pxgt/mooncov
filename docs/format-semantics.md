# Format semantics

This document records the interoperability decisions used by mooncov 0.1.0.

## Unified model

A report contains files. A file has a normalized source path, an optional test
name, and independent line, branch, and function entries.

- A line is identified by its positive source line number.
- A branch is identified by line, block string, and branch string.
- A function is identified by name and optional declaration line.
- Hit counts are non-negative MoonBit `Int` values.
- An unknown branch count is distinct from numeric zero.

Canonicalization sums duplicate identities and sorts paths and entries. It is
used before statistics and full-fidelity JSON output, preventing duplicate
records from inflating coverage totals.

## LCOV

### Accepted input

- `TN`, including an empty test name;
- `SF`;
- `FN` and `FNDA`;
- `DA`, with an optional checksum field;
- `BRDA`, including `-` for unknown taken counts;
- `FNF`, `FNH`, `LF`, `LH`, `BRF`, and `BRH`;
- `VER`;
- `end_of_record`.

Blank lines and lines beginning with `#` are ignored. Summary fields are
accepted for compatibility but recalculated from entries. The last record may
omit `end_of_record`.

An unknown tag is an error so a misspelled data tag cannot silently erase
coverage. Errors contain the one-based physical input line.

### Output

Serialization canonicalizes the whole report first. Every output record
includes `TN`, `SF`, calculated function totals, calculated line totals,
calculated branch totals, and `end_of_record`. Files and entries are sorted by
stable identity. A function whose declaration line is unknown has `FNDA`
output but no invented `FN` line.

LCOV has no general escaping mechanism. Newlines in source paths, test names,
or function names are rejected during encoding.

## Coveralls JSON

The decoder reads:

- root `source_files`;
- each source file's `name`;
- sparse `coverage` values, where array index plus one is the source line;
- optional flattened `branches` quadruples.

Line `null` means uninstrumented. Branch `null` means instrumented but with an
unknown taken count. Counts must be finite, integral, and non-negative. Branch
block and branch identifiers may be integers or strings.

The encoder emits service metadata, source names, sparse coverage arrays, and
branches. Function coverage is not encoded because the interoperable schema has
no standard field for it.

## Cobertura XML

The decoder reads class `filename` attributes, class-level line `number` and
`hits`, optional method names and method lines, and standard
`condition-coverage="P% (covered/total)"` attributes. XML declarations,
comments, CDATA, and declarations are skipped; quoted attributes support named
and numeric XML entities.

Cobertura does not carry LCOV block and branch identifiers. A condition total
is represented with synthetic block `cobertura` and zero-based branch strings;
the covered synthetic entries precede uncovered entries. This preserves
aggregate branch statistics without claiming identity information the source
format lacks.

The encoder emits deterministic Cobertura XML with root, package, class,
method, line, and condition elements. It canonicalizes first. Function entries
without a known source line are omitted because a valid method line cannot be
invented.

## Merge

Paths are normalized before matching. Counts for identical entries are added.
Known and unknown branch counts combine as follows:

| Left | Right | Result |
|:--|:--|:--|
| unknown | unknown | unknown |
| known | unknown | known |
| unknown | known | known |
| known | known | sum |

Equal test names are retained. One absent name adopts the present name.
Conflicting names result in no test name, avoiding a false single-producer
label.

## Statistics and gates

An entry is covered only when its count is greater than zero. Unknown branches
are instrumented totals but not covered. Percentages use
`covered * 100 / total`.

An empty dimension is 100%. This makes unsupported dimensions neutral rather
than automatically failing. A caller that requires presence can separately
check that `CoverageCount::total` is nonzero.

Gate thresholds must be finite values in the inclusive range 0–100. An actual
percentage equal to its threshold passes.

## Unified diff

The parser uses destination (`+++`) paths and new-file ranges from `@@` hunk
headers. Conventional `a/` and `b/` prefixes are removed. New-file headers,
deleted files, optional hunk counts, CRLF input, and tab-separated header
timestamps are supported.

Only instrumented line records inside changed ranges are counted. Overlapping
ranges do not double-count a line. A path that has no matching file report is
listed in `unmatched_files`.

Mooncov 0.1.0 strips surrounding path quotes but does not decode Git's C-style
quoted-path escape sequences.
