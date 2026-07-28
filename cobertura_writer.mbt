///|
fn cobertura_rate(count : CoverageCount) -> String {
  (count.percentage() / 100.0).to_string()
}

///|
fn cobertura_method_rate(function : CoverageFunction) -> String {
  if function.hits > 0 {
    "1"
  } else {
    "0"
  }
}

///|
fn branches_by_line(file : FileCoverage) -> Map[Int, Array[CoverageBranch]] {
  let grouped : Map[Int, Array[CoverageBranch]] = {}
  for branch in file.branches {
    grouped.get_or_init(branch.line, () => []).push(branch)
  }
  grouped
}

///|
fn line_hits_map(file : FileCoverage) -> Map[Int, Int] {
  let hits : Map[Int, Int] = {}
  for line in file.lines {
    hits[line.line] = line.hits
  }
  for branch in file.branches {
    if !hits.contains(branch.line) {
      hits[branch.line] = 0
    }
  }
  hits
}

///|
fn write_cobertura_methods(output : StringBuilder, file : FileCoverage) -> Unit {
  let functions = [
    for function in file.functions if function.line is Some(_) => function
  ]
  functions.sort_by(compare_functions)
  if functions.is_empty() {
    output.write_string("          <methods/>\n")
    return
  }
  output.write_string("          <methods>\n")
  for function in functions {
    guard function.line is Some(line) else { continue }
    output.write_string(
      "            <method name=\"\{xml_escape_attribute(function.name)}\" " +
      "signature=\"\" line-rate=\"\{cobertura_method_rate(function)}\">\n",
    )
    output.write_string("              <lines>\n")
    output.write_string(
      "                <line number=\"\{line}\" hits=\"\{function.hits}\"/>\n",
    )
    output.write_string("              </lines>\n")
    output.write_string("            </method>\n")
  }
  output.write_string("          </methods>\n")
}

///|
fn write_cobertura_line(
  output : StringBuilder,
  line : Int,
  hits : Int,
  branches : Array[CoverageBranch]?,
) -> Unit {
  match branches {
    None =>
      output.write_string(
        "            <line number=\"\{line}\" hits=\"\{hits}\"/>\n",
      )
    Some(items) => {
      let covered = items.fold(init=0, (count, branch) => {
        if branch.is_covered() {
          count + 1
        } else {
          count
        }
      })
      let total = items.length()
      let percent = if total == 0 { 100 } else { covered * 100 / total }
      output.write_string(
        "            <line number=\"\{line}\" hits=\"\{hits}\" " +
        "branch=\"true\" condition-coverage=\"\{percent}% " +
        "(\{covered}/\{total})\">\n",
      )
      output.write_string("              <conditions>\n")
      for branch in items {
        let coverage = if branch.is_covered() { 100 } else { 0 }
        output.write_string(
          "                <condition number=\"" +
          "\{xml_escape_attribute(branch.branch)}\" type=\"jump\" " +
          "coverage=\"\{coverage}%\"/>\n",
        )
      }
      output.write_string("              </conditions>\n")
      output.write_string("            </line>\n")
    }
  }
}

///|
fn write_cobertura_class(output : StringBuilder, file : FileCoverage) -> Unit {
  let summary = summarize_canonical_file(file)
  let escaped_path = xml_escape_attribute(file.path)
  output.write_string(
    "        <class name=\"\{escaped_path}\" filename=\"\{escaped_path}\" " +
    "line-rate=\"\{cobertura_rate(summary.lines)}\" " +
    "branch-rate=\"\{cobertura_rate(summary.branches)}\">\n",
  )
  write_cobertura_methods(output, file)
  output.write_string("          <lines>\n")
  let hits = line_hits_map(file)
  let grouped_branches = branches_by_line(file)
  let line_numbers = [ for line, _ in hits => line ]
  line_numbers.sort()
  for line in line_numbers {
    write_cobertura_line(output, line, hits[line], grouped_branches.get(line))
  }
  output.write_string("          </lines>\n")
  output.write_string("        </class>\n")
}

///|
/// Encode a report as deterministic Cobertura XML.
///
/// Cobertura carries aggregate branch conditions rather than LCOV branch
/// identities. Mooncov writes each branch as a condition and guarantees that
/// line and branch summary counts survive a mooncov encode/decode round trip.
pub fn to_cobertura(
  report : CoverageReport,
  source_root? : String = ".",
) -> String raise CoverageError {
  let canonical = canonicalize_report(report)
  let summary = canonical.files.fold(init=empty_summary(), (acc, file) => {
    add_summaries(acc, summarize_canonical_file(file))
  })
  let output = StringBuilder()
  output.write_string("<?xml version=\"1.0\" ?>\n")
  output.write_string(
    "<coverage lines-valid=\"\{summary.lines.total}\" " +
    "lines-covered=\"\{summary.lines.covered}\" " +
    "line-rate=\"\{cobertura_rate(summary.lines)}\" " +
    "branches-valid=\"\{summary.branches.total}\" " +
    "branches-covered=\"\{summary.branches.covered}\" " +
    "branch-rate=\"\{cobertura_rate(summary.branches)}\" " +
    "complexity=\"0\" version=\"mooncov-0.1.0\" timestamp=\"0\">\n",
  )
  output.write_string("  <sources>\n")
  output.write_string(
    "    <source>\{xml_escape_attribute(source_root)}</source>\n",
  )
  output.write_string("  </sources>\n")
  output.write_string("  <packages>\n")
  output.write_string(
    "    <package name=\".\" line-rate=\"\{cobertura_rate(summary.lines)}\" " +
    "branch-rate=\"\{cobertura_rate(summary.branches)}\">\n",
  )
  output.write_string("      <classes>\n")
  for file in canonical.files {
    write_cobertura_class(output, file)
  }
  output.write_string("      </classes>\n")
  output.write_string("    </package>\n")
  output.write_string("  </packages>\n")
  output.write_string("</coverage>\n")
  output.to_string()
}
