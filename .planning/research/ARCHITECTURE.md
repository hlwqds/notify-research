# Architecture Research: Cross-Platform Audio Notification Support (v1.1)

**Domain:** Cross-platform integration for existing Claude Code audio notification system
**Researched:** 2026-03-30
**Confidence:** HIGH

## Executive Summary

This research covers how to extend the v1.0 Linux-only notification system to macOS and Windows. The key architectural discovery is that Claude Code provides a first-class `"shell": "powershell"` field on command hooks, which eliminates the need for bash-to-PowerShell translation at the hook level. The architecture should NOT change the Docker TTS generation pipeline or the pre-generated MP3 files -- those are platform-agnostic already. The changes are confined to three layers: (1) the playback command selection per OS, (2) the install/uninstall scripts, and (3) the cooldown wrapper.

## Critical Discovery: Claude Code `"shell": "powershell"` Field

**HIGH confidence** -- verified from official Claude Code hooks reference at code.claude.com/docs/en/hooks.

Claude Code hooks support a `"shell"` field on command hooks that accepts `"bash"` (default) or `"powershell"`. When set to `"powershell"`, Claude Code spawns PowerShell directly (auto-detects `pwsh.exe` for PowerShell 7+ with fallback to `powershell.exe` 5.1). This is independent of the `CLAUDE_CODE_USE_POWERSHELL_TOOL` setting.

This means:
- On Windows, hooks can run native PowerShell commands without any bash translation layer
- The same `settings.json` structure works on all platforms -- only the `command` and `shell` fields differ
- No need for a Windows-compatible bash layer (Git Bash, WSL, etc.)

**Schema:**
```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "shell": "powershell",
        "command": "powershell-command-here",
        "async": true,
        "timeout": 10
      }]
    }]
  }
}
```

## Architecture Overview: What Changes vs What Stays

### Unchanged Components (Platform-Agnostic)

| Component | Why Unchanged |
|-----------|---------------|
| `audio/notify-*.mp3` | MP3 files are platform-independent. Already committed to repo. |
| `Dockerfile` + `generate.sh` | Docker TTS generation only runs on Linux (for audio creation). Output is MP3. |
| `settings.json` hook structure | Same 4 events: Stop, Notification, StopFailure, SubagentStop. Same `async: true`. |
| Hook event mapping | Stop->complete, Notification->confirm, StopFailure->error, SubagentStop->progress. |
| `~/.claude/` as install target | Claude Code uses `~/.claude/` on all platforms for settings and user data. |

### Components That Need Platform Variants

| Component | Linux | macOS | Windows |
|-----------|-------|-------|---------|
| **Audio playback command** | `/usr/bin/paplay` | `/usr/bin/afplay` | PowerShell `MediaPlayer` |
| **Cooldown wrapper** | `scripts/notify-play.sh` (bash) | `scripts/notify-play.sh` (bash, reuse) | `scripts/notify-play.ps1` (PowerShell) |
| **Install script** | `scripts/install.sh` (bash) | `scripts/install.sh` (bash, reuse) | `scripts/install.ps1` (PowerShell) |
| **Uninstall script** | `scripts/uninstall.sh` (bash) | `scripts/uninstall.sh` (bash, reuse) | `scripts/uninstall.ps1` (PowerShell) |
| **Hook `shell` field** | Omitted (default `bash`) | Omitted (default `bash`) | `"shell": "powershell"` |

### Key Insight: macOS Shares Linux Scripts

macOS ships with bash (or zsh with bash compatibility) and `/usr/bin/afplay`. The only difference from Linux is the playback command (`afplay` instead of `paplay`). This means `install.sh`, `uninstall.sh`, and `notify-play.sh` work on macOS with a single change: detect the OS and select the correct player.

Windows requires completely separate scripts in PowerShell.

## Recommended Architecture

```
+------------------------------------------------------------------+
|                    Platform Detection Layer                       |
|                                                                  |
|  install.sh (Linux/macOS)       install.ps1 (Windows)            |
|  - detect OS via uname           - native PowerShell              |
|  - select: paplay or afplay      - select: Windows.Media.MediaPlayer |
|  - inject hooks with jq          - inject hooks with ConvertFrom-Json  |
+------------------------------------------------------------------+
        |                                    |
        v                                    v
+------------------------------------------------------------------+
|                  Shared Layer (All Platforms)                     |
|                                                                  |
|  audio/notify-*.mp3  -- pre-generated, committed to repo        |
|  ~/.claude/           -- install target for all platforms        |
|  settings.json hooks  -- same 4 events, same event mapping       |
|  5-second cooldown    -- same debouncing logic per notification  |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                Platform-Specific Playback Layer                   |
|                                                                  |
|  Linux:   notify-play.sh -> /usr/bin/paplay $AUDIO_FILE         |
|  macOS:   notify-play.sh -> /usr/bin/afplay $AUDIO_FILE         |
|  Windows: notify-play.ps1 -> [Windows.Media.MediaPlayer]::Play  |
+------------------------------------------------------------------+
```

## Component Details

### 1. notify-play.sh (Linux + macOS, Modified)

The existing `notify-play.sh` works on both Linux and macOS with one change: detect the OS and select the playback command.

**Current (Linux-only):**
```bash
/usr/bin/paplay "$AUDIO_FILE" 2>/dev/null || true
```

**Proposed (Linux + macOS):**
```bash
detect_player() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "/usr/bin/afplay"
    else
        echo "/usr/bin/paplay"
    fi
}

PLAYER=$(detect_player)
$PLAYER "$AUDIO_FILE" 2>/dev/null || true
```

**Design decision:** Use `uname` for OS detection rather than checking for command existence. Rationale: `uname` is instant and unambiguous. Checking `command -v afplay` would also work but is unnecessary since we already know the platform at install time.

**Cooldown mechanism:** The existing `/tmp/claude-notify-{type}.lock` timestamp approach works on macOS too (macOS has `/tmp`). No change needed.

### 2. notify-play.ps1 (Windows, New)

Windows needs a PowerShell equivalent of the cooldown wrapper. The cooldown logic must use a file-based timestamp mechanism equivalent to the bash version.

**Proposed structure:**
```powershell
# notify-play.ps1 — Windows cooldown wrapper for notification playback
param(
    [string]$Type,
    [string]$AudioFile
)

$LockFile = "$env:TEMP\claude-notify-$Type.lock"
$CooldownSec = 5

# Check cooldown
if (Test-Path $LockFile) {
    $LockAge = (Get-Date) - (Get-Item $LockFile).LastWriteTime
    if ($LockAge.TotalSeconds -lt $CooldownSec) {
        exit 0
    }
}

# Update lock and play
Set-Content -Path $LockFile -Value (Get-Date) -NoNewline

Add-Type -AssemblyName presentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$player.Open([System.Uri]::new($AudioFile))
$player.Play()
exit 0
```

**Key considerations for notify-play.ps1:**

| Concern | Approach |
|---------|----------|
| **MP3 playback** | `System.Windows.Media.MediaPlayer` via `presentationCore` assembly. Supports MP3 natively. Non-blocking by default (Play() returns immediately). |
| **Cooldown** | File timestamp in `$env:TEMP`, equivalent to `/tmp` on Linux/macOS. |
| **Error handling** | Exit 0 always (matches bash behavior). Stop/SubagentStop hooks block on non-zero exit. |
| **MediaPlayer disposal** | Not needed. The script exits after Play(), and Claude Code's async timeout kills the process if needed. MediaPlayer is a lightweight object. |
| **No `SoundPlayer`** | `System.Media.SoundPlayer` only supports WAV files, not MP3. Must use MediaPlayer. |

**Confidence: HIGH** for `MediaPlayer` approach -- verified from Stack Overflow, Microsoft docs, and multiple PowerShell sources. `SoundPlayer` WAV-only limitation is well-documented.

### 3. install.sh (Linux + macOS, Modified)

The existing `install.sh` needs two changes:

**Change 1: OS detection for player prerequisite check**

Current:
```bash
for cmd in jq paplay; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found." >&2
        exit 1
    fi
done
```

Proposed:
```bash
for cmd in jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found." >&2
        exit 1
    fi
done

# Check platform-specific audio player
if [[ "$(uname)" == "Darwin" ]]; then
    PLAYER="afplay"
else
    PLAYER="paplay"
fi

if ! command -v "$PLAYER" &>/dev/null; then
    echo "ERROR: $PLAYER not found." >&2
    exit 1
fi
```

**Change 2: None needed for hook injection.** The hooks already reference `notify-play.sh` which now handles OS detection internally. The jq command and hook structure remain identical.

### 4. install.ps1 (Windows, New)

The Windows install script must mirror `install.sh` behavior: copy audio files and inject hooks into `settings.json`. The key difference is using PowerShell's `ConvertFrom-Json` / `ConvertTo-Json` instead of `jq`.

**Proposed structure:**
```powershell
# install.ps1 — Install Claude Code notification hooks on Windows
param()

$ClaudeDir = "$env:USERPROFILE\.claude"
$SettingsPath = "$ClaudeDir\settings.json"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$NotifyPlay = "$RepoRoot\scripts\notify-play.ps1"

# Prerequisite checks
# - Claude Code version check (optional, same logic as bash)
# - PowerShell MediaCapability check (presentationCore assembly)

# Copy audio files
$Types = @("complete", "confirm", "error", "progress")
foreach ($Type in $Types) {
    $Src = "$RepoRoot\audio\notify-$Type.mp3"
    $Dst = "$ClaudeDir\notify-$Type.mp3"
    if (-not (Test-Path $Src)) {
        Write-Error "ERROR: $Src not found. Audio files must be pre-generated."
        exit 1
    }
    Copy-Item $Src $Dst -Force
}

# Read and modify settings.json
$settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json

# Ensure hooks object exists
if (-not $settings.hooks) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{}) -Force
}

# Define hook commands
$hookEvents = @{
    Stop          = @{ cmd = "$NotifyPlay complete $ClaudeDir\notify-complete.mp3" }
    Notification  = @{ cmd = "$NotifyPlay confirm $ClaudeDir\notify-confirm.mp3" }
    StopFailure   = @{ cmd = "$NotifyPlay error $ClaudeDir\notify-error.mp3" }
    SubagentStop  = @{ cmd = "$NotifyPlay progress $ClaudeDir\notify-progress.mp3" }
}

foreach ($event in $hookEvents.Keys) {
    $hookEntry = @(
        @{
            hooks = @(
                @{
                    type    = "command"
                    shell   = "powershell"
                    command = $hookEvents[$event].cmd
                    async   = $true
                    timeout = 10
                }
            )
        }
    )
    $settings.hooks | Add-Member -NotePropertyName $event -NotePropertyValue $hookEntry -Force
}

# Write back
$settings | ConvertTo-Json -Depth 100 | Set-Content $SettingsPath -Encoding UTF8
```

**Critical considerations for install.ps1:**

| Concern | Approach | Confidence |
|---------|----------|------------|
| **JSON manipulation** | `ConvertFrom-Json` / `ConvertTo-Json -Depth 100`. Must use `-Depth 100` because default depth is 2 in PowerShell 5.x. | HIGH -- standard PowerShell pattern |
| **`shell` field** | Set to `"powershell"` on each hook. This tells Claude Code to spawn PowerShell for these hooks. | HIGH -- official Claude Code feature |
| **Backslash in paths** | PowerShell handles backslashes natively. `$ClaudeDir\notify-complete.mp3` works correctly. | HIGH |
| **Idempotency** | `Add-Member -Force` overwrites existing properties, same as jq's `=` assignment. Safe to run multiple times. | HIGH |
| **UTF-8 encoding** | `Set-Content -Encoding UTF8` ensures settings.json is readable. Without this, PowerShell 5.x may write UTF-16 BOM which breaks JSON parsers. | MEDIUM -- `-Encoding UTF8` in PS 5.x writes UTF-8 with BOM. PS 7+ defaults to UTF-8 without BOM. Consider using `[System.IO.File]::WriteAllText()` if BOM issues arise. |
| **No `jq` dependency** | PowerShell's built-in JSON cmdlets replace jq entirely on Windows. Do not require jq on Windows. | HIGH -- this is the standard approach |

### 5. uninstall.ps1 (Windows, New)

Mirrors `uninstall.sh`: removes hook entries from `settings.json` and deletes audio files.

```powershell
# uninstall.ps1 — Remove Claude Code notification hooks on Windows
$ClaudeDir = "$env:USERPROFILE\.claude"
$SettingsPath = "$ClaudeDir\settings.json"

$settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json

# Remove hook entries
$eventsToRemove = @("Stop", "Notification", "StopFailure", "SubagentStop")
foreach ($event in $eventsToRemove) {
    if ($settings.hooks.PSObject.Properties[$event]) {
        $settings.hooks.PSObject.Properties.Remove($event)
    }
}

# Write back
$settings | ConvertTo-Json -Depth 100 | Set-Content $SettingsPath -Encoding UTF8

# Remove audio files
$Types = @("complete", "confirm", "error", "progress")
foreach ($Type in $Types) {
    Remove-Item "$ClaudeDir\notify-$Type.mp3" -ErrorAction SilentlyContinue
}
```

## Hook Configuration Per Platform

### Linux (Current, No Change)
```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "/path/to/notify-play.sh complete /home/user/.claude/notify-complete.mp3", "async": true, "timeout": 10}]}],
    "Notification": [{"hooks": [{"type": "command", "command": "/path/to/notify-play.sh confirm /home/user/.claude/notify-confirm.mp3", "async": true, "timeout": 10}]}],
    "StopFailure": [{"hooks": [{"type": "command", "command": "/path/to/notify-play.sh error /home/user/.claude/notify-error.mp3", "async": true, "timeout": 10}]}],
    "SubagentStop": [{"hooks": [{"type": "command", "command": "/path/to/notify-play.sh progress /home/user/.claude/notify-progress.mp3", "async": true, "timeout": 10}]}]
  }
}
```

### macOS (Same as Linux, `shell` omitted = default `bash`)
```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "/path/to/notify-play.sh complete /Users/user/.claude/notify-complete.mp3", "async": true, "timeout": 10}]}]
  }
}
```

Identical structure. Only difference: `~` expands to `/Users/user` instead of `/home/user`. `notify-play.sh` auto-detects `afplay` vs `paplay`.

### Windows (New: `shell: "powershell"`)
```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "shell": "powershell", "command": "C:\\path\\to\\notify-play.ps1 -Type complete -AudioFile C:\\Users\\user\\.claude\\notify-complete.mp3", "async": true, "timeout": 10}]}]
  }
}
```

Key differences:
1. `"shell": "powershell"` -- tells Claude Code to invoke PowerShell
2. Script is `.ps1` not `.sh`
3. Uses PowerShell parameter syntax (`-Type`, `-AudioFile`)
4. Windows paths use backslashes

## Data Flow Per Platform

### Linux Data Flow (Unchanged)
```
Claude Code fires Stop event
  -> Hook command: /path/to/notify-play.sh complete ~/.claude/notify-complete.mp3
  -> notify-play.sh checks /tmp/claude-notify-complete.lock (cooldown)
  -> Within cooldown? -> exit 0 (skip)
  -> Touch lock file
  -> /usr/bin/paplay ~/.claude/notify-complete.mp3
  -> PulseAudio plays audio
  -> exit 0
```

### macOS Data Flow
```
Claude Code fires Stop event
  -> Hook command: /path/to/notify-play.sh complete ~/.claude/notify-complete.mp3
  -> notify-play.sh uname == "Darwin" -> PLAYER=/usr/bin/afplay
  -> notify-play.sh checks /tmp/claude-notify-complete.lock (cooldown)
  -> Within cooldown? -> exit 0 (skip)
  -> Touch lock file
  -> /usr/bin/afplay ~/.claude/notify-complete.mp3
  -> CoreAudio plays audio
  -> exit 0
```

### Windows Data Flow
```
Claude Code fires Stop event
  -> Hook command (shell=powershell): C:\path\to\notify-play.ps1 -Type complete -AudioFile C:\Users\user\.claude\notify-complete.mp3
  -> notify-play.ps1 checks $env:TEMP\claude-notify-complete.lock (cooldown)
  -> Within cooldown? -> exit 0 (skip)
  -> Write timestamp to lock file
  -> Add-Type -AssemblyName presentationCore
  -> New-Object System.Windows.Media.MediaPlayer
  -> $player.Open(mp3 file)
  -> $player.Play()
  -> exit 0
  -> Windows audio subsystem plays audio
```

## Audio Playback Comparison

| Property | `paplay` (Linux) | `afplay` (macOS) | `MediaPlayer` (Windows) |
|----------|------------------|------------------|------------------------|
| **Format support** | MP3, WAV, OGG, FLAC | MP3, WAV, AAC, M4A, AIFC | MP3, WAV, WMA, AAC |
| **Blocking behavior** | Blocks until playback finishes | Blocks until playback finishes | Non-blocking (Play() returns immediately) |
| **Installation** | Pre-installed (PipeWire/PulseAudio) | Pre-installed (macOS) | Pre-installed (Windows .NET Framework) |
| **Dependencies** | libpulse | CoreAudio | `presentationCore` assembly |
| **In async hook** | Works fine (async: true handles blocking) | Works fine (async: true handles blocking) | Works fine (already non-blocking) |
| **Error on missing** | Exits non-zero | Exits non-zero | Assembly load error |

**Important:** All three commands block (or not) but since hooks use `async: true`, Claude Code does not wait. The `timeout: 10` kills any runaway process.

## Project Structure After v1.1

```
notify-research/
├── audio/                      # (UNCHANGED) Pre-generated MP3 files
│   ├── notify-complete.mp3
│   ├── notify-confirm.mp3
│   ├── notify-error.mp3
│   └── notify-progress.mp3
├── scripts/
│   ├── install.sh              # (MODIFIED) Linux + macOS install
│   ├── uninstall.sh            # (MODIFIED) Linux + macOS uninstall
│   ├── notify-play.sh          # (MODIFIED) Linux + macOS cooldown wrapper
│   ├── install.ps1             # (NEW) Windows install
│   ├── uninstall.ps1           # (NEW) Windows uninstall
│   └── notify-play.ps1         # (NEW) Windows cooldown wrapper
├── Dockerfile                  # (UNCHANGED) TTS generation only
├── generate.sh                 # (UNCHANGED) TTS generation only
├── requirements.txt            # (UNCHANGED)
└── generate.py                 # (UNCHANGED)
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Using `SoundPlayer` on Windows

**What:** Using `System.Media.SoundPlayer` instead of `MediaPlayer`.

**Why wrong:** `SoundPlayer` only supports WAV files. The project distributes MP3 files.

**Do instead:** Use `System.Windows.Media.MediaPlayer` (from `presentationCore` assembly) which supports MP3 natively.

### Anti-Pattern 2: Trying to Make One Script Work Everywhere

**What:** Writing a single `notify-play.sh` that somehow works on Windows via Git Bash or WSL.

**Why wrong:** Windows hooks support `"shell": "powershell"` natively. Mixing bash and PowerShell creates fragile, hard-to-debug setups. Git Bash on Windows has path translation issues (`/c/Users/...`) that cause subtle bugs.

**Do instead:** Separate scripts per platform. Bash for Linux/macOS, PowerShell for Windows. This is what Claude Code's official documentation demonstrates.

### Anti-Pattern 3: Using `ConvertTo-Json` Without `-Depth 100`

**What:** Writing PowerShell install.ps1 without specifying `-Depth 100`.

**Why wrong:** PowerShell 5.x defaults to `-Depth 2`, which silently truncates nested objects. The hook structure is 4 levels deep (`hooks.Stop[0].hooks[0].command`), so default depth would corrupt the JSON.

**Do instead:** Always use `-Depth 100` (or a sufficiently high number) when writing settings.json.

### Anti-Pattern 4: BOM in settings.json

**What:** Using `Set-Content` in PowerShell 5.x without specifying encoding, which writes UTF-16 with BOM.

**Why wrong:** Claude Code's JSON parser may fail on UTF-16 BOM (`\xEF\xBB\xBF` or `\xFF\xFE` prefix).

**Do instead:** Use `Set-Content -Encoding UTF8` (PS 5.x) or consider `[System.IO.File]::WriteAllText($path, $content)` (PS 7+ defaults to UTF-8 without BOM).

### Anti-Pattern 5: Installing jq on Windows

**What:** Requiring jq as a prerequisite on Windows for settings.json manipulation.

**Why wrong:** PowerShell has built-in JSON cmdlets (`ConvertFrom-Json`, `ConvertTo-Json`). Adding jq creates an unnecessary dependency.

**Do instead:** Use PowerShell's native JSON cmdlets for Windows scripts.

## Build Order and Dependencies

```
Phase 1: Modify notify-play.sh for OS detection
    |-- Add uname check for Darwin
    |-- Select afplay vs paplay
    |-- Test on Linux (must not break existing behavior)
    Depends on: Nothing (standalone modification)
    Blocks: Phase 2

Phase 2: Modify install.sh for macOS support
    |-- Remove paplay from prerequisite check (make it conditional)
    |-- Add afplay/paplay detection
    |-- Update user-facing messages
    Depends on: Phase 1 (notify-play.sh handles OS detection)
    Blocks: Phase 3

Phase 3: Create notify-play.ps1 (Windows cooldown wrapper)
    |-- Implement cooldown logic in PowerShell
    |-- Implement MediaPlayer playback
    |-- Test MP3 playback on Windows
    Depends on: Nothing (independent of Phase 1-2)
    Blocks: Phase 4

Phase 4: Create install.ps1 (Windows install script)
    |-- Copy audio files to ~/.claude/
    |-- Inject hooks with ConvertFrom-Json / ConvertTo-Json
    |-- Set shell: "powershell" on hook entries
    Depends on: Phase 3 (notify-play.ps1 must exist)
    Blocks: Phase 5

Phase 5: Create uninstall.ps1 (Windows uninstall script)
    |-- Remove hook entries from settings.json
    |-- Delete audio files from ~/.claude/
    Depends on: Phase 4 (must understand install.ps1 structure)
    Blocks: Nothing

Phase 6: Documentation and README updates
    |-- Installation instructions for each platform
    |-- Troubleshooting section
    Depends on: All previous phases
    Blocks: Nothing
```

**Parallelism opportunity:** Phase 1-2 (Linux/macOS) and Phase 3-5 (Windows) are independent and can be developed in parallel.

## Pitfalls and Mitigations

| Pitfall | Severity | Mitigation |
|---------|----------|------------|
| `ConvertTo-Json -Depth` truncation | High | Always use `-Depth 100`. Add test that reads back settings.json and verifies hook structure. |
| UTF-8 BOM corruption on Windows | High | Use `Set-Content -Encoding UTF8`. Test that Claude Code reads the modified settings.json correctly. |
| `MediaPlayer` assembly not available | Low | `presentationCore` is part of .NET Framework 4+ and .NET Core/5+, available on all modern Windows. No mitigation needed. |
| `afplay` path on macOS | Low | `/usr/bin/afplay` is at a fixed path on all macOS versions. No mitigation needed. |
| PowerShell 5.x vs 7+ differences | Medium | Test on both. Use `-Depth 100` for both (PS 7+ defaults to 100 but explicit is safer). Avoid PS 7-only features. |
| `stat -c %Y` not available on macOS | Medium | `notify-play.sh` current code uses `stat -c %Y` which is GNU-only. macOS uses `stat -f %m`. Must fix. |
| Path separator differences | Low | Each platform's script uses its native separator. No cross-platform path issues. |
| `$HOME` vs `$USERPROFILE` | Low | Bash uses `$HOME`, PowerShell uses `$env:USERPROFILE`. Each script uses its platform's convention. |

## Pre-Submission Checklist

- [x] Platform-specific vs shared code clearly separated
- [x] Data flow direction explicit per platform
- [x] Build order implications noted
- [x] All findings have confidence levels
- [x] Sources verified (official docs for Claude Code hooks)
- [x] Anti-patterns documented
- [x] install.ps1 mirrors install.sh behavior described

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- `"shell": "powershell"` field, async hooks, command hook schema (HIGH confidence, verified 2026-03-30)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide) -- Windows PowerShell notification example, cross-platform hook patterns (HIGH confidence, verified 2026-03-30)
- [afplay man page (macOS)](https://community.unix.com/t/osx-afplay-command-line-audio-player-manual/362074) -- MP3 support, blocking behavior (HIGH confidence)
- [PowerShell MediaPlayer for MP3 (Stack Overflow)](https://stackoverflow.com/questions/25895428/how-to-play-mp3-with-powershell-simple) -- System.Windows.Media.MediaPlayer for MP3 playback (HIGH confidence)
- [PowerShell SoundPlayer WAV limitation (Microsoft DevBlogs)](https://devblogs.microsoft.com/scripting/powertip-use-powershell-to-play-wav-files/) -- SoundPlayer only supports WAV (HIGH confidence)
- [PowerShell JSON manipulation patterns](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json) -- ConvertTo-Json -Depth parameter (HIGH confidence)
- Existing codebase: `scripts/install.sh`, `scripts/uninstall.sh`, `scripts/notify-play.sh` -- analyzed for v1.0 architecture (HIGH confidence, read 2026-03-30)

---
*Architecture research for: Claude Code voice notification system v1.1 cross-platform support*
*Researched: 2026-03-30*
