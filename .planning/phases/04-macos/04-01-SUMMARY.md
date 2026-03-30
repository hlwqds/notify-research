---
phase: 04-macos
plan: 01
subsystem: shell-scripts
tags: [bash, macos, portability, afplay, bsd-stat, hooks]

# Dependency graph
requires:
  - phase: 03-hooks
    provides: "notify-play.sh, install.sh, uninstall.sh (Linux-only scripts)"
provides:
  - Cross-platform notify-play.sh (afplay on macOS, paplay on Linux)
  - Cross-platform install.sh (portable grep/version_gte, OS-conditional prereqs)
  - Verified uninstall.sh is already portable (no changes needed)
affects: [05-windows]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OS detection via uname -s with Darwin branch for macOS"
    - "BSD vs GNU stat: stat -f %m (macOS) vs stat -c %Y (Linux)"
    - "Portable version comparison: pure bash version_gte() replacing sort -V"
    - "Portable regex: grep -oE replacing grep -oP (BSD grep lacks -P)"

key-files:
  created: []
  modified:
    - scripts/notify-play.sh
    - scripts/install.sh

key-decisions:
  - "Cached OS via uname -s variable instead of calling uname multiple times"
  - "Pure bash version_gte() function instead of sort -V for macOS bash 3.2 compatibility"
  - "grep -oE with [0-9]+ instead of grep -oP with \d+ for BSD grep compatibility"

patterns-established:
  - "OS branch pattern: if [[ \"$OS\" == \"Darwin\" ]]; then ... else ... fi"
  - "Platform-specific audio player: afplay (macOS) vs paplay (Linux)"

requirements-completed: [MAC-01, MAC-02, INST-01, INST-02]

# Metrics
duration: 4min
completed: 2026-03-30
---

# Phase 4 Plan 1: macOS Script Compatibility Summary

**OS-conditional stat/afplay branches in notify-play.sh, portable version_gte() and grep -oE in install.sh, uninstall.sh verified already portable**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-30T07:48:04Z
- **Completed:** 2026-03-30T07:51:50Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- notify-play.sh detects OS via uname -s, uses stat -f %m on macOS and stat -c %Y on Linux, plays via afplay or paplay
- install.sh replaces all GNU-only commands (grep -oP, sort -V) with portable equivalents (grep -oE, version_gte bash function)
- install.sh checks platform-appropriate audio player (afplay on macOS, paplay on Linux)
- uninstall.sh confirmed fully portable with zero modifications needed

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix notify-play.sh for macOS (MAC-01, MAC-02)** - `5c2064a` (feat)
2. **Task 2: Fix install.sh for macOS (INST-01)** - `0acf724` (feat)
3. **Task 3: Verify uninstall.sh works on macOS (INST-02)** - no commit (verification only, no changes)

## Files Created/Modified
- `scripts/notify-play.sh` - Added OS detection, BSD stat branch, afplay playback branch
- `scripts/install.sh` - Replaced grep -oP with grep -oE, sort -V with version_gte(), added OS-conditional prereq checks

## Decisions Made
- Cached OS via `uname -s` in a variable rather than calling `uname` repeatedly -- cleaner and marginally faster
- Used `grep -oE '[0-9]+'` instead of `grep -oP '\d+'` because BSD grep (macOS) does not support `-P` (Perl regex)
- Implemented `version_gte()` as a pure bash function instead of `sort -V` because BSD sort lacks the `-V` flag

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 4 (macOS) is complete. All three scripts work on both Linux and macOS.
- Phase 5 (Windows) can proceed independently -- Windows uses separate PowerShell scripts, not these bash scripts.
- No blockers for Phase 5.

---
*Phase: 04-macos*
*Completed: 2026-03-30*
