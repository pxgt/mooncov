///|
fn coveralls_error(path : String, message : String) -> CoverageError {
  InvalidCoveralls("\{path}: \{message}")
}

///|
fn is_json_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\r' || char == '\n'
}

///|
fn is_json_hex_digit(char : Char) -> Bool {
  char.is_ascii_digit() ||
  (char >= 'a' && char <= 'f') ||
  (char >= 'A' && char <= 'F')
}

///|
fn json_value_start_after_key(
  chars : Array[Char],
  index : Int32,
  key : String,
) -> Int32? {
  let marker = "\"\{key}\""
  if !chars_have_prefix(chars, index, marker) {
    return None
  }
  let mut cursor = index + marker.to_array().length()
  while cursor < chars.length() && is_json_space(chars[cursor]) {
    cursor = cursor + 1
  }
  if cursor >= chars.length() || chars[cursor] != ':' {
    return None
  }
  cursor = cursor + 1
  while cursor < chars.length() && is_json_space(chars[cursor]) {
    cursor = cursor + 1
  }
  Some(cursor)
}

///|
fn is_json_unicode_escape(chars : Array[Char], index : Int32) -> Bool {
  if index + 5 >= chars.length() ||
    chars[index] != '\\' ||
    chars[index + 1] != 'u' {
    return false
  }
  for offset in 2..<6 {
    if !is_json_hex_digit(chars[index + offset]) {
      return false
    }
  }
  true
}

///|
fn is_json_simple_escape(char : Char) -> Bool {
  char == '"' ||
  char == '\\' ||
  char == '/' ||
  char == 'b' ||
  char == 'f' ||
  char == 'n' ||
  char == 'r' ||
  char == 't'
}

///|
fn copy_json_string(
  chars : Array[Char],
  start : Int32,
  output : StringBuilder,
) -> Int32 {
  output.write_char('"')
  let mut index = start + 1
  while index < chars.length() {
    output.write_char(chars[index])
    if chars[index] == '"' {
      return index + 1
    }
    if chars[index] == '\\' && index + 1 < chars.length() {
      output.write_char(chars[index + 1])
      index = index + 2
    } else {
      index = index + 1
    }
  }
  index
}

///|
fn copy_repaired_path_string(
  chars : Array[Char],
  opening_quote : Int32,
  output : StringBuilder,
) -> Int32 {
  output.write_char('"')
  let mut index = opening_quote + 1
  while index < chars.length() {
    let char = chars[index]
    if char == '"' {
      output.write_char(char)
      return index + 1
    }
    if char != '\\' {
      output.write_char(char)
      index = index + 1
      continue
    }
    if index + 1 < chars.length() && is_json_simple_escape(chars[index + 1]) {
      output.write_char(chars[index])
      output.write_char(chars[index + 1])
      index = index + 2
    } else if is_json_unicode_escape(chars, index) {
      for offset in 0..<6 {
        output.write_char(chars[index + offset])
      }
      index = index + 6
    } else {
      // MoonBit 0.1.20260703 on Windows writes source-file separators as
      // bare backslashes. Only an otherwise-invalid JSON escape is doubled.
      output.write_char('\\')
      output.write_char('\\')
      index = index + 1
    }
  }
  index
}

///|
fn copy_repaired_source_files_array(
  chars : Array[Char],
  start : Int32,
  output : StringBuilder,
) -> Int32 {
  let mut index = start
  let mut array_depth = 0
  let mut object_depth = 0
  while index < chars.length() {
    let char = chars[index]
    if char == '"' {
      if array_depth == 1 && object_depth == 1 {
        match json_value_start_after_key(chars, index, "name") {
          Some(value_start) =>
            if value_start < chars.length() && chars[value_start] == '"' {
              for copy_index in index..<value_start {
                output.write_char(chars[copy_index])
              }
              index = copy_repaired_path_string(chars, value_start, output)
              continue
            }
          None => ()
        }
      }
      index = copy_json_string(chars, index, output)
      continue
    }
    output.write_char(char)
    match char {
      '[' => array_depth = array_depth + 1
      ']' => {
        array_depth = array_depth - 1
        if array_depth == 0 {
          return index + 1
        }
      }
      '{' => object_depth = object_depth + 1
      '}' => object_depth = object_depth - 1
      _ => ()
    }
    index = index + 1
  }
  index
}

///|
fn repair_moon_windows_coveralls_names(input : String) -> String {
  let chars = input.to_array()
  let output = StringBuilder(size_hint=input.length())
  let mut index = 0
  let mut object_depth = 0
  let mut array_depth = 0
  while index < chars.length() {
    if chars[index] == '"' {
      if object_depth == 1 && array_depth == 0 {
        match json_value_start_after_key(chars, index, "source_files") {
          Some(value_start) =>
            if value_start < chars.length() && chars[value_start] == '[' {
              for copy_index in index..<value_start {
                output.write_char(chars[copy_index])
              }
              index = copy_repaired_source_files_array(
                chars, value_start, output,
              )
              continue
            }
          None => ()
        }
      }
      index = copy_json_string(chars, index, output)
    } else {
      let char = chars[index]
      output.write_char(char)
      match char {
        '{' => object_depth = object_depth + 1
        '}' => object_depth = object_depth - 1
        '[' => array_depth = array_depth + 1
        ']' => array_depth = array_depth - 1
        _ => ()
      }
      index = index + 1
    }
  }
  output.to_string()
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
fn coveralls_string(value : Json, path : String) -> String raise CoverageError {
  match value {
    String(text) => text
    _ => raise coveralls_error(path, "expected string")
  }
}

///|
fn coveralls_int(value : Json, path : String) -> Int32 raise CoverageError {
  match value {
    Number(number, repr=_) =>
      if number.is_nan() || number.is_inf() || number.trunc() != number {
        raise coveralls_error(path, "expected finite integer")
      } else {
        let integer = number.to_int()
        if integer.to_double() != number {
          raise coveralls_error(path, "integer is outside MoonBit Int range")
        }
        integer
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
fn branch_identifier(value : Json, path : String) -> String raise CoverageError {
  match value {
    String(text) => text
    Number(number, repr=_) =>
      if number.is_nan() || number.is_inf() || number.trunc() != number {
        raise coveralls_error(path, "expected integer or string")
      } else {
        let integer = number.to_int()
        if integer.to_double() != number {
          raise coveralls_error(
            path, "integer identifier is outside MoonBit Int range",
          )
        }
        integer.to_string()
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
        file.lines.push({ line: index + 1, hits, })
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
      path, "flattened branch array length must be divisible by four",
    )
  }
  for group in 0..<(branches.length() / 4) {
    let index = group * 4
    let line = coveralls_int(branches[index], "\{path}[\{index}]")
    if line <= 0 {
      raise coveralls_error("\{path}[\{index}]", "branch line must be positive")
    }
    let block = branch_identifier(branches[index + 1], "\{path}[\{index + 1}]")
    let branch = branch_identifier(branches[index + 2], "\{path}[\{index + 2}]")
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
    file.branches.push({ line, block, branch, taken, })
  }
}

///|
fn parse_coveralls_file(
  value : Json,
  index : Int32,
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
fn parse_coveralls_json(input : String) -> Json raise CoverageError {
  try @json.parse(input) catch {
    original_error => {
      let repaired = repair_moon_windows_coveralls_names(input)
      if repaired == input {
        raise InvalidCoveralls("invalid JSON: \{original_error}")
      }
      @json.parse(repaired) catch {
        _ => raise InvalidCoveralls("invalid JSON: \{original_error}")
      }
    }
  } noraise {
    root => root
  }
}

///|
/// Parse Coveralls JSON produced by `moon coverage report -f coveralls`.
///
/// The standard `source_files[].coverage` array and flattened `branches`
/// array are supported. `null` coverage slots are preserved as
/// non-instrumented lines rather than counted as misses. If strict decoding
/// fails, invalid bare Windows separators emitted by MoonBit 0.1.20260703 are
/// repaired only in `source_files[].name` before one strict retry.
pub fn parse_coveralls(
  input : String,
  strip_prefix~ : String = "",
) -> CoverageReport raise CoverageError {
  let root = parse_coveralls_json(input)
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
