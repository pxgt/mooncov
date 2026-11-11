///|
test "extract added-side ranges from a multi-file unified diff" {
  let diff =
    #|diff --git a/src/a.mbt b/src/a.mbt
    #|--- a/src/a.mbt
    #|+++ b/src/a.mbt
    #|@@ -1,2 +3,4 @@ fn a {
    #| context
    #|diff --git a/src/new.mbt b/src/new.mbt
    #|--- /dev/null
    #|+++ b/src/new.mbt
    #|@@ -0,0 +1 @@
    #|+new
    #|
  let ranges = @mooncov.parse_unified_diff(diff)
  inspect(ranges.length(), content="2")
  inspect(ranges[0].path, content="src/a.mbt")
  inspect(ranges[0].start_line, content="3")
  inspect(ranges[0].end_line, content="6")
  inspect(ranges[1].path, content="src/new.mbt")
  inspect(ranges[1].end_line, content="1")
}

///|
test "ignore deleted files and deletion-only new-side hunks" {
  let diff =
    #|--- a/old.mbt
    #|+++ /dev/null
    #|@@ -1,3 +0,0 @@
    #|--- a/kept.mbt
    #|+++ b/kept.mbt
    #|@@ -4,2 +4,0 @@
    #|
  let ranges = @mooncov.parse_unified_diff(diff)
  inspect(ranges.length(), content="0")
}

///|
test "changed-line summary counts overlapping ranges once" {
  let file = @mooncov.FileCoverage::new("src/a.mbt")
  file.add_line(2, 1)
  file.add_line(3, 0)
  file.add_line(4, 5)
  file.add_line(8, 0)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let ranges : Array[@mooncov.ChangedRange] = [
    { path: "src/a.mbt", start_line: 2, end_line: 4, },
    { path: "src/a.mbt", start_line: 3, end_line: 8, },
    { path: "src/missing.mbt", start_line: 1, end_line: 2, },
  ]
  let summary = @mooncov.summarize_diff(report, ranges)
  inspect(summary.lines.covered, content="2")
  inspect(summary.lines.total, content="4")
  inspect(summary.matched_files, content="1")
  inspect(summary.unmatched_files.length(), content="1")
  inspect(summary.unmatched_files[0], content="src/missing.mbt")
}

///|
test "diff threshold uses the same inclusive boundary semantics" {
  let file = @mooncov.FileCoverage::new("src/a.mbt")
  file.add_line(1, 1)
  file.add_line(2, 0)
  let report = @mooncov.CoverageReport::new()
  report.add_file(file)
  let ranges : Array[@mooncov.ChangedRange] = [
    { path: "src/a.mbt", start_line: 1, end_line: 2, },
  ]
  assert_true(@mooncov.check_diff_threshold(report, ranges, 50.0).passed)
  assert_false(@mooncov.check_diff_threshold(report, ranges, 50.1).passed)
}

///|
test "unified diff parser points to malformed hunk headers" {
  let diff = "+++ b/src/a.mbt\n@@ broken @@\n"
  try @mooncov.parse_unified_diff(diff) catch {
    InvalidDiff(line, message) => {
      inspect(line, content="2")
      inspect(message, content="malformed unified diff hunk header")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid diff")
  }
}
