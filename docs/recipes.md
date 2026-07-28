# Recipes

## Convert MoonBit Coveralls JSON to LCOV

Generate coverage with the MoonBit toolchain, then normalize it:

```text
moon coverage report -f coveralls -o coverage.json
moon run cmd/main -- normalize coveralls coverage.json > lcov.info
```

The exact `moon coverage report` options vary by toolchain release. Verify the
installed command with:

```text
moon coverage report --help
```

## Merge reports from parallel test jobs

When all inputs share a format:

```text
moon run cmd/main -- merge lcov unit.info integration.info > combined.info
```

For mixed formats, call `parse_lcov`, `parse_coveralls`, or
`parse_cobertura` in a small MoonBit program, then pass the reports to
`merge_reports`.

## Normalize Cobertura XML

```text
moon coverage report -f cobertura -o coverage.xml
moon run cmd/main -- summary cobertura coverage.xml
moon run cmd/main -- normalize cobertura coverage.xml > lcov.info
```

## Enforce line coverage in CI

```text
moon run cmd/main -- gate lcov combined.info 80
```

Exit code 0 means pass, 2 means the measured percentage is below the threshold,
and 1 means input or command processing failed.

For separate line, branch, and function thresholds, use the library API:

```mbt nocheck
let result = @mooncov.check_thresholds(
  report,
  @mooncov.CoverageThresholds::new(
    lines=80.0,
    branches=70.0,
    functions=85.0,
  ),
)
```

## Exclude generated files

```mbt nocheck
let filtered = @mooncov.select_paths(
  report,
  ["src/**/*.mbt"],
  ["**/generated/**", "**/vendor/**"],
)
```

Apply filtering before summary, gating, or export.

## Pull-request changed-line coverage

Save a standard unified diff and use:

```mbt nocheck
let ranges = @mooncov.parse_unified_diff(diff_text)
let result = @mooncov.check_diff_threshold(report, ranges, 90.0)
```

Inspect `result.summary.unmatched_files`. A strict CI policy may choose to fail
when it is non-empty.

## Markdown check summary

```mbt nocheck
let body = @mooncov.to_markdown(
  report,
  title="Coverage for pull request",
)
```

The output is suitable for a job summary or pull-request comment. Paths and
titles have Markdown table separators and newlines escaped.
