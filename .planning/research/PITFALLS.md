# Pitfalls Research: Cross-Platform Audio Notification Support (v1.1)

**Domain:** Cross-platform audio notification system (Linux/macOS/Windows) for Claude Code hooks
**Researched:** 2026-03-30
**Confidence:** MEDIUM-HIGH
**Scope:** Pitfalls specific to ADDING macOS and Windows support to the existing Linux notification system

## Critical Pitfalls

Mistakes that cause silent failures, broken hooks, or require rewrites.

### Pitfall 1: Windows Backslash Paths in Hook Commands Silently Fail

**What goes wrong:**
All hooks using Windows backslash paths (`\`) in `settings.json` fail with "Module not found" errors. The backslashes are completely stripped before reaching the shell executable, turning `C:\Users\username\.claude\scripts\notify-play.ps1` into `C:Usersusernameclaude...`.

**Why it happens:**
Claude Code >= 2.1.47 changed how it passes command strings to the shell. Backslashes in the command are consumed as escape characters before reaching the target executable. This is a confirmed bug (GitHub issue #26759, reported 2026-02-19) affecting all Windows/MINGW users.

**Consequences:**
Every hook command that uses absolute Windows paths fails silently. The install script works (writes to settings.json), but the hooks never execute at runtime. User gets zero notification with no error visible in normal Claude Code output.

**Prevention:**
1. Always use forward slashes in hook `command` values, even on Windows: `"command": "bash C:/Users/username/.claude/scripts/notify-play.sh"`
2. In install.ps1, convert all paths to forward slashes before writing to settings.json
3. Never hardcode backslash paths in the hook command strings
4. Test hook execution on Windows after install, not just settings.json writing

**Detection:**
- `claude --debug` shows "hook error" entries for every hook event
- Running the command manually with backslashes works, but hooks fail
- Check that the hook command in settings.json contains no `\` characters

**Phase to address:**
Phase 1 (Cross-platform install scripts) -- this is the highest-priority pitfall. The install scripts MUST generate forward-slash paths for Windows.

---

### Pitfall 2: PowerShell `ConvertTo-Json` Truncates Nested Objects (Default Depth 2)

**What goes wrong:**
Using PowerShell's native `ConvertTo-Json` to manipulate `settings.json` silently truncates nested objects beyond 2 levels deep. The hooks configuration is 4+ levels deep (`.hooks.Stop[].hooks[].command`). After round-tripping through `ConvertTo-Json | Set-Content`, the hook entries become `{...}` placeholders or are completely lost.

**Why it happens:**
PowerShell's `ConvertTo-Json` defaults to `-Depth 2`. The Claude Code `settings.json` hook structure requires at least depth 5 to fully preserve:
```
hooks (1) -> Stop (2) -> [0] (3) -> hooks (4) -> [0] (5) -> command
```

**Consequences:**
install.ps1 appears to succeed (no errors), but `settings.json` is corrupted -- hook entries are empty objects or missing entirely. Claude Code either ignores malformed hooks or errors on load. The existing Linux `jq` approach has no such limitation.

**Prevention:**
1. Always use `ConvertTo-Json -Depth 10` (or higher) when writing settings.json
2. Better: use `jq` on Windows too -- it works via Git Bash/MINGW, and the install.ps1 can invoke `jq.exe` if available
3. Best: write the Windows install as a PowerShell wrapper that calls a bash script (same logic, same jq invocation)
4. Validate JSON structure after writing -- load it back and check that hook entries exist

**Detection:**
- Open settings.json after install and verify hook entries are not `{...}` placeholders
- Compare file size before and after -- truncated file is suspiciously small
- Run `claude /hooks` to check if hooks are registered

**Phase to address:**
Phase 1 (Cross-platform install scripts) -- JSON manipulation is the core of install/uninstall. This must work correctly on all platforms.

---

### Pitfall 3: `stat -c %Y` Does Not Work on macOS (Cooldown Lock Breaks)

**What goes wrong:**
The existing `notify-play.sh` uses `stat -c %Y "$LOCK_FILE"` to get file modification time for the 5-second cooldown. On macOS, this command fails because macOS uses BSD `stat`, not GNU `stat`. The BSD equivalent is `stat -f %m`. The script crashes with "stat: illegal option -- c" on every notification.

**Why it happens:**
`stat` is not POSIX-standardized. Linux uses GNU coreutils `stat` with `-c` for format strings and `%Y` for mtime epoch. macOS uses BSD `stat` with `-f` for format strings and `%m` for mtime epoch. The two are completely incompatible.

**Consequences:**
Every hook invocation that calls `notify-play.sh` fails with a non-zero exit code. Since the script uses `set -euo pipefail`, the error is fatal. The notification never plays. On macOS, the user sees no error because Claude Code async hooks swallow stderr.

**Prevention:**
1. Detect OS and use the correct stat flag:
```bash
if [[ "$(uname)" == "Darwin" ]]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
else
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
fi
```
2. Alternative: avoid `stat` entirely. Use `date +%s` and `find` with OS detection, or use a pure bash approach
3. Test on macOS before considering the cross-platform migration complete

**Detection:**
- Run `notify-play.sh` manually on macOS -- it errors immediately
- Check for "stat: illegal option" in `claude --debug` output
- On macOS, `/tmp/claude-notify-*.lock` files are never created

**Phase to address:**
Phase 1 (Cross-platform notify-play.sh) -- this is the first script that must work on all platforms.

---

### Pitfall 4: `/tmp` Lock Files Break on macOS (Sandboxed TMPDIR)

**What goes wrong:**
The existing cooldown mechanism hardcodes `/tmp/claude-notify-${TYPE}.lock` as the lock file path. On macOS, `/tmp` is a symlink to `/private/tmp`, and recent macOS versions (Ventura 13.7.7+) have restricted `/tmp` access. More critically, `$TMPDIR` on macOS points to a per-user sandboxed path like `/var/folders/jd/.../T/`, not `/tmp`.

**Why it happens:**
macOS uses per-user temp directories via `$TMPDIR` for security sandboxing. Hardcoded `/tmp` paths work (via the symlink) but may break in future macOS versions or under App Sandbox. On Windows, `/tmp` does not exist at all -- the temp directory is `%TEMP%` or `%TMP%`.

**Consequences:**
On macOS: Lock files may fail to create in restricted environments. On Windows: The bash script tries to write to `/tmp` which does not exist, causing cooldown to always fail (actually this means no cooldown, but the script still works since `set -euo pipefail` would fail on the `[ -f ]` check succeeding but `stat` failing). The Windows PowerShell equivalent needs `%TEMP%`.

**Prevention:**
1. Use `$TMPDIR` on macOS/Linux and `%TEMP%` on Windows:
```bash
LOCK_DIR="${TMPDIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/claude-notify-${TYPE}.lock"
```
2. In PowerShell: `$lockFile = Join-Path $env:TEMP "claude-notify-$type.lock"`
3. Document that lock files use platform temp directories

**Detection:**
- On Windows bash (Git Bash/MINGW): check if `/tmp` resolves
- On macOS restricted environments: check if lock file creation succeeds
- Look for permission denied errors in hook output

**Phase to address:**
Phase 1 (Cross-platform notify-play.sh) -- must work with platform temp directories.

---

## Moderate Pitfalls

Mistakes that degrade user experience or cause platform-specific bugs.

### Pitfall 5: Windows Audio Playback Blocking -- `WMPlayer.OCX` Leaves Orphan Processes

**What goes wrong:**
Using the Windows Media Player COM object (`New-Object -ComObject WMPlayer.OCX`) to play notification audio leaves a hidden `wmplayer.exe` process running after each notification. Over time, dozens of orphan processes accumulate, consuming memory and potentially causing audio conflicts.

**Why it happens:**
The COM object requires explicit cleanup: `$player.close()` followed by `[System.Runtime.InteropServices.Marshal]::ReleaseComObject($player)`. Most example scripts skip this cleanup. Additionally, the COM object's async playback (`$player.playState` monitoring) requires a polling loop, making the script more complex than needed.

**Consequences:**
Zombie `wmplayer.exe` processes accumulate. Each uses ~30MB of memory. After a day of coding with frequent notifications, the user may have 50+ zombie processes. Eventually, audio playback starts failing or the system becomes sluggish.

**Prevention:**
1. Use `.NET `System.Media.SoundPlayer` instead -- it has simple `Play()` (non-blocking) and `PlaySync()` (blocking) methods, and cleans up automatically:
```powershell
(New-Object System.Media.SoundPlayer 'C:\path\to\notify.mp3').PlaySync()
```
2. If using WMPlayer.OCX, always call `$player.close()` and release the COM object in a `try/finally` block
3. The `SoundPlayer` approach is preferred for short notification sounds

**Detection:**
- Check Task Manager for multiple `wmplayer.exe` processes
- Audio playback becomes unreliable after many notifications

**Phase to address:**
Phase 1 (Cross-platform audio playback) -- this is the core user-facing behavior.

---

### Pitfall 6: `afplay` Concurrent Playback Causes AudioQueueStart Errors

**What goes wrong:**
On macOS, `afplay` is not designed for concurrent playback. If multiple notifications fire within the cooldown window but the cooldown logic fails (or before it takes effect), launching multiple `afplay` instances can trigger `AudioQueueStart` errors and require restarting `coreaudiod` to recover.

**Why it happens:**
`afplay` uses Apple's AudioQueue API, which has undocumented behavior when multiple instances access the same audio device simultaneously. The cooldown mechanism is supposed to prevent this, but if the cooldown fails (see Pitfall 3), rapid-fire notifications can trigger the issue.

**Consequences:**
Audio becomes completely broken on macOS until the user restarts `coreaudiod`:
```bash
sudo launchctl stop com.apple.audio.coreaudiod
sudo launchctl start com.apple.audio.coreaudiod
```
This affects ALL audio on the system, not just notifications.

**Prevention:**
1. Ensure the cooldown mechanism is rock-solid on macOS (fix Pitfall 3 first)
2. Add a process-level guard: check if `afplay` is already running before launching:
```bash
if pgrep -x afplay > /dev/null 2>&1; then
    exit 0  # Already playing, skip
fi
```
3. Redirect stderr to /dev/null and use `|| true` for safety

**Detection:**
- `afplay` produces `AudioQueueStart` errors in console output
- System audio stops working (no sound from any app)
- `coreaudiod` process needs restart

**Phase to address:**
Phase 1 (Cross-platform audio playback) -- defensive coding for macOS.

---

### Pitfall 7: Claude Code Hook `shell` Field Not Set for Windows PowerShell Hooks

**What goes wrong:**
On Windows, Claude Code hooks default to running via `bash` (if available via Git Bash/MINGW) or `cmd`. If the install script writes bash commands but the user's environment only has PowerShell, hooks fail silently. Conversely, if the install script writes PowerShell commands but Claude Code runs them via bash, they fail.

**Why it happens:**
Claude Code hooks support a `"shell": "powershell"` field on command hooks. Without it, Claude Code auto-detects the shell: it looks for `pwsh.exe` (PowerShell 7+) first, then `powershell.exe` (5.1), with a fallback to bash. The `shell` field tells Claude Code explicitly which shell to use for a specific hook. This feature exists but is not obvious from the default configuration.

**Consequences:**
- Bash commands fail if bash is not in PATH (common on fresh Windows installs without Git for Windows)
- PowerShell commands fail if Claude Code tries to run them via bash
- The install script works but hooks never execute

**Prevention:**
1. In install.ps1, set `"shell": "powershell"` on all hook entries
2. In install.sh (Linux/macOS), explicitly set `"shell": "bash"` (or omit since bash is default)
3. Document that Windows users need PowerShell 5.1+ (pre-installed on Windows 10/11) or PowerShell 7+
4. The `shell` field is the cleanest solution -- it lets each platform's install script configure hooks for the correct shell

**Detection:**
- On Windows, check `claude --debug` for "shell not found" or "command not found" errors
- If hooks fire but produce no output, the shell may be wrong
- Test: manually run the hook command in the target shell

**Phase to address:**
Phase 1 (Cross-platform install scripts) -- the `shell` field must be set correctly per platform.

---

### Pitfall 8: macOS `date +%s` Compatibility

**What goes wrong:**
The `notify-play.sh` script uses `date +%s` to get the current epoch time. On macOS, the BSD `date` command supports `%s` (seconds since epoch), but older BSD variants (FreeBSD 6.x, some macOS versions before Sierra) may not. In practice, all modern macOS versions (10.12+) support this, so this is LOW risk.

**Why it happens:**
GNU `date` and BSD `date` have different flag sets. The `%s` format specifier is supported on both GNU and modern BSD `date`, but was historically a GNU extension.

**Consequences:**
If `date +%s` fails, the arithmetic expression in the cooldown check produces an error. Under `set -euo pipefail`, this crashes the script.

**Prevention:**
1. Test on the minimum supported macOS version (likely 12 Monterey)
2. If paranoid, use `perl -e 'print time'` as a fallback (perl is always available on macOS)
3. In practice, `date +%s` works on macOS 10.12+, so this is low risk

**Detection:**
- Run `date +%s` on the target macOS version
- Check for "date: illegal option" or empty output

**Phase to address:**
Phase 1 (Cross-platform notify-play.sh) -- verify during macOS testing.

---

## Minor Pitfalls

### Pitfall 9: Windows `jq` Not Available Natively

**What goes wrong:**
The install and uninstall scripts depend on `jq` for JSON manipulation of `settings.json`. On Windows, `jq` is not pre-installed. The PowerShell approach using `ConvertTo-Json` has its own pitfalls (Pitfall 2).

**Prevention:**
1. Bundle `jq.exe` with the project for Windows, or check for it and provide install instructions
2. Alternative: have install.ps1 download `jq.exe` from GitHub releases
3. Alternative: write a PowerShell native JSON manipulation using `-Depth 10` (see Pitfall 2)
4. Git for Windows includes `jq.exe` in its PATH -- check `C:\Program Files\Git\usr\bin\jq.exe`

**Phase to address:**
Phase 1 (Cross-platform install scripts) -- decide jq strategy for Windows.

---

### Pitfall 10: macOS `afplay` Format Limitation (Irrelevant for MP3)

**What goes wrong:**
`afplay` only supports formats handled by Apple CoreAudio: AIFF, CAF, MP3, WAV, M4A, AAC. It cannot play OGG, Opus, FLAC, or other open-source formats.

**Why it happens:**
`afplay` relies on CoreAudio framework for format decoding.

**Prevention:**
This is a non-issue for the current project because the audio files are MP3, which CoreAudio fully supports. However, if the format ever changes to OGG or FLAC, this would break macOS playback without any error message (afplay fails silently on unsupported formats).

**Detection:**
- Test with actual audio files on macOS
- `afplay` produces no output on failure -- use file format check before playback

**Phase to address:**
Not a concern for v1.1 (MP3 format). Flag for future if audio format changes.

---

### Pitfall 11: Script Shebang Line (`#!/usr/bin/env bash`) on Windows

**What goes wrong:**
The shebang line `#!/usr/bin/env bash` is ignored by Windows native. If the user tries to run `notify-play.sh` directly from PowerShell or cmd, it fails. The script only works when invoked by Claude Code's hook runner, which handles shell selection.

**Prevention:**
1. Claude Code's `shell: "bash"` field handles this -- it invokes bash explicitly
2. For direct script testing on Windows, document that scripts must be run via `bash notify-play.sh`
3. The Windows install.ps1 should not try to execute bash scripts directly

**Phase to address:**
Phase 1 (Cross-platform install scripts) -- ensure scripts are invoked via the correct shell.

---

### Pitfall 12: PowerShell `SoundPlayer` Only Supports WAV Natively

**What goes wrong:**
The recommended `.NET SoundPlayer` class only natively supports WAV files. If the notification audio is MP3 (as in the current project), `SoundPlayer` throws an exception: "The wave header is corrupt."

**Why it happens:**
`System.Media.SoundPlayer` is a legacy .NET class built on Windows waveOut API. It only understands WAV format.

**Prevention:**
1. Use `WMPlayer.OCX` COM object for MP3 playback (with proper cleanup, see Pitfall 5)
2. Or use `System.Media.SoundPlayer` with WAV files instead of MP3
3. Or use `[System.Windows.Media.MediaPlayer]` from PresentationCore (supports MP3 but requires WPF/PresentationCore assembly loaded)
4. Or use `Invoke-Item $audioFile` which opens the file with the system default player (simplest but opens a visible window)
5. The simplest reliable approach for MP3 on Windows is:
```powershell
Add-Type -AssemblyName presentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$player.Open([System.Uri]::new("C:\path\to\notify.mp3"))
$player.Play()
Start-Sleep -Seconds 3  # Wait for notification to finish
$player.Close()
```

**Detection:**
- `SoundPlayer` constructor with MP3 path throws immediately
- Error: "The wave header is corrupt" or similar

**Phase to address:**
Phase 1 (Cross-platform audio playback) -- this directly affects which Windows audio approach to use.

---

## Architecture Pitfalls

### Pitfall 13: One Script to Rule Them All -- Cross-Platform Wrapper Complexity

**What goes wrong:**
Trying to make `notify-play.sh` work on all three platforms with OS detection leads to a fragile script that accumulates platform-specific branches. Every new platform adds complexity, and testing all combinations becomes impractical.

**Why it happens:**
The natural instinct is to modify the existing script rather than create new ones. But the three platforms have fundamentally different audio playback mechanisms:
- Linux: `paplay` (PulseAudio/PipeWire)
- macOS: `afplay` (CoreAudio)
- Windows: PowerShell/.NET (Windows Media APIs)

**Prevention:**
1. Keep `notify-play.sh` for Linux/macOS only (both are Unix-like)
2. Create a separate `notify-play.ps1` for Windows
3. Let the install scripts choose the correct wrapper per platform
4. The shared logic (cooldown, lock files, argument parsing) can be duplicated or extracted to a shared module
5. Alternatively, use the Claude Code `shell` field to invoke the correct script per platform

**Detection:**
- notify-play.sh grows beyond 50 lines with multiple `if [[ "$(uname)" == ... ]]` branches
- Testing matrix becomes 3 OS x 4 events = 12 combinations, each needing separate validation

**Phase to address:**
Phase 1 (Architecture decision) -- decide on single-script vs multi-script approach before writing code.

---

### Pitfall 14: Idempotency Across Different Install Scripts

**What goes wrong:**
The install.sh ensures idempotency via jq's JSON manipulation (setting the same hook entries replaces them). If install.ps1 uses a different JSON manipulation approach, running install.sh and then install.ps1 (or vice versa) may produce different JSON formatting or corrupt the hooks section.

**Why it happens:**
`jq` formats JSON with specific indentation and ordering. PowerShell's `ConvertTo-Json` uses different formatting (2-space indentation, different key ordering for objects). If a user switches platforms and re-runs the other install script, the JSON formatting changes but the content should remain the same -- unless the PowerShell script uses `-Depth` truncation (Pitfall 2).

**Prevention:**
1. Both install scripts should produce identical JSON structure for hooks
2. Test: run install.sh, verify hooks, then run install.ps1 on the same settings.json, verify hooks still work
3. Consider having both scripts use `jq` for JSON manipulation (jq.exe exists for Windows)
4. Or accept that switching platforms requires re-running the appropriate install script

**Detection:**
- Diff the settings.json before and after running the "other" platform's install
- Run `claude /hooks` to verify hooks are correctly registered after cross-platform install

**Phase to address:**
Phase 1 (Cross-platform install scripts) -- test cross-platform idempotency.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Cross-platform notify-play.sh | Pitfall 3 (stat incompatible), Pitfall 4 (TMPDIR), Pitfall 6 (afplay concurrency) | OS-detect stat flags, use $TMPDIR, add pgrep guard for afplay |
| Windows audio playback | Pitfall 5 (orphan processes), Pitfall 12 (SoundPlayer WAV-only) | Use MediaPlayer from PresentationCore, or WMPlayer.OCX with cleanup |
| install.ps1 JSON manipulation | Pitfall 2 (ConvertTo-Json depth), Pitfall 1 (backslash paths) | Use -Depth 10, always forward slashes in command strings |
| Hook shell configuration | Pitfall 7 (shell field not set) | Set `"shell": "powershell"` on Windows, `"shell": "bash"` on Linux/macOS |
| Architecture design | Pitfall 13 (one-script complexity), Pitfall 14 (cross-platform idempotency) | Separate bash and PowerShell scripts, use jq for JSON on all platforms |

---

## "Looks Done But Isn't" Checklist for Cross-Platform

- [ ] **macOS stat:** Does `stat -f %m` work on macOS? (or OS-detect stat flags)
- [ ] **macOS TMPDIR:** Does lock file creation work with `$TMPDIR` on macOS?
- [ ] **macOS afplay:** Does `afplay` play the MP3 files? (it should, MP3 is CoreAudio-supported)
- [ ] **macOS concurrency:** Does rapid-fire notification trigger AudioQueueStart errors?
- [ ] **Windows paths:** Do hook commands in settings.json use forward slashes?
- [ ] **Windows shell:** Do hooks have `"shell": "powershell"` set?
- [ ] **Windows audio:** Does the chosen audio approach (MediaPlayer/WMPlayer/Invoke-Item) play MP3 without leaving zombie processes?
- [ ] **Windows JSON:** Does install.ps1 preserve full hook structure without truncation?
- [ ] **Windows jq:** Is jq available, or does install.ps1 handle JSON correctly without it?
- [ ] **Cross-platform idempotency:** Can both install scripts safely run on the same settings.json?
- [ ] **Cooldown:** Does the 5-second cooldown work identically on all three platforms?
- [ ] **Error swallowing:** Since hooks are async, can you detect failures? (`claude --debug`)

---

## Sources

### HIGH Confidence (Official Documentation / Verified Issues)

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- `shell` field, async hooks, hook configuration schema, Windows PowerShell support (verified 2026-03-30)
- [GitHub Issue #26759: Windows backslash paths broken in 2.1.47](https://github.com/anthropics/claude-code/issues/26759) -- confirmed bug with backslash path stripping in hook commands (verified 2026-03-30)

### MEDIUM Confidence (Multiple Sources Agree)

- [PowerShell ConvertTo-Json default depth 2](https://stackoverflow.com/questions/53583677/unexpected-convertto-json-results-answer-it-has-a-default-depth-of-2) -- StackOverflow, PowerShell GitHub issues #8393 and #3181
- [GNU stat vs BSD stat differences](https://stackoverflow.com/q/22245576) -- StackOverflow, multiple shell scripting references
- [macOS /tmp vs $TMPDIR](https://news.ycombinator.com/item?id=41913610) -- Hacker News, conda GitHub issue #15440, macOS Ventura restrictions (Flutter issue #173450)
- [afplay format support](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/SupportedAudioFormatsMacOSX/SupportedAudioFormatsMacOSX.html) -- Apple Developer docs, OSXDaily confirmation
- [afplay limitations and concurrency issues](https://stackoverflow.com/q/27482091) -- StackOverflow, Reddit r/macOS discussions
- [PowerShell jq alternatives](https://ncox.dev/blog/jq-powershell/) -- dedicated jq-to-PowerShell translation guide

### LOW Confidence (Training Data / Unverified)

- `WMPlayer.OCX` orphan process issue -- based on training data knowledge of COM object lifecycle; no specific source verified
- `System.Media.SoundPlayer` WAV-only limitation -- well-known .NET constraint but no specific documentation linked
- `System.Windows.Media.MediaPlayer` for MP3 -- approach known from training data, recommended by community but not verified against latest .NET docs
- Windows `TEMP`/`TMP` environment variables -- standard convention but edge cases not verified

---
*Pitfalls research for: Claude Code voice notification system v1.1 cross-platform support*
*Researched: 2026-03-30*
