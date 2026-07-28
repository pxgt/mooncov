///|
/// Errors raised while decoding or validating coverage data.
pub(all) suberror CoverageError {
  InvalidLineNumber(Int)
  InvalidHitCount(Int)
  InvalidLcov(Int, String)
  InvalidCoveralls(String)
  InvalidModel(String)
  InvalidThreshold(String, Double)
  InvalidDiff(Int, String)
} derive(Debug, Eq)

///|
/// A covered or uncovered source line.
pub(all) struct CoverageLine {
  line : Int
  hits : Int
} derive(Debug, Eq)

///|
/// A branch arm reported by a coverage producer.
///
/// `taken = None` represents LCOV's `-` value, meaning that the producer
/// instrumented the branch but did not report a numeric execution count.
pub(all) struct CoverageBranch {
  line : Int
  block : String
  branch : String
  taken : Int?
} derive(Debug, Eq)

///|
/// A function entry from a coverage report.
///
/// Some formats do not carry a declaration line, so `line` is optional.
pub(all) struct CoverageFunction {
  name : String
  line : Int?
  hits : Int
} derive(Debug, Eq)

///|
/// Coverage data for one normalized source path.
pub(all) struct FileCoverage {
  path : String
  test_name : String?
  lines : Array[CoverageLine]
  branches : Array[CoverageBranch]
  functions : Array[CoverageFunction]
} derive(Debug, Eq)

///|
/// A format-neutral coverage report.
pub(all) struct CoverageReport {
  files : Array[FileCoverage]
} derive(Debug, Eq)

///|
/// Create an empty file report.
///
/// # Example
/// ```mbt check
/// test {
///   let file = FileCoverage::new("src/lib.mbt")
///   inspect(file.path, content="src/lib.mbt")
///   inspect(file.lines.length(), content="0")
/// }
/// ```
pub fn FileCoverage::new(path : String, test_name? : String) -> FileCoverage {
  { path, test_name, lines: [], branches: [], functions: [] }
}

///|
/// Create an empty coverage report.
pub fn CoverageReport::new() -> CoverageReport {
  { files: [] }
}

///|
/// Add line coverage after validating the line number and hit count.
pub fn FileCoverage::add_line(
  self : FileCoverage,
  line : Int,
  hits : Int,
) -> Unit raise CoverageError {
  if line <= 0 {
    raise InvalidLineNumber(line)
  }
  if hits < 0 {
    raise InvalidHitCount(hits)
  }
  self.lines.push({ line, hits })
}

///|
/// Add branch coverage after validating its source line and optional count.
pub fn FileCoverage::add_branch(
  self : FileCoverage,
  line : Int,
  block : String,
  branch : String,
  taken : Int?,
) -> Unit raise CoverageError {
  if line <= 0 {
    raise InvalidLineNumber(line)
  }
  if taken is Some(count) && count < 0 {
    raise InvalidHitCount(count)
  }
  self.branches.push({ line, block, branch, taken })
}

///|
/// Add function coverage after validating the optional declaration line and
/// hit count.
pub fn FileCoverage::add_function(
  self : FileCoverage,
  name : String,
  line? : Int,
  hits : Int,
) -> Unit raise CoverageError {
  if line is Some(value) && value <= 0 {
    raise InvalidLineNumber(value)
  }
  if hits < 0 {
    raise InvalidHitCount(hits)
  }
  self.functions.push({ name, line, hits })
}

///|
/// Add a file to a report.
pub fn CoverageReport::add_file(
  self : CoverageReport,
  file : FileCoverage,
) -> Unit {
  self.files.push(file)
}

///|
/// Return the file with the exact normalized path, if present.
pub fn CoverageReport::find_file(
  self : CoverageReport,
  path : StringView,
) -> FileCoverage? {
  match self.files.search_by(file => path.equal_to_string(file.path)) {
    Some(index) => Some(self.files[index])
    None => None
  }
}

///|
/// Return whether a line or count pair represents executed code.
pub fn CoverageLine::is_covered(self : CoverageLine) -> Bool {
  self.hits > 0
}

///|
/// Return whether a branch has a positive execution count.
pub fn CoverageBranch::is_covered(self : CoverageBranch) -> Bool {
  self.taken.unwrap_or(0) > 0
}

///|
/// Return whether a function has a positive execution count.
pub fn CoverageFunction::is_covered(self : CoverageFunction) -> Bool {
  self.hits > 0
}
