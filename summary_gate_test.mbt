///|
fn summary_fixture() -> @mooncov.CoverageReport raise @mooncov.CoverageError {
  let file = @mooncov.FileCoverage::new("src/summary.mbt")
  file.add_line(1, 3)
  file.add_line(2, 0)
  file.add_line(3, 1)
  file.add_line(4, 0)
  file.add_branch(2, "0", "0", Some(1))
  file.add_branch(2, "0", "1", None)
  file.add_function("covered", 2, line=1)
  file.add_function("missed", 0, line=3)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  report
}

///|
test "summaries count each coverage dimension independently" {
  let summary = @mooncov.summarize(summary_fixture())
  inspect(summary.lines.covered, content="2")
  inspect(summary.lines.total, content="4")
  inspect(summary.lines.percentage(), content="50")
  inspect(summary.branches.covered, content="1")
  inspect(summary.branches.total, content="2")
  inspect(summary.functions.covered, content="1")
  inspect(summary.functions.total, content="2")
}

///|
test "empty dimensions are gate-neutral at one hundred percent" {
  let summary = @mooncov.summarize(@mooncov.CoverageReport::new())
  inspect(summary.lines.percentage(), content="100")
  inspect(summary.branches.percentage(), content="100")
  inspect(summary.functions.percentage(), content="100")
}

///|
test "threshold equality passes while stricter values fail" {
  let exact = @mooncov.check_thresholds(
    summary_fixture(),
    @mooncov.CoverageThresholds::new(lines=50.0, branches=50.0, functions=50.0),
  )
  assert_true(exact.passed)
  let strict = @mooncov.check_thresholds(
    summary_fixture(),
    @mooncov.CoverageThresholds::new(lines=50.1, branches=90.0),
  )
  assert_false(strict.passed)
  inspect(strict.violations.length(), content="2")
  assert_true(strict.violations[0].metric == Lines)
  assert_true(strict.violations[1].metric == Branches)
}

///|
test "summaries coalesce duplicate entries before counting totals" {
  let file = @mooncov.FileCoverage::new("src/dup.mbt")
  file.add_line(1, 0)
  file.add_line(1, 2)
  let summary = @mooncov.summarize_file(file)
  inspect(summary.lines.total, content="1")
  inspect(summary.lines.covered, content="1")
}

///|
test "invalid percentages are rejected before gate evaluation" {
  let report = @mooncov.CoverageReport::new()
  try
    @mooncov.check_thresholds(
      report,
      @mooncov.CoverageThresholds::new(lines=101.0),
    )
  catch {
    InvalidThreshold(metric, value) => {
      inspect(metric, content="lines")
      inspect(value, content="101")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid threshold")
  }
}

///|
test "per-file summaries are path sorted" {
  let report = @mooncov.CoverageReport::new()
  report.add_file(@mooncov.FileCoverage::new("z.mbt"))
  report.add_file(@mooncov.FileCoverage::new("a.mbt"))
  let summaries = @mooncov.summarize_files(report)
  inspect(summaries[0].path, content="a.mbt")
  inspect(summaries[1].path, content="z.mbt")
}
