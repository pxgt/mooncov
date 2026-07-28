///|
fn filter_fixture() -> @mooncov.CoverageReport {
  let report = @mooncov.CoverageReport::new()
  report.add_file(@mooncov.FileCoverage::new("src/lib.mbt"))
  report.add_file(@mooncov.FileCoverage::new("src/internal/parser.mbt"))
  report.add_file(@mooncov.FileCoverage::new("test/lib_test.mbt"))
  report.add_file(@mooncov.FileCoverage::new("generated/api.mbt"))
  report
}

///|
test "path filters apply includes before excludes" {
  let filter = @mooncov.PathFilter::new(
    ["src/**/*.mbt"],
    ["**/internal/**"],
  )
  let selected = @mooncov.filter_report(filter_fixture(), filter)
  inspect(selected.files.length(), content="1")
  inspect(selected.files[0].path, content="src/lib.mbt")
}

///|
test "empty includes accept all paths while excludes still win" {
  let selected = @mooncov.select_paths(
    filter_fixture(),
    [],
    ["generated/**", "**/*_test.mbt"],
  )
  inspect(selected.files.length(), content="2")
  inspect(selected.files[0].path, content="src/lib.mbt")
  inspect(selected.files[1].path, content="src/internal/parser.mbt")
}

///|
test "filtering returns independent arrays" {
  let original = filter_fixture()
  let selected = @mooncov.filter_report(
    original,
    @mooncov.PathFilter::all(),
  )
  selected.files.pop() |> ignore
  selected.files[0].lines.push({ line: 1, hits: 1 })
  inspect(original.files.length(), content="4")
  inspect(original.files[0].lines.length(), content="0")
}

///|
test "filter allows normalized Windows paths" {
  let filter = @mooncov.PathFilter::new(["src/**"], [])
  assert_true(filter.allows("src\\nested\\file.mbt"))
  assert_false(filter.allows("tests\\file.mbt"))
}
