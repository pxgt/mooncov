# Architecture

`mooncov` separates format handling from coverage analysis. The root MoonBit
package owns the public data model and algorithms; `cmd/main` is a native-only
file adapter around that library.

## Data flow

1. An LCOV, Coveralls JSON, or Cobertura XML parser creates a common
   `CoverageReport` model.
2. Path normalization, filtering, canonicalization, and merge operations work
   only on that model.
3. Summary, threshold, changed-line, comparison, and regression checks consume
   the normalized report without reading files.
4. Writers produce deterministic LCOV, Coveralls JSON, Cobertura XML, Markdown,
   or full JSON output.
5. The CLI handles paths and process exit codes, then delegates to the root
   package.

This split keeps the library portable across wasm, wasm-gc, JavaScript, and
native. Only the file-oriented CLI is restricted to native.

## Boundaries

The project parses and transforms coverage reports. It does not instrument
MoonBit programs, run tests, upload reports, host a CI service, or render an
interactive HTML application. Input text is treated as data and is never
executed.

Format-specific information that cannot be represented by another format is
handled according to [format-semantics.md](format-semantics.md). Public API
changes must be visible in the committed `pkg.generated.mbti` file.

## Maintenance

New format behavior should include malformed-input tests, deterministic
round-trip tests, and a documented information-loss policy. Large-report
performance and property testing are tracked separately from the 0.1.1 release.
