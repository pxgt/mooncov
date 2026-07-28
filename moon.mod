name = "Xpeng/mooncov"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/pxgt/mooncov"

license = "Apache-2.0"

keywords = [
  "coverage",
  "lcov",
  "coveralls",
  "ci",
  "testing",
]

description = "Coverage report parsing, merging, filtering, gating, and conversion for MoonBit projects."

import {
  "moonbitlang/x@0.4.45",
}

options(
  "preferred-target": "native",
)
