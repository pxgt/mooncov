///|
fn coveralls_error(path : String, message : String) -> CoverageError {
  InvalidCoveralls("\{path}: \{message}")
}

///|
fn coveralls_object(
  value : Json,
  path : String,
) -> Map[String, Json] raise CoverageError {
  match value {
    Object(fields) => fields
    _ => raise coveralls_error(path, "expected object")
  }
}

///|
fn coveralls_array(
  value : Json,
  path : String,
) -> Array[Json] raise CoverageError {
  match value {
    Array(values) => values
    _ => raise coveralls_error(path, "expected array")
  }
}

///|
fn coveralls_string(
  value : Json,
  path : String,
) -> String raise CoverageError {
  match value {
    String(text) => text
    _ => raise coveralls_error(path, "expected string")
  }
}

///|
fn coveralls_int(
  value : Json,
  path : String,
) -> Int raise CoverageError {
  match value {
    Number(number, repr=_) =>
      if number.is_nan() ||
        number.is_inf() ||
        number.trunc() != number {
        raise coveralls_error(path, "expected finite integer")
      } else {
        number.to_int()
      }
    _ => raise coveralls_error(path, "expected number")
  }
}

///|
fn required_coveralls_field(
  object : Map[String, Json],
  key : String,
  path : String,
) -> Json raise CoverageError {
  match object.get(key) {
    Some(value) => value
    None => raise coveralls_error(path, "missing field \"\{key}\"")
  }
}

///|
fn branch_identifier(
  value : Json,
  path : String,
) -> String raise CoverageError {
  match value {
    String(text) => text
    Number(number, repr=_) =>
      if number.is_nan() ||
        number.is_inf() ||
        number.trunc() != number {
        raise coveralls_error(path, "expected integer or string")
      } else {
        number.to_int().to_string()
      }
    _ => raise coveralls_error(path, "expected integer or string")
  }
}

///|
fn parse_coveralls_coverage(
  file : FileCoverage,
  coverage : Array[Json],
  path : String,
) -> Unit raise CoverageError {
  for index, value in coverage {
    match value {
      Null => ()
      _ => {
        let hits = coveralls_int(value, "\{path}[\{index}]")
        if hits < 0 {
          raise coveralls_error(
            "\{path}[\{index}]",
            "hit count must not be negative",
          )
        }
        file.lines.push({ line: index + 1, hits })
      }
    }
  }
}

///|
fn parse_coveralls_branches(
  file : FileCoverage,
  branches : Array[Json],
  path : String,
) -> Unit raise CoverageError {
  if branches.length() % 4 != 0 {
    raise coveralls_error(
      path,
      "flattened branch array length must be divisible by four",
    )
  }
  for group in 0..<(branches.length() / 4) {
    let index = group * 4
    let line = coveralls_int(branches[index], "\{path}[\{index}]")
    if line <= 0 {
      raise coveralls_error(
        "\{path}[\{index}]",
        "branch line must be positive",
      )
    }
    let block = branch_identifier(
      branches[index + 1],
      "\{path}[\{index + 1}]",
    )
    let branch = branch_identifier(
      branches[index + 2],
      "\{path}[\{index + 2}]",
    )
    let taken = match branches[index + 3] {
      Null => None
      value => {
        let count = coveralls_int(value, "\{path}[\{index + 3}]")
        if count < 0 {
          raise coveralls_error(
            "\{path}[\{index + 3}]",
            "branch count must not be negative",
          )
        }
        Some(count)
      }
    }
    file.branches.push({ line, block, branch, taken })
  }
}

///|
fn parse_coveralls_file(
  value : Json,
  index : Int,
  strip_prefix : String,
) -> FileCoverage raise CoverageError {
  let path = "$.source_files[\{index}]"
  let object = coveralls_object(value, path)
  let name = coveralls_string(
    required_coveralls_field(object, "name", path),
    "\{path}.name",
  )
  let coverage = coveralls_array(
    required_coveralls_field(object, "coverage", path),
    "\{path}.coverage",
  )
  let file = FileCoverage::new(normalize_path(name, strip_prefix~))
  parse_coveralls_coverage(file, coverage, "\{path}.coverage")
  match object.get("branches") {
    Some(branch_json) =>
      parse_coveralls_branches(
        file,
        coveralls_array(branch_json, "\{path}.branches"),
        "\{path}.branches",
      )
    None => ()
  }
  file
}

///|
/// Parse Coveralls/CodeCov JSON produced by `moon coverage report -f
/// coveralls`.
///
/// The standard `source_files[].coverage` array and flattened `branches`
/// array are supported. `null` coverage slots are preserved as
/// non-instrumented lines rather than counted as misses.
pub fn parse_coveralls(
  input : String,
  strip_prefix? : String = "",
) -> CoverageReport raise CoverageError {
  let root = @json.parse(input) catch {
    error => raise InvalidCoveralls("invalid JSON: \{error}")
  }
  let object = coveralls_object(root, "$")
  let source_files = coveralls_array(
    required_coveralls_field(object, "source_files", "$"),
    "$.source_files",
  )
  let report = CoverageReport::new()
  for index, source_file in source_files {
    report.files.push(parse_coveralls_file(source_file, index, strip_prefix))
  }
  report
}
