# Claude Code 语音通知

## What This Is

为 Claude Code 提供语音通知的系统。使用 Spark-TTS 0.5B 预生成中文语音通知音频，通过 Claude Code hooks 在任务完成、需要用户交互、执行出错、子 agent 完成等场景自动播放提醒用户。一键安装，无需手动配置。

## Core Value

用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## Current State

Phase 4 complete — macOS 兼容已实现（notify-play.sh afplay + BSD stat，install.sh 便携命令）。Windows 兼容待开发。

## Current Milestone: v1.1 跨平台兼容

**Goal:** 让语音通知系统在 macOS 和 Windows 上也能开箱即用，保持一键安装体验。

**Target features:**
- 跨平台音频播放：根据 OS 自动选择 afplay(macOS) / PowerShell(Windows) / paplay(Linux)
- 跨平台安装脚本：install.sh(Linux/macOS) + install.ps1(Windows)，卸载同理
- notify-play.sh 改造为跨平台通知播放包装器
- Docker 构建环境不变（仅 Linux 预生成 mp3，分发平台无关）

## Requirements

### Validated (v1.0)

- ✓ Docker 化 Spark-TTS 环境 — v1.0
- ✓ 4 种通知语音（任务完成、请确认、出错、进行中）— v1.0

### Validated (v1.1)

- ✓ macOS afplay 音频播放 — Phase 4
- ✓ macOS BSD stat 兼容 — Phase 4
- ✓ install.sh macOS 便携命令支持 — Phase 4
- ✓ uninstall.sh macOS 兼容（无需改动）— Phase 4
- ✓ 一键脚本生成所有音频文件 — v1.0
- ✓ Claude Code hooks 4 种事件通知（Stop/Notification/StopFailure/SubagentStop）— v1.0
- ✓ 非阻塞播放（async: true）+ 5 秒冷却防抖 — v1.0

### Active

- [ ] Windows 兼容：notify-play.ps1 + install.ps1 + uninstall.ps1

### Out of Scope

- 实时语音合成 — CPU 推理 8 分钟/句，性能不可接受
- 动态文案通知 — 需要实时 TTS，超出预生成架构
- GUI 界面 — 音频通知已足够，保持简单
- 多语言支持 — 中文即可
- 音量控制 — 用户通过系统音量控制即可

## Context

- `scripts/install.sh` — 一键安装（复制 mp3 + 注入 hooks 到 settings.json）
- `scripts/uninstall.sh` — 一键卸载
- `scripts/notify-play.sh` — 冷却包装器（5 秒防抖）
- `audio/notify-*.mp3` — 4 个预生成音频，提交到仓库
- `Dockerfile` + `requirements.txt` — Spark-TTS Docker 构建环境
- `generate.sh` — 音频重新生成编排脚本
- Hooks 使用 `async: true`，paplay 绝对路径播放

## Constraints

- **性能**：Spark-TTS CPU 推理约 8 分钟/句，只能预生成不能实时合成
- **环境**：使用 Docker 容器化 Spark-TTS，消除宿主机依赖
- **平台**：Linux (Fedora)，使用 `paplay` 播放音频
- **跨平台**：v1.1 目标支持 macOS (afplay) 和 Windows (PowerShell)
- **许可**：Spark-TTS 使用 Apache 2.0 许可证

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

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-03-30 after starting v1.1 milestone*
