///|
test "parse Coveralls source files, sparse lines, and branches" {
  let input =
    #|{
    #|  "service_name": "local",
    #|  "source_files": [
    #|    {
    #|      "name": "D:\\repo\\src\\lib.mbt",
    #|      "source_digest": "ignored",
    #|      "coverage": [null, 3, 0, null, 2],
    #|      "branches": [3, 0, 0, 2, 3, "0", "1", null]
    #|    }
    #|  ]
    #|}
  let report = @mooncov.parse_coveralls(input, strip_prefix="D:/repo")
  let file = report.files[0]
  inspect(file.path, content="src/lib.mbt")
  inspect(file.lines.length(), content="3")
  inspect(file.lines[0].line, content="2")
  inspect(file.lines[0].hits, content="3")
  inspect(file.lines[2].line, content="5")
  inspect(file.branches.length(), content="2")
  inspect(file.branches[1].branch, content="1")
  assert_true(file.branches[1].taken is None)
}

///|
test "parse empty Coveralls source list" {
  let report = @mooncov.parse_coveralls("{\"source_files\":[]}")
  inspect(report.files.length(), content="0")
}

///|
test "Coveralls parser rejects fractional hit counts with a JSON path" {
  let input = "{\"source_files\":[{\"name\":\"src/a.mbt\",\"coverage\":[1.5]}]}"
  try @mooncov.parse_coveralls(input) catch {
    InvalidCoveralls(message) =>
      inspect(
        message,
        content="$.source_files[0].coverage[0]: expected finite integer",
      )
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid Coveralls error")
  }
}

///|
test "Coveralls parser rejects malformed flattened branches" {
  let input = "{\"source_files\":[{\"name\":\"src/a.mbt\",\"coverage\":[]," +
    "\"branches\":[1,0,0]}]}"
  try @mooncov.parse_coveralls(input) catch {
    InvalidCoveralls(message) =>
      inspect(
        message,
        content="$.source_files[0].branches: flattened branch array length must be divisible by four",
      )
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid branch array error")
  }
}

///|
test "Coveralls parser rejects missing source_files" {
  try @mooncov.parse_coveralls("{}") catch {
    InvalidCoveralls(message) =>
      inspect(message, content="$: missing field \"source_files\"")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected missing field error")
  }
}
