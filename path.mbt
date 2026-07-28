///|
fn collapse_path(path : String) -> String {
  let slash_path = path.replace_all(old="\\", new="/")
  let unix_absolute = slash_path.has_prefix("/")
  let drive_absolute = slash_path.length() >= 3 &&
    slash_path[1] == ':' &&
    slash_path[2] == '/'
  let absolute = unix_absolute || drive_absolute
  let protected_segments = if drive_absolute { 1 } else { 0 }
  let segments : Array[String] = []
  for view in slash_path.split("/") {
    let segment = "\{view}"
    match segment {
      "" | "." => ()
      ".." =>
        if segments.length() > protected_segments &&
          segments[segments.length() - 1] != ".." {
          ignore(segments.pop())
        } else if !absolute {
          segments.push(segment)
        }
      _ => segments.push(segment)
    }
  }
  let body = segments.join("/")
  if unix_absolute {
    if body == "" {
      "/"
    } else {
      "/\{body}"
    }
  } else if drive_absolute && segments.length() == 1 {
    "\{body}/"
  } else {
    body
  }
}

///|
fn remove_normalized_prefix(path : String, prefix : String) -> String {
  if prefix == "" || prefix == "." {
    return path
  }
  if path == prefix {
    return ""
  }
  let boundary = if prefix.has_suffix("/") { prefix } else { "\{prefix}/" }
  if path.has_prefix(boundary) {
    let remainder = path[boundary.length():]
    "\{remainder}"
  } else {
    path
  }
}

///|
/// Normalize separators and dot segments in a coverage source path.
///
/// If `strip_prefix` is supplied, it is normalized first and removed only at
/// a complete path-segment boundary. The function intentionally preserves
/// letter case because case sensitivity belongs to the caller's filesystem.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(
///     normalize_path(
///       "D:\\work\\pkg\\.\\src\\..\\src\\lib.mbt",
///       strip_prefix="D:/work/pkg",
///     ),
///     content="src/lib.mbt",
///   )
/// }
/// ```
pub fn normalize_path(path : String, strip_prefix? : String = "") -> String {
  let normalized = collapse_path(path)
  remove_normalized_prefix(normalized, collapse_path(strip_prefix))
}

///|
fn glob_chars(
  pattern : Array[Char],
  pattern_index : Int,
  value : Array[Char],
  value_index : Int,
) -> Bool {
  if pattern_index == pattern.length() {
    return value_index == value.length()
  }
  match pattern[pattern_index] {
    '*' => {
      let is_double = pattern_index + 1 < pattern.length() &&
        pattern[pattern_index + 1] == '*'
      let next_pattern = if is_double {
        pattern_index + 2
      } else {
        pattern_index + 1
      }
      if is_double &&
        next_pattern < pattern.length() &&
        pattern[next_pattern] == '/' &&
        glob_chars(pattern, next_pattern + 1, value, value_index) {
        return true
      }
      if glob_chars(pattern, next_pattern, value, value_index) {
        return true
      }
      value_index < value.length() &&
      (is_double || value[value_index] != '/') &&
      glob_chars(pattern, pattern_index, value, value_index + 1)
    }
    '?' =>
      value_index < value.length() &&
      value[value_index] != '/' &&
      glob_chars(pattern, pattern_index + 1, value, value_index + 1)
    expected =>
      value_index < value.length() &&
      value[value_index] == expected &&
      glob_chars(pattern, pattern_index + 1, value, value_index + 1)
  }
}

///|
/// Match a normalized path against a small, portable glob dialect.
///
/// `*` matches within one segment, `?` matches one non-separator character,
/// and `**` can cross separators. Backslashes in both inputs are normalized.
pub fn glob_match(pattern : String, path : String) -> Bool {
  let normalized_pattern = pattern.replace_all(old="\\", new="/")
  let normalized_path = normalize_path(path)
  glob_chars(normalized_pattern.to_array(), 0, normalized_path.to_array(), 0)
}
