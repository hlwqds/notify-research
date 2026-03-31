# Phase 12: Multi-Voice Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 12-multi-voice-foundation
**Areas discussed:** voice params, generation timing, directory migration, generate.sh

---

## Voice Style Parameters

| Option | Description | Selected |
|--------|-------------|----------|
| 男声 (male/high pitch/moderate speed) | 与 default 形成明显对比，男声通知 | ✓ |
| 活泼女声 (female/high pitch/fast speed) | 更活泼的语调，保持女声但风格不同 | |
| 童声/可爱风 (女童/低龄音色) | 可爱风格，但 TTS 对此支持不确定 | |

**User's choice:** 男声 (male/high pitch/moderate speed)

### Voice Directory Naming

| Option | Description | Selected |
|--------|-------------|----------|
| default + male | 简洁明了 | |
| female + male | 对称命名 | |
| gentle + deep | 描述性命名 | ✓ |

**User's choice:** gentle + deep

---

## Deep Voice Generation Timing

| Option | Description | Selected |
|--------|-------------|----------|
| 本 phase 生成并提交 | Phase 12 同时生成 deep 语音并提交到仓库 | ✓ |
| 只建基础，后续生成 | Phase 12 只建基础设施，生成放在单独步骤 | |

**User's choice:** 本 phase 生成并提交

**User note:** 语音生成是本地预生成然后推送到仓库中的，不能让用户生成。

---

## Directory Migration Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| 一次性迁移 + 全部更新 | git mv + 更新所有引用 (install.sh/tests/generate.sh) | ✓ |
| 保留旧路径 + 新增 voices/ | 两套路径共存 | |

**User's choice:** 一次性迁移 + 全部更新

---

## generate.sh Changes

| Option | Description | Selected |
|--------|-------------|----------|
| 添加 --voice + 输出目录支持 | 支持 --voice flag，输出到 audio/voices/{name}/，保留 ~/.claude/ 输出模式 | ✓ |
| 只改 generate.py | generate.sh 不动 | |
| 新脚本替代 | voices/generate-voice.sh 替代 generate.sh | |

**User's choice:** 添加 --voice + 输出目录支持

---

## Claude's Discretion

- voices/*.json schema design
- Whether to add voices.json manifest file
- generate.py --output-dir vs deriving from --voice
- Whether to add --list-voices flag

## Deferred Ideas

None.
