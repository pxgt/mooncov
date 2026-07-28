# mooncov

[![CI](https://github.com/pxgt/mooncov/actions/workflows/ci.yml/badge.svg)](https://github.com/pxgt/mooncov/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

`mooncov` 是一个纯 MoonBit 覆盖率报告工具包，面向库、命令行工具和 CI
流程。它将 LCOV、Coveralls JSON 和 Cobertura XML 转换为统一的类型化数据模型，
并提供合并、过滤、统计、阈值检查、基线比较和稳定输出。

核心库支持 `wasm`、`wasm-gc`、`js` 和 `native` 后端；文件型 CLI 仅支持 `native`。

## 功能

- 解析和确定性输出 LCOV tracefile；
- 解析和输出 Coveralls `source_files` JSON；
- 解析和输出 Cobertura XML；
- 统一表示行、分支和函数覆盖率；
- 合并多个任务或后端产生的报告；
- 规范化路径，并按 `*`、`?`、`**` 规则筛选文件；
- 统计整体和单文件覆盖率；
- 检查行、分支和函数覆盖率阈值；
- 比较基线，限制允许的覆盖率下降；
- 根据 unified diff 检查改动行覆盖率；
- 输出 Markdown 和完整 JSON 报告；
- 提供可直接运行的 native CLI。

## 安装

```text
moon add Xpeng/mooncov
```

在调用方的 `moon.pkg` 中导入：

```text
import {
  "Xpeng/mooncov",
}
```

## 最小示例

```mbt
test {
  let report = @mooncov.parse_lcov(
    "SF:src/lib.mbt\nDA:1,1\nDA:2,0\nend_of_record\n",
  )
  let summary = @mooncov.summarize(report)
  inspect(summary.lines.covered, content="1")
  inspect(summary.lines.total, content="2")
}
```

## 命令行示例

克隆仓库后，可从项目根目录运行：

```text
moon run cmd/main
moon run cmd/main -- summary lcov examples/sample.info
moon run cmd/main -- validate lcov examples/sample.info
moon run cmd/main -- summary cobertura examples/sample.xml
```

CLI 还支持格式规范化、报告合并、基线比较和回归门禁。完整参数及行为边界见
[README.mbt.md](README.mbt.md)。

## 验证

```text
moon fmt --check
moon info --target all
moon check --target all --deny-warn --warn-list +73
moon build --target all
moon test --target all --deny-warn
moon run cmd/main
moon package
git diff --exit-code
```

GitHub Actions 会执行格式、接口、检查、构建、测试、示例和打包验证。

## 文档关系

本文件是供 GitHub 和 GitLink 展示的项目首页。
[README.mbt.md](README.mbt.md) 是详细文档，包含 API 说明、格式语义、
边界条件和会参与 MoonBit 检查与测试的 `mbt check` 示例。
更多设计说明见 [docs/format-semantics.md](docs/format-semantics.md)，
CI 用法见 [docs/recipes.md](docs/recipes.md)。

## 来源说明

项目为原创 MoonBit 实现，行为设计参考 LCOV、Coveralls、Cobertura
和 MoonBit coverage 的公开格式与工具文档，没有复制其他覆盖率库的实现。
与 Mooncakes 上的 `PingGuoMiaoMiao/mooncove` 相比，本项目侧重标准格式
互操作、统计与 CI 门禁；两者没有实现来源关系。

## 许可证

项目采用 [Apache License 2.0](LICENSE)。
