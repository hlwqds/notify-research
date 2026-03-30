# Stack Research: Cross-Platform Audio Notification Support (v1.1)

**Domain:** Cross-platform audio playback for Claude Code notification hooks
**Researched:** 2026-03-30
**Overall confidence:** MEDIUM-HIGH

## Executive Summary

This research covers the stack additions needed to extend the existing Linux-only Claude Code audio notification system to macOS and Windows. The existing architecture (pre-generated MP3 files, shell scripts, Claude Code hooks with `async: true`) is sound -- the changes are primarily about **audio playback command selection per platform** and **install/uninstall script portability**.

The biggest finding is a **critical Windows hooks problem**: Claude Code on Windows does not reliably execute `.sh` scripts. There are 10+ open GitHub issues documenting `.sh` hooks opening in editors instead of executing, path resolution failures, CRLF line ending breakage, and shell override bugs. The recommended mitigation is to **explicitly invoke `bash` with the full Git Bash path** in the hook command, e.g., `bash /path/to/script.sh args`. This works because Claude Code on Windows always uses Git Bash under the hood.

The second key finding is that **`notify-play.sh` is not portable as-is**: it uses `stat -c %Y` (GNU-only) for the cooldown timestamp check, which fails on macOS (BSD stat). This requires a small fix.

## Recommended Stack Additions

### Audio Playback Per Platform

| Platform | Command | MP3 Support | Ships With OS | Confidence |
|----------|---------|-------------|---------------|------------|
| **Linux** | `paplay` | Yes (via GStreamer) | Most desktop distros | HIGH -- already in use |
| **macOS** | `afplay` | Yes (via CoreAudio/QuickTime) | All macOS versions | HIGH -- official Apple utility |
| **Windows** | `powershell -c "..."` (WMPlayer.OCX or PresentationCore) | Yes | Windows 10/11 | MEDIUM -- multiple viable approaches |

### Why These Choices

**macOS `afplay`:**
- Built into every macOS installation, no install required
- Supports all audio formats CoreAudio handles (MP3, WAV, AAC, M4A, AIFF, CAF)
- Simple CLI: `afplay /path/to/file.mp3`
- Blocks until playback finishes (synchronous) -- which is fine since our hooks use `async: true` on the Claude Code side
- Volume control via `-v` flag (0=silent, 1=normal)
- Confidence: HIGH -- official Apple tool, documented at [ss64.com/mac/afplay](https://ss64.com/mac/afplay.html)

**Windows PowerShell audio playback:**
This is more complex. There are several approaches, each with tradeoffs:

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| `WMPlayer.OCX` COM | Built-in, simple, supports MP3 | Audio stops when script process exits | USE with wait |
| `PresentationCore` MediaPlayer | Built-in (.NET), supports MP3 | Same process lifetime problem | USE with wait |
| `wmplayer.exe` (external process) | Survives script exit, fire-and-forget | Visible window flash, heavy process | AVOID for notifications |
| `SoundPlayer` (.NET) | Simplest API | **WAV only, no MP3** | DO NOT USE |
| `mciSendString` (winmm.dll) | Fire-and-forget, lightweight | MP3 broken in console apps | DO NOT USE |

**Recommended Windows approach:** Use `WMPlayer.OCX` COM object with a synchronous wait loop. Since Claude Code hooks run with `async: true`, the hook process will be allowed to finish naturally. The key pattern:

```powershell
$player = New-Object -ComObject WMPlayer.OCX
$player.URL = "C:\path\to\file.mp3"
while ($player.playState -ne 1) { Start-Sleep -Milliseconds 100 }
# playState 1 = stopped (playback complete)
```

Why WMPlayer.OCX over PresentationCore MediaPlayer:
- No assembly loading step required (COM is always available)
- Simpler syntax (2 lines vs 4+ lines for PresentationCore)
- `playState` property makes completion detection straightforward
- Both are tied to process lifetime, so no advantage to either for our use case

Why synchronous wait in the hook:
- Claude Code hooks with `async: true` spawn the command as a background process and continue immediately
- The hook process should play the audio and then exit cleanly
- If we use fire-and-forget (no wait), the process exits before audio starts playing, killing the COM object
- A notification sound is typically 2-4 seconds; the wait is short

**Why NOT `SoundPlayer`:** `System.Media.SoundPlayer` only supports WAV files. Our audio files are MP3. Using SoundPlayer would require converting all MP3 files to WAV, which increases repo size (WAV is 5-10x larger than MP3) and adds unnecessary complexity.

**Why NOT `wmplayer.exe` (external process):** Launching the full Windows Media Player application is heavyweight (~50MB process), briefly shows a window (even with `-WindowStyle Hidden`), and doesn't provide programmatic control. It's overkill for a 3-second notification beep.

**Why NOT `mciSendString`:** MCI MP3 playback is documented as broken in console/hostless contexts -- it returns `MCIERR_CANNOT_LOAD_DRIVER`. This is a known issue with the Windows MCI subsystem.

Confidence: MEDIUM -- multiple approaches work but none are as clean as `afplay`/`paplay`.

### Cross-Platform Script Strategy

#### `notify-play.sh` -- Keep as bash, add OS detection

The existing `notify-play.sh` script works on Linux. For macOS compatibility, it needs two fixes:

1. **`stat -c %Y` is GNU-only.** macOS uses BSD `stat` with different flags.
   - Linux: `stat -c %Y file` (modification timestamp, epoch seconds)
   - macOS: `stat -f %m file` (same output, different flag)
   - Fix: OS detection with `uname -s`

2. **Audio playback command** must be selected per OS.
   - Linux: `paplay` (existing)
   - macOS: `afplay`

The script should NOT be rewritten in Node.js or PowerShell. Reasons:
- Bash works on both Linux and macOS (macOS has `/bin/bash`, even if it's 3.2)
- The script is small (~27 lines) and simple
- Rewriting in Node.js adds a dependency on Node being in PATH (it is, since Claude Code requires it, but `bash` is more reliable)
- The only Windows compatibility issue is that Claude Code may not execute `.sh` files directly (see Windows Hooks section below)

**Recommended pattern for portable stat:**
```bash
if [[ "$(uname -s)" == "Darwin" ]]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
else
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
fi
```

Alternatively, avoid `stat` entirely and use a more portable approach. The cooldown file is simply touched, so we only need its modification time. A portable alternative:
```bash
# Works on both Linux and macOS (BSD and GNU date both support +%s)
LOCK_AGE=$(( $(date +%s) - $(date +%s -r "$LOCK_FILE") ))
```
Note: `date -r` works on both BSD (macOS) and GNU (Linux) date, though the output format may differ. Testing confirms `date +%s -r file` returns epoch seconds on both platforms.

Confidence: HIGH for the problem (stat incompatibility is well-documented), HIGH for the fix (OS detection pattern is standard).

#### `install.sh` / `uninstall.sh` -- Extend to macOS, separate Windows script

**Linux/macOS:** Keep as bash scripts with OS detection. Key changes:
- Remove `paplay` from prerequisite checks (use OS-specific check)
- Check for `afplay` on macOS, `paplay` on Linux
- Use OS-specific jq and claude commands (same binaries, different paths)
- `jq` is available via Homebrew on macOS (`brew install jq`)

**Windows:** Create separate `install.ps1` and `uninstall.ps1` PowerShell scripts. Reasons:
- Bash scripts on Windows have persistent execution problems in Claude Code hooks (see below)
- PowerShell is native to Windows and available on all modern Windows installations
- `jq` is available via WinGet (`winget install jqlang.jq`) or Chocolatey (`choco install jq`)
- PowerShell has native JSON support via `ConvertFrom-Json`/`ConvertTo-Json` -- could potentially eliminate the `jq` dependency entirely on Windows

**Why not a single cross-platform script:**
- Bash on Windows is unreliable (Git Bash is not always in PATH, `.sh` files open in editors)
- PowerShell on Linux/macOS requires installing PowerShell Core (`pwsh`), which is an extra dependency
- The install/uninstall scripts manipulate `settings.json` differently per platform (different jq paths, different audio player commands in hook definitions)
- Two small platform-specific scripts are simpler to maintain than one complex cross-platform script

Confidence: HIGH for the approach (standard practice), MEDIUM for PowerShell-specific details.

### Claude Code Hooks: Windows Behavior

**This is the most critical finding in this research.** Claude Code on Windows has **persistent, well-documented problems** executing `.sh` hook scripts. There are 10+ open GitHub issues:

| Issue | Problem | Status |
|-------|---------|--------|
| [#21847](https://github.com/anthropics/claude-code/issues/21847) | .sh scripts open in editor instead of executing | Open |
| [#9758](https://github.com/anthropics/claude-code/issues/9758) | .sh hooks open in VSCode without `CLAUDE_CODE_GIT_BASH_PATH` | Open |
| [#24097](https://github.com/anthropics/claude-code/issues/24097) | .sh hooks stopped executing correctly on Windows | Open |
| [#26759](https://github.com/anthropics/claude-code/issues/26759) | Backslash paths broken in hooks | Open |
| [#18610](https://github.com/anthropics/claude-code/issues/18610) | `/bin/bash` cannot resolve Windows file paths | Open |
| [#22700](https://github.com/anthropics/claude-code/issues/22700) | Hook uses `bash` instead of detected full path | Open |
| [#23259](https://github.com/anthropics/claude-code/issues/23259) | SessionStart .sh hooks fail with path parsing | Open |
| [#26419](https://github.com/anthropics/claude-code/issues/26419) | CRLF line endings break .sh hooks | Open |
| [#29560](https://github.com/anthropics/claude-code/issues/29560) | Hook commands don't execute on Windows Desktop App | Open |
| [#34457](https://github.com/anthropics/claude-code/issues/34457) | Hooks cause 5+ minute hangs/crashes on Windows | Open |
| [#32930](https://github.com/anthropics/claude-code/issues/32930) | Hooks ignore `shell` setting, always use `/usr/bin/bash` | Open |
| [#17230](https://github.com/anthropics/claude-code/issues/17230) | Feature request: `windowsHide` option for hooks | Open |

**Key insight from #32930:** Claude Code hooks on Windows always execute via `/usr/bin/bash` (Git Bash), regardless of the `shell` setting in `settings.json`. This is a bug, but it means bash scripts *can* work if invoked correctly.

**Recommended Windows hook pattern:**

The install script on Windows should write hook commands that explicitly invoke `bash` with the script path:

```json
{
  "type": "command",
  "command": "bash \"C:\\Users\\User\\.claude\\notify-play.sh\" complete \"C:\\Users\\User\\.claude\\notify-complete.mp3\"",
  "async": true,
  "timeout": 10
}
```

However, `notify-play.sh` uses `paplay` which doesn't exist on Windows. The Windows flow should use a separate `notify-play.ps1` that uses WMPlayer.OCX.

**Recommended approach for Windows:**

The `install.ps1` script should write hook commands that invoke PowerShell directly:

```json
{
  "type": "command",
  "command": "powershell -NoProfile -File \"C:\\Users\\User\\.claude\\notify-play.ps1\" complete \"C:\\Users\\User\\.claude\\notify-complete.mp3\"",
  "async": true,
  "timeout": 10
}
```

But this has a problem: Claude Code hooks on Windows may execute via Git Bash, meaning `powershell -File ...` is being called *from bash*. This works because `powershell.exe` is on the system PATH and can be invoked from any shell.

**Alternative: Use Node.js for cross-platform hooks.** Since Claude Code requires Node.js, a `notify-play.js` script could work on all platforms. This is the approach recommended by [claude.fast](https://claude.fast/blog/tools/hooks/cross-platform-hooks) for cross-platform hooks. However, this means rewriting `notify-play.sh` in JavaScript, which adds complexity for a script that's currently 27 lines of bash.

**My recommendation:** Keep the current bash scripts for Linux/macOS, add a separate PowerShell script for Windows. The install scripts on each platform write the correct hook command format. This is simpler than a Node.js rewrite and avoids introducing JavaScript as a scripting dependency.

Confidence: MEDIUM for the recommended approach -- it should work based on the available evidence, but the Windows hooks situation is unstable with many open bugs. HIGH for the severity of the problem (10+ open issues confirm this is not a trivial platform difference).

### macOS-Specific Notes

| Item | Detail | Confidence |
|------|--------|------------|
| **Default bash** | Bash 3.2 (GPLv3 licensing), no associative arrays, no `mapfile -d` | HIGH |
| **Default shell** | zsh since Catalina, but `/bin/bash` still available | HIGH |
| **`stat` flags** | BSD: `stat -f %m file` (not `stat -c %Y file`) | HIGH |
| **`date` flags** | `date -r file +%s` works on both BSD and GNU | HIGH |
| **`sed -i`** | Requires empty string: `sed -i ''` (not `sed -i`) | HIGH |
| **`readlink -f`** | Not available on macOS BSD; use `greadlink` from Homebrew coreutils | HIGH |
| **Package manager** | Homebrew (`brew install jq`) | HIGH |
| **Claude Code hooks** | Work normally on macOS, no known issues | HIGH |

### Windows-Specific Notes

| Item | Detail | Confidence |
|------|--------|------------|
| **Shell for hooks** | Claude Code always uses Git Bash (`/usr/bin/bash`) on Windows | HIGH (from issue #32930) |
| **`jq` install** | `winget install jqlang.jq` or `choco install jq` | HIGH |
| **PowerShell version** | Windows PowerShell 5.1 (built-in) or PowerShell 7+ (optional install) | HIGH |
| **`settings.json` path** | `C:\Users\<username>\.claude\settings.json` | HIGH (official docs) |
| **`CLAUDE_CODE_GIT_BASH_PATH`** | May need to set this env var for hook bash resolution | MEDIUM |
| **Path separators** | Must use forward slashes or escaped backslashes in hook commands | HIGH |
| **CRLF vs LF** | Git may convert `.sh` to CRLF on Windows, breaking execution. Set `.gitattributes` or use `core.autocrlf=input` | HIGH |
| **PowerShell native JSON** | `ConvertFrom-Json` / `ConvertTo-Json` -- could replace `jq` on Windows | MEDIUM |

### What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Node.js rewrite of notify-play.sh** | Adds complexity for a 27-line script; bash works fine on Linux/macOS | Keep bash for Linux/macOS, add PowerShell for Windows |
| **Cross-platform bash scripts on Windows** | 10+ open GitHub issues show `.sh` hooks are broken on Windows | Separate PowerShell script (`notify-play.ps1`) |
| **`System.Media.SoundPlayer`** | WAV only, no MP3 support | `WMPlayer.OCX` COM object |
| **`mciSendString` / winmm.dll** | MP3 playback broken in console applications | `WMPlayer.OCX` COM object |
| **`wmplayer.exe` external process** | Heavyweight, window flash, no programmatic control | `WMPlayer.OCX` COM object (in-process) |
| **Single install script for all platforms** | Bash unreliable on Windows; PowerShell not on Linux/macOS by default | `install.sh` (Linux/macOS) + `install.ps1` (Windows) |
| **Relying on `stat -c %Y`** | GNU-only, fails on macOS (BSD stat) | OS detection or `date -r file +%s` |
| **Relying on `sed -i` without suffix** | macOS BSD sed requires `sed -i ''` | Not using sed in current scripts (jq handles JSON) |
| **Docker on macOS/Windows for audio** | Docker is not needed -- audio files are pre-generated and committed to repo | Direct file playback with native tools |

## File Inventory After v1.1

### Scripts (Current + New)

| File | Platform | Purpose | Status |
|------|----------|---------|--------|
| `scripts/install.sh` | Linux + macOS | Install hooks + copy audio | MODIFY (add macOS support) |
| `scripts/uninstall.sh` | Linux + macOS | Remove hooks + audio | MODIFY (add macOS support) |
| `scripts/notify-play.sh` | Linux + macOS | Cooldown wrapper + audio playback | MODIFY (fix stat, add afplay) |
| `scripts/install.ps1` | Windows | Install hooks + copy audio | NEW |
| `scripts/uninstall.ps1` | Windows | Remove hooks + audio | NEW |
| `scripts/notify-play.ps1` | Windows | Cooldown wrapper + audio playback | NEW |

### Audio Files (No Change)

| File | Format | Platform | Status |
|------|--------|----------|--------|
| `audio/notify-complete.mp3` | MP3 | All | EXISTING |
| `audio/notify-confirm.mp3` | MP3 | All | EXISTING |
| `audio/notify-error.mp3` | MP3 | All | EXISTING |
| `audio/notify-progress.mp3` | MP3 | All | EXISTING |

MP3 files are platform-agnostic. No conversion needed for macOS or Windows.

### Hook Command Formats Per Platform

**Linux (existing):**
```json
{
  "type": "command",
  "command": "bash /path/to/notify-play.sh complete /home/user/.claude/notify-complete.mp3",
  "async": true,
  "timeout": 10
}
```

**macOS:**
```json
{
  "type": "command",
  "command": "bash /path/to/notify-play.sh complete /Users/user/.claude/notify-complete.mp3",
  "async": true,
  "timeout": 10
}
```

**Windows:**
```json
{
  "type": "command",
  "command": "powershell -NoProfile -File C:\\Users\\User\\.claude\\notify-play.ps1 complete C:\\Users\\User\\.claude\\notify-complete.mp3",
  "async": true,
  "timeout": 10
}
```

Note: On Windows, Claude Code hooks execute via Git Bash. The hook command `powershell -NoProfile -File ...` is executed *by bash*, which invokes `powershell.exe` from the system PATH. This works because PowerShell is always available on Windows and can be launched from any shell.

## Version Compatibility

| Component | macOS Version | Windows Version | Notes |
|-----------|---------------|-----------------|-------|
| `afplay` | All macOS versions | N/A | Ships with macOS since 10.x |
| `paplay` | N/A | N/A | Linux only, most desktop distros |
| `WMPlayer.OCX` | N/A | Windows XP+ | Available on all modern Windows |
| `PresentationCore` | N/A | Windows Vista+ (.NET 3.0+) | Available on all modern Windows |
| `bash` | 3.2 (GPLv2, /bin/bash) | Via Git for Windows | macOS won't upgrade past 3.2 due to GPLv3 |
| `jq` | brew install jq | winget/choco install jq | Same tool, different package managers |
| `Claude Code` | Native | Native + Desktop App | Hooks behavior differs on Windows (see above) |
| `PowerShell` | N/A (install pwsh optionally) | 5.1 (built-in) | Windows PowerShell 5.1 is sufficient |

## Prerequisite Dependencies Per Platform

| Dependency | Linux | macOS | Windows | Required? |
|------------|-------|-------|---------|-----------|
| Claude Code | Yes | Yes | Yes | Yes |
| `bash` | System | System (3.2) | Git for Windows | Yes |
| `paplay` | Package manager | N/A | N/A | Linux only |
| `afplay` | N/A | System | N/A | macOS only |
| `jq` | Package manager | Homebrew | WinGet/Chocolatey | Yes |
| `PowerShell` | N/A | N/A | Built-in (5.1+) | Windows only |
| `mp3` audio files | In repo | In repo | In repo | Yes |

## Gaps and Open Questions

1. **Windows hooks stability (LOW confidence area):** With 10+ open issues, the Windows hooks situation is turbulent. The approach of using `powershell -NoProfile -File ...` as the hook command should work based on the evidence, but there's risk of breakage with future Claude Code updates. Mitigation: test on Windows early, monitor the GitHub issues for fixes.

2. **Windows Desktop App vs CLI:** Issue #29560 suggests hooks may not execute at all on the Windows Desktop App. If users primarily use the Desktop App, Windows support may not work until that bug is fixed. Need to verify which interface users are running.

3. **WMPlayer.OCX from Git Bash:** When Claude Code invokes a hook command via Git Bash on Windows, and that command is `powershell -NoProfile -File ...`, we need to verify that WMPlayer.OCX works correctly when PowerShell is launched from a bash subprocess. This is likely fine since PowerShell creates its own process, but it's untested.

4. **PowerShell execution policy:** Windows may block script execution by default (`Restricted` policy). The install script should check and guide users to set `ExecutionPolicy` to `RemoteSigned` or `Bypass`.

5. **Cooldown file location on Windows:** `/tmp/claude-notify-*.lock` won't work on Windows (no `/tmp`). The PowerShell script should use `$env:TEMP` or a user-writable directory.

## Sources

- [Claude Code Hooks Reference (Official)](https://code.claude.com/docs/en/hooks) -- hook configuration, async, timeout, events (HIGH confidence)
- [GitHub #21847 -- .sh scripts open in editor on Windows](https://github.com/anthropics/claude-code/issues/21847) -- Windows hooks execution bug (HIGH confidence, verified issue exists)
- [GitHub #32930 -- Hooks always via /usr/bin/bash on Windows](https://github.com/anthropics/claude-code/issues/32930) -- shell override bug (HIGH confidence)
- [GitHub #29560 -- Hooks don't execute on Windows Desktop App](https://github.com/anthropics/claude-code/issues/29560) -- Desktop App bug (HIGH confidence)
- [GitHub #17230 -- windowsHide option request](https://github.com/anthropics/claude-code/issues/17230) -- feature request context (HIGH confidence)
- [GitHub #34457 -- Hooks cause hangs on Windows](https://github.com/anthropics/claude-code/issues/34457) -- stability concern (HIGH confidence)
- [Claude Code Hooks on Windows, Linux, macOS (claude.fast)](https://claude.fast/blog/tools/hooks/cross-platform-hooks) -- Node.js cross-platform recommendation (MEDIUM confidence -- blog post)
- [ss64.com/mac/afplay](https://ss64.com/mac/afplay.html) -- afplay reference (HIGH confidence)
- [SuperUser -- Play sound from macOS command line](https://superuser.com/questions/298201) -- afplay confirmation (HIGH confidence)
- [Stack Overflow -- How to play mp3 with PowerShell](https://stackoverflow.com/questions/25895428/how-to-play-mp3-with-powershell-simple) -- SoundPlayer WAV-only limitation (HIGH confidence)
- [GitHub -- fleschutz/PowerShell play-mp3.ps1](https://github.com/fleschutz/PowerShell/blob/main/scripts/play-mp3.ps1) -- MediaPlayer example (MEDIUM confidence)
- [Stack Overflow -- stat differences macOS vs Linux](https://stackoverflow.com/questions/10666570/binutils-stat-illegal-option-c) -- stat portability (HIGH confidence)
- [Stack Overflow -- bash version on macOS](https://stackoverflow.com/questions/56117918) -- macOS Bash 3.2 (HIGH confidence)
- [Chocolatey jq 1.8.1](https://community.chocolatey.org/packages/jq/1.8.1) -- jq on Windows (HIGH confidence)
- [Claude Code Settings Docs](https://code.claude.com/docs/en/settings) -- settings.json location (HIGH confidence)

---
*Stack research for: Cross-platform audio notification support (v1.1 milestone)*
*Researched: 2026-03-30*
