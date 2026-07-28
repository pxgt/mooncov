///|
/// An inclusive new-file line range extracted from a unified diff hunk.
pub(all) struct ChangedRange {
  path : String
  start_line : Int
  end_line : Int
} derive(Debug, Eq)

///|
/// Instrumented line coverage selected by a collection of changed ranges.
pub(all) struct DiffSummary {
  lines : CoverageCount
  changed_ranges : Int
  matched_files : Int
  unmatched_files : Array[String]
} derive(Debug, Eq)

///|
/// The result of a changed-line coverage gate.
pub(all) struct DiffGateResult {
  passed : Bool
  summary : DiffSummary
  actual : Double
  required : Double
} derive(Debug)

///|
fn diff_owned(view : StringView) -> String {
  "\{view}"
}

///|
fn clean_diff_path(raw : String, strip_prefix : String) -> String {
  let without_timestamp = match raw.split_once("\t") {
    Some((path, _)) => diff_owned(path)
    None => raw
  }
  let trimmed = "\{without_timestamp.trim()}"
  let unquoted = if trimmed.length() >= 2 &&
    trimmed.has_prefix("\"") &&
    trimmed.has_suffix("\"") {
    "\{trimmed[1:trimmed.length() - 1]}"
  } else {
    trimmed
  }
  let without_git_prefix = if unquoted.has_prefix("a/") ||
    unquoted.has_prefix("b/") {
    "\{unquoted[2:]}"
  } else {
    unquoted
  }
  normalize_path(without_git_prefix, strip_prefix~)
}

///|
fn parse_hunk_range(
  header : String,
  input_line : Int,
) -> (Int, Int) raise CoverageError {
  let fields : Array[String] = []
  for field in header.split(" ") {
    if field != "" {
      fields.push(diff_owned(field))
    }
  }
  if fields.length() < 4 ||
    fields[0] != "@@" ||
    !fields[2].has_prefix("+") ||
    fields[3] != "@@" {
    raise InvalidDiff(input_line, "malformed unified diff hunk header")
  }
  let token = "\{fields[2][1:]}"
  let (start_text, count_text) = match token.split_once(",") {
    Some((start, count)) => (diff_owned(start), diff_owned(count))
    None => (token, "1")
  }
  let start : Int = @strconv.from_str(start_text) catch {
    _ => raise InvalidDiff(input_line, "invalid new-file hunk start")
  }
  let count : Int = @strconv.from_str(count_text) catch {
    _ => raise InvalidDiff(input_line, "invalid new-file hunk count")
  }
  if start < 0 || count < 0 {
    raise InvalidDiff(input_line, "hunk start and count must not be negative")
  }
  (start, count)
}

///|
/// Parse new-file ranges from standard unified diff text.
///
/// `+++ b/path` headers select the destination path. Deleted files
/// (`+++ /dev/null`) and deletion-only hunks (`+start,0`) produce no ranges.
/// Git's conventional `a/` and `b/` prefixes are removed automatically.
pub fn parse_unified_diff(
  input : String,
  strip_prefix? : String = "",
) -> Array[ChangedRange] raise CoverageError {
  let ranges : Array[ChangedRange] = []
  let mut current_path : String? = None
  let mut saw_destination_header = false
  for index, raw_view in input.split("\n") {
    let input_line = index + 1
    let raw = diff_owned(raw_view)
    let line = "\{raw.trim_end(chars="\r")}"
    if line.has_prefix("+++ ") {
      saw_destination_header = true
      let raw_path = "\{line[4:]}"
      current_path = if raw_path == "/dev/null" {
        None
      } else {
        let path = clean_diff_path(raw_path, strip_prefix)
        if path == "" {
          raise InvalidDiff(input_line, "new-file path must not be empty")
        }
        Some(path)
      }
    } else if line.has_prefix("@@") {
      if !saw_destination_header {
        raise InvalidDiff(input_line, "hunk has no preceding +++ file header")
      }
      let (start, count) = parse_hunk_range(line, input_line)
      if count > 0 && current_path is Some(path) {
        if start <= 0 {
          raise InvalidDiff(input_line, "non-empty hunk start must be positive")
        }
        let end_line = start + count - 1
        if end_line < start {
          raise InvalidDiff(input_line, "new-file hunk range exceeds Int")
        }
        ranges.push({ path, start_line: start, end_line })
      }
    }
  }
  ranges
}

///|
fn line_in_changed_ranges(
  path : String,
  line : Int,
  ranges : ArrayView[ChangedRange],
) -> Bool {
  for range in ranges {
    if range.path == path && line >= range.start_line && line <= range.end_line {
      return true
    }
  }
  false
}

///|
fn range_path_matches(path : String, ranges : ArrayView[ChangedRange]) -> Bool {
  ranges.any(range => range.path == path)
}

///|
/// Calculate changed-line coverage for instrumented lines.
///
/// Changed lines absent from the coverage report are not treated as misses,
/// because executable and non-executable source cannot be distinguished from
/// a unified diff alone. Their paths are exposed in `unmatched_files` when no
/// file-level coverage record exists at all.
pub fn summarize_diff(
  report : CoverageReport,
  ranges : ArrayView[ChangedRange],
) -> DiffSummary raise CoverageError {
  for range in ranges {
    if range.path == "" ||
      range.start_line <= 0 ||
      range.end_line < range.start_line {
      raise InvalidModel("changed range must have a path and positive bounds")
    }
  }
  let canonical = canonicalize_report(report)
  let report_paths : Map[String, Unit] = {}
  let mut covered = 0
  let mut total = 0
  let mut matched_files = 0
  for file in canonical.files {
    report_paths[file.path] = ()
    if range_path_matches(file.path, ranges) {
      matched_files = matched_files + 1
    }
    for line in file.lines {
      if line_in_changed_ranges(file.path, line.line, ranges) {
        total = total + 1
        if line.is_covered() {
          covered = covered + 1
        }
      }
    }
  }
  let unmatched_set : Map[String, Unit] = {}
  for range in ranges {
    if !report_paths.contains(range.path) {
      unmatched_set[range.path] = ()
    }
  }
  let unmatched_files = [ for path, _ in unmatched_set => path ]
  unmatched_files.sort()
  {
    lines: { covered, total },
    changed_ranges: ranges.length(),
    matched_files,
    unmatched_files,
  }
}

///|
/// Enforce a minimum percentage on instrumented changed lines.
pub fn check_diff_threshold(
  report : CoverageReport,
  ranges : ArrayView[ChangedRange],
  minimum : Double,
) -> DiffGateResult raise CoverageError {
  validate_threshold("diff lines", Some(minimum))
  let summary = summarize_diff(report, ranges)
  let actual = summary.lines.percentage()
  { passed: actual >= minimum, summary, actual, required: minimum }
}
