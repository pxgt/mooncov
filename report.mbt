///|
fn percentage_text(count : CoverageCount) -> String {
  let hundredths = (count.percentage() * 100.0).round().to_int()
  let whole = hundredths / 100
  let fraction = hundredths % 100
  let fraction_text = if fraction < 10 {
    "0\{fraction}"
  } else {
    fraction.to_string()
  }
  "\{whole}.\{fraction_text}%"
}

///|
fn count_text(count : CoverageCount) -> String {
  "\{percentage_text(count)} (\{count.covered}/\{count.total})"
}

///|
fn markdown_cell(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new=" ")
}

///|
fn write_summary_row(
  output : StringBuilder,
  scope : String,
  summary : CoverageSummary,
) -> Unit {
  output.write_string(
    "| \{markdown_cell(scope)} | \{count_text(summary.lines)} | " +
    "\{count_text(summary.branches)} | " +
    "\{count_text(summary.functions)} |\n",
  )
}

///|
/// Render report-wide and optional per-file statistics as a Markdown table.
pub fn to_markdown(
  report : CoverageReport,
  title? : String = "Coverage report",
  include_files? : Bool = true,
) -> String raise CoverageError {
  let output = StringBuilder()
  output.write_string("## \{markdown_cell(title)}\n\n")
  output.write_string("| Scope | Lines | Branches | Functions |\n")
  output.write_string("|:--|--:|--:|--:|\n")
  write_summary_row(output, "**Overall**", summarize(report))
  if include_files {
    for file in summarize_files(report) {
      write_summary_row(output, "`\{file.path}`", file.summary)
    }
  }
  output.to_string()
}

///|
fn count_json(count : CoverageCount) -> Json {
  Json::object({
    "covered": json_integer(count.covered),
    "total": json_integer(count.total),
    "percentage": Json::number(count.percentage()),
  })
}

///|
fn summary_json(summary : CoverageSummary) -> Json {
  Json::object({
    "lines": count_json(summary.lines),
    "branches": count_json(summary.branches),
    "functions": count_json(summary.functions),
  })
}

///|
fn line_json(line : CoverageLine) -> Json {
  Json::object({
    "line": json_integer(line.line),
    "hits": json_integer(line.hits),
  })
}

///|
fn branch_json(branch : CoverageBranch) -> Json {
  Json::object({
    "line": json_integer(branch.line),
    "block": Json::string(branch.block),
    "branch": Json::string(branch.branch),
    "taken": match branch.taken {
      Some(count) => json_integer(count)
      None => Json::null()
    },
  })
}

///|
fn function_json(function : CoverageFunction) -> Json {
  Json::object({
    "name": Json::string(function.name),
    "line": match function.line {
      Some(line) => json_integer(line)
      None => Json::null()
    },
    "hits": json_integer(function.hits),
  })
}

///|
fn unified_file_json(file : FileCoverage) -> Json {
  Json::object({
    "path": Json::string(file.path),
    "test_name": match file.test_name {
      Some(name) => Json::string(name)
      None => Json::null()
    },
    "summary": summary_json(summarize_canonical_file(file)),
    "lines": Json::array([ for line in file.lines => line_json(line) ]),
    "branches": Json::array(
      [
        for branch in file.branches => branch_json(branch)
      ],
    ),
    "functions": Json::array(
      [
        for function in file.functions => function_json(function)
      ],
    ),
  })
}

///|
/// Encode the complete unified model and calculated statistics as JSON.
///
/// Unlike Coveralls JSON, this mooncov-specific format retains function
/// coverage and test names.
pub fn to_json_report(
  report : CoverageReport,
  indent? : Int = 2,
) -> String raise CoverageError {
  if indent < 0 {
    raise InvalidModel("JSON indentation must not be negative")
  }
  let canonical = canonicalize_report(report)
  let root = Json::object({
    "format": Json::string("mooncov-report-v1"),
    "summary": summary_json(
      canonical.files.fold(init=empty_summary(), (acc, file) => {
        add_summaries(acc, summarize_canonical_file(file))
      }),
    ),
    "files": Json::array(
      [
        for file in canonical.files => unified_file_json(file)
      ],
    ),
  })
  root.stringify(indent~)
}

///|
fn metric_name(metric : CoverageMetric) -> String {
  match metric {
    Lines => "lines"
    Branches => "branches"
    Functions => "functions"
  }
}

///|
/// Produce a concise human-readable threshold result for CI logs.
pub fn gate_message(result : GateResult) -> String {
  if result.passed {
    return "coverage gate passed"
  }
  let parts : Array[String] = []
  for violation in result.violations {
    parts.push(
      "\{metric_name(violation.metric)} " +
      "\{violation.actual}% < \{violation.required}%",
    )
  }
  "coverage gate failed: \{parts.join("; ")}"
}
