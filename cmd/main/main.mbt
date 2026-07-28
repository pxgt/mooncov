///|
fn usage() -> String {
  (
    #|mooncov - coverage report bridge
    #|
    #|Usage:
    #|  moon run cmd/main
    #|  moon run cmd/main -- summary <lcov|coveralls|cobertura> <file>
    #|  moon run cmd/main -- validate <lcov|coveralls|cobertura> <file>
    #|  moon run cmd/main -- normalize <lcov|coveralls|cobertura> <file>
    #|  moon run cmd/main -- json <lcov|coveralls|cobertura> <file>
    #|  moon run cmd/main -- gate <lcov|coveralls|cobertura> <file> <minimum-lines>
    #|  moon run cmd/main -- merge <lcov|coveralls|cobertura> <file> <file> [...]
    #|  moon run cmd/main -- compare <lcov|coveralls|cobertura> <before> <after>
    #|  moon run cmd/main -- regress <lcov|coveralls|cobertura> <before> <after> <allowed-line-drop>
    #|
    #|With no arguments, mooncov prints a built-in reproducible demonstration.
    #|
  )
}

///|
fn read_report(format : String, path : String) -> @mooncov.CoverageReport raise {
  let input = @fs.read_file_to_string(path)
  match format {
    "lcov" => @mooncov.parse_lcov(input)
    "coveralls" => @mooncov.parse_coveralls(input)
    "cobertura" => @mooncov.parse_cobertura(input)
    _ =>
      raise @mooncov.InvalidModel(
        "input format must be lcov, coveralls, or cobertura",
      )
  }
}

///|
fn print_demo() -> Unit raise {
  let sample =
    #|TN:demo
    #|SF:src/calculator.mbt
    #|FN:1,add
    #|FNDA:4,add
    #|DA:1,4
    #|DA:2,0
    #|BRDA:2,0,0,1
    #|BRDA:2,0,1,0
    #|end_of_record
    #|
  println(@mooncov.to_markdown(@mooncov.parse_lcov(sample)))
}

///|
fn parse_percentage(value : String, label : String) -> Double raise {
  let percentage : Double = @strconv.from_str(value) catch {
    _ => raise @mooncov.InvalidModel("\{label} must be a number")
  }
  percentage
}

///|
fn run_command(args : Array[String]) -> Unit raise {
  if args.length() <= 1 {
    print_demo()
    return
  }
  match args[1] {
    "help" | "--help" | "-h" => println(usage())
    "summary" =>
      if args.length() != 4 {
        raise @mooncov.InvalidModel("summary expects format and file")
      } else {
        println(@mooncov.to_markdown(read_report(args[2], args[3])))
      }
    "validate" =>
      if args.length() != 4 {
        raise @mooncov.InvalidModel("validate expects format and file")
      } else {
        let report = read_report(args[2], args[3])
        let summary = @mooncov.summarize(report)
        println(
          "valid: \{report.files.length()} files, " +
          "\{summary.lines.covered}/\{summary.lines.total} covered lines",
        )
      }
    "normalize" =>
      if args.length() != 4 {
        raise @mooncov.InvalidModel("normalize expects format and file")
      } else {
        println(@mooncov.to_lcov(read_report(args[2], args[3])))
      }
    "json" =>
      if args.length() != 4 {
        raise @mooncov.InvalidModel("json expects format and file")
      } else {
        println(@mooncov.to_json_report(read_report(args[2], args[3])))
      }
    "gate" =>
      if args.length() != 5 {
        raise @mooncov.InvalidModel(
          "gate expects format, file, and minimum-lines",
        )
      } else {
        let report = read_report(args[2], args[3])
        let result = @mooncov.check_thresholds(
          report,
          @mooncov.CoverageThresholds::new(
            lines=parse_percentage(args[4], "minimum line coverage"),
          ),
        )
        println(@mooncov.gate_message(result))
        if !result.passed {
          @sys.exit(2)
        }
      }
    "merge" =>
      if args.length() < 5 {
        raise @mooncov.InvalidModel(
          "merge expects format and at least two files",
        )
      } else {
        let reports : Array[@mooncov.CoverageReport] = []
        for index in 3..<args.length() {
          reports.push(read_report(args[2], args[index]))
        }
        println(@mooncov.to_lcov(@mooncov.merge_reports(reports)))
      }
    "compare" =>
      if args.length() != 5 {
        raise @mooncov.InvalidModel(
          "compare expects format, baseline file, and current file",
        )
      } else {
        let comparison = @mooncov.compare_reports(
          read_report(args[2], args[3]),
          read_report(args[2], args[4]),
        )
        println(@mooncov.comparison_to_markdown(comparison))
      }
    "regress" =>
      if args.length() != 6 {
        raise @mooncov.InvalidModel(
          "regress expects format, baseline, current, and allowed line drop",
        )
      } else {
        let result = @mooncov.check_regressions(
          read_report(args[2], args[3]),
          read_report(args[2], args[4]),
          @mooncov.RegressionLimits::new(
            lines=parse_percentage(args[5], "allowed line drop"),
          ),
        )
        println(@mooncov.regression_message(result))
        if !result.passed {
          @sys.exit(2)
        }
      }
    command =>
      raise @mooncov.InvalidModel(
        "unknown command \"\{command}\"; run with --help",
      )
  }
}

///|
fn exit_with_error(message : String) -> Unit {
  println("mooncov: \{message}")
  @sys.exit(1)
}

///|
fn main {
  try run_command(@sys.get_cli_args()) catch {
    @mooncov.InvalidLineNumber(line) =>
      exit_with_error("invalid line number: \{line}")
    @mooncov.InvalidHitCount(hits) =>
      exit_with_error("invalid hit count: \{hits}")
    @mooncov.InvalidLcov(line, message) =>
      exit_with_error("LCOV line \{line}: \{message}")
    @mooncov.InvalidCoveralls(message) =>
      exit_with_error("Coveralls: \{message}")
    @mooncov.InvalidCobertura(line, message) =>
      exit_with_error("Cobertura line \{line}: \{message}")
    @mooncov.InvalidModel(message) => exit_with_error(message)
    @mooncov.InvalidThreshold(metric, value) =>
      exit_with_error("invalid \{metric} threshold: \{value}")
    @mooncov.InvalidDiff(line, message) =>
      exit_with_error("diff line \{line}: \{message}")
    error => exit_with_error("\{Repr(error)}")
  } noraise {
    _ => ()
  }
}
