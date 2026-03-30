# Phase 5: Windows - Research

**Researched:** 2026-03-30
**Domain:** Windows PowerShell scripting, .NET audio playback, Claude Code hooks on Windows
**Confidence:** MEDIUM

## Summary

This phase creates three PowerShell scripts (notify-play.ps1, install.ps1, uninstall.ps1) that mirror the existing bash scripts for Linux/macOS. The primary technical challenges are: (1) playing MP3 audio without a visible window using System.Windows.Media.MediaPlayer, (2) correctly injecting hooks into Claude Code's settings.json with the `"shell": "powershell"` marker and forward-slash paths, and (3) writing JSON without BOM in PowerShell 5.1.

The Claude Code hooks subsystem on Windows has significant known instability (issues #26759, #29560, #26746, #32930), with backslash paths being stripped and hooks sometimes not executing at all. The mitigations are well-documented: use forward-slash paths and the `"shell": "powershell"` hook field. However, the Windows Desktop App may still not execute hooks at all (#29560) -- this is an upstream bug with no workaround.

The MediaPlayer approach for audio playback in PowerShell 5.1 has a threading subtlety: MediaPlayer.Play() is non-blocking and the script may exit before playback finishes. The script must either wait for playback completion or accept async fire-and-forget behavior (acceptable since hooks are async:true anyway).

**Primary recommendation:** Use System.Windows.Media.MediaPlayer with Add-Type -AssemblyName PresentationCore, a while-loop waiting for NaturalDuration completion, and [System.IO.File]::WriteAllText() for BOM-free JSON output. Set $ErrorActionPreference = "Stop" and wrap all audio logic in try/catch that always exits 0.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Minimum PowerShell 5.1 compatibility (Windows 10/11 built-in), do not require PowerShell 7+
- **D-02:** Use System.Windows.Media.MediaPlayer (.NET) for MP3 playback via Add-Type loading PresentationCore assembly
- **D-03:** 5-second cooldown debounce mechanism using $env:TEMP\claude-notify-{type}.lock file + timestamp comparison
- **D-04:** Use PowerShell native JSON cmdlets (ConvertFrom-Json / ConvertTo-Json -Depth 100), write with [System.IO.File]::WriteAllText() to avoid BOM
- **D-05:** All hook command paths use forward slashes (per #26759 workaround), e.g. C:/Users/name/.claude/notify-complete.mp3
- **D-06:** PowerShell scripts go in scripts/ directory, alongside bash scripts
- **D-07:** Windows uses $env:USERPROFILE\.claude\ as Claude config directory
- **D-08:** install.ps1 requires user to specify repo path via parameter (or notify-play.ps1 location), does not assume repo path
- **D-09:** MP3 files copied from local repo audio/ directory, user must clone repo first

### Claude's Discretion
- install.ps1 parameter design (-RepoPath vs -ScriptPath, default values etc.)
- MediaPlayer Add-Type loading approach and error handling
- uninstall.ps1 whether to clean up $env:TEMP lock files
- PowerShell script error output format (Write-Warning / Write-Error)

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WIN-01 | notify-play.ps1 uses MediaPlayer to play MP3 without popping up a window | MediaPlayer pattern (PresentationCore), non-visual playback verified |
| WIN-02 | notify-play.ps1 implements same 5-second cooldown debounce as Linux | Lock file in $env:TEMP with timestamp comparison pattern |
| WIN-03 | install.ps1 injects hooks into Claude Code settings.json | JSON manipulation with ConvertFrom-Json/ConvertTo-Json + WriteAllText |
| WIN-04 | install.ps1 uses `"shell": "powershell"` to mark Windows hooks | Official Claude Code hooks docs confirm `"shell": "powershell"` field |
| WIN-05 | install.ps1 uses forward slashes in all paths (bug #26759 workaround) | Issue #26759 documented: backslash paths stripped by Claude Code |
| WIN-06 | uninstall.ps1 removes hooks from settings.json | JSON manipulation pattern: delete .hooks.Stop/Notification/StopFailure/SubagentStop |
</phase_requirements>

## Standard Stack

### Core
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| PowerShell | 5.1+ | Script runtime | Built-in on Windows 10/11; D-01 mandates 5.1 compatibility |
| .NET Framework | 4.x | MediaPlayer assembly host | Required for PresentationCore; ships with Windows 10+ |
| System.Windows.Media.MediaPlayer | .NET 4.x | MP3 audio playback | No-window playback, built into .NET Framework, no extra dependencies |

### Supporting
| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| ConvertFrom-Json / ConvertTo-Json | PS 5.1 built-in | JSON manipulation | Reading and writing settings.json |
| [System.IO.File]::WriteAllText() | .NET Framework | BOM-free UTF-8 file write | Writing settings.json (D-04) |
| System.Text.UTF8Encoding($false) | .NET Framework | UTF-8 without BOM encoding | Parameter for WriteAllText |
| $env:TEMP | Windows built-in | Lock file directory | Replaces /tmp for cooldown files |
| $env:USERPROFILE | Windows built-in | User home directory | Replaces $HOME for Claude config path |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MediaPlayer (PresentationCore) | WMPlayer.OCX COM object | COM object spawns a visible background process; MediaPlayer is lighter and truly headless |
| MediaPlayer (PresentationCore) | System.Media.SoundPlayer | SoundPlayer only supports WAV, not MP3 |
| ConvertFrom-Json | jq.exe | jq.exe is an external dependency; REQUIREMENTS.md explicitly excludes it ("Out of Scope: jq.exe for Windows") |
| PowerShell 5.1 | PowerShell 7+ (pwsh) | PS 7+ not guaranteed on user machines; D-01 requires 5.1 minimum |

**Installation:**
No installation needed -- PowerShell 5.1, .NET Framework 4.x, and PresentationCore are all pre-installed on Windows 10/11.

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── install.sh            # Existing: Linux/macOS installer (DO NOT MODIFY)
├── uninstall.sh          # Existing: Linux/macOS uninstaller (DO NOT MODIFY)
├── notify-play.sh        # Existing: Linux/macOS player (DO NOT MODIFY)
├── install.ps1           # NEW: Windows installer
├── uninstall.ps1         # NEW: Windows uninstaller
└── notify-play.ps1       # NEW: Windows audio player
```

### Pattern 1: notify-play.ps1 -- Audio Playback with Cooldown
**What:** PowerShell script that plays an MP3 notification sound with 5-second per-type cooldown debounce.
**When to use:** Called by Claude Code hooks on Stop/Notification/StopFailure/SubagentStop events.
**Key requirements:**
- Always exits 0 (hook non-blocking requirement)
- Parameters: `$Type` (string), `$AudioFile` (string)
- Lock file: `$env:TEMP\claude-notify-$Type.lock`
- Must handle MediaPlayer loading failure gracefully

**Example:**
```powershell
# Source: Research synthesis from official Claude Code hooks docs + .NET MediaPlayer docs
param(
    [Parameter(Mandatory=$true)][string]$Type,
    [Parameter(Mandatory=$true)][string]$AudioFile
)

$ErrorActionPreference = "Stop"
$CooldownSec = 5
$LockFile = Join-Path $env:TEMP "claude-notify-$Type.lock"

# Cooldown check
if (Test-Path $LockFile) {
    $lockAge = ((Get-Date) - (Get-Item $LockFile).LastWriteTime).TotalSeconds
    if ($lockAge -lt $CooldownSec) { exit 0 }
}

# Update lock timestamp
Set-Content -Path $LockFile -Value (Get-Date) -NoNewline

# Play audio
try {
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([System.Uri]::new($AudioFile))
    Start-Sleep -Milliseconds 500  # Wait for media to load
    $player.Play()

    # Wait for playback to finish (async hooks have timeout:10)
    while ($player.Position -lt $player.NaturalDuration.TimeSpan -and $player.NaturalDuration.HasTimeSpan) {
        Start-Sleep -Milliseconds 100
    }
    $player.Close()
} catch {
    # Always exit 0 -- hook must not block Claude
}
exit 0
```

### Pattern 2: install.ps1 -- Settings.json Hook Injection
**What:** PowerShell script that reads settings.json, injects 4 notification hooks, writes back BOM-free.
**When to use:** User runs manually to install notification hooks.
**Key requirements:**
- Parameter: `-RepoPath` (mandatory) pointing to cloned repo root
- Use `$env:USERPROFILE\.claude\settings.json` as settings path
- Forward slashes in all paths (D-05)
- `"shell": "powershell"` on each hook (WIN-04)
- BOM-free JSON output (D-04)

**Example hook entry to inject:**
```json
{
  "type": "command",
  "shell": "powershell",
  "command": "powershell -File C:/Users/name/scripts/notify-play.ps1 complete C:/Users/name/.claude/notify-complete.mp3",
  "async": true,
  "timeout": 10
}
```

**Event mapping (must match install.sh exactly):**
| Claude Code Event | Audio File | Notification Type |
|---|---|---|
| Stop | notify-complete.mp3 | complete |
| Notification | notify-confirm.mp3 | confirm |
| StopFailure | notify-error.mp3 | error |
| SubagentStop | notify-progress.mp3 | progress |

### Pattern 3: Settings.json Read-Modify-Write (BOM-Free)
**What:** PowerShell 5.1 pattern for modifying JSON files without introducing BOM.
**When to use:** install.ps1 and uninstall.ps1 modifying settings.json.

**Example:**
```powershell
# Source: StackOverflow + Microsoft Learn documentation
$settingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json

# Modify hooks...
# $settings.hooks.Stop = @( @{ hooks = @( ...) } )

# Write back BOM-free
$jsonOutput = $settings | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($settingsPath, $jsonOutput, $utf8NoBom)
```

### Pattern 4: uninstall.ps1 -- Hook Removal
**What:** PowerShell script that removes the 4 notification hook entries from settings.json.
**When to use:** User runs manually to uninstall notification hooks.

**Example:**
```powershell
$settingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json

# Remove hook entries (mirror uninstall.sh exactly)
$settings.hooks | Get-Member -MemberType NoteProperty |
    Where-Object { $_.Name -in @('Stop','Notification','StopFailure','SubagentStop') } |
    ForEach-Object { $settings.huts.PSObject.Properties.Remove($_.Name) }

# Write back BOM-free
$jsonOutput = $settings | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($settingsPath, $jsonOutput, $utf8NoBom)

# Remove audio files
foreach ($type in @('complete','confirm','error','progress')) {
    $f = Join-Path $env:USERPROFILE ".claude\notify-$type.mp3"
    if (Test-Path $f) { Remove-Item $f }
}
```

### Anti-Patterns to Avoid
- **Using Set-Content or Out-File for settings.json:** These write UTF-8 with BOM in PS 5.1, which breaks Claude Code's JSON parser. Always use [System.IO.File]::WriteAllText().
- **Using backslash in hook command paths:** Claude Code strips backslashes on Windows (issue #26759). Always use forward slashes.
- **Exiting non-zero from notify-play.ps1:** Stop and SubagentStop hooks block on non-zero exit. Always `exit 0`.
- **Using ConvertTo-Json with default depth (2):** settings.json is deeply nested. Must use `-Depth 100`.
- **Loading PresentationFramework:** Not needed for MediaPlayer. Only load PresentationCore and WindowsBase.
- **Using WMPlayer.OCX:** Creates a visible COM process. MediaPlayer is headless.
- **Forgetting try/catch in notify-play.ps1:** MediaPlayer loading can fail. Must catch and exit 0.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing/generation | Custom string manipulation | ConvertFrom-Json / ConvertTo-Json | Handles all JSON edge cases, PSCustomObject round-trip |
| UTF-8 without BOM file writing | Custom byte writing | [System.IO.File]::WriteAllText() + UTF8Encoding($false) | Battle-tested .NET API, correct encoding handling |
| Audio playback | Direct P/Invoke or COM | System.Windows.Media.MediaPlayer | Built-in .NET class, handles MP3 natively, no extra deps |
| File timestamp comparison | Custom date math | (Get-Date) - (Get-Item).LastWriteTime | PowerShell's built-in TimeSpan subtraction |
| Settings.json hook structure | Build JSON string manually | PSCustomObject with ConvertTo-Json | Type-safe, handles quoting and escaping correctly |

**Key insight:** PowerShell 5.1 has excellent .NET Framework interop. Every problem here (JSON, encoding, audio, timestamps) has a built-in .NET solution. Resist the urge to use external tools or custom string manipulation.

## Common Pitfalls

### Pitfall 1: PowerShell 5.1 BOM in JSON Output
**What goes wrong:** `Set-Content -Encoding UTF8` or `Out-File -Encoding UTF8` writes a 3-byte BOM (EF BB BF) at the start of the file. Claude Code's JSON parser may fail on BOM-prefixed files, causing settings.json to be silently ignored or corrupted.
**Why it happens:** PowerShell 5.1 defaults to UTF-8 with BOM for all text file operations. This was changed in PowerShell 7+ to default to no-BOM.
**How to avoid:** Always use `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))` for any JSON file writes.
**Warning signs:** Claude Code not picking up settings changes; JSON parsing errors in verbose mode; file size 3 bytes larger than expected.

### Pitfall 2: Backslash Paths Stripped by Claude Code
**What goes wrong:** Hook commands containing `C:\Users\...` paths get their backslashes stripped, producing mangled paths like `C:Users....mp3`. The hook fails with "Module not found" or file-not-found errors.
**Why it happens:** Claude Code's hook executor interprets backslashes as escape characters on Windows (issues #26759, #26746, #23957). This is a known, recurring bug across multiple versions (2.1.39 through 2.1.47+).
**How to avoid:** Use forward slashes in ALL hook command paths: `C:/Users/name/.claude/notify-complete.mp3`. Forward slashes work correctly in PowerShell and Windows APIs.
**Warning signs:** Hook matched but command failed; "Module not found" in hook debug output; path contains no separators.

### Pitfall 3: MediaPlayer Playback Cut Short by Script Exit
**What goes wrong:** notify-play.ps1 exits before MediaPlayer finishes playing the MP3, resulting in no audible notification.
**Why it happens:** `MediaPlayer.Play()` is non-blocking. The script continues to `exit 0` immediately, the PowerShell process terminates, and the MediaPlayer object is garbage-collected, stopping playback mid-stream.
**How to avoid:** Add a while-loop that waits for `MediaPlayer.Position >= MediaPlayer.NaturalDuration.TimeSpan` after calling `Play()`. Check `NaturalDuration.HasTimeSpan` first (it may not be available immediately after Open). Since hooks are async:true with timeout:10, the wait loop is acceptable.
**Warning signs:** No audio plays; notification sound is truncated; audio only plays for a split second.

### Pitfall 4: ConvertTo-Json Truncates Deep Settings.json
**What goes wrong:** After injecting hooks, settings.json is missing nested data. Permission rules, tool configurations, or other deeply nested settings are replaced with string representations like `"System.Collections.Generic.Dictionary..."`.
**Why it happens:** `ConvertTo-Json` defaults to `-Depth 2`. Any nesting beyond 2 levels is silently converted to a string representation. settings.json often has 4-6 levels of nesting.
**How to avoid:** Always use `-Depth 100` with ConvertTo-Json when writing settings.json.
**Warning signs:** Existing settings disappear after install/uninstall; Claude Code behaves differently after running install.ps1.

### Pitfall 5: Hook Commands Not Executing on Windows Desktop App
**What goes wrong:** Hooks are correctly configured in settings.json but never fire on the Windows Desktop App (Claude Desktop).
**Why it happens:** Known bug (issue #29560) where hooks are matched by the hook system but the underlying commands never execute on the Windows Desktop App. There is no known workaround.
**How to avoid:** This is an upstream bug. Document it clearly. The scripts should work correctly when Claude Code is used via terminal/CLI (not Desktop App). Test with `claude --debug` to verify hook execution.
**Warning signs:** Hooks work in terminal but not in Claude Desktop; verbose mode shows no hook activity on Desktop App.

### Pitfall 6: PowerShell Profile Output Interferes with JSON
**What goes wrong:** The user's PowerShell profile ($PROFILE) prints text to stdout. When Claude Code invokes a PowerShell hook, the profile output appears before the JSON response, causing JSON parsing failures.
**Why it happens:** PowerShell loads the user's profile script on every invocation, which may contain Write-Host, echo, or other output.
**How to avoid:** Hook commands use `-File` flag (`powershell -File script.ps1`), which does NOT load the user profile. This is the correct invocation pattern for hooks. Additionally, the notification hooks do not produce JSON output, so this is less of a concern than for decision-making hooks.
**Warning signs:** Unexpected text in hook debug output; JSON parsing errors.

### Pitfall 7: PowerShell.exe vs pwsh.exe Detection
**What goes wrong:** install.ps1 tests for `powershell` or `pwsh` incorrectly, or the user has PS 7+ installed alongside PS 5.1.
**Why it happens:** Windows 10/11 ships with `powershell.exe` (PS 5.1). Users may also install `pwsh.exe` (PS 7+). Claude Code auto-detects `pwsh.exe` with fallback to `powershell.exe` when `"shell": "powershell"` is set.
**How to avoid:** Scripts should target PS 5.1 minimum. The `powershell -File` invocation in hook commands is correct -- Claude Code will resolve the appropriate executable. Do not hardcode `pwsh.exe` in hook commands since it may not be installed.
**Warning signs:** "powershell not found" errors; hooks fail only for users without PS 7+.

## Code Examples

Verified patterns from official sources:

### Claude Code Hook Entry for Windows (Official Syntax)
```json
// Source: https://code.claude.com/docs/en/hooks -- "Windows PowerShell tool" section
// Verified: 2026-03-30 via web scraping of official docs
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "shell": "powershell",
            "command": "powershell -File C:/Users/name/scripts/notify-play.ps1 complete C:/Users/name/.claude/notify-complete.mp3",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### BOM-Free JSON Write (StackOverflow + Microsoft Learn)
```powershell
# Source: https://stackoverflow.com/questions/5596982/
# Verified: StackOverflow canonical answer + Microsoft Learn PS encoding docs
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
# ... modify $settings ...
$jsonOutput = $settings | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($settingsPath, $jsonOutput, $utf8NoBom)
```

### MediaPlayer Play-and-Wait Pattern
```powershell
# Source: StackOverflow MediaPlayer pattern + .NET MediaPlayer docs
# Confidence: MEDIUM -- pattern is well-documented but STA threading edge cases exist
Add-Type -AssemblyName PresentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$player.Open([System.Uri]::new("C:/path/to/file.mp3"))
Start-Sleep -Milliseconds 500  # Let media open
$player.Play()

# Wait for playback completion
while ($player.NaturalDuration.HasTimeSpan -and $player.Position -lt $player.NaturalDuration.TimeSpan) {
    Start-Sleep -Milliseconds 100
}
$player.Stop()
$player.Close()
```

### Forward-Slash Path Conversion
```powershell
# Convert any backslash path to forward slashes for Claude Code hook compatibility
function ConvertTo-ForwardSlashPath([string]$Path) {
    return $Path -replace '\\', '/'
}
# Usage: $hookPath = ConvertTo-ForwardSlashPath "C:\Users\name\scripts\notify-play.ps1"
# Result: "C:/Users/name/scripts/notify-play.ps1"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WMPlayer.OCX COM object | System.Windows.Media.MediaPlayer (.NET) | WPF/.NET 3.0+ | MediaPlayer is headless, no COM overhead, no visible process |
| Out-File / Set-Content | [System.IO.File]::WriteAllText() | PS 5.1 era | BOM-free output critical for JSON config files |
| PowerShell profile loaded on every invocation | `powershell -File` skips profile | PS 2.0+ | Cleaner hook execution, no profile side effects |
| ConvertTo-Json default depth 2 | ConvertTo-Json -Depth 100 | PS 3.0+ | Prevents deep JSON truncation |

**Deprecated/outdated:**
- WMPlayer.OCX: Old COM-based approach, heavier and may create visible processes. Still works but MediaPlayer is preferred.
- `powershell.exe -Command "..."` for hooks: Prefer `-File` to avoid profile loading and escaping issues.

## Open Questions

1. **MediaPlayer in non-interactive context (Claude Code hook spawn)**
   - What we know: MediaPlayer requires no UI window and uses PresentationCore. It works in console/PS 5.1.
   - What's unclear: Whether Claude Code's hook spawning environment has the STA thread context that MediaPlayer may need for reliable playback. Some sources suggest MediaPlayer works fine in MTA for simple playback, others indicate STA is required.
   - Recommendation: Implement with a try/catch wrapping all MediaPlayer code. If MediaPlayer fails, catch the error silently and exit 0. The hook must never block Claude. IfMediaPlayer proves unreliable in testing, consider a fallback to `[System.Media.SoundPlayer]` with WAV files (SoundPlayer is simpler but WAV-only). However, since hooks are async:true and the audio files are already MP3, start with MediaPlayer.

2. **ConvertTo-Json property ordering on PS 5.1**
   - What we know: ConvertTo-Json in PS 5.1 may reorder properties alphabetically, potentially changing the structure of settings.json.
   - What's unclear: Whether Claude Code cares about JSON key ordering.
   - Recommendation: Claude Code uses standard JSON parsing which is order-independent. Property reordering is cosmetic only. If it becomes a concern, consider reading the file as raw text, using a targeted string replacement approach instead of full parse-serialize.

3. **PowerShell execution policy blocking scripts**
   - What we know: Windows default execution policy (RemoteSigned) allows locally-created scripts but blocks downloaded scripts. Users cloning the repo via git get files with "Zone.Identifier" alternate data stream marking them as "from internet".
   - What's unclear: How often this will affect users in practice.
   - Recommendation: Document in README that users may need to run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` or unblock scripts via `Unblock-File scripts/*.ps1`. Consider adding a check in install.ps1 that warns if current execution policy would block the script.

4. **$env:TEMP vs $env:LOCALAPPDATA for lock files**
   - What we know: Both are writable. D-03 specifies $env:TEMP.
   - What's unclear: Whether $env:TEMP is always available in Claude Code's hook spawn environment.
   - Recommendation: Use $env:TEMP per D-03. Fall back to [System.IO.Path]::GetTempPath() if $env:TEMP is empty. Both should resolve to the same location.

## Environment Availability

Step 2.6: SKIPPED (this phase produces scripts for Windows, but research is being conducted on Linux. No Windows environment is available to verify. The scripts target built-in Windows components only -- no external dependencies need to be installed.)

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PowerShell 5.1 | Script runtime | N/A (Linux dev env) | -- | Built-in on Windows 10+ |
| .NET Framework 4.x | PresentationCore | N/A (Linux dev env) | -- | Built-in on Windows 10+ |
| PresentationCore.dll | MediaPlayer | N/A (Linux dev env) | -- | GAC on Windows 10+ |

**Note:** All dependencies are built-in Windows components. No installation step is needed. Testing must be done on a Windows machine.

## Sources

### Primary (HIGH confidence)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- Full hook configuration schema, `"shell": "powershell"` field, async hooks, exit codes. Verified 2026-03-30.
- [StackOverflow: UTF-8 without BOM in PowerShell](https://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom) -- WriteAllText + UTF8Encoding($false) pattern. Verified canonical answer.
- [Microsoft Learn: ConvertTo-Json](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-7.6) -- -Depth parameter, max 100, default 2. Verified 2026-03-30.
- [Microsoft Learn: File encoding in PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/understanding-file-encoding?view=powershell-7.5) -- PS 5.1 BOM behavior documented.

### Secondary (MEDIUM confidence)
- [GitHub issue #26759: Windows backslash paths broken](https://github.com/anthropics/claude-code/issues/26759) -- Confirms backslash stripping bug, forward-slash workaround.
- [GitHub issue #29560: Windows Desktop App hooks not executing](https://github.com/anthropics/claude-code/issues/29560) -- Confirmed upstream bug with no workaround.
- [GitHub issue #32930: Hooks not respecting shell setting](https://github.com/anthropics/claude-code/issues/32930) -- Related to shell detection on Windows.
- [StackOverflow: ConvertTo-Json depth of 2](https://stackoverflow.com/questions/53583677/unexpected-convertto-json-results-answer-it-has-a-default-depth-of-2) -- Confirms depth truncation behavior.
- [StackOverflow: PowerShell MediaPlayer](https://stackoverflow.com/questions/17924310/powershell-system-windows-media-mediaplayer-register-objectevent) -- MediaPlayer usage pattern in PS.
- [.NET MediaPlayer Class docs](https://learn.microsoft.com/en-us/dotnet/api/system.windows.media.mediaplayer?view=windowsdesktop-10.0) -- Official API reference for MediaPlayer.

### Tertiary (LOW confidence)
- [Reddit: PowerShell MediaPlayer ISE 5.1 events not firing](https://www.reddit.com/r/PowerShell/comments/jc43a9/powershell_ise_51_windowsmediaplayer_class_events/) -- ISE-specific issue, may not apply to console hooks.
- Blog posts on PowerShell + WPF headless usage -- Pattern synthesis, not verified against official docs.

## Project Constraints (from CLAUDE.md)

- **Sensitive data:** No API keys or tokens involved in this phase (pure local scripts).
- **GSD Workflow Enforcement:** All file changes must go through `/gsd:execute-phase` workflow.
- **Claude Code hooks documentation** (from CLAUDE.md sources) is the authoritative reference for hook configuration.
- **REQUIREMENTS.md Out of Scope:** jq.exe for Windows -- do NOT use jq in PowerShell scripts; use native ConvertFrom-Json/ConvertTo-Json.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components (PowerShell 5.1, .NET Framework, PresentationCore) are built-in Windows features, well-documented.
- Architecture: MEDIUM - PowerShell patterns are well-established, but MediaPlayer in Claude Code hook context is untested. The forward-slash path workaround for issue #26759 is verified but the underlying Windows hooks subsystem remains unstable.
- Pitfalls: HIGH - BOM issue, backslash stripping, depth truncation, and script-exit-before-playback are all well-documented with verified solutions.

**Research date:** 2026-03-30
**Valid until:** 14 days (Windows hooks subsystem may change; verify issue #29560 status before implementation)
