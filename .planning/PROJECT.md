# Claude Code 语音通知

## What This Is

为 Claude Code 提供语音通知的系统。使用 Spark-TTS 0.5B 生成中文语音通知音频，通过 Claude Code hooks 在任务完成、需要用户交互、执行出错等场景自动播放提醒用户。

## Core Value

用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 使用 Spark-TTS 0.5B 生成 4 种通知语音（任务完成、请确认、出错、进行中）
- [ ] 一键脚本生成所有音频文件到 `~/.claude/` 目录
- [ ] 记录 Spark-TTS 安装和配置步骤
- [ ] 音频文件与 Claude Code hooks 配合（hooks 已配置，播放 `~/.claude/notify-*.mp3`）

### Out of Scope

- 实时语音合成（TTS 推理约 8 分钟/句，只做预生成） — 性能不可接受
- 动态文案 — 预生成固定文案即可
- GUI 界面 — 纯 CLI 脚本

## Context

- Claude Code hooks 已在 `~/.claude/settings.json` 配置（notification hook + stop hook）
- Hooks 执行 `paplay ~/.claude/notify-confirm.mp3 2>/dev/null &` 播放音频
- Spark-TTS 运行环境：conda `sparktts` (Python 3.12)，代码在 `/tmp/Spark-TTS`
- TTS 参数：`--gender female --pitch low --speed low`（温柔低沉慵懒风格）
- 音频输出需转换为 mp3 格式（ffmpeg）

## Constraints

- **性能**：Spark-TTS CPU 推理约 8 分钟/句，只能预生成不能实时合成
- **环境**：需要 conda 环境 `sparktts` 和 `/tmp/Spark-TTS` 代码
- **平台**：Linux (Fedora)，使用 `paplay` 播放音频
- **许可**：Spark-TTS 使用 Apache 2.0 许可证

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 预生成而非实时合成 | CPU 推理 8 分钟/句，实时不可接受 | — Pending |
| 4 种固定通知文案 | 覆盖主要场景（完成、确认、出错、进行中） | — Pending |
| Spark-TTS 0.5B | 开源 Apache 2.0，中文支持好 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-30 after initialization*
