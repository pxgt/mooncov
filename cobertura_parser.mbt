///|
priv struct CoberturaMethod {
  name : String
  mut line : Int32?
  mut hits : Int32
}

///|
fn cobertura_required_attribute(
  tag : XmlTag,
  name : String,
) -> String raise CoverageError {
  match tag.attributes.get(name) {
    Some(value) => value
    None =>
      raise InvalidCobertura(
        tag.input_line,
        "<\{tag.name}> is missing attribute \{name}",
      )
  }
}

///|
fn cobertura_int_text(
  text : String,
  input_line : Int32,
  field : String,
) -> Int32 raise CoverageError {
  @str.parse_int(text) catch {
    _ => raise InvalidCobertura(input_line, "\{field} must be a MoonBit Int")
  }
}

///|
fn cobertura_integer_attribute(
  tag : XmlTag,
  name : String,
) -> Int32 raise CoverageError {
  cobertura_int_text(
    cobertura_required_attribute(tag, name),
    tag.input_line,
    "\{tag.name}.\{name}",
  )
}

///|
fn parse_condition_coverage(
  value : String,
  input_line : Int32,
) -> (Int32, Int32) raise CoverageError {
  guard value.split_once("(") is Some((_, after_open)) else {
    raise InvalidCobertura(
      input_line, "condition-coverage must contain (covered/total)",
    )
  }
  guard after_open.split_once(")") is Some((counts, _)) else {
    raise InvalidCobertura(
      input_line, "condition-coverage is missing closing parenthesis",
    )
  }
  guard counts.split_once("/") is Some((covered_view, total_view)) else {
    raise InvalidCobertura(
      input_line, "condition-coverage must contain covered/total",
    )
  }
  let covered_text = "\{covered_view.trim()}"
  let total_text = "\{total_view.trim()}"
  let covered = cobertura_int_text(
    covered_text, input_line, "condition covered count",
  )
  let total = cobertura_int_text(
    total_text, input_line, "condition total count",
  )
  if covered < 0 || total < 0 || covered > total {
    raise InvalidCobertura(
      input_line, "condition counts must satisfy 0 <= covered <= total",
    )
  }
  (covered, total)
}

///|
fn add_cobertura_branches(
  file : FileCoverage,
  tag : XmlTag,
  line : Int32,
) -> Unit raise CoverageError {
  match tag.attributes.get("branch") {
    Some("true") =>
      match tag.attributes.get("condition-coverage") {
        Some(value) => {
          let (covered, total) = parse_condition_coverage(value, tag.input_line)
          for branch in 0..<total {
            file.branches.push({
              line,
              block: "cobertura",
              branch: branch.to_string(),
              taken: Some(if branch < covered { 1 } else { 0 }),
            })
          }
        }
        None =>
          raise InvalidCobertura(
            tag.input_line,
            "branch line is missing condition-coverage",
          )
      }
    Some("false") | None => ()
    Some(value) =>
      raise InvalidCobertura(
        tag.input_line,
        "line.branch must be true or false, got \{value}",
      )
  }
}

///|
fn update_cobertura_method(
  method_entry : CoberturaMethod,
  line : Int32,
  hits : Int32,
) -> Unit {
  match method_entry.line {
    Some(previous) => if line < previous { method_entry.line = Some(line) }
    None => method_entry.line = Some(line)
  }
  if hits > method_entry.hits {
    method_entry.hits = hits
  }
}

///|
fn finish_cobertura_method(
  file : FileCoverage,
  method_entry : CoberturaMethod,
) -> Unit {
  file.functions.push({
    name: method_entry.name,
    line: method_entry.line,
    hits: method_entry.hits,
  })
}

///|
/// Parse Cobertura XML coverage into mooncov's unified model.
///
/// Class-level `<line>` elements preserve line hits. Standard
/// `condition-coverage="P% (covered/total)"` attributes are represented as
/// synthetic branch identities because Cobertura does not expose LCOV block
/// and branch identifiers. Optional `<method>` sections become function
/// entries using the first method line and maximum line hit count.
pub fn parse_cobertura(
  input : String,
  strip_prefix~ : String = "",
) -> CoverageReport raise CoverageError {
  let report = CoverageReport::new()
  let mut current_file : FileCoverage? = None
  let mut current_method : CoberturaMethod? = None
  for tag in scan_xml_tags(input) {
    match (tag.closing, tag.name) {
      (false, "class") => {
        if current_file is Some(_) {
          raise InvalidCobertura(tag.input_line, "nested <class> is invalid")
        }
        let filename = cobertura_required_attribute(tag, "filename")
        current_file = Some(
          FileCoverage::new(normalize_path(filename, strip_prefix~)),
        )
        if tag.self_closing {
          guard current_file is Some(file) else {
            raise InvalidCobertura(tag.input_line, "internal class state error")
          }
          report.files.push(file)
          current_file = None
        }
      }
      (true, "class") => {
        if current_method is Some(_) {
          raise InvalidCobertura(tag.input_line, "class closed before method")
        }
        guard current_file is Some(file) else {
          raise InvalidCobertura(
            tag.input_line,
            "closing class has no open class",
          )
        }
        report.files.push(file)
        current_file = None
      }
      (false, "method") => {
        guard current_file is Some(_) else {
          raise InvalidCobertura(
            tag.input_line,
            "method appears outside a class",
          )
        }
        if current_method is Some(_) {
          raise InvalidCobertura(tag.input_line, "nested method is invalid")
        }
        current_method = Some({
          name: cobertura_required_attribute(tag, "name"),
          line: None,
          hits: 0,
        })
        if tag.self_closing {
          guard (current_file, current_method)
            is (Some(file), Some(method_entry)) else {
            raise InvalidCobertura(
              tag.input_line,
              "internal method state error",
            )
          }
          finish_cobertura_method(file, method_entry)
          current_method = None
        }
      }
      (true, "method") => {
        guard (current_file, current_method) is (Some(file), Some(method_entry)) else {
          raise InvalidCobertura(
            tag.input_line,
            "closing method has no open method",
          )
        }
        finish_cobertura_method(file, method_entry)
        current_method = None
      }
      (false, "line") => {
        guard current_file is Some(file) else {
          raise InvalidCobertura(tag.input_line, "line appears outside a class")
        }
        let line = cobertura_integer_attribute(tag, "number")
        let hits = cobertura_integer_attribute(tag, "hits")
        if line <= 0 {
          raise InvalidCobertura(tag.input_line, "line.number must be positive")
        }
        if hits < 0 {
          raise InvalidCobertura(
            tag.input_line,
            "line.hits must not be negative",
          )
        }
        match current_method {
          Some(method_entry) =>
            update_cobertura_method(method_entry, line, hits)
          None => {
            file.lines.push({ line, hits, })
            add_cobertura_branches(file, tag, line)
          }
        }
      }
      _ => ()
    }
  }
  if current_method is Some(_) {
    raise InvalidCobertura(1, "document ended inside a method")
  }
  if current_file is Some(_) {
    raise InvalidCobertura(1, "document ended inside a class")
  }
  canonicalize_report(report)
}
