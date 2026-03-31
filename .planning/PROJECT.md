# Claude Code 语音通知

## What This Is

为 Claude Code 提供跨平台语音通知的系统。使用 Spark-TTS 0.5B 预生成中文语音通知音频，通过 Claude Code hooks 在任务完成、需要用户交互、执行出错、子 agent 完成等场景自动播放提醒用户。三平台一键安装，22 个自动化测试覆盖全部核心逻辑。

## Core Value

用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## Current State

v1.3 shipped — 11 phases, 18 plans complete. Cross-platform notification system with CI and full test coverage:
- 4 pre-generated mp3 notification sounds
- 6 scripts (install/uninstall/notify-play × bash/PowerShell)
- 22 automated tests (10 bats-core + 12 Pester)
- ShellCheck + PSScriptAnalyzer static analysis
- Docker test matrix (Linux bats, pwsh Pester)

### Shipped Versions

- **v1.3 GitHub Actions CI** — 3-platform CI matrix, README with CI badge
- **v1.1 跨平台兼容** — macOS afplay + Windows PowerShell, 三平台一键安装
- **v1.0 语音通知** — Docker TTS + 4 mp3 + Claude Code hooks

## Current Milestone: Planning next milestone

All v1.3 requirements shipped. Ready for next milestone definition.

## Requirements

### Validated

- ✓ Docker 化 Spark-TTS 环境 — v1.0
- ✓ 4 种通知语音（任务完成、请确认、出错、进行中）— v1.0
- ✓ 一键脚本生成所有音频文件 — v1.0
- ✓ Claude Code hooks 4 种事件通知（Stop/Notification/StopFailure/SubagentStop）— v1.0
- ✓ 非阻塞播放（async: true）+ 5 秒冷却防抖 — v1.0
- ✓ macOS afplay 音频播放 + BSD stat 兼容 — v1.1
- ✓ macOS install.sh 便携命令支持 — v1.1
- ✓ Windows notify-play.ps1 MediaPlayer + 冷却防抖 — v1.1
- ✓ Windows install.ps1 shell:powershell + forward-slash 路径 — v1.1
- ✓ Windows uninstall.ps1 hook 清理 + 文件删除 — v1.1
- ✓ ShellCheck 静态分析 bash 脚本 — v1.2
- ✓ PowerShell PSScriptAnalyzer 分析 ps1 脚本 — v1.2
- ✓ bats 单元测试 shell 脚本核心逻辑（10 tests）— v1.2
- ✓ Pester 单元测试 PowerShell 脚本核心逻辑（12 tests）— v1.2
- ✓ Docker 测试矩阵覆盖 Linux/macOS/Windows — v1.2

- ✓ CI-compatible test paths ($REPO_ROOT/$RepoRoot, no hardcoded /app/) — v1.3 Phase 9
- ✓ GitHub Actions CI workflow (3-platform matrix, lint + test) — v1.3 Phase 10
- ✓ README with CI status badge and project documentation — v1.3 Phase 11

### Active

(None — all shipped requirements validated)

### Out of Scope

- 实时语音合成 — CPU 推理 8 分钟/句，性能不可接受
- 动态文案通知 — 需要实时 TTS，超出预生成架构
- GUI 界面 — 音频通知已足够，保持简单
- 多语言支持 — 中文即可
- 音量控制 — 用户通过系统音量控制即可
- macOS Docker 容器测试 — 不可容器化，mock 测试覆盖
- Windows Docker 容器测试 — 3-11 GB 镜像过大
- GitHub Actions CI — v1.3 shipped
- bash 代码覆盖率 — kcov 停止维护，无成熟工具

## Context

- `scripts/install.sh` — Linux/macOS 一键安装
- `scripts/uninstall.sh` — Linux/macOS 一键卸载
- `scripts/notify-play.sh` — Linux/macOS 冷却包装器（paplay/afplay，5 秒防抖）
- `scripts/notify-play.ps1` — Windows 音频播放（MediaPlayer + 5 秒冷却）
- `scripts/install.ps1` — Windows 一键安装（PowerShell hooks 注入）
- `scripts/uninstall.ps1` — Windows 一键卸载
- `audio/notify-*.mp3` — 4 个预生成音频，提交到仓库
- `tests/bash/*.bats` — 10 bats-core 测试
- `tests/powershell/*.Tests.ps1` — 12 Pester 测试
- `tests/stubs/` — mock stubs（paplay, afplay, claude CLI）
- `tests/fixtures/` — 共享测试 fixture（settings.json, dummy.mp3）
- `test.sh` — 统一测试入口（lint + bash + powershell + Docker 矩阵）
- `.github/workflows/ci.yml` — GitHub Actions CI workflow（3-platform matrix）
- `README.md` — 项目文档（CI badge、安装说明、hook 配置）
- `Dockerfile` + `requirements.txt` — Spark-TTS Docker 构建环境（仅预生成用）
- `generate.sh` — 音频重新生成编排脚本

## Constraints

- **性能**：Spark-TTS CPU 推理约 8 分钟/句，只能预生成不能实时合成
- **环境**：Docker 容器化 Spark-TTS，仅用于音频预生成，运行时无需 Docker
- **平台**：Linux (paplay)、macOS (afplay)、Windows (MediaPlayer)
- **许可**：Spark-TTS 使用 Apache 2.0 许可证
- **测试**：Docker Linux-only 容器测试，macOS/Windows 代码路径通过 mock 覆盖；GitHub Actions CI 三平台自动运行

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 预生成而非实时合成 | CPU 推理 8 分钟/句 | ✓ v1.0 validated |
| Docker 容器化 | 消除宿主机依赖 | ✓ v1.0 validated |
| Spark-TTS 0.5B | 开源 Apache 2.0，中文支持好 | ✓ v1.0 validated |
| mp3 提交到仓库 | 免除 Docker 依赖即可使用 | ✓ v1.0 validated |
| async: true 非阻塞 | 原生 Claude Code 机制 | ✓ v1.0 validated |
| jq 幂等操作 settings.json | 避免 sed/awk 破坏配置 | ✓ v1.0 validated |
| 5 秒冷却防抖 | 临时文件时间戳，轻量无依赖 | ✓ v1.0 validated |
| bash 覆盖 Linux + macOS | uname -s 检测，共享一套脚本 | ✓ v1.1 validated |
| Windows 单独 PowerShell | PS 5.1 兼容，.NET MediaPlayer 无 GUI | ✓ v1.1 validated |
| BOM-free JSON 写入 | PS Set-Content 带 BOM，用 WriteAllText 替代 | ✓ v1.1 validated |
| forward-slash 路径 | Claude Code Windows hooks 反斜杠 bug #26759 | ✓ v1.1 validated |
| NOTIFY_LOCK_DIR 环境变量 | 测试可覆盖 lock file 路径，/tmp 默认值兼容 | ✓ v1.2 validated |
| Docker Linux-only 测试 | Windows 容器 3-11 GB，Pester 在 pwsh 容器运行 | ✓ v1.2 validated |
| CI-compatible test paths | $REPO_ROOT/$RepoRoot 替代 /app/，mktemp stubs 替代 /usr/bin/ | ✓ v1.3 Phase 9 validated |
| Pester 5.6.1 pinned | 避免 Pester 6.x beta 不兼容 | ✓ v1.2 validated |
| CI 3-platform matrix | 三平台 lint + test 自动化 | ✓ v1.3 Phase 10 validated |
| README with CI badge | 项目文档 + CI 状态展示 | ✓ v1.3 Phase 11 validated |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-03-31 after v1.3 milestone completion*
