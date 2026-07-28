///|
fn usage() -> String {
  (
    #|mooncov - coverage report bridge
    #|
    #|Usage:
    #|  moon run cmd/main
    #|  moon run cmd/main -- summary <lcov|coveralls> <file>
    #|  moon run cmd/main -- validate <lcov|coveralls> <file>
    #|  moon run cmd/main -- normalize <lcov|coveralls> <file>
    #|  moon run cmd/main -- json <lcov|coveralls> <file>
    #|  moon run cmd/main -- gate <lcov|coveralls> <file> <minimum-lines>
    #|  moon run cmd/main -- merge <lcov|coveralls> <file> <file> [...]
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
    _ => raise @mooncov.InvalidModel("input format must be lcov or coveralls")
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
fn parse_minimum(value : String) -> Double raise {
  let minimum : Double = @strconv.from_str(value) catch {
    _ => raise @mooncov.InvalidModel("minimum line coverage must be a number")
  }
  minimum
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
          @mooncov.CoverageThresholds::new(lines=parse_minimum(args[4])),
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
    command =>
      raise @mooncov.InvalidModel(
        "unknown command \"\{command}\"; run with --help",
      )
  }
}

///|
fn main {
  try run_command(@sys.get_cli_args()) catch {
    error => {
      println("mooncov: \{error}")
      @sys.exit(1)
    }
  } noraise {
    _ => ()
  }
}
