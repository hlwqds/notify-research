# Project Research Summary

**Project:** Claude Code Voice Notification System
**Domain:** Cross-platform audio notification hooks for Claude Code
**Researched:** 2026-03-30
**Confidence:** MEDIUM-HIGH

## Executive Summary

This project is a Claude Code hook-based voice notification system that plays pre-generated Chinese MP3 audio files when tasks complete, fail, or need user interaction. v1.0 shipped with Linux-only support using `paplay` for audio playback and bash scripts for install/uninstall/cooldown logic. v1.1 extends this to macOS and Windows.

The recommended approach is a **dual-script strategy**: extend existing bash scripts for macOS compatibility (macOS shares bash with Linux, differing only in the audio player command) and create separate PowerShell scripts for Windows. This avoids the fragile pattern of cross-platform bash on Windows, where 10+ open Claude Code GitHub issues document broken `.sh` hook execution. Claude Code provides a first-class `"shell": "powershell"` field on command hooks, which enables native PowerShell hook execution on Windows without any bash translation layer.

The key risks are concentrated on Windows: the Windows hooks subsystem is unstable with many open bugs, backslash paths in hook commands are silently stripped by Claude Code (confirmed bug #26759), and PowerShell's `ConvertTo-Json` truncates nested JSON by default. All three have well-documented mitigations (forward-slash paths, `-Depth 100`, and `MediaPlayer` for audio playback). macOS support is low-risk -- it requires only switching from `paplay` to `afplay` and fixing one GNU-only `stat` command.

## Key Findings

### Recommended Stack

The stack additions are minimal because audio files are pre-generated and platform-agnostic. The changes are confined to OS-specific playback commands and install scripts.

**Core platform technologies:**
- **`afplay` (macOS):** Built-in Apple CLI audio player, supports MP3 natively, zero install required -- the obvious choice for macOS playback
- **`System.Windows.Media.MediaPlayer` (Windows):** .NET PresentationCore assembly for MP3 playback. Avoid `SoundPlayer` (WAV-only) and `WMPlayer.OCX` (orphan processes). PowerShell built-in JSON cmdlets replace `jq` on Windows
- **Extended `install.sh` (Linux + macOS):** Single bash script with `uname` detection handles both Unix platforms. No separate macOS script needed
- **New `install.ps1` + `notify-play.ps1` (Windows):** Separate PowerShell scripts avoid the unreliable bash-on-Windows layer entirely

**Critical version constraints:**
- PowerShell `ConvertTo-Json -Depth 100` is mandatory (default depth 2 silently corrupts the nested hook JSON)
- macOS Bash 3.2 has no associative arrays -- current scripts do not use them, so no issue
- Backslash paths in `settings.json` hook commands fail silently on Windows -- always use forward slashes

### Expected Features

**Must have (table stakes):**
- T1: OS detection in install script (`uname -s`) -- root dependency for everything
- T2: macOS audio playback via `afplay` -- zero install, built into macOS
- T3: Windows audio playback via PowerShell `MediaPlayer` -- no third-party tools
- T4: Platform-specific hook commands in `settings.json` with `shell` field
- T5: Forward-slash paths in Windows hook commands (bug #26759 workaround)
- T6: Cross-platform cooldown in `notify-play.sh` (fix GNU-only `stat`)
- T7: Windows `install.ps1` with JSON manipulation
- T8: Windows `uninstall.ps1`
- T9: macOS support in `install.sh` (conditional prerequisite check)

**Should have (competitive):**
- D1: Unified install.sh with OS auto-detection (naturally falls out of T1)
- D2: Audio player fallback chain (`paplay` -> `aplay` on Linux)
- D3: Hook verification smoke test after install

**Defer (v2+):**
- D4: pwsh.exe auto-detection in install.ps1 (Claude Code handles this automatically)
- Volume control per notification (system volume controls suffice)
- Cross-platform Node.js rewrite of `notify-play.sh` (unnecessary complexity for 27-line scripts)

### Architecture Approach

The architecture splits cleanly into three layers: (1) a platform detection layer in install scripts that selects the correct audio player and writes platform-appropriate hook commands, (2) a shared layer of pre-generated MP3 files and identical cooldown semantics, and (3) a platform-specific playback layer using native OS audio commands.

**Major components:**
1. **`notify-play.sh` (modified)** -- Cooldown wrapper + audio playback for Linux and macOS. OS detection via `uname` selects `paplay` or `afplay`. Must fix `stat -c %Y` to work on macOS.
2. **`notify-play.ps1` (new)** -- Windows cooldown wrapper using `$env:TEMP` lock files and `MediaPlayer` for MP3 playback. Parallels bash version structure.
3. **`install.sh` (modified)** -- Linux + macOS install. Adds OS-conditional prerequisite check (`afplay` vs `paplay`). Hook commands unchanged since `notify-play.sh` handles player selection internally.
4. **`install.ps1` (new)** -- Windows install. Uses PowerShell `ConvertFrom-Json`/`ConvertTo-Json` with `-Depth 100`. Sets `"shell": "powershell"` on all hook entries. No `jq` dependency.
5. **`uninstall.sh` / `uninstall.ps1`** -- Remove hook entries and delete audio files. Mirror the install scripts per platform.

**Key architectural decision:** Keep bash for Linux/macOS, add separate PowerShell for Windows. Do NOT try to make one script work on all three platforms -- the three OSes have fundamentally different audio subsystems.

### Critical Pitfalls

1. **Windows backslash paths silently fail in hook commands** -- Claude Code >= 2.1.47 strips backslashes as escape characters. All Windows hook commands must use forward slashes (`C:/Users/...` not `C:\Users\...`). This is the highest-priority pitfall because it causes silent failures with no visible error.

2. **PowerShell `ConvertTo-Json` truncates nested objects at depth 2** -- The hook structure is 5 levels deep. Without `-Depth 100`, `install.ps1` silently corrupts `settings.json`. Always use `-Depth 100`.

3. **`stat -c %Y` is GNU-only and crashes on macOS** -- The existing cooldown mechanism in `notify-play.sh` uses Linux-specific `stat` flags. Fix with OS detection or use `date -r file +%s` (works on both BSD and GNU).

4. **`WMPlayer.OCX` leaves orphan processes** -- The COM-based Windows Media Player creates zombie processes (~30MB each) if not cleaned up. Use `System.Windows.Media.MediaPlayer` from PresentationCore instead, which is lighter and does not have this problem.

5. **Claude Code Windows hooks are unstable** -- 10+ open GitHub issues document broken `.sh` execution, path resolution failures, and hangs. The `"shell": "powershell"` field provides a clean workaround. Test on Windows early and monitor Claude Code updates for breaking changes.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: macOS Support (Extend Existing Scripts)

**Rationale:** macOS shares bash with Linux. This is the lowest-risk cross-platform extension -- it requires only changing the audio player command and fixing one `stat` incompatibility. It proves the OS-detection pattern before tackling the more complex Windows story.

**Delivers:** Working `install.sh` / `uninstall.sh` / `notify-play.sh` on both Linux and macOS.

**Addresses:** T1 (OS detection), T2 (afplay), T6 (cross-platform cooldown), T9 (macOS install.sh), D1 (unified install.sh)

**Avoids:** Pitfall 3 (stat incompatibility), Pitfall 4 (TMPDIR)

**Research flag:** SKIP -- macOS support is well-documented with high-confidence sources. `afplay` is a standard Apple tool, and the stat fix is a well-known bash portability pattern.

### Phase 2: Windows Playback Wrapper

**Rationale:** The Windows audio playback script (`notify-play.ps1`) is independent of the install scripts and can be developed and tested in isolation. Getting MediaPlayer working correctly on Windows is the highest-risk technical piece, so it should be validated before building the install/uninstall tooling around it.

**Delivers:** `notify-play.ps1` that plays MP3 via `MediaPlayer` with 5-second cooldown using `$env:TEMP` lock files.

**Addresses:** T3 (Windows MediaPlayer), T5 (forward-slash paths in hook commands)

**Avoids:** Pitfall 5 (orphan processes), Pitfall 12 (SoundPlayer WAV-only)

**Research flag:** NEEDS VALIDATION -- `MediaPlayer` approach for MP3 from PowerShell is community-documented but not verified against latest .NET on actual Windows hardware during this research session. The Claude Code `"shell": "powershell"` field is officially documented but Windows hooks have many open bugs.

### Phase 3: Windows Install/Uninstall Scripts

**Rationale:** Once the playback wrapper works, build the install scripts that wire everything together. This phase has the most pitfalls (JSON depth, BOM encoding, path normalization, idempotency) but they are all well-understood with clear mitigations.

**Delivers:** `install.ps1` and `uninstall.ps1` that copy audio files, inject hooks with `"shell": "powershell"`, and handle all JSON manipulation correctly.

**Addresses:** T4 (platform-specific hooks), T7 (install.ps1), T8 (uninstall.ps1)

**Avoids:** Pitfall 1 (backslash paths), Pitfall 2 (JSON depth truncation), Pitfall 7 (shell field), Pitfall 14 (cross-platform idempotency)

**Research flag:** STANDARD PATTERNS -- PowerShell JSON manipulation is well-documented. The main risk is the interaction between Claude Code's hook execution on Windows and PowerShell, which can only be validated by testing on actual Windows.

### Phase Ordering Rationale

- macOS first because it is a 2-hour modification to existing scripts with near-zero risk
- Windows playback second because it is the highest-risk technical component and needs validation before investing in install scripts
- Windows install third because it depends on the playback wrapper being correct, but once that is validated, the install scripts are straightforward PowerShell with well-known patterns
- Linux/macOS (Phase 1) and Windows (Phases 2-3) are independent tracks and can be developed in parallel
- Windows Desktop App compatibility (issue #29560) should be checked early but is not a blocker for CLI users

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Windows MediaPlayer behavior when invoked from Claude Code hook context -- community-documented but not verified on actual Windows. Claude Code Windows Desktop App hook support is unknown.
- **Phase 3:** PowerShell 5.1 vs PowerShell 7 JSON handling differences (minor, `-Depth 100` works on both). UTF-8 BOM handling in PS 5.1 `Set-Content -Encoding UTF8` (PS 5.x writes UTF-8 with BOM, PS 7 does not).

Phases with standard patterns (skip research-phase):
- **Phase 1:** macOS support is well-understood. `afplay` is a standard Apple utility. `stat` portability is a classic bash problem with established solutions. High confidence across all sources.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Audio playback tools are OS built-ins with official documentation. Windows approach has multiple viable options with clear tradeoffs documented. |
| Features | HIGH | 9 table-stakes features identified from official Claude Code hooks docs, existing codebase analysis, and platform documentation. Feature dependencies mapped explicitly. |
| Architecture | HIGH | Clean three-layer architecture with clear platform boundaries. Build order validated. The `"shell": "powershell"` discovery simplifies Windows support significantly. |
| Pitfalls | MEDIUM-HIGH | 14 pitfalls identified with clear mitigations. Top 4 are well-documented with verified sources. Windows-specific pitfalls (especially hook execution instability) carry medium confidence because the platform is unstable with many open Claude Code bugs. |

**Overall confidence:** MEDIUM-HIGH

The research is high-confidence for the recommended approach and architecture. The medium component comes from Windows: the Claude Code hooks subsystem on Windows has 10+ open bugs, and the `MediaPlayer` approach for audio playback, while community-documented, has not been verified on actual Windows during this research session. macOS support is straightforward and high-confidence throughout.

### Gaps to Address

- **Windows MediaPlayer in hook context:** The `MediaPlayer` approach needs validation on actual Windows to confirm it works when PowerShell is invoked from Claude Code's hook runner. If it fails, `WMPlayer.OCX` with proper cleanup is the fallback.
- **Windows Desktop App hook support:** GitHub issue #29560 suggests hooks may not execute on the Claude Code Windows Desktop App. If the target audience uses the Desktop App, this could be a showstopper for Windows support.
- **PowerShell UTF-8 BOM:** PowerShell 5.1 `Set-Content -Encoding UTF8` writes UTF-8 with BOM, which may confuse Claude Code's JSON parser. Need to test and potentially use `[System.IO.File]::WriteAllText()` instead.
- **Cross-platform idempotency:** Running `install.sh` and then `install.ps1` on the same `settings.json` (or vice versa) may produce different JSON formatting. The content should be identical but this has not been tested.
- **PowerShell execution policy:** Windows may block `.ps1` scripts by default. Install instructions need to address `Set-ExecutionPolicy RemoteSigned` or equivalent.

## Sources

### Primary (HIGH confidence)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- `"shell"` field, async hooks, timeout, hook events
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide) -- cross-platform hook patterns, Windows PowerShell example
- [GitHub Issue #26759](https://github.com/anthropics/claude-code/issues/26759) -- Windows backslash path bug confirmed in Claude Code >= 2.1.47
- [GitHub Issue #32930](https://github.com/anthropics/claude-code/issues/32930) -- Claude Code hooks on Windows always use Git Bash, ignoring `shell` setting
- Existing codebase: `scripts/install.sh`, `scripts/uninstall.sh`, `scripts/notify-play.sh` -- analyzed for v1.0 architecture and portability issues

### Secondary (MEDIUM confidence)
- [Stack Overflow -- Play MP3 with PowerShell](https://stackoverflow.com/questions/25895428) -- `SoundPlayer` WAV-only limitation, `MediaPlayer` for MP3
- [Stack Overflow -- stat differences macOS vs Linux](https://stackoverflow.com/questions/10666570) -- GNU vs BSD `stat` flag incompatibility
- [PowerShell `ConvertTo-Json` depth issue](https://stackoverflow.com/questions/53583677) -- default depth 2 truncation
- [GitHub Issue #29560](https://github.com/anthropics/claude-code/issues/29560) -- Hooks don't execute on Windows Desktop App
- [claude.fast -- Cross-platform hooks](https://claude.fast/blog/tools/hooks/cross-platform-hooks) -- Node.js cross-platform approach (alternative considered, rejected)

### Tertiary (LOW confidence)
- `WMPlayer.OCX` orphan process behavior -- based on training data, no specific source verified
- `System.Windows.Media.MediaPlayer` from PresentationCore -- community-documented but not tested on actual Windows during this research
- Windows TEMP/TMP environment variables -- standard convention, edge cases not verified

---
*Research completed: 2026-03-30*
*Ready for roadmap: yes*
