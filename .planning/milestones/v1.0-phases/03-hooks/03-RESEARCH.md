# Phase 3: Hooks 集成 - Research

**Researched:** 2026-03-30
**Domain:** Claude Code hooks configuration, shell scripting (jq), Linux audio playback
**Confidence:** HIGH

## Summary

This phase modifies `~/.claude/settings.json` to register Claude Code hooks for 4 events (Stop, Notification, StopFailure, SubagentStop), each playing a corresponding pre-generated MP3 notification audio via `paplay`. The core deliverables are: an `install.sh` script that copies audio files and idempotently injects hooks into settings.json using jq, and an `uninstall.sh` script that cleanly removes them.

Claude Code hooks now support a native `async: true` field on command hooks, which runs the hook in the background without blocking Claude's execution. This is superior to the original plan's `paplay ... &` shell backgrounding approach -- `async: true` is the officially supported mechanism for non-blocking side-effect hooks. Additionally, Stop and SubagentStop hooks can **block** Claude from stopping (exit code 2 or JSON `decision: "block"`), so our hooks must ensure they always exit 0.

**Primary recommendation:** Use `async: true` on all notification hooks instead of shell `&` backgrounding. This is the Claude Code-native mechanism for non-blocking hooks and avoids accidental blocking behavior.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### 音频文件部署
- **D-01:** 安装时将 `audio/notify-*.mp3` 复制到 `~/.claude/`，hooks 播放 `~/.claude/notify-*.mp3`（不直接引用 repo 路径）
- **D-02:** 路径固定为 `~/.claude/notify-{type}.mp3`，hooks 中使用绝对路径

#### 事件映射
- **D-03:** 4 种事件通知：
  - `Stop` → `notify-complete.mp3`（任务完成）
  - `Notification` → `notify-confirm.mp3`（需要用户注意）
  - `StopFailure` → `notify-error.mp3`（执行出错）
  - `SubagentStop` → `notify-progress.mp3`（子 agent 完成）
- **D-04:** 音频播放后台运行（`paplay ... 2>/dev/null &`），不阻塞 Claude Code

#### 冷却/防抖
- **D-05:** 同一音频 5 秒内不重复播放（简单冷却机制）
- **D-06:** 冷却实现方式：基于临时文件时间戳（`/tmp/claude-notify-{type}.lock`），轻量无额外依赖

#### 安装脚本
- **D-07:** 提供 `install.sh`，功能：复制 mp3 → 用 jq 结构化修改 `~/.claude/settings.json` 添加 hooks → 幂等（重复运行不出错）
- **D-08:** 提供 `uninstall.sh`，用 jq 从 settings.json 移除 notify hooks → 清理 `~/.claude/notify-*.mp3`
- **D-09:** 安装脚本必须用 jq 或 Node.js 操作 JSON，禁止用 sed/awk 修改 settings.json（避免破坏配置）
- **D-10:** hooks 中的 command 使用绝对路径：`/usr/bin/paplay ~/.claude/notify-{type}.mp3 2>/dev/null &`

### Claude's Discretion
- 冷却锁文件的具体命名和清理策略
- 安装脚本的输出信息和帮助格式
- hooks 的 timeout 值
- 是否检查 paplay 可用性（依赖检测）

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOOKS-01 | Claude Code hooks 配置 3 种事件对应不同音频：Stop → notify-complete.mp3、Notification → notify-confirm.mp3、StopFailure → notify-error.mp3 | Full hook event schema, configuration format, and async behavior documented. CONTEXT.md expands to 4 events including SubagentStop. |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| **jq** | 1.8.1 | JSON manipulation for settings.json | Required by D-09; available on system at `/usr/bin/jq`; safest way to modify JSON without corruption |
| **bash** | 5.x | Install/uninstall script runtime | Standard Linux shell; supports all needed operations (file copy, jq invocation, file tests) |
| **paplay** | 17.0 (PipeWire) | Audio playback | PipeWire/PulseAudio command-line player; available at `/usr/bin/paplay`; project constraint (CLAUDE.md) |

### Claude Code Hook System
| Feature | Details | Confidence |
|---------|---------|------------|
| Hook events | Stop, Notification, StopFailure, SubagentStop | HIGH -- verified on official docs |
| `async: true` | Native background execution for command hooks | HIGH -- verified on official docs |
| `timeout` field | Optional seconds before canceling; default 600s for command hooks | HIGH -- verified on official docs |
| Exit code behavior | Stop/SubagentStop can BLOCK on exit 2; StopFailure/Notification cannot block | HIGH -- verified on official docs |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `async: true` | Shell `&` backgrounding (`paplay ... &`) | `async: true` is the official mechanism; `&` works but creates orphan processes. Recommend `async: true` with a small wrapper script for cooldown logic |
| jq | Node.js for JSON manipulation | jq is lighter and already available; Node.js would work but adds complexity for simple JSON ops |
| `paplay` | `mpv --no-video` or `aplay` | paplay is the project-standard player (CLAUDE.md); mpv is heavier; aplay is ALSA-only (no mixing) |

**Installation:**
No package installation needed -- all tools are already available on the system.

## Architecture Patterns

### Recommended Project Structure
```
notify-research/
├── audio/
│   ├── notify-complete.mp3      # Phase 2 output (exists)
│   ├── notify-confirm.mp3       # Phase 2 output (exists)
│   ├── notify-error.mp3         # Phase 2 output (exists)
│   └── notify-progress.mp3      # Phase 2 output (exists)
├── scripts/
│   ├── install.sh               # NEW: install hooks + copy audio
│   ├── uninstall.sh             # NEW: remove hooks + cleanup audio
│   └── notify-play.sh           # NEW: cooldown wrapper for paplay
├── .planning/
│   └── phases/03-hooks/
│       ├── 03-CONTEXT.md
│       └── 03-RESEARCH.md       # This file
└── CLAUDE.md
```

### Pattern 1: Cooldown Wrapper Script

**What:** A small shell script `notify-play.sh` that checks a lock file timestamp before playing audio, implements the 5-second cooldown from D-05/D-06.

**When to use:** Every notification hook command calls this wrapper instead of calling `paplay` directly.

**Why:** The `async: true` flag runs the hook in background, but we still need cooldown logic to prevent rapid-fire duplicate notifications. A wrapper script keeps the hook command simple and the cooldown logic centralized.

**Example:**
```bash
#!/bin/bash
# scripts/notify-play.sh
# Usage: notify-play.sh <type> <audio_file>
# Plays audio with 5-second cooldown to prevent duplicate notifications.

TYPE="$1"
AUDIO_FILE="$2"
LOCK_FILE="/tmp/claude-notify-${TYPE}.lock"
COOLDOWN_SEC=5

# Check cooldown: if lock file exists and is younger than COOLDOWN_SEC, skip
if [ -f "$LOCK_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
    if [ "$AGE" -lt "$COOLDOWN_SEC" ]; then
        exit 0  # Within cooldown, skip playback
    fi
fi

# Touch lock file and play audio
touch "$LOCK_FILE"
/usr/bin/paplay "$AUDIO_FILE" 2>/dev/null
exit 0  # MUST exit 0 -- Stop/SubagentStop hooks block on exit 2
```

**Key insight:** The wrapper script MUST always `exit 0`. Stop and SubagentStop hooks interpret exit code 2 as "block Claude from stopping," which would create an infinite loop.

### Pattern 2: Idempotent Hook Installation via jq

**What:** Using jq to add hooks to `~/.claude/settings.json` without destroying existing hooks.

**When to use:** install.sh must append notify hooks alongside existing GSD hooks (SessionStart, PostToolUse, PreToolUse).

**Example (install.sh core logic):**
```bash
# The hook configuration to inject
NOTIFY_HOOK='{"hooks": [{"hooks": [{"type": "command", "command": "/path/to/scripts/notify-play.sh complete ~/.claude/notify-complete.mp3", "async": true, "timeout": 10}]}]}'

# Add Stop hook (idempotent -- overwrites if exists, adds if not)
jq --argjson hook "$NOTIFY_HOOK" '.hooks.Stop = $hook.hooks' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json
```

**Why jq over sed/awk:** D-09 explicitly forbids sed/awk for JSON. jq preserves JSON structure, handles nested objects correctly, and won't corrupt the file.

### Pattern 3: Clean Hook Removal via jq

**What:** Using jq `del()` to remove specific hook event entries.

**When to use:** uninstall.sh must remove notify hooks without affecting existing GSD hooks.

**Example (uninstall.sh core logic):**
```bash
# Remove all 4 notify hook events
jq 'del(.hooks.Stop, .hooks.Notification, .hooks.StopFailure, .hooks.SubagentStop)' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json
```

**Important:** This removes the ENTIRE Stop/Notification/StopFailure/SubagentStop arrays, not individual entries. If the user ever adds other hooks to these events, they would be lost too. For v1 this is acceptable since these events currently have no hooks. If needed, a more surgical approach could filter by command string.

### Pattern 4: Hook Configuration Format

**What:** The exact JSON structure for settings.json hooks, based on verified Claude Code documentation.

**Source:** https://code.claude.com/docs/en/hooks (HIGH confidence)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/notify-play.sh complete /home/user/.claude/notify-complete.mp3",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/notify-play.sh confirm /home/user/.claude/notify-confirm.mp3",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/notify-play.sh error /home/user/.claude/notify-error.mp3",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/notify-play.sh progress /home/user/.claude/notify-progress.mp3",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Anti-Patterns to Avoid

- **Accidental blocking:** Stop and SubagentStop hooks with non-zero exit codes prevent Claude from stopping. All notification hooks MUST exit 0.
- **Shell `&` instead of `async: true`:** The `async: true` field is the official mechanism. Using `&` in the command string works but is less explicit and harder to reason about.
- **Relative paths in hook commands:** Claude Code runs hooks in the current working directory, which varies. Always use absolute paths (D-10).
- **Hardcoded `$HOME`:** Use `$HOME` or `/home/$USER` in scripts, not a hardcoded username, for portability.
- **Lock file accumulation:** Lock files in `/tmp/` are cleaned on reboot, but should have a reasonable TTL (5s cooldown is sufficient).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON manipulation | Custom parsing with sed/awk | `jq` (v1.8.1) | jq handles nested JSON, string escaping, and structure preservation. sed/awk corrupt JSON (explicitly forbidden by D-09) |
| Background execution | Shell `&` with process management | Claude Code `async: true` | Native async hook support; no orphan process risk; officially documented |
| Audio playback | Custom audio player integration | `paplay` (PipeWire) | Standard Linux audio player; handles format detection, mixing, and device routing automatically |

**Key insight:** This phase has no complex logic to hand-roll. The main deliverables are configuration (JSON) and orchestration (shell scripts). All hard problems (audio playback, async execution, JSON manipulation) have standard tools.

## Common Pitfalls

### Pitfall 1: Stop Hook Blocks Claude from Stopping
**What goes wrong:** A notification hook on Stop or SubagentStop exits with non-zero code, causing Claude to never finish.
**Why it happens:** Claude Code interprets exit code 2 on Stop/SubagentStop as "block stoppage." Any non-zero exit code (except 0) triggers this.
**How to avoid:** Every hook command/script MUST `exit 0`. The cooldown wrapper must always exit 0 even when skipping playback.
**Warning signs:** Claude keeps running after finishing a task; infinite agent loops.

### Pitfall 2: jq Output Clobbers settings.json on Error
**What goes wrong:** If jq fails (syntax error, invalid JSON input), the `> tempfile && mv tempfile settings.json` pattern can leave an empty or partial file.
**Why it happens:** The `>` redirect creates the file before jq runs. If jq fails, the empty file gets moved.
**How to avoid:** Write to a temp file first, verify it's non-empty, then move:
```bash
jq '.hooks.Stop = ...' ~/.claude/settings.json > /tmp/claude-settings-tmp.json
if [ -s /tmp/claude-settings-tmp.json ]; then
    mv /tmp/claude-settings-tmp.json ~/.claude/settings.json
else
    rm -f /tmp/claude-settings-tmp.json
    echo "ERROR: jq failed, settings.json not modified" >&2
    exit 1
fi
```

### Pitfall 3: Hook Commands Not Found After Install
**What goes wrong:** The hook command references a script path that doesn't exist or isn't executable.
**Why it happens:** Using relative paths, or the install script doesn't set execute permissions on `notify-play.sh`.
**How to avoid:** install.sh must `chmod +x scripts/notify-play.sh`. All hook commands use absolute paths.
**Warning signs:** Hook shows in `/hooks` menu but doesn't produce audio; check with `claude --debug`.

### Pitfall 4: Duplicate Hooks on Repeated Install
**What goes wrong:** Running install.sh twice adds duplicate hook entries.
**Why it happens:** Using jq `+=` (append) instead of `=` (overwrite) for hook arrays.
**How to avoid:** Use `jq '.hooks.Stop = [...] '` (assignment) not `jq '.hooks.Stop += [...]'` (append). Since we're the only user of these 4 event types, overwrite is safe.

### Pitfall 5: Cooldown Lock Files in /tmp Not Cleaned
**What goes wrong:** Stale lock files accumulate in `/tmp/`.
**Why it happens:** Lock files are only used for timestamp comparison, never deleted.
**How to avoid:** This is benign -- `/tmp/` is cleaned on reboot. The cooldown check compares file age, so old files just get overridden. No explicit cleanup needed.

## Code Examples

### Event-to-Audio Mapping (verified from CONTEXT.md D-03)

| Claude Code Event | Audio File | Notification Meaning |
|-------------------|-----------|---------------------|
| `Stop` | `notify-complete.mp3` | Task completed |
| `Notification` | `notify-confirm.mp3` | Needs user attention |
| `StopFailure` | `notify-error.mp3` | API error occurred |
| `SubagentStop` | `notify-progress.mp3` | Subagent finished |

### Current settings.json Structure (verified from live file)

```json
{
  "env": { ... },
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "node ...gsd-check-update.js" }] }],
    "PostToolUse": [{ "matcher": "Bash|Edit|Write|MultiEdit|Agent|Task", "hooks": [{ "type": "command", "command": "node ...gsd-context-monitor.js", "timeout": 10 }] }],
    "PreToolUse": [{ "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "node ...gsd-prompt-guard.js", "timeout": 5 }] }]
  },
  "statusLine": { ... },
  "skipDangerousModePermissionPrompt": true
}
```

**Key observation:** Stop, Notification, StopFailure, and SubagentStop events are NOT currently present. install.sh adds them as new top-level keys under `hooks`.

### StopFailure Event Details (verified from official docs)

| Property | Value |
|----------|-------|
| Matcher support | Yes -- matches on `error` field (`rate_limit`, `authentication_failed`, `billing_error`, `invalid_request`, `server_error`, `max_output_tokens`, `unknown`) |
| Decision control | **None** -- output and exit code are ignored |
| Input fields | `error` (required), `error_details` (optional), `last_assistant_message` (optional) |
| Hook types supported | `command` and `http` only (no `prompt` or `agent`) |

**Impact on our hooks:** StopFailure is the safest event for audio -- no risk of blocking, no decision control needed. Notification is similarly safe.

### Stop Event Details (verified from official docs)

| Property | Value |
|----------|-------|
| Matcher support | No -- always fires |
| Decision control | Yes -- exit 2 or JSON `decision: "block"` prevents stopping |
| Input fields | `stop_hook_active` (bool), `last_assistant_message` (string) |
| Hook types supported | `command`, `http`, `prompt`, `agent` |

**Impact on our hooks:** Stop hooks MUST exit 0. The `async: true` flag mitigates risk since async hooks cannot block by design.

### async: true Behavior (verified from official docs)

- Available only on `type: "command"` hooks
- Claude starts the process and continues immediately
- Hook receives same JSON input via stdin as sync hooks
- After background process exits, output with `systemMessage` or `additionalContext` is delivered on next conversation turn
- Completion notifications suppressed by default (visible in verbose mode)
- Default timeout: same 10-minute max as sync hooks (we should set a shorter timeout)
- **Critical:** Async hooks cannot block or control Claude's behavior -- response fields like `decision` have no effect

**Recommendation:** Use `async: true` for all 4 notification hooks. Set `timeout: 10` (10 seconds) since audio files are under 15KB and play in under 1 second. This replaces the D-04 approach of `paplay ... &`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Shell `&` for background | `async: true` hook field | 2025 (Claude Code added async hooks) | Use native async instead of shell backgrounding |
| sed/awk for JSON | jq for JSON | Industry standard | D-09 mandates jq/Node.js |
| Sync hooks only | Sync + async hooks | 2025 | Async hooks prevent blocking without shell tricks |

**Recommended update to D-04:** Replace `paplay ... 2>/dev/null &` with `async: true` in the hook configuration. The `notify-play.sh` wrapper script calls `paplay` synchronously (no `&`), and the `async: true` flag handles background execution at the Claude Code level.

## Open Questions

1. **Should install.sh detect and warn if existing non-notify hooks exist on Stop/Notification/StopFailure/SubagentStop?**
   - What we know: Currently no hooks exist on these events (verified).
   - What's unclear: Whether future hooks might be added by other plugins.
   - Recommendation: For v1, use simple overwrite (`jq '.hooks.Stop = ...'`). The uninstall script removes the entire event key. Add a warning in install.sh if the event already has hooks from a different source (check command string for "notify-play").

2. **Should cooldown be per-type or global?**
   - What we know: D-05 says "同一音频 5 秒内不重复播放" which implies per-type.
   - What's unclear: Whether different audio types should also have a global cooldown.
   - Recommendation: Per-type cooldown (one lock file per notification type). Simpler and matches D-05.

3. **Should notify-play.sh be in the repo or in ~/.claude/?**
   - What we know: D-01 copies mp3 to ~/.claude/. D-10 uses absolute paths.
   - What's unclear: Where to deploy the wrapper script.
   - Recommendation: Keep notify-play.sh in the repo `scripts/` directory and reference by absolute path. This way updates to the cooldown logic don't require re-running install.sh.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| jq | settings.json manipulation (D-09) | Yes | 1.8.1 | Node.js (also available: v22.22.0) |
| paplay | Audio playback | Yes | 17.0 (PipeWire) | mpv or aplay |
| bash | Install/uninstall scripts | Yes | 5.x | -- |
| PipeWire/PulseAudio | Audio server for paplay | Yes | Running | -- |
| ~/.claude/settings.json | Hook configuration target | Yes | Has 3 existing hook events | -- |
| audio/notify-*.mp3 | Pre-generated audio files (Phase 2) | Yes | 4 files, ~10-15KB each | -- |

**Missing dependencies with no fallback:**
None.

**Missing dependencies with fallback:**
None.

## Sources

### Primary (HIGH confidence)
- Claude Code hooks reference (https://code.claude.com/docs/en/hooks) -- Full event schema, configuration format, async hooks, exit code behavior, JSON input/output. Read and verified 2026-03-30.
- Current `~/.claude/settings.json` -- Verified existing hook structure (SessionStart, PostToolUse, PreToolUse) and confirmed Stop/Notification/StopFailure/SubagentStop are absent.
- CONTEXT.md D-01 through D-10 -- User decisions locked for this phase.

### Secondary (MEDIUM confidence)
- WebSearch: "Claude Code hooks StopFailure event type 2026" -- Confirmed StopFailure is a valid event with specific input fields (error, error_details, last_assistant_message).
- System probe: paplay, jq, bash, PipeWire all available and versioned.

### Tertiary (LOW confidence)
- None needed -- all findings verified against primary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools verified on system, versions confirmed
- Architecture: HIGH - Claude Code hooks format verified against official docs
- Pitfalls: HIGH - Stop/SubagentStop blocking behavior documented in official docs

**Research date:** 2026-03-30
**Valid until:** 90 days (Claude Code hooks API is stable; no major changes expected)
