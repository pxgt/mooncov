///|
test "Cobertura writer round trips summary dimensions and functions" {
  let file = @mooncov.FileCoverage::new("src/a&b.mbt")
  file.add_line(1, 3)
  file.add_line(2, 0)
  file.add_branch(2, "0", "yes", Some(1))
  file.add_branch(2, "0", "no", Some(0))
  file.add_function("choose<T>", 3, line=1)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let xml = @mooncov.to_cobertura(report, source_root="workspace&root")
  assert_true(xml.contains("filename=\"src/a&amp;b.mbt\""))
  assert_true(xml.contains("<source>workspace&amp;root</source>"))
  assert_true(xml.contains("condition-coverage=\"50% (1/2)\""))
  let decoded = @mooncov.parse_cobertura(xml)
  let before = @mooncov.summarize(report)
  let after = @mooncov.summarize(decoded)
  assert_true(before == after)
  inspect(decoded.files[0].functions.length(), content="1")
  inspect(decoded.files[0].functions[0].name, content="choose<T>")
  inspect(decoded.files[0].functions[0].hits, content="3")
}

///|
test "Cobertura writer is deterministic across input order" {
  let first = @mooncov.CoverageReport::new()
  first.add_file(@mooncov.FileCoverage::new("z.mbt"))
  first.add_file(@mooncov.FileCoverage::new("a.mbt"))
  let second = @mooncov.CoverageReport::new()
  second.add_file(@mooncov.FileCoverage::new("a.mbt"))
  second.add_file(@mooncov.FileCoverage::new("z.mbt"))
  assert_true(@mooncov.to_cobertura(first) == @mooncov.to_cobertura(second))
}

///|
test "Cobertura writer represents branch-only source lines" {
  let file = @mooncov.FileCoverage::new("src/branch.mbt")
  file.add_branch(7, "0", "0", None)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let xml = @mooncov.to_cobertura(report)
  assert_true(xml.contains("<line number=\"7\" hits=\"0\""))
  let decoded = @mooncov.parse_cobertura(xml)
  inspect(decoded.files[0].lines.length(), content="1")
  inspect(decoded.files[0].branches.length(), content="1")
  assert_false(decoded.files[0].branches[0].is_covered())
}
