# Phase 3: Hooks 集成 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

修改 `~/.claude/settings.json`，添加 Claude Code hooks 在 4 种事件（Stop、Notification、StopFailure、SubagentStop）时自动播放对应的预生成 mp3 通知音频。提供 `install.sh` 安装脚本，用 jq 结构化修改 settings.json（幂等），并复制 mp3 到 `~/.claude/`。

</domain>

<decisions>
## Implementation Decisions

### 音频文件部署
- **D-01:** 安装时将 `audio/notify-*.mp3` 复制到 `~/.claude/`，hooks 播放 `~/.claude/notify-*.mp3`（不直接引用 repo 路径）
- **D-02:** 路径固定为 `~/.claude/notify-{type}.mp3`，hooks 中使用绝对路径

### 事件映射
- **D-03:** 4 种事件通知：
  - `Stop` → `notify-complete.mp3`（任务完成）
  - `Notification` → `notify-confirm.mp3`（需要用户注意）
  - `StopFailure` → `notify-error.mp3`（执行出错）
  - `SubagentStop` → `notify-progress.mp3`（子 agent 完成）
- **D-04:** 音频播放后台运行（`paplay ... 2>/dev/null &`），不阻塞 Claude Code

### 冷却/防抖
- **D-05:** 同一音频 5 秒内不重复播放（简单冷却机制）
- **D-06:** 冷却实现方式：基于临时文件时间戳（`/tmp/claude-notify-{type}.lock`），轻量无额外依赖

### 安装脚本
- **D-07:** 提供 `install.sh`，功能：复制 mp3 → 用 jq 结构化修改 `~/.claude/settings.json` 添加 hooks → 幂等（重复运行不出错）
- **D-08:** 提供 `uninstall.sh`，用 jq 从 settings.json 移除 notify hooks → 清理 `~/.claude/notify-*.mp3`
- **D-09:** 安装脚本必须用 jq 或 Node.js 操作 JSON，禁止用 sed/awk 修改 settings.json（避免破坏配置）
- **D-10:** hooks 中的 command 使用绝对路径：`/usr/bin/paplay ~/.claude/notify-{type}.mp3 2>/dev/null &`

### Claude's Discretion
- 冷却锁文件的具体命名和清理策略
- 安装脚本的输出信息和帮助格式
- hooks 的 timeout 值
- 是否检查 paplay 可用性（依赖检测）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — 项目愿景、约束（Platform: Linux Fedora, paplay 播放）
- `.planning/REQUIREMENTS.md` — HOOKS-01 需求定义

### Phase 2 Artifacts (inputs)
- `audio/notify-complete.mp3` — 预生成的任务完成通知音频
- `audio/notify-confirm.mp3` — 预生成的请确认通知音频
- `audio/notify-error.mp3` — 预生成的出错通知音频
- `audio/notify-progress.mp3` — 预生成的进行中通知音频

### Phase 2 Context
- `.planning/phases/02-generate-script/02-CONTEXT.md` — Phase 2 决策 D-11/D-12（mp3 在仓库 audio/ 目录）

### External
- Claude Code hooks 文档: https://docs.anthropic.com/en/docs/claude-code/hooks — hook 事件类型和配置格式
- 当前 `~/.claude/settings.json` — 已有 gsd 插件 hooks，需在此基础上追加 notify hooks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `audio/notify-*.mp3` — 4 个预生成的通知音频，install.sh 需复制到 `~/.claude/`

### Established Patterns
- `~/.claude/settings.json` 已有 hooks 结构（SessionStart, PostToolUse, PreToolUse），notify hooks 追加到同一对象
- settings.json 使用标准 JSON 格式，hooks 按 event type 组织

### Integration Points
- `~/.claude/settings.json` 的 `hooks` 字段 — notify hooks 插入位置
- `~/.claude/notify-*.mp3` — 音频文件部署目标位置
- `/usr/bin/paplay` — 音频播放命令

</code_context>

<specifics>
## Specific Ideas

- 用户明确要求：修改 settings.json 时用 jq/Node.js 结构化操作，不用 sed/awk（防止破坏 JSON 配置）
- 当前 settings.json 没有 Stop/Notification/StopFailure/SubagentStop hooks，需要新增
- PipeWire/PulseAudio 自动混音，多个音频可同时播放
- 用户经常使用 Agent 工具，所以 SubagentStop 事件需要通知

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-hooks*
*Context gathered: 2026-03-30*
