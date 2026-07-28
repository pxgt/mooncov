# mooncov

[![CI](https://github.com/pxgt/mooncov/actions/workflows/ci.yml/badge.svg)](https://github.com/pxgt/mooncov/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

`mooncov` is a pure MoonBit coverage-report toolkit for libraries, command-line
tools, and CI pipelines. It parses LCOV and Coveralls JSON into one typed data
model, merges reports from parallel jobs, normalizes and filters source paths,
checks project or changed-line thresholds, and exports deterministic LCOV,
Coveralls JSON, Markdown, or full-fidelity JSON.

The reusable library supports MoonBit's `wasm`, `wasm-gc`, `js`, and `native`
backends. The optional file-oriented CLI is native-only because it reads local
files.

## Why this exists

`moon coverage report` can produce useful Coveralls, Cobertura, HTML, terminal,
and bisect outputs, but downstream systems often need to combine runs, enforce
their own policy, or translate data without depending on a hosted service.
`mooncov` keeps those workflow operations local and deterministic.

Typical uses include:

- merging unit, integration, and backend-specific coverage;
- converting MoonBit's Coveralls JSON into LCOV for another CI consumer;
- excluding generated or vendored sources with portable globs;
- failing CI when line, branch, or function coverage drops below a threshold;
- checking only instrumented lines touched by a unified Git diff;
- posting a compact Markdown table to a pull request;
- retaining all three coverage dimensions in a stable JSON artifact.

## Feature matrix

| Capability | Status |
|:--|:--|
| LCOV parse and deterministic write | Supported |
| Coveralls/CodeCov JSON parse and write | Supported |
| Line, branch, and function model | Supported |
| Duplicate-safe multi-report merge | Supported |
| Path normalization and `*` / `?` / `**` filters | Supported |
| Overall and per-file summaries | Supported |
| Line, branch, and function threshold gate | Supported |
| Unified-diff changed-line coverage | Supported |
| Markdown and full-fidelity JSON output | Supported |
| Cobertura XML | Not implemented in 0.1.0 |

## Installation

After the package is published to [mooncakes.io](https://mooncakes.io/):

```text
moon add Xpeng/mooncov@0.1.0
```

Then import the root package in `moon.pkg`:

```text
import {
  "Xpeng/mooncov",
}
```

For local development, clone the repository and run:

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
```

The project was developed with `moon 0.1.20260703` and
`moonc v0.10.3+16975d007`.

## Quick start: parse and summarize LCOV

```mbt check
///|
test "README: parse and summarize LCOV" {
  let input =
    #|TN:unit
    #|SF:src/lib.mbt
    #|FN:1,run
    #|FNDA:2,run
    #|DA:1,2
    #|DA:2,0
    #|BRDA:2,0,0,1
    #|BRDA:2,0,1,0
    #|end_of_record
    #|
  let report = @mooncov.parse_lcov(input)
  let summary = @mooncov.summarize(report)
  inspect(summary.lines.covered, content="1")
  inspect(summary.lines.total, content="2")
  inspect(summary.branches.covered, content="1")
  inspect(summary.functions.covered, content="1")
}
```

`parse_lcov` accepts `TN`, `SF`, `FN`, `FNDA`, `DA`, `BRDA`, `VER`, the six
standard aggregate tags, and `end_of_record`. Aggregate totals are recalculated
from entries instead of trusted. A missing final `end_of_record` is accepted;
malformed entries raise `CoverageError::InvalidLcov` with the physical input
line.

## Merge reports and enforce policy

```mbt check
///|
test "README: merge and gate reports" {
  let first = @mooncov.parse_lcov(
    "SF:src/lib.mbt\nDA:1,1\nDA:2,0\nend_of_record\n",
  )
  let second = @mooncov.parse_lcov(
    "SF:src/lib.mbt\nDA:1,2\nDA:2,1\nend_of_record\n",
  )
  let merged = @mooncov.merge_reports([first, second])
  inspect(merged.files[0].lines[0].hits, content="3")
  inspect(merged.files[0].lines[1].hits, content="1")
  let gate = @mooncov.check_thresholds(
    merged,
    @mooncov.CoverageThresholds::new(lines=100.0),
  )
  assert_true(gate.passed)
}
```

Entries merge by these identities:

- file: normalized source path;
- line: source line number;
- branch: line, block identifier, and branch identifier;
- function: function name and optional declaration line.

Counts are added. If one branch count is unknown (`-`/`null`) and another is
known, the known count is retained; two unknown counts remain unknown.

Threshold values are percentages from `0` through `100`, inclusive. Equality
passes. A dimension with no instrumented entries evaluates to 100%, so a
line-only producer does not fail a branch gate merely because it cannot report
branches.

## Path normalization and filtering

```mbt check
///|
test "README: normalize and filter paths" {
  let report = @mooncov.parse_lcov(
    "SF:D:\\repo\\src\\lib.mbt\nDA:1,1\nend_of_record\n" +
    "SF:D:\\repo\\generated\\api.mbt\nDA:1,1\nend_of_record\n",
    strip_prefix="D:/repo",
  )
  let selected = @mooncov.select_paths(report, ["src/**/*.mbt"], [
    "**/generated/**",
  ])
  inspect(selected.files.length(), content="1")
  inspect(selected.files[0].path, content="src/lib.mbt")
}
```

Normalization converts `\` to `/`, removes repeated separators and `.` segments,
and resolves `..` without escaping an absolute root. Matching is
case-sensitive and independent of the host operating system:

- `*` matches zero or more characters inside one segment;
- `?` matches one non-separator character;
- `**` can cross path separators;
- excludes are applied after includes and always win;
- an empty include list accepts all paths.

## Changed-line coverage

```mbt check
///|
test "README: changed-line gate" {
  let report = @mooncov.parse_lcov(
    "SF:src/lib.mbt\nDA:10,1\nDA:11,0\nend_of_record\n",
  )
  let diff =
    #|--- a/src/lib.mbt
    #|+++ b/src/lib.mbt
    #|@@ -9,0 +10,2 @@
    #|+covered
    #|+missed
    #|
  let ranges = @mooncov.parse_unified_diff(diff)
  let result = @mooncov.check_diff_threshold(report, ranges, 50.0)
  assert_true(result.passed)
  inspect(result.summary.lines.total, content="2")
}
```

Diff coverage counts only changed lines that the coverage producer
instrumented. A unified diff alone cannot tell executable lines from comments
or whitespace, so absent line records are not guessed as misses. Paths with no
file-level coverage record are returned in `DiffSummary::unmatched_files` for a
caller to handle explicitly.

## Coveralls JSON

The parser accepts the standard `source_files` array, sparse `coverage` arrays,
and flattened branch arrays. `null` line slots mean “not instrumented” and do
not become misses.

```mbt check
///|
test "README: Coveralls to LCOV" {
  let coveralls = "{\"source_files\":[{\"name\":\"src/a.mbt\"," +
    "\"coverage\":[1,0,null],\"branches\":[2,0,0,0]}]}"
  let report = @mooncov.parse_coveralls(coveralls)
  let lcov = @mooncov.to_lcov(report)
  assert_true(lcov.contains("DA:1,1"))
  assert_true(lcov.contains("DA:2,0"))
  assert_true(lcov.contains("BRDA:2,0,0,0"))
}
```

Coveralls has no standard function-coverage field. Therefore
`to_coveralls_json` intentionally serializes lines and branches only. Use
`to_json_report` when a full-fidelity mooncov artifact is required.

## Output APIs

```mbt nocheck
///|
let lcov : String = @mooncov.to_lcov(report)

///|
let coveralls : String = @mooncov.to_coveralls_json(
  report,
  service_name="github-actions",
  service_job_id="build-42",
)

///|
let markdown : String = @mooncov.to_markdown(report)

///|
let json : String = @mooncov.to_json_report(report)
```

All outputs are deterministic after canonicalization. LCOV records preserve
file order while sorting their entries; the merge, Markdown, and unified JSON
paths sort normalized files.

## Command-line example

The CLI is deliberately a thin adapter over the public library:

```text
# Built-in demo; no input file required
moon run cmd/main

# Reproduce the repository sample
moon run cmd/main -- summary lcov examples/sample.info
moon run cmd/main -- validate lcov examples/sample.info

# Convert either accepted format to canonical LCOV or full JSON
moon run cmd/main -- normalize coveralls path/to/coverage.json
moon run cmd/main -- json lcov path/to/lcov.info

# Exit with code 2 if line coverage is below 80%
moon run cmd/main -- gate lcov path/to/lcov.info 80

# Merge two or more inputs of the same format and print LCOV
moon run cmd/main -- merge lcov unit.info integration.info
```

The root module prefers the native backend so `moon run cmd/main` works without
an extra flag. This preference does not restrict the root library: CI still
checks and tests it on every stable backend.

## Public API overview

- Model: `CoverageReport`, `FileCoverage`, `CoverageLine`,
  `CoverageBranch`, `CoverageFunction`;
- Formats: `parse_lcov`, `to_lcov`, `parse_coveralls`,
  `to_coveralls_json`;
- Composition: `merge_reports`, `canonicalize_report`;
- Paths: `normalize_path`, `glob_match`, `PathFilter`, `filter_report`,
  `select_paths`;
- Statistics: `summarize`, `summarize_file`, `summarize_files`;
- Gates: `CoverageThresholds`, `check_thresholds`, `gate_message`;
- Diff: `parse_unified_diff`, `summarize_diff`, `check_diff_threshold`;
- Reports: `to_markdown`, `to_json_report`.

The generated [pkg.generated.mbti](pkg.generated.mbti) is the authoritative
compact interface listing for release 0.1.0.

## Reproducible verification

Run from the repository root:

```text
moon fmt --check
moon info --target all
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn
moon build --target all
moon run cmd/main
moon run cmd/main -- summary lcov examples/sample.info
moon package
git diff --exit-code
```

CI executes the same essential format, interface, check, build, test, example,
and package gates.

## Scope and compatibility notes

- The 0.1.0 release does not parse or emit Cobertura XML.
- LCOV extension tags other than `VER` are rejected rather than silently
  discarded; standard aggregate tags are accepted.
- LCOV function names may contain commas because only the first comma separates
  their numeric field.
- Coveralls numeric coverage values must be finite, integral, and non-negative.
- Path matching preserves case; callers targeting case-insensitive filesystems
  may normalize case before constructing reports.
- Unified-diff parsing handles standard Git destination headers, optional tab
  timestamps, destination ranges with omitted counts, new files, and deleted
  files. Git C-style escape sequences inside quoted path headers are not
  decoded in 0.1.0.
- Hit-count addition uses MoonBit `Int`; inputs should stay within that type's
  range.

See [docs/format-semantics.md](docs/format-semantics.md) for detailed format
decisions and [docs/recipes.md](docs/recipes.md) for CI-oriented recipes.

## Project origin and open-source compliance

This project is an original MoonBit implementation. It uses public format
documentation as behavioral references:

- [LCOV tracefile format](https://github.com/linux-test-project/lcov);
- [Coveralls JSON format](https://docs.coveralls.io/api-introduction);
- [MoonBit coverage tooling](https://docs.moonbitlang.com/en/stable/toolchain/moon/coverage.html).

No implementation source was copied from LCOV, Coveralls, Codecov, or another
coverage library. Repository fixtures are small original examples written for
this project. The only runtime dependency is
[`moonbitlang/x`](https://mooncakes.io/docs/moonbitlang/x/) for native CLI file
and process access; the library code uses `moonbitlang/core`.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md)
for the validation commands and format-fixture rules. Security issues should be
reported according to [SECURITY.md](SECURITY.md).

## License

Copyright 2026 mooncov contributors.

Licensed under the [Apache License 2.0](LICENSE).
