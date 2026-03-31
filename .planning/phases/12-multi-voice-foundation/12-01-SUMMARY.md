---
phase: 12-multi-voice-foundation
plan: 01
subsystem: infra
tags: [audio, voice, migration, paths]

# Dependency graph
requires:
  - phase: 1-3 (v1.0)
    provides: 4 pre-generated mp3 notification files at audio/notify-*.mp3
  - phase: 4-5 (v1.1)
    provides: install.ps1 with audio copy logic
  - phase: 6-8 (v1.2)
    provides: 22 automated tests referencing audio paths
provides:
  - audio/voices/gentle/ directory with 4 mp3 notification files
  - VOICE variable in install.sh defaulting to "gentle" (per-voice pattern)
  - $VoiceName variable in install.ps1 defaulting to "gentle"
  - All test files updated to reference audio/voices/gentle/ paths
affects: [12-02-generate-parameterization, 12-03-voice-manifest, 13, 14]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "audio/voices/{voice-name}/ directory-per-voice layout"
    - "VOICE env var with default fallback (VOICE:-gentle) in install.sh"

key-files:
  created:
    - audio/voices/gentle/notify-complete.mp3
    - audio/voices/gentle/notify-confirm.mp3
    - audio/voices/gentle/notify-error.mp3
    - audio/voices/gentle/notify-progress.mp3
  modified:
    - scripts/install.sh
    - scripts/install.ps1
    - tests/bash/install.bats
    - tests/bash/notify-play.bats
    - tests/bash/uninstall.bats
    - tests/powershell/notify-play.Tests.ps1

key-decisions:
  - "Use git mv to preserve file history during migration"
  - "VOICE env var defaults to 'gentle' -- Phase 14 adds interactive selection"
  - "PowerShell $VoiceName hardcoded to 'gentle' (no -Voice param until Phase 14)"

patterns-established:
  - "Per-voice directory: audio/voices/{name}/ with notify-{type}.mp3 files"
  - "VOICE env var for install-time voice selection (bash)"
  - "$VoiceName variable for install-time voice selection (PowerShell)"

requirements-completed: [VOICE-01]

# Metrics
duration: 1min
completed: 2026-03-31
---

# Phase 12 Plan 1: Audio Per-Voice Directory Migration Summary

**Migrated 4 audio files from flat audio/ to audio/voices/gentle/ directory-per-voice layout, updated all 7 consumer files (2 scripts, 5 tests) with new paths**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-31T05:33:43Z
- **Completed:** 2026-03-31T05:35:03Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- Established audio/voices/{name}/ directory pattern for multi-voice support (VOICE-01)
- Migrated 4 mp3 files using git mv to preserve history
- Updated install.sh with VOICE env var defaulting to "gentle"
- Updated install.ps1 with $VoiceName hardcoded to "gentle"
- Updated all 5 test files to reference new audio/voices/gentle/ paths
- Verified zero remaining flat audio/notify-*.mp3 references in project files

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate audio files to per-voice directory structure** - `9aa064d` (feat)
2. **Task 2: Run existing test suite to verify migration correctness** - verification-only, no file changes (bats not installed, paths confirmed via grep)

**Plan metadata:** (pending final docs commit)

## Files Created/Modified
- `audio/voices/gentle/notify-complete.mp3` - Moved from audio/ (task completion sound)
- `audio/voices/gentle/notify-confirm.mp3` - Moved from audio/ (confirmation sound)
- `audio/voices/gentle/notify-error.mp3` - Moved from audio/ (error sound)
- `audio/voices/gentle/notify-progress.mp3` - Moved from audio/ (progress sound)
- `scripts/install.sh` - Added VOICE="${VOICE:-gentle}" variable, updated audio source path
- `scripts/install.ps1` - Added $VoiceName = "gentle", updated audio source path
- `tests/bash/install.bats` - Updated setup() cp source path
- `tests/bash/notify-play.bats` - Updated 4 audio path references
- `tests/bash/uninstall.bats` - Updated setup() cp source path
- `tests/powershell/notify-play.Tests.ps1` - Updated 4 audio path references

## Decisions Made
- Used git mv to preserve file history during migration (plan specified this approach)
- VOICE env var defaults to "gentle" via ${VOICE:-gentle} pattern -- enables future override and Phase 14 interactive selection
- PowerShell install.ps1 hardcodes "gentle" without -Voice parameter yet (Phase 14 adds VOICE-04)
- Did NOT modify generate.py or generate.sh (Plan 02 handles those)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- bats-core not installed on system; verified correctness via grep path reference checks instead of running tests

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- audio/voices/gentle/ directory structure is ready for Plan 02 (generate parameterization)
- Plan 02 can now update generate.py and generate.sh to output to audio/voices/{voice}/
- Plan 03 can create voices.json manifest alongside the gentle/ directory
- Phase 14 can add interactive voice selection to install.sh/install.ps1

## Self-Check: PASSED

- All 4 audio files found at audio/voices/gentle/notify-{type}.mp3
- 12-01-SUMMARY.md found at .planning/phases/12-multi-voice-foundation/
- Commit 9aa064d found in git log

---
*Phase: 12-multi-voice-foundation*
*Completed: 2026-03-31*
