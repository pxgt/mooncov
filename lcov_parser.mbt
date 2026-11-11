///|
priv struct LcovBuilder {
  mut test_name : String?
  mut path : String?
  lines : Array[CoverageLine]
  branches : Array[CoverageBranch]
  function_lines : Map[String, Int32]
  function_hits : Map[String, Int32]
  function_order : Array[String]
}

///|
fn LcovBuilder::new() -> LcovBuilder {
  {
    test_name: None,
    path: None,
    lines: [],
    branches: [],
    function_lines: {},
    function_hits: {},
    function_order: [],
  }
}

///|
fn parse_lcov_int(
  value : StringView,
  input_line : Int32,
  field : String,
) -> Int32 raise CoverageError {
  @str.parse_int(value) catch {
    _ => raise InvalidLcov(input_line, "invalid integer for \{field}: \{value}")
  }
}

///|
fn remember_function(builder : LcovBuilder, name : String) -> Unit {
  if !builder.function_lines.contains(name) &&
    !builder.function_hits.contains(name) {
    builder.function_order.push(name)
  }
}

///|
fn parse_lcov_function_definition(
  builder : LcovBuilder,
  value : StringView,
  input_line : Int32,
) -> Unit raise CoverageError {
  match value.split_once(",") {
    Some((line_view, name_view)) => {
      let line = parse_lcov_int(line_view, input_line, "FN line")
      let name = "\{name_view}"
      if line <= 0 {
        raise InvalidLcov(input_line, "FN line must be positive")
      }
      if name == "" {
        raise InvalidLcov(input_line, "FN name must not be empty")
      }
      remember_function(builder, name)
      builder.function_lines[name] = line
    }
    None => raise InvalidLcov(input_line, "FN must contain line,name")
  }
}

///|
fn parse_lcov_function_hits(
  builder : LcovBuilder,
  value : StringView,
  input_line : Int32,
) -> Unit raise CoverageError {
  match value.split_once(",") {
    Some((hits_view, name_view)) => {
      let hits = parse_lcov_int(hits_view, input_line, "FNDA hits")
      let name = "\{name_view}"
      if hits < 0 {
        raise InvalidLcov(input_line, "FNDA hits must not be negative")
      }
      if name == "" {
        raise InvalidLcov(input_line, "FNDA name must not be empty")
      }
      remember_function(builder, name)
      builder.function_hits.update_or_default(name, hits, old => old + hits)
    }
    None => raise InvalidLcov(input_line, "FNDA must contain hits,name")
  }
}

///|
fn parse_lcov_line(
  builder : LcovBuilder,
  value : StringView,
  input_line : Int32,
) -> Unit raise CoverageError {
  let fields = value.split(",").to_array()
  if fields.length() < 2 {
    raise InvalidLcov(input_line, "DA must contain line,hits")
  }
  let line = parse_lcov_int(fields[0], input_line, "DA line")
  let hits = parse_lcov_int(fields[1], input_line, "DA hits")
  if line <= 0 {
    raise InvalidLcov(input_line, "DA line must be positive")
  }
  if hits < 0 {
    raise InvalidLcov(input_line, "DA hits must not be negative")
  }
  builder.lines.push({ line, hits, })
}

///|
fn parse_lcov_branch(
  builder : LcovBuilder,
  value : StringView,
  input_line : Int32,
) -> Unit raise CoverageError {
  let fields = value.split(",").to_array()
  if fields.length() != 4 {
    raise InvalidLcov(input_line, "BRDA must contain line,block,branch,taken")
  }
  let line = parse_lcov_int(fields[0], input_line, "BRDA line")
  if line <= 0 {
    raise InvalidLcov(input_line, "BRDA line must be positive")
  }
  let taken = if fields[3] == "-" {
    None
  } else {
    let count = parse_lcov_int(fields[3], input_line, "BRDA taken")
    if count < 0 {
      raise InvalidLcov(input_line, "BRDA taken must not be negative")
    }
    Some(count)
  }
  builder.branches.push({
    line,
    block: "\{fields[1]}",
    branch: "\{fields[2]}",
    taken,
  })
}

///|
fn finish_lcov_record(
  builder : LcovBuilder,
  report : CoverageReport,
  strip_prefix : String,
  input_line : Int32,
) -> Unit raise CoverageError {
  guard builder.path is Some(path) else {
    raise InvalidLcov(input_line, "record is missing SF")
  }
  let functions : Array[CoverageFunction] = []
  for name in builder.function_order {
    functions.push({
      name,
      line: builder.function_lines.get(name),
      hits: builder.function_hits.get_or_default(name, 0),
    })
  }
  report.files.push({
    path: normalize_path(path, strip_prefix~),
    test_name: builder.test_name,
    lines: builder.lines,
    branches: builder.branches,
    functions,
  })
}

///|
fn is_lcov_summary_tag(tag : String) -> Bool {
  tag == "FNF" ||
  tag == "FNH" ||
  tag == "LF" ||
  tag == "LH" ||
  tag == "BRF" ||
  tag == "BRH"
}

///|
/// Parse an LCOV tracefile into the format-neutral coverage model.
///
/// Aggregate summary tags (`LF`, `LH`, `FNF`, `FNH`, `BRF`, and `BRH`) are
/// accepted but recalculated by mooncov instead of trusted. A final
/// `end_of_record` is recommended but not required.
///
/// # Example
/// ```mbt check
/// test {
///   let report = @mooncov.parse_lcov(
///     "TN:unit\nSF:src/lib.mbt\nDA:1,3\nDA:2,0\nend_of_record\n",
///   )
///   inspect(report.files.length(), content="1")
///   inspect(report.files[0].lines[0].hits, content="3")
/// }
/// ```
pub fn parse_lcov(
  input : String,
  strip_prefix~ : String = "",
) -> CoverageReport raise CoverageError {
  let report = CoverageReport::new()
  let mut builder = LcovBuilder::new()
  let mut last_line = 0
  for index, raw_view in input.split("\n") {
    let input_line = index + 1
    last_line = input_line
    let raw = "\{raw_view}"
    let line = "\{raw.trim_end(chars="\r")}"
    if line == "" || line.has_prefix("#") {
      continue
    }
    if line == "end_of_record" {
      finish_lcov_record(builder, report, strip_prefix, input_line)
      builder = LcovBuilder::new()
      continue
    }
    guard line.split_once(":") is Some((tag_view, value)) else {
      raise InvalidLcov(input_line, "expected TAG:value or end_of_record")
    }
    let tag = "\{tag_view}"
    match tag {
      "TN" =>
        builder.test_name = if value == "" { None } else { Some("\{value}") }
      "SF" =>
        if builder.path is Some(_) {
          raise InvalidLcov(input_line, "multiple SF entries in one record")
        } else if value == "" {
          raise InvalidLcov(input_line, "SF path must not be empty")
        } else {
          builder.path = Some("\{value}")
        }
      "FN" => parse_lcov_function_definition(builder, value, input_line)
      "FNDA" => parse_lcov_function_hits(builder, value, input_line)
      "DA" => parse_lcov_line(builder, value, input_line)
      "BRDA" => parse_lcov_branch(builder, value, input_line)
      "VER" => ()
      _ =>
        if !is_lcov_summary_tag(tag) {
          raise InvalidLcov(input_line, "unsupported LCOV tag: \{tag}")
        }
    }
  }
  if builder.path is Some(_) {
    finish_lcov_record(builder, report, strip_prefix, last_line + 1)
  } else if builder.test_name is Some(_) ||
    !builder.lines.is_empty() ||
    !builder.branches.is_empty() ||
    !builder.function_order.is_empty() {
    raise InvalidLcov(last_line + 1, "incomplete record is missing SF")
  }
  report
}
