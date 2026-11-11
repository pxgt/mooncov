///|
fn make_merge_report(
  path : String,
  line_hits : Int32,
  branch_hits : Int32?,
  function_hits : Int32,
  test_name? : String,
) -> @mooncov.CoverageReport raise @mooncov.CoverageError {
  let file = match test_name {
    Some(value) => @mooncov.FileCoverage::new(path, test_name=value)
    None => @mooncov.FileCoverage::new(path)
  }
  file.add_line(4, line_hits)
  file.add_branch(5, "0", "1", branch_hits)
  file.add_function("work", function_hits, line=3)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  report
}

///|
test "merge matching normalized files by coverage identity" {
  let first = make_merge_report(
    "D:\\repo\\src\\work.mbt",
    2,
    Some(1),
    3,
    test_name="unit",
  )
  let second = make_merge_report(
    "D:/repo/src/./work.mbt",
    5,
    Some(4),
    7,
    test_name="unit",
  )
  let merged = @mooncov.merge_reports([first, second], strip_prefix="D:/repo")
  inspect(merged.files.length(), content="1")
  inspect(merged.files[0].path, content="src/work.mbt")
  inspect(merged.files[0].lines[0].hits, content="7")
  guard merged.files[0].branches[0].taken is Some(branch_hits) else {
    fail("expected known branch count")
  }
  inspect(branch_hits, content="5")
  inspect(merged.files[0].functions[0].hits, content="10")
}

///|
test "merge known and unknown branch counts without inventing hits" {
  let unknown = make_merge_report("src/a.mbt", 0, None, 0)
  let known = make_merge_report("src/a.mbt", 0, Some(0), 0)
  let result = @mooncov.merge_reports([unknown, known])
  guard result.files[0].branches[0].taken is Some(count) else {
    fail("expected known zero count")
  }
  inspect(count, content="0")
  let both_unknown = @mooncov.merge_reports([unknown, unknown])
  assert_true(both_unknown.files[0].branches[0].taken is None)
}

///|
test "canonicalization coalesces duplicate entries and sorts files" {
  let report = @mooncov.CoverageReport::new()
  let z = @mooncov.FileCoverage::new("z.mbt")
  z.add_line(9, 1)
  z.add_line(2, 2)
  z.add_line(9, 4)
  report.add_file(z)
  report.add_file(@mooncov.FileCoverage::new("a.mbt"))
  let canonical = @mooncov.canonicalize_report(report)
  inspect(canonical.files[0].path, content="a.mbt")
  inspect(canonical.files[1].path, content="z.mbt")
  inspect(canonical.files[1].lines.length(), content="2")
  inspect(canonical.files[1].lines[0].line, content="2")
  inspect(canonical.files[1].lines[1].hits, content="5")
}

///|
test "merge clears conflicting test names" {
  let first = make_merge_report("src/a.mbt", 1, Some(1), 1, test_name="unit")
  let second = make_merge_report(
    "src/a.mbt",
    1,
    Some(1),
    1,
    test_name="integration",
  )
  let merged = @mooncov.merge_reports([first, second])
  assert_true(merged.files[0].test_name is None)
}

///|
test "merge rejects negative counts from manually constructed models" {
  let report : @mooncov.CoverageReport = {
    files: [
      {
        path: "src/bad.mbt",
        test_name: None,
        lines: [{ line: 1, hits: -1, }],
        branches: [],
        functions: [],
      },
    ],
  }
  try @mooncov.merge_reports([report]) catch {
    InvalidModel(message) =>
      inspect(message, content="line hit count must not be negative")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid model")
  }
}
