///|
test "parse MoonBit-style Cobertura class line coverage" {
  let input =
    #|<?xml version="1.0" ?>
    #|<coverage lines-valid="3" lines-covered="2" line-rate="0.666667">
    #|  <packages>
    #|    <package name=".">
    #|      <classes>
    #|        <class name="parser" filename="D:\repo\src\parser.mbt">
    #|          <lines>
    #|            <line number="3" hits="7"/>
    #|            <line number="4" hits="0"/>
    #|            <line number="9" hits="1"/>
    #|          </lines>
    #|        </class>
    #|      </classes>
    #|    </package>
    #|  </packages>
    #|</coverage>
    #|
  let report = @mooncov.parse_cobertura(input, strip_prefix="D:/repo")
  inspect(report.files.length(), content="1")
  inspect(report.files[0].path, content="src/parser.mbt")
  inspect(report.files[0].lines.length(), content="3")
  inspect(report.files[0].lines[1].hits, content="0")
  inspect(@mooncov.summarize(report).lines.covered, content="2")
}

///|
test "parse Cobertura conditions, methods, and XML entities" {
  let input =
    #|<coverage>
    #|  <packages><package name="pkg"><classes>
    #|    <class name="A" filename="src/a&amp;b.mbt">
    #|      <methods>
    #|        <method name="choose&lt;T&gt;" signature="">
    #|          <lines><line number="8" hits="4"/></lines>
    #|        </method>
    #|      </methods>
    #|      <lines>
    #|        <line number="8" hits="4" branch="true"
    #|          condition-coverage="50% (1/2)"/>
    #|      </lines>
    #|    </class>
    #|  </classes></package></packages>
    #|</coverage>
    #|
  let report = @mooncov.parse_cobertura(input)
  let file = report.files[0]
  inspect(file.path, content="src/a&b.mbt")
  inspect(file.functions.length(), content="1")
  inspect(file.functions[0].name, content="choose<T>")
  inspect(file.functions[0].hits, content="4")
  inspect(file.branches.length(), content="2")
  assert_true(file.branches[0].is_covered())
  assert_false(file.branches[1].is_covered())
}

///|
test "Cobertura parser coalesces duplicate classes for one path" {
  let input =
    #|<coverage><packages><package><classes>
    #|  <class filename="src/a.mbt"><lines><line number="1" hits="2"/></lines></class>
    #|  <class filename="src/./a.mbt"><lines><line number="1" hits="3"/></lines></class>
    #|</classes></package></packages></coverage>
  let report = @mooncov.parse_cobertura(input)
  inspect(report.files.length(), content="1")
  inspect(report.files[0].lines.length(), content="1")
  inspect(report.files[0].lines[0].hits, content="5")
}

///|
test "Cobertura parser reports malformed attributes by physical line" {
  let input =
    #|<coverage>
    #|  <class filename="src/a.mbt">
    #|    <line number="x" hits="1"/>
    #|  </class>
    #|</coverage>
    #|
  try @mooncov.parse_cobertura(input) catch {
    InvalidCobertura(line, message) => {
      inspect(line, content="3")
      inspect(message, content="line.number must be a MoonBit Int")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid Cobertura")
  }
}

///|
test "Cobertura parser rejects unknown XML entities" {
  let input = "<coverage><class filename=\"a&missing;.mbt\"/></coverage>"
  try @mooncov.parse_cobertura(input) catch {
    InvalidCobertura(line, message) => {
      inspect(line, content="1")
      inspect(message, content="unknown XML entity &missing;")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid entity")
  }
}
