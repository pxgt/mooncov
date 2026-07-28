///|
fn report_fixture() -> @mooncov.CoverageReport raise @mooncov.CoverageError {
  let file = @mooncov.FileCoverage::new("src/lib|core.mbt", test_name="unit")
  file.add_line(1, 2)
  file.add_line(2, 0)
  file.add_branch(2, "0", "0", Some(0))
  file.add_function("run", 2, line=1)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  report
}

///|
test "Markdown report contains overall and escaped file rows" {
  let output = @mooncov.to_markdown(report_fixture(), title="CI | coverage")
  assert_true(output.contains("## CI \\| coverage"))
  assert_true(output.contains("| **Overall** | 50.00% (1/2)"))
  assert_true(output.contains("`src/lib\\|core.mbt`"))
  assert_true(output.contains("100.00% (1/1)"))
}

///|
test "Markdown report can omit file details" {
  let output = @mooncov.to_markdown(
    report_fixture(),
    include_files=false,
  )
  assert_true(output.contains("**Overall**"))
  assert_false(output.contains("src/lib"))
}

///|
test "unified JSON retains all three coverage dimensions" {
  let output = @mooncov.to_json_report(report_fixture())
  assert_true(@json.valid(output))
  assert_true(output.contains("\"format\": \"mooncov-report-v1\""))
  assert_true(output.contains("\"functions\""))
  assert_true(output.contains("\"test_name\": \"unit\""))
  assert_true(output.contains("\"percentage\": 50"))
}

///|
test "JSON report is deterministic after canonicalization" {
  let first = @mooncov.CoverageReport::new()
  first.add_file(@mooncov.FileCoverage::new("z.mbt"))
  first.add_file(@mooncov.FileCoverage::new("a.mbt"))
  let second = @mooncov.CoverageReport::new()
  second.add_file(@mooncov.FileCoverage::new("a.mbt"))
  second.add_file(@mooncov.FileCoverage::new("z.mbt"))
  inspect(
    @mooncov.to_json_report(first) == @mooncov.to_json_report(second),
    content="true",
  )
}

///|
test "gate messages explain every violation" {
  let result = @mooncov.check_thresholds(
    report_fixture(),
    @mooncov.CoverageThresholds::new(lines=80.0, branches=10.0),
  )
  let message = @mooncov.gate_message(result)
  assert_true(message.has_prefix("coverage gate failed:"))
  assert_true(message.contains("lines 50% < 80%"))
  assert_true(message.contains("branches 0% < 10%"))
}
