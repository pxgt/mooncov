///|
/// Coverage before and after a change, plus the percentage-point delta.
#derive(Debug)
pub(all) struct MetricChange {
  before : CoverageCount
  after : CoverageCount
  percentage_delta : Double
}

///|
/// How a source path changed between two reports.
#derive(Debug, Eq)
pub(all) enum FileChangeKind {
  Added
  Removed
  Modified
  Unchanged
}

///|
/// A per-file summary comparison.
#derive(Debug, Eq)
pub(all) struct FileComparison {
  path : String
  kind : FileChangeKind
  before : CoverageSummary
  after : CoverageSummary
}

///|
/// Report-wide metric changes and path-level comparisons.
#derive(Debug)
pub(all) struct CoverageComparison {
  baseline : CoverageSummary
  current : CoverageSummary
  lines : MetricChange
  branches : MetricChange
  functions : MetricChange
  files : Array[FileComparison]
}

///|
/// Allowed percentage-point drops for regression checks.
#derive(Debug)
pub(all) struct RegressionLimits {
  lines : Double?
  branches : Double?
  functions : Double?
}

///|
/// One metric whose drop exceeded its allowance.
#derive(Debug)
pub(all) struct RegressionViolation {
  metric : CoverageMetric
  percentage_delta : Double
  allowed_drop : Double
}

///|
/// Result of comparing current coverage to a baseline policy.
#derive(Debug)
pub(all) struct RegressionResult {
  passed : Bool
  comparison : CoverageComparison
  violations : Array[RegressionViolation]
}

///|
/// Construct optional maximum percentage-point drops.
pub fn RegressionLimits::new(
  lines? : Double,
  branches? : Double,
  functions? : Double,
) -> RegressionLimits {
  { lines, branches, functions, }
}

///|
fn metric_change(before : CoverageCount, after : CoverageCount) -> MetricChange {
  { before, after, percentage_delta: after.percentage() - before.percentage(), }
}

///|
fn file_summary_map(
  report : CoverageReport,
) -> Map[String, CoverageSummary] raise CoverageError {
  let summaries : Map[String, CoverageSummary] = Map([])
  for file in summarize_files(report) {
    summaries[file.path] = file.summary
  }
  summaries
}

///|
fn file_change_kind(
  before_present : Bool,
  after_present : Bool,
  before : CoverageSummary,
  after : CoverageSummary,
) -> FileChangeKind {
  match (before_present, after_present) {
    (false, true) => Added
    (true, false) => Removed
    (true, true) => if before == after { Unchanged } else { Modified }
    (false, false) => Unchanged
  }
}

///|
/// Compare a current report to a baseline after canonicalization.
///
/// Deltas are percentage points, so moving from 75% to 80% is `+5`, not a
/// relative 6.67% increase. File comparisons include added and removed paths.
pub fn compare_reports(
  baseline_report : CoverageReport,
  current_report : CoverageReport,
) -> CoverageComparison raise CoverageError {
  let baseline = summarize(baseline_report)
  let current = summarize(current_report)
  let before_files = file_summary_map(baseline_report)
  let after_files = file_summary_map(current_report)
  let path_set : Map[String, Unit] = Map([])
  for path, _ in before_files {
    path_set[path] = ()
  }
  for path, _ in after_files {
    path_set[path] = ()
  }
  let paths = [ for path, _ in path_set => path ]
  paths.sort()
  let files : Array[FileComparison] = []
  for path in paths {
    let before_present = before_files.contains(path)
    let after_present = after_files.contains(path)
    let before = before_files.get_or_default(path, empty_summary())
    let after = after_files.get_or_default(path, empty_summary())
    files.push({
      path,
      kind: file_change_kind(before_present, after_present, before, after),
      before,
      after,
    })
  }
  {
    baseline,
    current,
    lines: metric_change(baseline.lines, current.lines),
    branches: metric_change(baseline.branches, current.branches),
    functions: metric_change(baseline.functions, current.functions),
    files,
  }
}

///|
fn add_regression_violation(
  violations : Array[RegressionViolation],
  metric : CoverageMetric,
  change : MetricChange,
  allowance : Double?,
) -> Unit {
  match allowance {
    Some(allowed_drop) =>
      if change.percentage_delta < -allowed_drop {
        violations.push({
          metric,
          percentage_delta: change.percentage_delta,
          allowed_drop,
        })
      }
    None => ()
  }
}

///|
/// Fail when a coverage percentage drops by more than an allowed number of
/// percentage points.
///
/// Equality passes: a 5-point drop satisfies an allowance of 5 points.
pub fn check_regressions(
  baseline : CoverageReport,
  current : CoverageReport,
  limits : RegressionLimits,
) -> RegressionResult raise CoverageError {
  validate_threshold("line regression allowance", limits.lines)
  validate_threshold("branch regression allowance", limits.branches)
  validate_threshold("function regression allowance", limits.functions)
  let comparison = compare_reports(baseline, current)
  let violations : Array[RegressionViolation] = []
  add_regression_violation(violations, Lines, comparison.lines, limits.lines)
  add_regression_violation(
    violations,
    Branches,
    comparison.branches,
    limits.branches,
  )
  add_regression_violation(
    violations,
    Functions,
    comparison.functions,
    limits.functions,
  )
  { passed: violations.is_empty(), comparison, violations, }
}

///|
fn delta_text(delta : Double) -> String {
  let hundredths = (delta * 100.0).round().to_int()
  let sign = if hundredths > 0 { "+" } else { "" }
  let absolute = if hundredths < 0 { -hundredths } else { hundredths }
  let whole = absolute / 100
  let fraction = absolute % 100
  let fraction_text = if fraction < 10 {
    "0\{fraction}"
  } else {
    fraction.to_string()
  }
  if hundredths < 0 {
    "-\{whole}.\{fraction_text} pp"
  } else {
    "\{sign}\{whole}.\{fraction_text} pp"
  }
}

///|
fn comparison_kind_text(kind : FileChangeKind) -> String {
  match kind {
    Added => "added"
    Removed => "removed"
    Modified => "modified"
    Unchanged => "unchanged"
  }
}

///|
fn write_comparison_row(
  output : StringBuilder,
  scope : String,
  metric : String,
  change : MetricChange,
) -> Unit {
  output.write_string(
    "| \{markdown_cell(scope)} | \{metric} | " +
    "\{count_text(change.before)} | \{count_text(change.after)} | " +
    "\{delta_text(change.percentage_delta)} |\n",
  )
}

///|
/// Render an overall and optional per-file baseline comparison as Markdown.
pub fn comparison_to_markdown(
  comparison : CoverageComparison,
  title~ : String = "Coverage comparison",
  include_files~ : Bool = true,
) -> String {
  let output = StringBuilder()
  output.write_string("## \{markdown_cell(title)}\n\n")
  output.write_string("| Scope | Metric | Before | After | Delta |\n")
  output.write_string("|:--|:--|--:|--:|--:|\n")
  write_comparison_row(output, "**Overall**", "lines", comparison.lines)
  write_comparison_row(output, "**Overall**", "branches", comparison.branches)
  write_comparison_row(output, "**Overall**", "functions", comparison.functions)
  if include_files {
    for file in comparison.files {
      let scope = "`\{file.path}` (\{comparison_kind_text(file.kind)})"
      write_comparison_row(
        output,
        scope,
        "lines",
        metric_change(file.before.lines, file.after.lines),
      )
      write_comparison_row(
        output,
        scope,
        "branches",
        metric_change(file.before.branches, file.after.branches),
      )
      write_comparison_row(
        output,
        scope,
        "functions",
        metric_change(file.before.functions, file.after.functions),
      )
    }
  }
  output.to_string()
}

///|
/// Produce a concise regression result for CI logs.
pub fn regression_message(result : RegressionResult) -> String {
  if result.passed {
    return "coverage regression check passed"
  }
  let messages : Array[String] = []
  for violation in result.violations {
    messages.push(
      "\{metric_name(violation.metric)} " +
      "changed \{delta_text(violation.percentage_delta)}; " +
      "allowed drop \{violation.allowed_drop} pp",
    )
  }
  "coverage regression check failed: \{messages.join("; ")}"
}
