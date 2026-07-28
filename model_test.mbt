///|
test "construct a report through the public model API" {
  let file = @mooncov.FileCoverage::new(
    "src/math.mbt",
    test_name="unit-tests",
  )
  file.add_line(3, 2)
  file.add_line(8, 0)
  file.add_branch(8, "0", "1", Some(0))
  file.add_function("sum", 2, line=3)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  inspect(report.files.length(), content="1")
  inspect(report.files[0].lines.length(), content="2")
  assert_true(report.files[0].lines[0].is_covered())
  assert_false(report.files[0].branches[0].is_covered())
}

///|
test "model rejects invalid source positions and counts" {
  let file = @mooncov.FileCoverage::new("src/bad.mbt")
  try file.add_line(0, 1) catch {
    InvalidLineNumber(line) => inspect(line, content="0")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid line error")
  }
  try file.add_branch(1, "0", "0", Some(-1)) catch {
    InvalidHitCount(hits) => inspect(hits, content="-1")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid hit count error")
  }
}
