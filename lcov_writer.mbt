///|
fn compare_lines(left : CoverageLine, right : CoverageLine) -> Int {
  left.line.compare(right.line)
}

///|
fn compare_branches(left : CoverageBranch, right : CoverageBranch) -> Int {
  let by_line = left.line.compare(right.line)
  if by_line != 0 {
    return by_line
  }
  let by_block = left.block.compare(right.block)
  if by_block != 0 {
    return by_block
  }
  left.branch.compare(right.branch)
}

///|
fn compare_optional_lines(left : Int?, right : Int?) -> Int {
  match (left, right) {
    (Some(a), Some(b)) => a.compare(b)
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn compare_functions(left : CoverageFunction, right : CoverageFunction) -> Int {
  let by_line = compare_optional_lines(left.line, right.line)
  if by_line != 0 {
    return by_line
  }
  left.name.compare(right.name)
}

///|
fn check_lcov_text(label : String, value : String) -> Unit raise CoverageError {
  if value.contains_char('\n') || value.contains_char('\r') {
    raise InvalidModel("\{label} must not contain a newline")
  }
}

///|
fn write_lcov_file(
  output : StringBuilder,
  file : FileCoverage,
) -> Unit raise CoverageError {
  check_lcov_text("source path", file.path)
  match file.test_name {
    Some(name) => {
      check_lcov_text("test name", name)
      output.write_string("TN:\{name}\n")
    }
    None => output.write_string("TN:\n")
  }
  output.write_string("SF:\{file.path}\n")
  let functions = [ for function in file.functions => function ]
  functions.sort_by(compare_functions)
  for function in functions {
    check_lcov_text("function name", function.name)
    match function.line {
      Some(line) => output.write_string("FN:\{line},\{function.name}\n")
      None => ()
    }
  }
  for function in functions {
    output.write_string("FNDA:\{function.hits},\{function.name}\n")
  }
  let functions_hit = functions.fold(init=0, (count, function) => {
    if function.hits > 0 {
      count + 1
    } else {
      count
    }
  })
  output.write_string("FNF:\{functions.length()}\n")
  output.write_string("FNH:\{functions_hit}\n")
  let lines = [ for line in file.lines => line ]
  lines.sort_by(compare_lines)
  for line in lines {
    output.write_string("DA:\{line.line},\{line.hits}\n")
  }
  let lines_hit = lines.fold(init=0, (count, line) => {
    if line.hits > 0 {
      count + 1
    } else {
      count
    }
  })
  output.write_string("LF:\{lines.length()}\n")
  output.write_string("LH:\{lines_hit}\n")
  let branches = [ for branch in file.branches => branch ]
  branches.sort_by(compare_branches)
  for branch in branches {
    let taken = match branch.taken {
      Some(count) => count.to_string()
      None => "-"
    }
    output.write_string(
      "BRDA:\{branch.line},\{branch.block},\{branch.branch},\{taken}\n",
    )
  }
  let branches_hit = branches.fold(init=0, (count, branch) => {
    if branch.is_covered() {
      count + 1
    } else {
      count
    }
  })
  output.write_string("BRF:\{branches.length()}\n")
  output.write_string("BRH:\{branches_hit}\n")
  output.write_string("end_of_record\n")
}

///|
/// Encode a coverage report as deterministic LCOV text.
///
/// Files retain report order while functions, lines, and branches are sorted
/// within each record. Summary fields are calculated from the actual entries.
pub fn to_lcov(report : CoverageReport) -> String raise CoverageError {
  let output = StringBuilder()
  let canonical = canonicalize_report(report)
  for file in canonical.files {
    write_lcov_file(output, file)
  }
  output.to_string()
}
