# Verification record

## Maintenance check: 2026-11-11

Starting source: default branch `main`, commit
`6483c21ea4be7f83e5edbd059abdc0558f6a7f36` (package version 0.1.1).
The maintenance changes are not a new Mooncakes release.

The official [stable download](https://www.moonbitlang.com/download/) was
checked on 2026-11-11. Actual `moon version --all` output:

```text
moon 0.1.20261104 (940aa18 2026-11-04) ~/.moon/bin/moon
moonc v0.10.20+65efd5b93 (2026-11-05) ~/.moon/bin/moonc
moonrun 0.1.20261104 (940aa18 2026-11-04) ~/.moon/bin/moonrun

Feature flags enabled: rr_moon_mod,rr_moon_pkg
```

Host: Ubuntu 22.04.5 x86_64 under WSL2; Node.js 22.23.4 and GCC.
This run does not establish results on macOS or Windows native.

The original source failed on removed `@strconv.from_str`, implicit derived
trait methods, deprecated derive syntax, and unqualified documentation-test
imports. The numeric parser failure also matches
[Issue #4](https://github.com/pxgt/mooncov/issues/4), reported on macOS arm64.
The fix uses `@str.parse_int` / `@str.parse_double` from
`moonbitlang/core/string` (verified with `moon ide doc`), explicit hidden
compatibility extensions, and qualified documentation examples. No warning is
disabled. The existing `moonbitlang/x@0.4.45` dependency builds successfully and
is retained.

Results: format, interface generation, strict four-target check, four-target
build and tests, all six CLI commands below, and `moon package --frozen`
passed. Tests: 75 each on wasm, wasm-gc, JavaScript and native (300 total).
The interface diff contains derive-format and Int/Int32 spelling migration;
the exported functions, fields and variants are retained.

CI installs the current stable toolchain and records its actual version on
every push, PR, manual run and weekly run. Node.js 22 is selected explicitly.
These are local results, not a claim that an unpushed branch has run on GitHub.

## Historical release verification

Version 0.1.1 was originally verified with:

```text
moon 0.1.20260803
moonc 0.10.6
```

Run from the repository root:

```text
moon fmt --check
moon info --target all
git diff --exit-code
moon check --target all --deny-warn --warn-list +73
moon build --target all
moon test --target all --deny-warn --warn-list +73
moon run cmd/main
moon run cmd/main -- summary lcov examples/sample.info
moon run cmd/main -- validate lcov examples/sample.info
moon run cmd/main -- summary cobertura examples/sample.xml
moon run cmd/main -- compare lcov examples/sample.info examples/sample.info
moon run cmd/main -- regress lcov examples/sample.info examples/sample.info 0
moon package --frozen
git diff --exit-code
```

The suite contains 75 tests. CI executes them on wasm, wasm-gc, JavaScript, and
native, for 300 backend test executions. The native commands above exercise the
bundled LCOV and Cobertura fixtures.

The authoritative automated record is the
[GitHub Actions workflow](https://github.com/pxgt/mooncov/actions/workflows/ci.yml).
Published packages are listed under
[`Xpeng/mooncov`](https://mooncakes.io/docs/#/Xpeng/mooncov).
