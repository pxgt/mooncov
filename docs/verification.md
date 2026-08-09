# Verification record

Version 0.1.1 is verified with:

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
