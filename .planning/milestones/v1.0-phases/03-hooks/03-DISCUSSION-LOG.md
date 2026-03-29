# Phase 3: Hooks 集成 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 3-hooks
**Areas discussed:** 音频路径, 事件选择, 安装脚本, 冷却防抖, 路径处理

---

## 音频路径

| Option | Description | Selected |
|--------|-------------|----------|
| 仓库 audio/ 直接播放 | hooks 直接引用 repo 内的 audio/notify-*.mp3 | |
| 复制到 ~/.claude/ 后播放 | 安装脚本把 mp3 复制到 ~/.claude/，hooks 播放 ~/.claude/notify-*.mp3 | ✓ |

**User's choice:** 复制到 ~/.claude/ 后播放
**Notes:** 路径固定，不依赖 repo 位置

---

## 事件选择

| Option | Description | Selected |
|--------|-------------|----------|
| 仅 3 种（ROADMAP 定义） | Stop → complete, Notification → confirm, StopFailure → error | |
| 加 SubagentStop | 在 3 种基础上加 SubagentStop → progress | ✓ |
| 你来定 | 让 Claude 推荐 | |

**User's choice:** 加 SubagentStop（4 种事件）
**Notes:** 用户经常用 Agent 工具，子 agent 完成时需要通知

---

## Notification 事件播放内容

| Option | Description | Selected |
|--------|-------------|----------|
| 播放 notify-confirm.mp3 | Claude Code 需要用户输入时播放确认音 | ✓ |
| 不播放 | 保持默认行为 | |

**User's choice:** 播放 notify-confirm.mp3

---

## 安装脚本

| Option | Description | Selected |
|--------|-------------|----------|
| 需要 install.sh | 脚本读取 settings.json → 结构化添加 hooks → 写回，幂等 | ✓ |
| 不需要，手动说明 | README 说明 JSON 片段，用户自己编辑 | |

**User's choice:** 需要 install.sh
**Notes:** 用户特别强调用 jq/Node.js 结构化修改 JSON，不用 sed

---

## 冷却/防抖

| Option | Description | Selected |
|--------|-------------|----------|
| 不防抖 | 每次事件都播放 | |
| 简单冷却 (5s) | 同一音频 5 秒内不重复播放 | ✓ |

**User's choice:** 简单冷却 5 秒
**Notes:** v2 有 HOOKS-02 冷却需求，v1 先做简单版

---

## Hooks 路径处理

| Option | Description | Selected |
|--------|-------------|----------|
| hooks 用绝对路径 | paplay ~/.claude/notify-*.mp3 | ✓ |
| 自动检测路径 | 脚本检测 repo 安装位置 | |

**User's choice:** hooks 用绝对路径

---

## Claude's Discretion

- 冷却锁文件的具体命名和清理策略
- 安装脚本的输出信息和帮助格式
- hooks 的 timeout 值
- 是否检查 paplay 可用性

## Deferred Ideas

None
