# Phase 2: 生成脚本 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 02-generate-script
**Areas discussed:** Selective generation, Docker rebuild strategy, Verification depth, Script UX and error handling

---

## Selective Generation

| Option | Description | Selected |
|--------|-------------|----------|
| 改造 generate.py (Recommended) | 给 generate.py 加 --type 参数，Docker 内部根据参数只生成指定类型 | ✓ |
| 环境变量控制 | generate.py 不动，用环境变量 NOTIFY_TYPE=confirm 控制 | |
| You decide | 技术细节由 Claude 决定 | |

**User's choice:** 改造 generate.py (Recommended)
**Notes:** 当前 generate.py 只能一次生成全部 4 种通知，需要改造支持选择性生成。

### Single vs Multiple Types

| Option | Description | Selected |
|--------|-------------|----------|
| 单个类型 | ./generate.sh --type confirm 只生成一个 | |
| 多个类型 (Recommended) | 支持 --type confirm,error 逗号分隔 | ✓ |
| You decide | 根据实际需求选 | |

**User's choice:** 多个类型
**Notes:** 支持 ./generate.sh --type confirm,error 一次指定多个类型重新生成。

---

## Docker Rebuild Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| 智能跳过 + --force (Recommended) | 检测镜像存在就跳过，加 --force-rebuild 可强制重建 | ✓ |
| 总是 build | 每次都 docker build（利用层缓存） | |
| You decide | | |

**User's choice:** 智能跳过 + --force (Recommended)
**Notes:** 避免不必要的 build，同时保留强制重建能力。

---

## Verification Depth

| Option | Description | Selected |
|--------|-------------|----------|
| 文件存在 + 格式检查 (Recommended) | 检查文件存在 + file 命令确认有效 MP3，不播放 | ✓ |
| 包含 paplay 试播 | 实际播放音频验证 | |
| You decide | | |

**User's choice:** 文件存在 + 格式检查 (Recommended)
**Notes:** paplay 试播在脚本中体验不好（尤其 CI/无头环境），只做文件和格式检查。

---

## Script UX and Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| 清晰进度 + 即停报错 (Recommended) | 步骤进度输出，出错立即停止 | ✓ |
| 丰富选项（dry-run 等） | dry-run、verbose、重试等 | |
| You decide | | |

**User's choice:** 清晰进度 + 即停报错 (Recommended)
**Notes:** 简洁够用即可，不需要 dry-run/verbose 等高级选项。

### Help Text

**User's choice:** 有中文帮助 — 包含中文帮助信息说明脚本用途。

---

## Claude's Discretion

- generate.py 的参数传递机制（argparse / sys.argv / 环境变量）
- 进度输出格式
- 退出码定义
- 脚本变量和路径拼接方式

## Deferred Ideas

None
