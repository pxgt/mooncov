///|
/// Include/exclude rules for normalized source paths.
///
/// An empty include list accepts every path. Excludes are evaluated after
/// includes and always win.
pub(all) struct PathFilter {
  includes : Array[String]
  excludes : Array[String]
} derive(Debug, Eq)

///|
/// Construct a reusable path filter.
pub fn PathFilter::new(
  includes : Array[String],
  excludes : Array[String],
) -> PathFilter {
  { includes, excludes }
}

///|
/// Construct a filter that accepts every path.
pub fn PathFilter::all() -> PathFilter {
  { includes: [], excludes: [] }
}

///|
fn any_glob_matches(patterns : Array[String], path : String) -> Bool {
  for pattern in patterns {
    if glob_match(pattern, path) {
      return true
    }
  }
  false
}

///|
/// Test whether a source path passes this filter.
pub fn PathFilter::allows(self : PathFilter, path : String) -> Bool {
  let normalized = normalize_path(path)
  let included = self.includes.is_empty() ||
    any_glob_matches(self.includes, normalized)
  included && !any_glob_matches(self.excludes, normalized)
}

///|
fn copy_file_coverage(file : FileCoverage) -> FileCoverage {
  {
    path: file.path,
    test_name: file.test_name,
    lines: [for line in file.lines => line],
    branches: [for branch in file.branches => branch],
    functions: [for function in file.functions => function],
  }
}

///|
/// Select files from a report without mutating or aliasing its arrays.
pub fn filter_report(
  report : CoverageReport,
  filter : PathFilter,
) -> CoverageReport {
  {
    files: [
      for file in report.files
      if filter.allows(file.path)
      => copy_file_coverage(file)
    ],
  }
}

///|
/// Convenience wrapper for one-off include and exclude lists.
pub fn select_paths(
  report : CoverageReport,
  includes : Array[String],
  excludes : Array[String],
) -> CoverageReport {
  filter_report(report, PathFilter::new(includes, excludes))
}
