# Phase 6: 测试基础设施 + 静态分析 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 06-test-infra-static-analysis
**Areas discussed:** test.sh 入口设计, Docker 测试矩阵, ShellCheck/PSScriptAnalyzer 配置, Fixture 和 notify-play.sh/ps1 改造

---

## test.sh 入口设计

| Option | Description | Selected |
|--------|-------------|----------|
| 子命令 flag 风格 | test.sh --lint / --bash / --powershell / --all。单一脚本。 | ✓ |
| 多脚本分离 | lint.sh、test-bash.sh、test-powershell.sh 各自独立。 | |
| Makefile targets | Makefile 定义 lint/test/test-all targets。 | |

**User's choice:** 子命令 flag 风格

---

## Docker 测试矩阵集成方式

| Option | Description | Selected |
|--------|-------------|----------|
| test.sh 内置 Docker 调用 | --bash/--powershell 时自动 docker build + run。 | ✓ |
| docker-compose.yml | docker-compose up bats / docker-compose up pester。 | |
| 手动 Docker 命令 | 提供镜像但不自动调用。 | |

**User's choice:** test.sh 内置 Docker 调用

---

## Docker 基础镜像策略

| Option | Description | Selected |
|--------|-------------|----------|
| 官方预构建镜像 + volume mount | bats/bats-core + mcr.microsoft.com/powershell，volume mount 注入测试。 | ✓ |
| 自定义 Dockerfile | FROM python:3.12-slim 安装 bats 和 pwsh。 | |
| 混合方案 | bats 官方镜像 + Pester 自定义。 | |

**User's choice:** 官方预构建镜像 + volume mount

---

## 静态分析严格级别

| Option | Description | Selected |
|--------|-------------|----------|
| warning 级别 | ShellCheck --severity warning, PSSA -Severity Warning。 | ✓ |
| error 级别 | 只报真正的错误。 | |
| info 级别（全量） | 最严格，可能大量噪音。 | |

**User's choice:** warning 级别

---

## lint 失败是否阻断 test.sh --all

| Option | Description | Selected |
|--------|-------------|----------|
| 失败阻断 | 返回非零退出码，--all 中止后续测试。 | ✓ |
| 仅警告不阻断 | 打印警告但不阻断。 | |

**User's choice:** 失败阻断

---

## 共享 fixture 文件内容

| Option | Description | Selected |
|--------|-------------|----------|
| fake settings.json + dummy.mp3 | settings.json 模拟真实结构，dummy.mp3 用于路径检查。 | ✓ |
| 最小骨架 | 空的 settings.json 骨架 + dummy.mp3。 | |
| 多场景 fixture | 多种 settings.json 变体。 | |

**User's choice:** fake settings.json + dummy.mp3

---

## notify-play.sh 环境变量命名

| Option | Description | Selected |
|--------|-------------|----------|
| NOTIFY_LOCK_DIR | 覆盖 lock file 目录，默认 /tmp。 | ✓ |
| NOTIFY_LOCK_FILE | 完整覆盖 lock file 路径。 | |

**User's choice:** NOTIFY_LOCK_DIR

---

## fake settings.json 结构

| Option | Description | Selected |
|--------|-------------|----------|
| 真实结构（有已有 hooks） | 包含 PreToolUse 等已有 hooks + 普通配置。 | ✓ |
| 最小空结构 | {} 或 {"hooks": {}}。 | |

**User's choice:** 真实结构（有已有 hooks）

---

## notify-play.ps1 是否加 $env:NOTIFY_LOCK_DIR

| Option | Description | Selected |
|--------|-------------|----------|
| 加 $env:NOTIFY_LOCK_DIR | 保持两个脚本可测试性机制对称。 | ✓ |
| 不改造 PS1 | PowerShell 已灵活，不需要额外改造。 | |

**User's choice:** 加 $env:NOTIFY_LOCK_DIR

---

## Claude's Discretion

- ShellCheck/PSScriptAnalyzer 排除规则 — 规划时决定
- bats-core 和 PowerShell 镜像版本 pin — 规划时选 stable 版本
- dummy.mp3 大小和格式 — 最小有效 MP3
- test.sh 输出格式 — 彩色/简洁，规划时决定

## Deferred Ideas

None.
