///|
test "parse LCOV lines, branches, and functions" {
  let input =
    #|TN:moon-test
    #|SF:D:\workspace\src\math.mbt
    #|FN:4,add
    #|FN:12,classify,value
    #|FNDA:3,add
    #|FNDA:0,classify,value
    #|DA:4,3
    #|DA:5,3,checksum
    #|DA:12,0
    #|BRDA:13,0,0,2
    #|BRDA:13,0,1,-
    #|FNF:2
    #|FNH:1
    #|LF:3
    #|LH:2
    #|BRF:2
    #|BRH:1
    #|end_of_record
    #|
  let report = @mooncov.parse_lcov(input, strip_prefix="D:/workspace")
  let file = report.files[0]
  inspect(file.path, content="src/math.mbt")
  guard file.test_name is Some(test_name) else { fail("expected test name") }
  inspect(test_name, content="moon-test")
  inspect(file.lines.length(), content="3")
  inspect(file.branches.length(), content="2")
  inspect(file.functions.length(), content="2")
  inspect(file.functions[1].name, content="classify,value")
  assert_true(file.branches[1].taken is None)
}

///|
test "parse multiple LCOV records and tolerate missing final terminator" {
  let input = "SF:src/a.mbt\r\nDA:1,1\r\nend_of_record\r\n" +
    "TN:second\r\nSF:src/b.mbt\r\nDA:7,0\r\n"
  let report = @mooncov.parse_lcov(input)
  inspect(report.files.length(), content="2")
  inspect(report.files[0].path, content="src/a.mbt")
  inspect(report.files[1].path, content="src/b.mbt")
  inspect(report.files[1].lines[0].hits, content="0")
}

///|
test "LCOV parser accumulates repeated function hit entries" {
  let input =
    #|SF:src/repeated.mbt
    #|FNDA:2,work
    #|FN:9,work
    #|FNDA:3,work
    #|end_of_record
    #|
  let report = @mooncov.parse_lcov(input)
  guard report.files[0].functions[0].line is Some(function_line) else {
    fail("expected function line")
  }
  inspect(function_line, content="9")
  inspect(report.files[0].functions[0].hits, content="5")
}

///|
test "LCOV parser reports the physical line for malformed entries" {
  let input = "TN:test\nSF:src/bad.mbt\nDA:not-a-line,1\nend_of_record\n"
  try @mooncov.parse_lcov(input) catch {
    InvalidLcov(line, message) => {
      inspect(line, content="3")
      inspect(message, content="invalid integer for DA line: not-a-line")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected malformed LCOV error")
  }
}

///|
test "LCOV parser rejects records without a source path" {
  try @mooncov.parse_lcov("TN:test\nDA:1,1\nend_of_record\n") catch {
    InvalidLcov(line, message) => {
      inspect(line, content="3")
      inspect(message, content="record is missing SF")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected missing source path error")
  }
}
