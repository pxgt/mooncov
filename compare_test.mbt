///|
fn comparison_report(
  path : String,
  hits : Array[Int],
) -> @mooncov.CoverageReport raise @mooncov.CoverageError {
  let file = @mooncov.FileCoverage::new(path)
  for index, count in hits {
    file.add_line(index + 1, count)
  }
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  report
}

///|
test "compare report percentages in percentage points" {
  let baseline = comparison_report("src/a.mbt", [1, 1, 0, 0])
  let current = comparison_report("src/a.mbt", [1, 1, 1, 0])
  let comparison = @mooncov.compare_reports(baseline, current)
  inspect(comparison.lines.before.percentage(), content="50")
  inspect(comparison.lines.after.percentage(), content="75")
  inspect(comparison.lines.percentage_delta, content="25")
  assert_true(comparison.files[0].kind == Modified)
}

///|
test "comparison labels added, removed, and unchanged files" {
  let baseline = @mooncov.CoverageReport::new()
  baseline.add_file(@mooncov.FileCoverage::new("removed.mbt"))
  baseline.add_file(@mooncov.FileCoverage::new("same.mbt"))
  let current = @mooncov.CoverageReport::new()
  current.add_file(@mooncov.FileCoverage::new("added.mbt"))
  current.add_file(@mooncov.FileCoverage::new("same.mbt"))
  let files = @mooncov.compare_reports(baseline, current).files
  inspect(files.length(), content="3")
  guard files.search_by(file => file.path == "added.mbt") is Some(added) else {
    fail("expected added file")
  }
  guard files.search_by(file => file.path == "removed.mbt") is Some(removed) else {
    fail("expected removed file")
  }
  guard files.search_by(file => file.path == "same.mbt") is Some(same) else {
    fail("expected unchanged file")
  }
  assert_true(files[added].kind == Added)
  assert_true(files[removed].kind == Removed)
  assert_true(files[same].kind == Unchanged)
}

///|
test "regression allowance is inclusive at its boundary" {
  let baseline = comparison_report("src/a.mbt", [1, 1, 1, 1])
  let current = comparison_report("src/a.mbt", [1, 1, 1, 0])
  let exact = @mooncov.check_regressions(
    baseline,
    current,
    @mooncov.RegressionLimits::new(lines=25.0),
  )
  assert_true(exact.passed)
  let strict = @mooncov.check_regressions(
    baseline,
    current,
    @mooncov.RegressionLimits::new(lines=24.9),
  )
  assert_false(strict.passed)
  inspect(strict.violations.length(), content="1")
  inspect(strict.violations[0].percentage_delta, content="-25")
}

///|
test "empty unsupported dimensions stay neutral during comparison" {
  let baseline = comparison_report("src/a.mbt", [1])
  let current = comparison_report("src/a.mbt", [0])
  let comparison = @mooncov.compare_reports(baseline, current)
  inspect(comparison.branches.percentage_delta, content="0")
  inspect(comparison.functions.percentage_delta, content="0")
}

///|
test "comparison Markdown reports signs and file states" {
  let baseline = comparison_report("src/a.mbt", [1, 0])
  let current = comparison_report("src/a.mbt", [1, 1])
  let markdown = @mooncov.comparison_to_markdown(
    @mooncov.compare_reports(baseline, current),
  )
  assert_true(markdown.contains("| **Overall** | lines |"))
  assert_true(markdown.contains("+50.00 pp"))
  assert_true(markdown.contains("`src/a.mbt` (modified)"))
}

///|
test "regression message names all failed dimensions" {
  let baseline = @mooncov.parse_lcov(
    "SF:a.mbt\nFN:1,f\nFNDA:1,f\nDA:1,1\nBRDA:1,0,0,1\nend_of_record\n",
  )
  let current = @mooncov.parse_lcov(
    "SF:a.mbt\nFN:1,f\nFNDA:0,f\nDA:1,0\nBRDA:1,0,0,0\nend_of_record\n",
  )
  let result = @mooncov.check_regressions(
    baseline,
    current,
    @mooncov.RegressionLimits::new(lines=0.0, branches=0.0, functions=0.0),
  )
  let message = @mooncov.regression_message(result)
  assert_true(message.contains("lines changed -100.00 pp"))
  assert_true(message.contains("branches changed -100.00 pp"))
  assert_true(message.contains("functions changed -100.00 pp"))
}
