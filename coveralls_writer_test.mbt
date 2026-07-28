///|
test "Coveralls encoder creates sparse coverage arrays" {
  let file = @mooncov.FileCoverage::new("src/sparse.mbt")
  file.add_line(2, 1)
  file.add_line(5, 3)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let encoded = @mooncov.to_coveralls_json(
    report,
    service_name="moon-test",
    service_job_id="42",
  )
  let decoded = @mooncov.parse_coveralls(encoded)
  inspect(decoded.files[0].lines.length(), content="2")
  inspect(decoded.files[0].lines[0].line, content="2")
  inspect(decoded.files[0].lines[1].line, content="5")
  inspect(decoded.files[0].lines[1].hits, content="3")
}

///|
test "Coveralls branch identifiers and null counts round trip" {
  let file = @mooncov.FileCoverage::new("src/branch.mbt")
  file.add_branch(7, "block-a", "1", None)
  file.add_branch(7, "0", "0", Some(5))
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let decoded = @mooncov.parse_coveralls(@mooncov.to_coveralls_json(report))
  inspect(decoded.files[0].branches.length(), content="2")
  inspect(decoded.files[0].branches[0].block, content="0")
  inspect(decoded.files[0].branches[1].block, content="block-a")
  assert_true(decoded.files[0].branches[1].taken is None)
}

///|
test "Coveralls encoder merges duplicate line slots" {
  let file = @mooncov.FileCoverage::new("src/duplicates.mbt")
  file.add_line(1, 2)
  file.add_line(1, 4)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let decoded = @mooncov.parse_coveralls(@mooncov.to_coveralls_json(report))
  inspect(decoded.files[0].lines.length(), content="1")
  inspect(decoded.files[0].lines[0].hits, content="6")
}
