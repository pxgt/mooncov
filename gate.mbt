///|
/// Coverage dimensions supported by a threshold gate.
pub(all) enum CoverageMetric {
  Lines
  Branches
  Functions
} derive(Debug, Eq)

///|
/// Optional minimum percentages for each coverage dimension.
pub(all) struct CoverageThresholds {
  lines : Double?
  branches : Double?
  functions : Double?
} derive(Debug)

///|
/// One failed coverage threshold.
pub(all) struct ThresholdViolation {
  metric : CoverageMetric
  actual : Double
  required : Double
} derive(Debug)

///|
/// The complete result of evaluating thresholds.
pub(all) struct GateResult {
  passed : Bool
  summary : CoverageSummary
  violations : Array[ThresholdViolation]
} derive(Debug)

///|
/// Construct optional percentage thresholds.
pub fn CoverageThresholds::new(
  lines? : Double,
  branches? : Double,
  functions? : Double,
) -> CoverageThresholds {
  { lines, branches, functions }
}

///|
fn validate_threshold(
  metric : String,
  value : Double?,
) -> Unit raise CoverageError {
  match value {
    Some(number) =>
      if number.is_nan() ||
        number.is_inf() ||
        number < 0.0 ||
        number > 100.0 {
        raise InvalidThreshold(metric, number)
      }
    None => ()
  }
}

///|
fn add_violation(
  violations : Array[ThresholdViolation],
  metric : CoverageMetric,
  actual : Double,
  required : Double?,
) -> Unit {
  match required {
    Some(minimum) =>
      if actual < minimum {
        violations.push({ metric, actual, required: minimum })
      }
    None => ()
  }
}

///|
/// Evaluate report-wide minimum coverage percentages.
///
/// Equality passes: a 75% result satisfies a 75% threshold. Metrics without
/// instrumented items evaluate to 100%; see `CoverageCount::percentage`.
pub fn check_thresholds(
  report : CoverageReport,
  thresholds : CoverageThresholds,
) -> GateResult raise CoverageError {
  validate_threshold("lines", thresholds.lines)
  validate_threshold("branches", thresholds.branches)
  validate_threshold("functions", thresholds.functions)
  let summary = summarize(report)
  let violations : Array[ThresholdViolation] = []
  add_violation(
    violations,
    Lines,
    summary.lines.percentage(),
    thresholds.lines,
  )
  add_violation(
    violations,
    Branches,
    summary.branches.percentage(),
    thresholds.branches,
  )
  add_violation(
    violations,
    Functions,
    summary.functions.percentage(),
    thresholds.functions,
  )
  { passed: violations.is_empty(), summary, violations }
}
