///|
priv struct FileAccumulator {
  path : String
  mut test_name : String?
  lines : Map[Int, Int]
  branches : Map[String, CoverageBranch]
  functions : Map[String, CoverageFunction]
}

///|
fn FileAccumulator::new(path : String, test_name : String?) -> FileAccumulator {
  { path, test_name, lines: {}, branches: {}, functions: {} }
}

///|
fn combine_test_names(left : String?, right : String?) -> String? {
  match (left, right) {
    (None, value) => value
    (value, None) => value
    (Some(a), Some(b)) => if a == b { Some(a) } else { None }
  }
}

///|
fn merge_taken(left : Int?, right : Int?) -> Int? {
  match (left, right) {
    (None, None) => None
    (Some(value), None) | (None, Some(value)) => Some(value)
    (Some(a), Some(b)) => Some(a + b)
  }
}

///|
fn branch_key(branch : CoverageBranch) -> String {
  "\{branch.line}:\{branch.block.length()}:\{branch.block}:\{branch.branch}"
}

///|
fn function_key(function : CoverageFunction) -> String {
  let line = match function.line {
    Some(value) => value.to_string()
    None => "-"
  }
  "\{function.name.length()}:\{function.name}:\{line}"
}

///|
fn FileAccumulator::add_file(
  self : FileAccumulator,
  file : FileCoverage,
) -> Unit raise CoverageError {
  self.test_name = combine_test_names(self.test_name, file.test_name)
  for line in file.lines {
    if line.line <= 0 {
      raise InvalidModel("line number must be positive")
    }
    if line.hits < 0 {
      raise InvalidModel("line hit count must not be negative")
    }
    self.lines.update_or_default(line.line, line.hits, previous => {
      previous + line.hits
    })
  }
  for branch in file.branches {
    if branch.line <= 0 {
      raise InvalidModel("branch line must be positive")
    }
    if branch.taken is Some(count) && count < 0 {
      raise InvalidModel("branch hit count must not be negative")
    }
    let key = branch_key(branch)
    match self.branches.get(key) {
      Some(previous) =>
        self.branches[key] = {
          line: previous.line,
          block: previous.block,
          branch: previous.branch,
          taken: merge_taken(previous.taken, branch.taken),
        }
      None => self.branches[key] = branch
    }
  }
  for function in file.functions {
    if function.line is Some(line) && line <= 0 {
      raise InvalidModel("function line must be positive")
    }
    if function.hits < 0 {
      raise InvalidModel("function hit count must not be negative")
    }
    let key = function_key(function)
    match self.functions.get(key) {
      Some(previous) =>
        self.functions[key] = {
          name: previous.name,
          line: previous.line,
          hits: previous.hits + function.hits,
        }
      None => self.functions[key] = function
    }
  }
}

///|
fn FileAccumulator::finish(self : FileAccumulator) -> FileCoverage {
  let lines : Array[CoverageLine] = [
    for line, hits in self.lines => { line, hits }
  ]
  lines.sort_by(compare_lines)
  let branches = [ for _, branch in self.branches => branch ]
  branches.sort_by(compare_branches)
  let functions = [ for _, function in self.functions => function ]
  functions.sort_by(compare_functions)
  { path: self.path, test_name: self.test_name, lines, branches, functions }
}

///|
/// Merge any number of coverage reports.
///
/// Files are matched by normalized path. Duplicate line, branch, and function
/// entries have their hit counts added. If only one side knows a branch count,
/// the known count wins; two unknown counts stay unknown. Conflicting test
/// names are cleared rather than reporting a misleading single producer.
pub fn merge_reports(
  reports : ArrayView[CoverageReport],
  strip_prefix? : String = "",
) -> CoverageReport raise CoverageError {
  let accumulators : Map[String, FileAccumulator] = Map([])
  for report in reports {
    for file in report.files {
      let path = normalize_path(file.path, strip_prefix~)
      if path == "" {
        raise InvalidModel("source path must not be empty")
      }
      let accumulator = match accumulators.get(path) {
        Some(existing) => existing
        None => {
          let created = FileAccumulator::new(path, file.test_name)
          accumulators[path] = created
          created
        }
      }
      accumulator.add_file(file)
    }
  }
  let files = [ for _, accumulator in accumulators => accumulator.finish() ]
  files.sort_by((left, right) => left.path.compare(right.path))
  { files, }
}

///|
/// Deduplicate and deterministically sort one report.
pub fn canonicalize_report(
  report : CoverageReport,
  strip_prefix? : String = "",
) -> CoverageReport raise CoverageError {
  merge_reports([report], strip_prefix~)
}
