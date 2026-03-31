# Phase 16: Marketplace 构建 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 16-marketplace
**Areas discussed:** Marketplace 标识符, Plugin source 类型, 发现元数据

---

## Marketplace 标识符

| Option | Description | Selected |
|--------|-------------|----------|
| hlwqds | 与 README 一致，用户习惯: /plugin install claude-voice-notify@hlwqds | ✓ |
| claude-voice-notify | 更具描述性: /plugin install claude-voice-notify@claude-voice-notify | |
| voice-notify | 简短但清晰: /plugin install claude-voice-notify@voice-notify | |

**User's choice:** hlwqds (Recommended)
**Notes:** README 已在 Phase 15 写入 `/plugin marketplace add hlwqds/notify-research`，需要保持一致。

---

## Plugin source 类型

| Option | Description | Selected |
|--------|-------------|----------|
| Relative path "./" | Claude Code clone 整个仓库，插件文件直接可用。单插件仓库最自然的选择。 | ✓ |
| GitHub source type | 单独指定 source type github + repo。适合多插件市场、仓库内子目录等场景。 | |

**User's choice:** Relative path "./" (Recommended)
**Notes:** 单插件仓库，相对路径最简单直接。

---

## 发现元数据

| Option | Description | Selected |
|--------|-------------|----------|
| 标准发现元数据 | keywords: ["notification", "audio", "voice", "chinese", "tts"], category: "productivity" | ✓ |
| 最小元数据 | 只填 description + version，让用户通过搜索 description 找到 | |
| 自定义 | 我有自己想用的 keywords/category | |

**User's choice:** 标准发现元数据 (Recommended)
**Notes:** 覆盖中英文搜索场景，分类为 productivity。

---

## Claude's Discretion

无 — 所有三个 gray area 都有明确决策。

## Deferred Ideas

None
