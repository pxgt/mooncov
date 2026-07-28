///|
/// A covered-item count and its instrumented total.
pub(all) struct CoverageCount {
  covered : Int
  total : Int
} derive(Debug, Eq)

///|
/// Line, branch, and function totals for a report or source file.
pub(all) struct CoverageSummary {
  lines : CoverageCount
  branches : CoverageCount
  functions : CoverageCount
} derive(Debug, Eq)

///|
/// A summary associated with one source path.
pub(all) struct FileSummary {
  path : String
  summary : CoverageSummary
} derive(Debug, Eq)

///|
/// Return the percentage in the inclusive range 0..100.
///
/// A metric with no instrumented items is defined as 100%, matching the
/// practical gate semantics that an absent metric cannot fail a build.
pub fn CoverageCount::percentage(self : CoverageCount) -> Double {
  if self.total == 0 {
    100.0
  } else {
    self.covered.to_double() * 100.0 / self.total.to_double()
  }
}

///|
fn summarize_canonical_file(file : FileCoverage) -> CoverageSummary {
  let lines = {
    covered: file.lines.fold(
      init=0,
      (count, item) => if item.is_covered() { count + 1 } else { count },
    ),
    total: file.lines.length(),
  }
  let branches = {
    covered: file.branches.fold(
      init=0,
      (count, item) => if item.is_covered() { count + 1 } else { count },
    ),
    total: file.branches.length(),
  }
  let functions = {
    covered: file.functions.fold(
      init=0,
      (count, item) => if item.is_covered() { count + 1 } else { count },
    ),
    total: file.functions.length(),
  }
  { lines, branches, functions }
}

///|
fn add_counts(left : CoverageCount, right : CoverageCount) -> CoverageCount {
  {
    covered: left.covered + right.covered,
    total: left.total + right.total,
  }
}

///|
fn add_summaries(
  left : CoverageSummary,
  right : CoverageSummary,
) -> CoverageSummary {
  {
    lines: add_counts(left.lines, right.lines),
    branches: add_counts(left.branches, right.branches),
    functions: add_counts(left.functions, right.functions),
  }
}

///|
fn empty_summary() -> CoverageSummary {
  {
    lines: { covered: 0, total: 0 },
    branches: { covered: 0, total: 0 },
    functions: { covered: 0, total: 0 },
  }
}

///|
/// Summarize one source file after coalescing duplicate coverage identities.
pub fn summarize_file(
  file : FileCoverage,
) -> CoverageSummary raise CoverageError {
  let report : CoverageReport = { files: [file] }
  let canonical = canonicalize_report(report)
  summarize_canonical_file(canonical.files[0])
}

///|
/// Summarize a whole report after coalescing duplicate paths and entries.
pub fn summarize(
  report : CoverageReport,
) -> CoverageSummary raise CoverageError {
  let canonical = canonicalize_report(report)
  canonical.files.fold(
    init=empty_summary(),
    (summary, file) =>
      add_summaries(summary, summarize_canonical_file(file)),
  )
}

///|
/// Produce deterministic per-file summaries sorted by normalized path.
pub fn summarize_files(
  report : CoverageReport,
) -> Array[FileSummary] raise CoverageError {
  let canonical = canonicalize_report(report)
  [
    for file in canonical.files => {
      path: file.path,
      summary: summarize_canonical_file(file),
    }
  ]
}
