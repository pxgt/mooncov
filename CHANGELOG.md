# Changelog

All notable changes to `mooncov` are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## 0.1.0 - 2026-07-28

### Added

- Format-neutral line, branch, and function coverage model.
- LCOV parser with physical-line diagnostics and deterministic writer.
- Coveralls/CodeCov JSON parser and writer for line and branch coverage.
- Path normalization plus portable `*`, `?`, and `**` filtering.
- Duplicate-safe multi-report merge and canonicalization.
- Overall and per-file coverage summaries.
- Line, branch, and function percentage gates.
- Unified-diff range parsing and changed-line coverage gates.
- Markdown and full-fidelity JSON reports.
- Native file-oriented command-line example.
- Cross-backend tests and GitHub Actions verification.
