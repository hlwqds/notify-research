# Phase 4: macOS 兼容 - Research

**Researched:** 2026-03-30
**Domain:** Cross-platform bash script portability (Linux -> macOS) for audio notification system
**Confidence:** HIGH

## Summary

Phase 4 extends existing bash scripts to work on macOS. The changes are small and confined to three scripts: `notify-play.sh` (stat + player fix), `install.sh` (prerequisite check + version check portability), and `uninstall.sh` (may need no changes). macOS and Linux share the same bash tooling; the differences are in specific command flags (GNU vs BSD).

The critical bug is `stat -c %Y` in `notify-play.sh` line 18 -- GNU-only syntax that crashes on macOS BSD `stat`. The fix is a `uname -s` branch switching to `stat -f %m`. A secondary discovery: `install.sh` uses `grep -oP` (line 17) and `sort -V` (line 20), both GNU-only and both will fail on macOS. These are in the optional version check block and need portable replacements.

**Primary recommendation:** Three targeted edits to existing scripts using `uname -s` OS detection -- no new scripts, no new dependencies, no architectural changes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** install.sh prerequisite 检查按平台分别进行 -- Linux 检查 paplay，macOS 不检查（afplay 内置）
- **D-02:** jq 仍然两个平台都需要检查（JSON 操控依赖不变）
- **D-03:** Claude Code 版本检查保持不变（macOS 也有 `claude` CLI）
- **D-04:** notify-play.sh 使用 `uname -s` 分支 -- Linux 用 `stat -c %Y`，macOS 用 `stat -f %m`
- **D-05:** 不使用 date 命令替代方案（date 命令跨平台差异更大）
- **D-06:** notify-play.sh 内部 OS 检测自动选择播放器 -- macOS 用 `afplay`，Linux 用 `/usr/bin/paplay`
- **D-07:** 不使用环境变量覆盖机制（保持简单，v1 不需要）
- **D-08:** hook 命令格式保持不变 -- macOS 和 Linux 路径格式完全相同
- **D-09:** 音频文件路径用 `$HOME/.claude/notify-*.mp3`，不需要平台适配

### Claude's Discretion
- OS 检测的具体实现方式（`uname -s` vs `uname` vs 其他）留给 planner
- 是否在 uninstall.sh 中添加 OS 特定逻辑（当前脚本无平台依赖，可能不需要）

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAC-01 | notify-play.sh 在 macOS 上使用 `afplay` 播放音频 | D-06 + ARCHITECTURE.md: `uname -s == "Darwin"` branch, `/usr/bin/afplay` at fixed path on all macOS versions. HIGH confidence. |
| MAC-02 | notify-play.sh 的 `stat` 调用兼容 BSD (macOS) | D-04 + PITFALLS.md Pitfall 3: `stat -c %Y` (GNU) -> `stat -f %m` (BSD). HIGH confidence -- well-documented incompatibility. |
| INST-01 | install.sh 支持 macOS（`uname -s` 检测，复制到 macOS 路径） | D-01 + new findings: `grep -oP` and `sort -V` also need fixing. See Additional Findings section. HIGH confidence. |
| INST-02 | uninstall.sh 支持 macOS | uninstall.sh has no platform-specific code (no stat, no grep -P, no sort -V, no paplay check). Likely no changes needed. HIGH confidence. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `bash` | 3.2+ (macOS) / 5.x (Linux) | Script runtime | Already used (`#!/usr/bin/env bash`). macOS bash 3.2 supports `set -euo pipefail`. |
| `afplay` | System (all macOS) | Audio playback on macOS | Built-in Apple utility, fixed path `/usr/bin/afplay`, supports MP3. No install needed. |
| `jq` | 1.6+ | JSON manipulation | Already required. Install via `brew install jq` on macOS. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `uname` | System | OS detection | `uname -s` returns "Darwin" on macOS, "Linux" on Linux. Standard POSIX command. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `uname -s` for OS detection | `command -v afplay` existence check | `uname` is instant and unambiguous; existence check is unnecessary since we know platform at install time |
| `stat -f %m` on macOS | `date +%s -r file` | D-05 explicitly rejects date-based alternative. `stat` approach is simpler. |
| `stat -f %m` on macOS | `perl -e 'print (stat($f))[9]'` | Unnecessarily complex for a stat replacement |

**Installation (macOS):**
```bash
brew install jq
# afplay: already installed
```

**Version verification:** Not applicable -- `afplay` and `uname` are system tools with no package manager.

## Architecture Patterns

### Recommended Project Structure

No structural changes. Phase 4 only modifies existing scripts.

```
scripts/
├── install.sh           # MODIFY: OS-detect prerequisite checks + fix grep/sort portability
├── uninstall.sh         # LIKELY NO CHANGE: no platform-specific code
└── notify-play.sh       # MODIFY: OS-detect stat + player command
```

### Pattern 1: OS Detection via `uname -s`

**What:** Single `uname -s` check at script top, cached in a variable, used for all platform branches.

**When to use:** Any script that needs Linux vs macOS behavior differences.

**Example:**
```bash
# Source: upstream STACK.md, ARCHITECTURE.md (HIGH confidence)
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
    # macOS-specific code
else
    # Linux-specific code
fi
```

**Claude's Discretion resolution:** Use `uname -s` (not bare `uname` which may return just the kernel name on some systems). Compare against `"Darwin"` for macOS. This is the standard, unambiguous approach.

### Pattern 2: Portable stat for Cooldown Timestamp

**What:** OS-specific stat invocation to get file modification time in epoch seconds.

**When to use:** `notify-play.sh` line 18 cooldown check.

**Example:**
```bash
# Source: D-04, PITFALLS.md Pitfall 3 (HIGH confidence)
if [[ "$(uname -s)" == "Darwin" ]]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
else
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
fi
```

### Pattern 3: Portable Version Extraction (for install.sh)

**What:** Replace `grep -oP` with a portable alternative for extracting version numbers.

**When to use:** `install.sh` line 17 Claude Code version check.

**Example:**
```bash
# Option A: sed + grep (both support basic regex on BSD and GNU)
CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)

# Option B: bash parameter expansion (pure bash, no external commands)
VERSION_OUTPUT=$(claude --version 2>/dev/null | head -1)
CLAUDE_VERSION=$(echo "$VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
```

Note: `grep -oE` (extended regex) works on both GNU and BSD grep. Only `-P` (Perl regex) is BSD-incompatible.

### Pattern 4: Portable Version Comparison (for install.sh)

**What:** Replace `sort -V` with a portable version comparison for Claude Code >= 2.1.78 check.

**When to use:** `install.sh` line 20.

**Example:**
```bash
# Option A: Pure bash function (works on bash 3.2+)
version_gte() {
    # Returns 0 if $1 >= $2
    [ "$1" = "$2" ] && return 0
    local IFS=.
    local i a=($1) b=($2)
    for ((i=0; i<${#b[@]}; i++)); do
        ((10#${a[i]:-0} < 10#${b[i]})) && return 1
        ((10#${a[i]:-0} > 10#${b[i]})) && return 0
    done
    return 0
}

if version_gte "$CLAUDE_VERSION" "$MIN_VERSION"; then
    echo "Version OK"
else
    echo "WARNING: version too old"
fi

# Option B: Skip version check entirely on macOS (afplay always works)
# The version check only matters for StopFailure hook event support.
# If Claude Code is installed, it's almost certainly >= 2.1.78.
```

### Anti-Patterns to Avoid

- **`grep -oP` (Perl regex):** BSD grep on macOS does not support `-P`. Use `grep -oE` (extended regex) instead.
- **`sort -V` (version sort):** BSD sort on macOS does not support `-V`. Use a pure bash comparison function or skip the version check.
- **`date -r` for stat replacement:** While `date -r file +%s` works on both platforms, D-05 explicitly rejects this approach. Use `stat` with OS detection.
- **Installing GNU coreutils for stat/sort/grep:** Adding Homebrew coreutils dependency defeats the purpose of "works out of the box." Use native commands with OS branches.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio playback on macOS | Custom CoreAudio/audioqueue invocation | `/usr/bin/afplay` | Built-in, reliable, supports MP3, synchronous by default |
| OS detection | Parsing `/etc/os-release` or other heuristics | `uname -s == "Darwin"` | Standard POSIX, instant, unambiguous |

**Key insight:** macOS `afplay` is the simplest audio playback tool available. One command, no arguments needed for default volume, synchronous (but async hooks handle that). There is no reason to build anything custom.

## Common Pitfalls

### Pitfall 1: `stat -c %Y` crashes on macOS (Cooldown Lock Breaks)

**What goes wrong:** `notify-play.sh` line 18 uses `stat -c %Y "$LOCK_FILE"` which is GNU-only. On macOS BSD stat, this produces "stat: illegal option -- c" and crashes under `set -euo pipefail`.

**Why it happens:** `stat` is not POSIX-standardized. GNU coreutils use `-c` with `%Y` for mtime epoch. BSD uses `-f` with `%m`.

**How to avoid:** Use `uname -s` branch (D-04). Linux: `stat -c %Y`, macOS: `stat -f %m`.

**Warning signs:** Script crashes silently on macOS. No lock files created. No notifications play.

**Confidence:** HIGH -- well-documented, verified in upstream PITFALLS.md.

### Pitfall 2: `grep -oP` fails on macOS (Version Extraction Breaks)

**What goes wrong:** `install.sh` line 17 uses `grep -oP '\d+\.\d+\.\d+'` to extract Claude Code version. macOS BSD grep does not support `-P` (Perl-compatible regex). Produces "grep: illegal option -- P" error.

**Why it happens:** BSD grep (macOS default) does not include PCRE support. The `-P` flag is GNU grep only.

**How to avoid:** Replace with `grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` (extended regex works on both GNU and BSD grep).

**Warning signs:** install.sh fails on macOS during version check. Error visible in terminal output.

**Confidence:** HIGH -- standard BSD vs GNU difference.

### Pitfall 3: `sort -V` fails on macOS (Version Comparison Breaks)

**What goes wrong:** `install.sh` line 20 uses `sort -V` for version sort. macOS BSD sort does not support `-V` flag.

**Why it happens:** `-V` (version sort) is a GNU coreutils extension. BSD sort has no equivalent.

**How to avoid:** Replace with a pure bash version comparison function (see Pattern 4), or wrap the entire version check in an OS-conditional block that skips on macOS since the version requirement is informational only (WARNING, not ERROR).

**Warning signs:** install.sh fails on macOS during version check.

**Confidence:** HIGH -- standard BSD vs GNU difference.

### Pitfall 4: `afplay` concurrent playback can break system audio

**What goes wrong:** If cooldown mechanism fails and multiple `afplay` instances launch simultaneously, Apple's AudioQueue API can produce errors requiring `coreaudiod` restart.

**Why it happens:** `afplay` uses AudioQueue which has undocumented behavior under concurrent access.

**How to avoid:** Ensure cooldown mechanism is rock-solid on macOS (fix Pitfall 1 first). Optionally add `pgrep -x afplay` guard before launching.

**Warning signs:** `AudioQueueStart` errors in console. ALL system audio stops working.

**Confidence:** MEDIUM -- documented in upstream PITFALLS.md Pitfall 6.

### Pitfall 5: `/tmp` lock files on macOS sandboxed environments

**What goes wrong:** `$TMPDIR` on macOS points to a per-user sandboxed path like `/var/folders/jd/.../T/`, not `/tmp`. Hardcoded `/tmp` works via symlink but may break in restricted environments.

**Why it happens:** macOS uses per-user temp directories for security sandboxing. `/tmp` is symlinked to `/private/tmp`.

**How to avoid:** Consider using `${TMPDIR:-/tmp}` instead of hardcoded `/tmp` for lock files. However, `/tmp` still works on macOS via symlink, so this is LOW priority.

**Warning signs:** Permission denied errors creating lock files.

**Confidence:** MEDIUM -- documented in upstream PITFALLS.md Pitfall 4.

## Additional Findings (Beyond Upstream Research)

### Discovery 1: `install.sh` Has Three Portability Issues (Not Just One)

The upstream research and CONTEXT.md identify the prerequisite check (paplay vs afplay) as the main install.sh change. Code inspection reveals two additional GNU-only commands in the version check block:

| Line | Command | Issue | Fix |
|------|---------|-------|-----|
| 17 | `grep -oP '\d+\.\d+\.\d+'` | BSD grep has no `-P` flag | Use `grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` |
| 20 | `sort -V` | BSD sort has no `-V` flag | Pure bash comparison or OS-conditional skip |
| 30 | `paplay` prerequisite check | macOS doesn't have paplay | OS-conditional: check `afplay` on Darwin |

**Impact on planning:** The version check block (lines 16-28) needs a portable rewrite. The simplest approach: since the version check only produces a WARNING (not an ERROR), and the `claude` command exists on macOS, wrap the entire version comparison in a function that degrades gracefully.

### Discovery 2: `uninstall.sh` Likely Needs No Changes

Code inspection confirms `uninstall.sh` has no platform-specific code:
- No `stat` calls
- No `grep -P` or `sort -V`
- No `paplay`/`afplay` references
- Uses only `jq` and `rm` (both portable)
- All paths use `$HOME/.claude/` (works on both platforms)

**Recommendation:** Verify in plan, but likely no changes needed for INST-02.

## Code Examples

### notify-play.sh: Complete Fix (D-04 + D-06)

```bash
#!/usr/bin/env bash
# notify-play.sh -- Plays notification audio with 5-second cooldown per type.
set -euo pipefail

TYPE="$1"
AUDIO_FILE="$2"
LOCK_FILE="/tmp/claude-notify-${TYPE}.lock"
COOLDOWN_SEC=5

OS="$(uname -s)"

# Check cooldown: if lock file exists and is younger than COOLDOWN_SEC, skip
if [ -f "$LOCK_FILE" ]; then
    if [[ "$OS" == "Darwin" ]]; then
        LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
    else
        LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
    fi
    if [ "$LOCK_AGE" -lt "$COOLDOWN_SEC" ]; then
        exit 0  # Within cooldown window, skip playback
    fi
fi

# Update lock timestamp and play audio
touch "$LOCK_FILE"

if [[ "$OS" == "Darwin" ]]; then
    /usr/bin/afplay "$AUDIO_FILE" 2>/dev/null || true
else
    /usr/bin/paplay "$AUDIO_FILE" 2>/dev/null || true
fi
exit 0
```

### install.sh: Portable Version Check

```bash
# Portable version extraction (grep -oE works on both GNU and BSD)
CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -n "$CLAUDE_VERSION" ]; then
    MIN_VERSION="2.1.78"
    # Portable version comparison (pure bash, no sort -V)
    if ! version_gte "$CLAUDE_VERSION" "$MIN_VERSION"; then
        echo "WARNING: Claude Code $CLAUDE_VERSION detected, requires >= $MIN_VERSION (StopFailure hook event)." >&2
        echo "  StopFailure notification will not work. Other hooks (Stop, Notification, SubagentStop) are unaffected." >&2
    fi
fi
```

### install.sh: Platform-Specific Prerequisite Check

```bash
# jq is required on all platforms
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq not found. Please install jq first." >&2
    exit 1
fi

# Platform-specific audio player check (D-01)
if [[ "$(uname -s)" == "Darwin" ]]; then
    # afplay is built into macOS -- just verify it exists
    if ! command -v afplay &>/dev/null; then
        echo "ERROR: afplay not found (unexpected on macOS)." >&2
        exit 1
    fi
else
    if ! command -v paplay &>/dev/null; then
        echo "ERROR: paplay not found. Please install paplay first." >&2
        exit 1
    fi
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `stat -c %Y` | `uname -s` branch: `stat -f %m` (BSD) / `stat -c %Y` (GNU) | This phase | Required for macOS support |
| `grep -oP` | `grep -oE` (extended regex) | This phase | Required for macOS support |
| `sort -V` | Pure bash version comparison | This phase | Required for macOS support |
| Hardcoded `paplay` | OS-conditional: `afplay` (Darwin) / `paplay` (Linux) | This phase | Required for macOS support |

**Deprecated/outdated:**
- None in this phase -- all changes are additive compatibility fixes.

## Open Questions

1. **Should `uninstall.sh` be modified for INST-02?**
   - What we know: Code inspection shows no platform-specific code in uninstall.sh.
   - What's unclear: Whether the "supports macOS" requirement means "tested on macOS" or "has macOS-specific code."
   - Recommendation: No code changes needed. INST-02 is satisfied by verifying the script works (which it should, since it uses only portable commands).

2. **Should the version check be skipped entirely on macOS?**
   - What we know: The version check only produces a WARNING. It's informational.
   - What's unclear: Whether Claude Code on macOS might be an older version that genuinely lacks StopFailure support.
   - Recommendation: Keep the check but make it portable. The WARNING is valuable user information.

3. **Should we use `pgrep -x afplay` guard for concurrent playback?**
   - What we know: afplay concurrency can break system audio (Pitfall 4).
   - What's unclear: How likely this is with the 5-second cooldown already in place.
   - Recommendation: OPTIONAL. Add it if time permits, but the cooldown should be sufficient. Flag as defensive enhancement, not blocker.

## Environment Availability

> Step 2.6: SKIPPED (no external dependencies identified beyond system tools that differ by platform)

This phase modifies existing bash scripts. No new tools or services need to be available on the development machine. The changes are code-only and can be verified by code review (checking GNU vs BSD compatibility).

## Validation Architecture

> Skipped per config: `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

## Sources

### Primary (HIGH confidence)
- `.planning/research/STACK.md` -- afplay details, GNU vs BSD stat differences, macOS-specific notes (internal research, verified 2026-03-30)
- `.planning/research/PITFALLS.md` -- Pitfall 3 (stat incompatibility), Pitfall 6 (afplay concurrency), Pitfall 4 (TMPDIR) (internal research, verified 2026-03-30)
- `.planning/research/ARCHITECTURE.md` -- OS detection pattern, macOS data flow, player selection pattern (internal research, verified 2026-03-30)
- `.planning/phases/04-macos/04-CONTEXT.md` -- Locked decisions D-01 through D-09 (user decisions, 2026-03-30)
- [ss64.com/mac/afplay](https://ss64.com/mac/afplay.html) -- afplay CLI reference: MP3 support, blocking behavior, volume flag (verified 2026-03-30)
- [Stack Overflow: grep -P not supported on macOS](https://stackoverflow.com/questions/16658333/grep-p-no-longer-works-how-can-i-rewrite-my-searches) -- confirms BSD grep lacks `-P`, recommends `-E` alternative (verified 2026-03-30)

### Secondary (MEDIUM confidence)
- [Stack Overflow: stat differences macOS vs Linux](https://stackoverflow.com/questions/10666570/binutils-stat-illegal-option-c) -- GNU vs BSD stat flag incompatibility (verified via upstream research)
- [GitHub Gist: POSIX shell version comparison](https://gist.github.com/akutz/4bf84cce21dfb49dd55ca19014e2668f) -- portable version comparison function (verified 2026-03-30)
- [Scripting OS X: bash zsh sh in macOS Catalina](https://scriptingosx.com/2020/06/about-bash-zsh-sh-and-dash-in-macos-catalina-and-beyond/) -- macOS bash 3.2 capabilities, pipefail support (verified 2026-03-30)

### Tertiary (LOW confidence)
- None -- all findings verified against primary sources or direct code inspection.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- afplay is built-in macOS, uname is POSIX, jq is same tool everywhere
- Architecture: HIGH -- upstream research is thorough, only 3 targeted edits needed
- Pitfalls: HIGH -- stat/grep/sort incompatibilities are well-documented, standard Unix knowledge

**Research date:** 2026-03-30
**Valid until:** Stable -- bash, stat, grep, sort behavior on macOS won't change. afplay is a stable Apple tool. 90 days.
