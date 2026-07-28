///|
fn json_integer(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn coveralls_branch_identifier_json(value : String) -> Json {
  let parsed : Int? = Some(@strconv.from_str(value)) catch { _ => None }
  match parsed {
    Some(number) => json_integer(number)
    None => Json::string(value)
  }
}

///|
fn coveralls_line_array(file : FileCoverage) -> Array[Json] raise CoverageError {
  let counts : Map[Int, Int] = Map([])
  let mut max_line = 0
  for item in file.lines {
    if item.line <= 0 {
      raise InvalidModel("line number must be positive")
    }
    if item.hits < 0 {
      raise InvalidModel("line hit count must not be negative")
    }
    counts.update_or_default(item.line, item.hits, old => old + item.hits)
    if item.line > max_line {
      max_line = item.line
    }
  }
  Array::makei(max_line, index => {
    match counts.get(index + 1) {
      Some(hits) => json_integer(hits)
      None => Json::null()
    }
  })
}

///|
fn coveralls_branch_array(
  file : FileCoverage,
) -> Array[Json] raise CoverageError {
  let flattened : Array[Json] = []
  let branches = [ for branch in file.branches => branch ]
  branches.sort_by(compare_branches)
  for branch in branches {
    if branch.line <= 0 {
      raise InvalidModel("branch line must be positive")
    }
    flattened.push(json_integer(branch.line))
    flattened.push(coveralls_branch_identifier_json(branch.block))
    flattened.push(coveralls_branch_identifier_json(branch.branch))
    flattened.push(
      match branch.taken {
        Some(count) =>
          if count < 0 {
            raise InvalidModel("branch hit count must not be negative")
          } else {
            json_integer(count)
          }
        None => Json::null()
      },
    )
  }
  flattened
}

///|
fn coveralls_file_json(file : FileCoverage) -> Json raise CoverageError {
  let object : Map[String, Json] = {
    "name": Json::string(file.path),
    "coverage": Json::array(coveralls_line_array(file)),
  }
  if !file.branches.is_empty() {
    object["branches"] = Json::array(coveralls_branch_array(file))
  }
  Json::object(object)
}

///|
/// Encode the line and branch portions of a report as Coveralls JSON.
///
/// Coveralls' source-file schema has no standard function-coverage field, so
/// function entries are intentionally not serialized. Numeric-looking branch
/// identifiers stay numeric; other identifiers are emitted as strings and are
/// accepted by mooncov's decoder.
pub fn to_coveralls_json(
  report : CoverageReport,
  service_name? : String = "mooncov",
  service_job_id? : String,
) -> String raise CoverageError {
  let source_files : Array[Json] = []
  let canonical = canonicalize_report(report)
  for file in canonical.files {
    source_files.push(coveralls_file_json(file))
  }
  let root : Map[String, Json] = {
    "service_name": Json::string(service_name),
    "source_files": Json::array(source_files),
  }
  match service_job_id {
    Some(value) => root["service_job_id"] = Json::string(value)
    None => ()
  }
  Json::object(root).stringify(indent=2)
}
