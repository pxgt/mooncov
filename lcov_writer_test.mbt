///|
test "encode deterministic LCOV records and summaries" {
  let file = @mooncov.FileCoverage::new("src/lib.mbt", test_name="unit")
  file.add_line(9, 0)
  file.add_line(2, 4)
  file.add_branch(9, "0", "1", None)
  file.add_branch(9, "0", "0", Some(2))
  file.add_function("later", 0, line=9)
  file.add_function("early", 4, line=2)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  inspect(
    @mooncov.to_lcov(report),
    content=(
      #|TN:unit
      #|SF:src/lib.mbt
      #|FN:2,early
      #|FN:9,later
      #|FNDA:4,early
      #|FNDA:0,later
      #|FNF:2
      #|FNH:1
      #|DA:2,4
      #|DA:9,0
      #|LF:2
      #|LH:1
      #|BRDA:9,0,0,2
      #|BRDA:9,0,1,-
      #|BRF:2
      #|BRH:1
      #|end_of_record
      #|
    ),
  )
}

///|
test "LCOV parser and writer round trip the unified model" {
  let source =
    #|TN:roundtrip
    #|SF:src/parser.mbt
    #|FN:3,parse
    #|FNDA:7,parse
    #|DA:3,7
    #|DA:4,1
    #|BRDA:4,0,0,1
    #|BRDA:4,0,1,0
    #|end_of_record
    #|
  let first = @mooncov.parse_lcov(source)
  let encoded = @mooncov.to_lcov(first)
  let second = @mooncov.parse_lcov(encoded)
  assert_true(first == second)
}

///|
test "LCOV writer rejects record-breaking path text" {
  let report = @mooncov.CoverageReport::new()
  report.add_file(@mooncov.FileCoverage::new("src/a.mbt\nSF:injected.mbt"))
  try @mooncov.to_lcov(report) catch {
    InvalidModel(message) =>
      inspect(message, content="source path must not contain a newline")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid model error")
  }
}

///|
test "LCOV writer canonicalizes duplicate paths and entries" {
  let first = @mooncov.FileCoverage::new("src/dup.mbt")
  first.add_line(1, 2)
  let second = @mooncov.FileCoverage::new("src/./dup.mbt")
  second.add_line(1, 3)
  let report = @mooncov.CoverageReport::new()
  report.add_file(first)
  report.add_file(second)
  let output = @mooncov.to_lcov(report)
  inspect(output.split("SF:").count(), content="2")
  assert_true(output.contains("DA:1,5"))
  assert_false(output.contains("DA:1,2"))
}
