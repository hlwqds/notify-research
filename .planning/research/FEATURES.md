# Feature Research

**Project:** Claude Code Voice Notification System
**Milestone:** v1.1 Cross-Platform Compatibility
**Researched:** 2026-03-30
**Confidence:** HIGH (verified with official Claude Code hooks docs, Claude Code hooks guide, GitHub issue #26759)

## Scope

This research covers ONLY the new features needed for cross-platform support (macOS + Windows). All v1.0 features are already shipped and listed as validated in PROJECT.md.

**v1.0 shipped features (not repeated here):**
- Docker Spark-TTS environment with 4 pre-generated Chinese mp3 files
- install.sh / uninstall.sh / notify-play.sh (Linux-only)
- Claude Code hooks for 4 events (Stop, Notification, StopFailure, SubagentStop)
- Non-blocking playback (`async: true`) with 5-second cooldown debounce
- jq-based idempotent settings.json manipulation

---

## Table Stakes (Must Have)

Features users expect for cross-platform. Missing any of these = product broken on non-Linux platforms.

| # | Feature | Why Expected | Complexity | Platform Notes |
|---|---------|--------------|------------|----------------|
| T1 | **OS detection in install script** | Must detect which platform the script is running on to choose correct audio player and hook command format | LOW | `uname -s` returns `Darwin`/`Linux`/`MINGW*`/`MSYS*`/`CYGWIN*`. Works in bash on all platforms. |
| T2 | **macOS audio playback via afplay** | macOS has no `paplay`. `afplay` is built-in, supports MP3 natively, zero install required | LOW | `afplay /path/to/file.mp3` -- always available on macOS, no dependencies to install |
| T3 | **Windows audio playback via PowerShell** | Windows has no `paplay` or `afplay`. PowerShell is always available. | MEDIUM | Requires `System.Windows.Media.MediaPlayer` from PresentationCore assembly (supports MP3). `System.Windows.Forms.SoundPlayer` is WAV-only -- do NOT use. |
| T4 | **Platform-specific hook commands in settings.json** | Claude Code `shell: "powershell"` field enables Windows hooks alongside bash hooks in the same settings.json | MEDIUM | Linux/macOS hooks use default bash. Windows hooks use `shell: "powershell"`. Install script must detect OS and write correct format. |
| T5 | **Forward-slash paths in settings.json on Windows** | Claude Code bug (v2.1.47+): backslash paths in hook commands are consumed as escape characters | LOW | Must use `C:/Users/...` not `C:\Users\...` in settings.json. Install script must normalize paths. |
| T6 | **Cross-platform cooldown in notify-play.sh** | Current implementation uses `stat -c %Y` (Linux-only). macOS uses `stat -f %m`. | LOW | Need platform-aware stat command, or use a portable alternative (e.g., `date` with file modification check). |
| T7 | **Windows install script (install.ps1)** | PowerShell equivalent of install.sh for Windows users | MEDIUM | Must copy mp3 files, inject hooks into settings.json with `shell: "powershell"`, handle forward-slash paths. No `jq` available by default on Windows. |
| T8 | **Windows uninstall script (uninstall.ps1)** | PowerShell equivalent of uninstall.sh | LOW | Must remove hook entries and delete mp3 files. Same `jq` constraint as install.ps1. |
| T9 | **macOS support in install.sh** | install.sh currently requires `paplay` and hardcodes Linux paths. Must work on macOS too. | LOW | Change prerequisite check from `paplay` to platform-appropriate player (`afplay` on macOS, `paplay` on Linux). |

---

## Differentiators (Nice to Have)

Features that make cross-platform experience excellent but are not blockers.

| # | Feature | Value Proposition | Complexity | Notes |
|---|---------|-------------------|------------|-------|
| D1 | **Unified install.sh with OS auto-detection** | Single script works on Linux and macOS. Users clone repo, run `bash install.sh`, it just works. | LOW | Already natural with `uname -s` detection. Eliminates need for separate macOS install script. |
| D2 | **Audio player fallback chain** | If primary player fails, try alternatives before giving up | LOW | Linux: `paplay` -> `aplay` (ALSA). macOS: `afplay`. Windows: `MediaPlayer` via PowerShell. Fallback only within same platform. |
| D3 | **Hook verification after install** | After install, test that hooks are correctly configured and audio can play | LOW | Run a quick smoke test: trigger one hook event and verify audio plays. Catches misconfiguration. |
| D4 | **Single install.ps1 with pwsh.exe auto-detection** | PowerShell script works on both Windows PowerShell 5.1 and PowerShell 7 (pwsh) | MEDIUM | Claude Code `shell: "powershell"` field auto-detects `pwsh.exe` with fallback to `powershell.exe`. Install script should match this detection. |

---

## Anti-Features (Explicitly NOT Build)

| # | Anti-Feature | Why Avoid | What to Do Instead |
|---|--------------|-----------|-------------------|
| A1 | **Converting mp3 to wav for Windows** | `System.Windows.Media.MediaPlayer` supports MP3 natively. No conversion needed. | Use MP3 as-is on all platforms (already the format in repo) |
| A2 | **Runtime OS detection inside hook commands** | Hook commands run on every event trigger. OS detection overhead is unnecessary when install-time detection is sufficient. | Detect OS once during install, write platform-correct hook commands to settings.json |
| A3 | **Third-party audio tools (fmedia, NirCmd, SoX)** | Adds dependencies. Users must install extra software. Defeats the "zero install" goal. | Use built-in tools only: `afplay` (macOS), `MediaPlayer` (Windows), `paplay` (Linux) |
| A4 | **WAV format distribution** | Larger file sizes. No quality benefit for 2-3 second notification clips. MP3 is universally supported on all three platforms. | Keep MP3 as distribution format |
| A5 | **Separate macOS install script** | Unnecessary when `install.sh` can auto-detect with `uname -s` | Extend install.sh with OS detection (D1) |
| A6 | **Windows batch script (.bat) installer** | CMD.exe lacks JSON manipulation capabilities needed for settings.json | Use PowerShell (.ps1) which has `ConvertFrom-Json` / `ConvertTo-Json` built-in |
| A7 | **Cygwin/MSYS2 bash script on Windows** | Claude Code runs hooks via `shell: "powershell"` on Windows, not bash. Bash scripts on Windows add a layer of complexity for no benefit. | Native PowerShell scripts for Windows. Bash for Linux/macOS. |
| A8 | **Audio volume control in notification system** | System volume controls work on all platforms. Per-notification volume is YAGNI. | Users adjust system volume |

---

## Feature Dependencies

```
T1 (OS Detection)
    └── required by ──> T4 (Platform-specific hook commands)
    └── required by ──> T6 (Cross-platform cooldown)
    └── required by ──> T9 (macOS install.sh support)

T2 (macOS afplay)
    └── required by ──> T4 (macOS hook commands use afplay)

T3 (Windows MediaPlayer)
    └── required by ──> T4 (Windows hook commands use MediaPlayer)
    └── required by ──> T7 (install.ps1 generates MediaPlayer commands)

T5 (Forward-slash paths)
    └── required by ──> T4 (Windows hook commands must use forward slashes)
    └── required by ──> T7 (install.ps1 must normalize paths)

T6 (Cross-platform cooldown)
    └── extends ──> existing notify-play.sh (refactor, not rewrite)

T7 (install.ps1)
    └── depends on ──> T3 (needs MediaPlayer command format)
    └── depends on ──> T5 (needs forward-slash path normalization)
    └── produces ──> T4 (writes Windows hook commands)

T8 (uninstall.ps1)
    └── depends on ──> T5 (needs forward-slash path normalization)
```

### Dependency Notes

- **T1 (OS detection) is the root dependency.** Everything else branches from knowing which platform we are on. Implement first.
- **T2 and T3 are independent.** macOS playback and Windows playback can be implemented in parallel.
- **T4 (platform-specific hook commands) is the integration point.** It combines T1, T2, T3, and T5 into the actual settings.json entries.
- **T7 (install.ps1) and T9 (macOS install.sh support) are independent delivery vehicles** for T4. They can be implemented in parallel.
- **T6 (cross-platform cooldown) is a standalone refactor** of existing notify-play.sh. No dependency on hook command format.

---

## Platform-Specific Technical Details

### macOS Audio Playback

| Aspect | Detail |
|--------|--------|
| **Player** | `afplay` (built-in, always available) |
| **Command** | `afplay /path/to/file.mp3` |
| **Format support** | MP3, WAV, AAC, M4A, AIFF, CAF |
| **Install required?** | No -- ships with macOS |
| **Exit code** | 0 on success, non-zero on failure |
| **Blocking?** | Yes -- blocks until playback finishes. Use `&` for non-blocking in bash. |
| **In hooks** | `afplay ~/.claude/notify-complete.mp3 &` (bash hook, no `shell` field needed) |

### Windows Audio Playback

| Aspect | Detail |
|--------|--------|
| **Player** | `System.Windows.Media.MediaPlayer` (PresentationCore assembly) |
| **Command** | `powershell.exe -Command "Add-Type -AssemblyName PresentationCore; \$player = New-Object System.Windows.Media.MediaPlayer; \$player.Open('C:/Users/name/.claude/notify-complete.mp3'); \$player.Play()"` |
| **Format support** | MP3, WAV, WMA, ASF |
| **Install required?** | No -- .NET Framework / .NET Runtime includes PresentationCore |
| **Exit code** | PowerShell command exits immediately (MediaPlayer plays asynchronously). Hook does NOT block. |
| **In hooks** | Use `shell: "powershell"` field. Command must use forward slashes for paths. |
| **Key gotcha** | First invocation loads PresentationCore assembly (~50-100ms). Subsequent invocations reuse loaded assembly if same PowerShell session, but Claude Code spawns a new process per hook event. Acceptable latency. |
| **Alternative (DO NOT USE)** | `System.Windows.Forms.SoundPlayer` -- WAV only, cannot play MP3 |

### Linux Audio Playback (existing, unchanged)

| Aspect | Detail |
|--------|--------|
| **Player** | `paplay` (PipeWire/PulseAudio) |
| **Command** | `/usr/bin/paplay /path/to/file.mp3 2>/dev/null` |
| **Format support** | MP3 (via GStreamer), WAV, OGG, FLAC |
| **Install required?** | Yes -- `pipewire-pulse` or `pulseaudio-utils` package |
| **In hooks** | Default bash hook, no `shell` field needed |

---

## Claude Code Hooks Platform Architecture

### settings.json Structure (Cross-Platform)

The same `~/.claude/settings.json` can contain hooks for multiple platforms using the `shell` field:

```jsonc
// On Linux/macOS: hooks use default shell (bash)
// On Windows: hooks use shell: "powershell"

{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            // Linux/macOS: no shell field needed, uses bash
            "command": "/path/to/notify-play.sh complete ~/.claude/notify-complete.mp3",
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
            "shell": "powershell",
            "command": "powershell.exe -Command \"Add-Type -AssemblyName PresentationCore; $p = New-Object System.Windows.Media.MediaPlayer; $p.Open('C:/Users/name/.claude/notify-error.mp3'); $p.Play()\"",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Key insight:** Claude Code processes ALL hook entries regardless of platform. If a Linux-only `paplay` hook is in settings.json on Windows, it will fail silently (or produce errors). The install script must write ONLY platform-appropriate hooks, not all-of-the-above.

**Confidence:** HIGH -- verified from official Claude Code hooks docs and hooks guide.

### The Install Script Must Be Platform-Selective

```
install.sh on Linux:
    └── Writes hooks WITHOUT shell field (bash default)
    └── Uses paplay for playback
    └── Prerequisite check: jq, paplay

install.sh on macOS:
    └── Writes hooks WITHOUT shell field (bash default)
    └── Uses afplay for playback
    └── Prerequisite check: jq (afplay always available)

install.ps1 on Windows:
    └── Writes hooks WITH shell: "powershell"
    └── Uses MediaPlayer for playback
    └── Prerequisite check: none (PowerShell JSON cmdlets built-in)
    └── Normalizes paths to forward slashes
```

---

## Complexity Assessment by Feature

### LOW Complexity (1-2 hours each)

| Feature | Effort | Risk |
|---------|--------|------|
| T1: OS detection | `<1 hour` | None -- `uname -s` is universally reliable |
| T2: macOS afplay | `<1 hour` | None -- simple command substitution |
| T5: Forward-slash paths | `<1 hour` | Low -- `sed` or parameter expansion to replace backslashes |
| T6: Cross-platform cooldown | `<1-2 hours` | Low -- conditional `stat` flag selection |
| T8: uninstall.ps1 | `<1 hour` | Low -- simpler than install, just deletion |
| T9: macOS install.sh | `<1 hour` | Low -- change prerequisite check and playback command |

### MEDIUM Complexity (2-4 hours each)

| Feature | Effort | Risk |
|---------|--------|------|
| T3: Windows MediaPlayer | `2-3 hours` | Medium -- PowerShell command string escaping is tricky. Must test on actual Windows. PresentationCore assembly loading time needs measurement. |
| T4: Platform-specific hook commands | `2-3 hours` | Medium -- integration point combining multiple concerns. Path construction, command formatting, and settings.json injection all must be correct per platform. |
| T7: install.ps1 | `3-4 hours` | Medium -- JSON manipulation in PowerShell without `jq`. Must handle settings.json that may not have `hooks` key yet. Forward-slash path normalization. PresentationCore command construction. |

### Total Estimated Effort

| Category | Features | Estimated Hours |
|----------|----------|-----------------|
| LOW | T1, T2, T5, T6, T8, T9 | 6-8 hours |
| MEDIUM | T3, T4, T7 | 7-10 hours |
| **Total** | **9 features** | **13-18 hours** |

---

## MVP Recommendation for v1.1

### Phase 1: Core Cross-Platform (T1, T6, T2, T9)

Extend the existing bash scripts to work on macOS. This is the lowest-risk path because macOS shares bash with Linux.

1. **T1**: Add OS detection to install.sh (`uname -s`)
2. **T6**: Make notify-play.sh cooldown work on macOS (conditional `stat` flag)
3. **T2**: Add afplay as playback option in notify-play.sh
4. **T9**: Update install.sh prerequisite check (afplay on macOS, paplay on Linux)

**Deliverable:** Single `install.sh` that works on both Linux and macOS.

### Phase 2: Windows Support (T3, T5, T4, T7, T8)

Build the Windows story from scratch since it requires a different scripting language.

1. **T5**: Establish forward-slash path normalization pattern
2. **T3**: Validate MediaPlayer approach on Windows (test presentation)
3. **T4**: Define Windows hook command format
4. **T7**: Build install.ps1 (copies mp3, writes hooks with `shell: "powershell"`)
5. **T8**: Build uninstall.ps1 (removes hooks, deletes mp3)

**Deliverable:** `install.ps1` + `uninstall.ps1` for Windows.

### Defer

- D2 (audio player fallback chain) -- single built-in player per platform is sufficient for v1.1
- D3 (hook verification) -- nice polish, not blocking
- D4 (pwsh.exe auto-detection in install.ps1) -- Claude Code handles this automatically via `shell: "powershell"`

---

## Sources

### Primary (HIGH confidence)
- Claude Code official hooks reference (https://code.claude.com/docs/en/hooks) -- verified 2026-03-30. Confirms `shell: "powershell"` field, `async: true`, `timeout` field, hook event types.
- Claude Code official hooks guide (https://code.claude.com/docs/en/hooks-guide) -- verified 2026-03-30. Shows cross-platform notification patterns (macOS osascript, Linux notify-send, Windows PowerShell MessageBox).
- GitHub Issue #26759 (anthropics/claude-code) -- verified 2026-03-30. Confirms Windows backslash path bug since v2.1.47. Workaround: use forward slashes.
- Existing codebase: `scripts/install.sh`, `scripts/uninstall.sh`, `scripts/notify-play.sh` -- read and analyzed for current implementation details.
- PROJECT.md -- v1.1 milestone requirements, validated v1.0 features, constraints.

### Secondary (MEDIUM confidence)
- macOS `afplay` man page (available on any macOS system) -- confirms MP3 support, blocking behavior, exit codes.
- `System.Windows.Media.MediaPlayer` .NET documentation -- confirms MP3 support via PresentationCore assembly. Not verified on actual Windows during this research session.
- PowerShell `ConvertFrom-Json` / `ConvertTo-Json` documentation -- standard PowerShell cmdlets available in PowerShell 5.1+.

### Verified Through Code Analysis
- `stat -c %Y` in notify-play.sh line 18 -- confirmed Linux-specific, needs macOS equivalent (`stat -f %m`)
- `paplay` hardcoded path in notify-play.sh line 26 -- needs to become platform-conditional
- Prerequisite check for `paplay` in install.sh line 30 -- needs to also accept `afplay` on macOS
- Hook command construction in install.sh lines 73-81 -- currently generates bash-only commands, needs platform branching

---
*Feature research for: Claude Code voice notification system v1.1 cross-platform*
*Researched: 2026-03-30*
