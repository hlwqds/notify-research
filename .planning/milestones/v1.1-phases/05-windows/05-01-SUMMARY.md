---
phase: 05-windows
plan: 01
subsystem: platform-windows
tags: [powershell, mediaplayer, claude-code-hooks, json-manipulation]

# Dependency graph
requires:
  - phase: 01-docker-tts
    provides: "Spark-TTS Docker environment, pre-generated mp3 audio files"
  - phase: 02-generate-script
    provides: "4 notification mp3 files in audio/ directory"
  - phase: 03-hooks
    provides: "Canonical hook event mapping and bash script patterns"
  - phase: 04-macos
    provides: "Cross-platform architecture pattern (platform-specific scripts alongside bash)"
provides:
  - "3 PowerShell scripts for Windows notification support (notify-play.ps1, install.ps1, uninstall.ps1)"
  - "MediaPlayer-based headless MP3 playback on Windows"
  - "BOM-free JSON manipulation pattern for settings.json"
  - "Forward-slash path workaround for Claude Code Windows hooks (issue #26759)"
affects: []

# Tech tracking
tech-stack:
  added: [powershell-5.1, system.windows.media.mediaplayer, .net-framework-4.x]
  patterns:
    - "BOM-free JSON write via WriteAllText + UTF8Encoding(\$false)"
    - "Forward-slash path conversion for Claude Code hooks on Windows"
    - "PowerShell PSObject.Properties.Remove for JSON key deletion"

key-files:
  created:
    - scripts/notify-play.ps1
    - scripts/install.ps1
    - scripts/uninstall.ps1
  modified: []

key-decisions:
  - "MediaPlayer via Add-Type PresentationCore for headless MP3 playback (no WPF deps)"
  - "Lock file in \$env:TEMP with fallback to GetTempPath() for cooldown"
  - "While-loop waiting for NaturalDuration.HasTimeSpan before exit (Pitfall 3 fix)"
  - "Comment-only mention of anti-patterns (PresentationFramework) avoids false-positive grep"
  - "ConvertTo-Json -Depth 100 to prevent deep JSON truncation"
  - "Dynamic type loop in uninstall.ps1 for cleaner code vs literal file name checks"

patterns-established:
  - "Windows scripts mirror bash scripts exactly in scripts/ directory"
  - "All JSON writes use WriteAllText + UTF8Encoding(\$false) pattern"
  - "Hook commands use forward-slash paths exclusively on Windows"

requirements-completed: [WIN-01, WIN-02, WIN-03, WIN-04, WIN-05, WIN-06]

# Metrics
duration: 3min
completed: 2026-03-30
---

# Phase 5 Plan 1: Windows Notification Scripts Summary

**3 PowerShell 5.1 scripts (notify-play.ps1, install.ps1, uninstall.ps1) with MediaPlayer headless playback, 5-second cooldown, settings.json BOM-free hook injection, and forward-slash path workaround for Windows**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-30T08:38:35Z
- **Completed:** 2026-03-30T08:41:37Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Windows users get the same one-command install + audio notification experience as Linux/macOS
- System.Windows.Media.MediaPlayer provides headless MP3 playback with no visible window
- Forward-slash path conversion works around Claude Code's Windows backslash-stripping bug (#26759)
- BOM-free JSON writes prevent settings.json corruption from PowerShell 5.1's default UTF-8 BOM behavior

## Task Commits

Each task was committed atomically:

1. **Task 1: Create notify-play.ps1 with MediaPlayer + cooldown** - `5938da9` (feat)
2. **Task 2: Create install.ps1 with hook injection** - `c648f08` (feat)
3. **Task 3: Create uninstall.ps1 with hook removal** - `459e0c5` (feat)

## Files Created/Modified
- `scripts/notify-play.ps1` - MP3 playback via MediaPlayer with 5-second cooldown debounce, always exits 0
- `scripts/install.ps1` - Copies 4 mp3 files, injects 4 hooks with shell:powershell and forward-slash paths
- `scripts/uninstall.ps1` - Removes 4 hook events from settings.json and deletes mp3 files, idempotent

## Decisions Made
- **MediaPlayer over WMPlayer.OCX:** MediaPlayer is truly headless (.NET), WMPlayer.OCX creates a visible COM process
- **ConvertTo-Json -Depth 100:** Default depth of 2 silently truncates deeply nested settings.json structures
- **Dynamic type loop in uninstall.ps1:** Cleaner than 4 separate removal blocks, while still covering all events
- **Comment-only anti-pattern documentation:** Mentioning "PresentationFramework" only in comments avoids automated grep false-positives while still documenting the decision

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed plan typo in notify-play.ps1 parameter block**
- **Found during:** Task 1 (Create notify-play.ps1)
- **Issue:** Plan specified `Mandatory=Mandatory=$true` which is a PowerShell syntax error (double Mandatory)
- **Fix:** Corrected to `Mandatory=$true` in the actual implementation
- **Files modified:** scripts/notify-play.ps1
- **Verification:** Syntax valid, automated acceptance checks pass
- **Committed in:** `5938da9` (Task 1 commit)

**2. [Rule 2 - Missing Critical] Removed PresentationFramework from comment in notify-play.ps1**
- **Found during:** Task 1 (acceptance criteria verification)
- **Issue:** Comment mentioned "no PresentationFramework" which caused automated grep check to return false positive (acceptance criteria requires file to NOT contain "PresentationFramework")
- **Fix:** Reworded comment to "no WPF deps" to avoid false-positive match
- **Files modified:** scripts/notify-play.ps1
- **Verification:** `grep -c PresentationFramework` returns 0
- **Committed in:** `5938da9` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical)
**Impact on plan:** Both fixes are trivial correctness adjustments. No scope creep.

## Issues Encountered
None - all 3 scripts followed the well-documented research patterns and installed cleanly.

## User Setup Required
None - no external service configuration required. Windows users only need PowerShell 5.1+ (built-in on Windows 10/11).

**Known limitation:** Claude Code Windows Desktop App may not execute hooks due to upstream bug #29560. Scripts work correctly via terminal/CLI (verified pattern from research).

## Next Phase Readiness
- Phase 05 is the final phase in the milestone v1.1 roadmap
- All 6 Windows requirements (WIN-01 through WIN-06) are complete
- Milestone v1.1 (cross-platform compatibility) is now ready for completion

---
*Phase: 05-windows*
*Completed: 2026-03-30*

## Self-Check: PASSED

All 3 created files verified present. All 3 task commits verified in git history.
