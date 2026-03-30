# Phase 4: macOS 兼容 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend existing bash scripts (install.sh, uninstall.sh, notify-play.sh) to work on macOS. No new scripts needed — macOS uses the same bash tooling as Linux. Changes are limited to OS detection and platform-specific audio playback command.
</domain>

<decisions>
## Implementation Decisions

### Prerequisite 检查
- **D-01:** install.sh prerequisite 检查按平台分别进行 — Linux 检查 paplay，macOS 不检查（afplay 内置）
- **D-02:** jq 仍然两个平台都需要检查（JSON 操控依赖不变）
- **D-03:** Claude Code 版本检查保持不变（macOS 也有 `claude` CLI）

### stat 兼容
- **D-04:** notify-play.sh 使用 `uname -s` 分支 — Linux 用 `stat -c %Y`，macOS 用 `stat -f %m`
- **D-05:** 不使用 date 命令替代方案（date 命令跨平台差异更大）

### 音频播放器
- **D-06:** notify-play.sh 内部 OS 检测自动选择播放器 — macOS 用 `afplay`，Linux 用 `/usr/bin/paplay`
- **D-07:** 不使用环境变量覆盖机制（保持简单，v1 不需要）

### Hook 命令路径
- **D-08:** hook 命令格式保持不变 — macOS 和 Linux 路径格式完全相同
- **D-09:** 音频文件路径用 `$HOME/.claude/notify-*.mp3`，不需要平台适配

### Claude's Discretion
- OS 检测的具体实现方式（`uname -s` vs `uname` vs 其他）留给 planner
- 是否在 uninstall.sh 中添加 OS 特定逻辑（当前脚本无平台依赖，可能不需要）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Scripts
- `scripts/notify-play.sh` — 需要修改：stat 调用 (line 18) + 播放器命令 (line 26)
- `scripts/install.sh` — 需要修改：prerequisite 检查 (line 30)
- `scripts/uninstall.sh` — 可能不需要修改（无平台特定代码）

### Research
- `.planning/research/STACK.md` — macOS afplay 详细信息和 GNU vs BSD stat 差异
- `.planning/research/PITFALLS.md` — stat -c %Y 是 Pitfall 3，有预防策略
- `.planning/research/ARCHITECTURE.md` — macOS 共享 Linux bash 脚本的架构说明

### Requirements
- `.planning/REQUIREMENTS.md` — MAC-01, MAC-02, INST-01, INST-02

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `notify-play.sh`: 现有冷却逻辑（LOCK_FILE + COOLDOWN_SEC）完全可复用，只需替换 `stat` 和播放器命令
- `install.sh`: jq 注入逻辑完全可复用，只需调整 prerequisite 检查
- `uninstall.sh`: 无平台特定代码，可能不需要改动

### Established Patterns
- `set -euo pipefail` — 所有脚本使用严格模式
- `jq` 幂等操作 settings.json — 不可变模式
- 临时文件 + trap 清理 — 安全的文件修改模式

### Integration Points
- `notify-play.sh` 被 `install.sh` 注入到 settings.json hooks 中
- 修改 notify-play.sh 后，install.sh 注入的 hook 命令不需要变（路径不变，脚本内部处理平台差异）

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-macos*
*Context gathered: 2026-03-30*
