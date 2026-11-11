# Changelog

All notable changes to `mooncov` are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## Unreleased

- Adapt numeric parsing to `moonbitlang/core/string`, qualify documentation
  test imports, and migrate derived trait methods without suppressing warnings.
- Refresh source formatting and interfaces for stable MoonBit 2026-11-04
  (`moonc v0.10.20+65efd5b93`).
- Add weekly compatibility checks and an explicit Node.js 22 test runtime.

## 0.1.1 - 2026-08-09

### Fixed

- Use `moonbitlang/core/env.args` in the native CLI so it links with the current
  MoonBit native runtime.

### Changed

- Refresh generated interfaces with MoonBit 0.1.20260803.
- Add architecture and reproducible verification records.
- Run warning 73 checks during tests and verify the frozen package artifact in
  CI.

## 0.1.0 - 2026-07-28

### Added

- Format-neutral line, branch, and function coverage model.
- LCOV parser with physical-line diagnostics and deterministic writer.
- Coveralls `source_files` JSON parser and writer for line and branch coverage.
- Cobertura XML parser and writer for line, branch-condition, and method data.
- Path normalization plus portable `*`, `?`, and `**` filtering.
- Duplicate-safe multi-report merge and canonicalization.
- Overall and per-file coverage summaries.
- Line, branch, and function percentage gates.
- Baseline comparisons, file-change classification, and regression allowances.
- Unified-diff range parsing and changed-line coverage gates.
- Markdown and full-fidelity JSON reports.
- Native file-oriented command-line example.
- Cross-backend tests and GitHub Actions verification.

### Fixed

- Accept bare Windows separators emitted by MoonBit 0.1.20260703 in Coveralls
  source-file names through a strict-first, invalid-escape-only fallback.
- Show structured error payloads in the native CLI.
