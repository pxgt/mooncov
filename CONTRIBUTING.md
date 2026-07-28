# Contributing to mooncov

Thank you for improving `mooncov`.

## Development setup

Install a current stable MoonBit toolchain, clone the repository, and run:

```text
moon version --all
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn
```

The native CLI additionally uses `moonbitlang/x`, which `moon` downloads from
the dependency pinned in `moon.mod`.

## Change guidelines

1. Keep public concrete coverage types in the root package.
2. Split implementation into cohesive `.mbt` files and separate top-level
   declarations with `///|`.
3. Verify standard-library and dependency APIs with `moon ide doc`; do not add
   guessed imports.
4. Add black-box tests for observable behavior. Use white-box tests only when a
   private parser invariant cannot be tested through the public API.
5. Include malformed-input cases for parser changes and round-trip cases for
   writer changes.
6. Use only original, minimal fixtures or fixtures whose source and license are
   documented.
7. Update `README.mbt.md`, format semantics, and the changelog when behavior or
   public API changes.

## Before opening a pull request

```text
moon fmt
moon info --target all
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn
moon build --target all
moon run cmd/main
moon run cmd/main -- summary lcov examples/sample.info
moon package
git diff --exit-code
```

Review generated `pkg.generated.mbti` changes. They are part of the public API
contract and should be committed intentionally.

## Commit style

Prefer small, meaningful commits that each leave the repository in a working
state. Do not use empty commits, repeated generated output, or artificial
splitting to increase commit count.
