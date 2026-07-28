///|
test "normalize portable and absolute paths" {
  inspect(
    @mooncov.normalize_path("src\\parser\\..\\model.mbt"),
    content="src/model.mbt",
  )
  inspect(
    @mooncov.normalize_path("/workspace//src/./main.mbt"),
    content="/workspace/src/main.mbt",
  )
  inspect(@mooncov.normalize_path("../src/lib.mbt"), content="../src/lib.mbt")
}

///|
test "strip only a complete normalized path prefix" {
  inspect(
    @mooncov.normalize_path("C:\\repo\\src\\lib.mbt", strip_prefix="C:/repo"),
    content="src/lib.mbt",
  )
  inspect(
    @mooncov.normalize_path("/repo-two/lib.mbt", strip_prefix="/repo"),
    content="/repo-two/lib.mbt",
  )
}

///|
test "glob matcher distinguishes segment and recursive wildcards" {
  assert_true(@mooncov.glob_match("src/*.mbt", "src/model.mbt"))
  assert_false(@mooncov.glob_match("src/*.mbt", "src/internal/model.mbt"))
  assert_true(@mooncov.glob_match("src/**/*.mbt", "src/internal/model.mbt"))
  assert_true(@mooncov.glob_match("src/**/*.mbt", "src/model.mbt"))
  assert_true(@mooncov.glob_match("src/??.mbt", "src/io.mbt"))
  assert_false(@mooncov.glob_match("src/??.mbt", "src/parser.mbt"))
}
