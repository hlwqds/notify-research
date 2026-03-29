---
phase: 02-generate-script
plan: 01
subsystem: audio, cli
tags: [spark-tts, mp3, bash, argparse, docker, selective-generation]

# Dependency graph
requires:
  - phase: 01-docker-tts
    provides: "Docker image (spark-tts-notify), generate.py, 4 pre-generated mp3 files at ~/.claude/"
provides:
  - "audio/ directory with 4 committed mp3 notification sounds"
  - "generate.py with --type argparse for selective generation via GENERATE_TYPES env var"
  - "generate.sh orchestration script (smart build, generate, verify pipeline)"
  - "test_generate_args.py unit tests for argparse/filtering logic"
affects: [03-hooks-integration]

# Tech tracking
tech-stack:
  added: []
  patterns: [argparse-env-var-default, docker-smart-build-skip, mp3-verification-via-file-command]

key-files:
  created:
    - audio/notify-complete.mp3
    - audio/notify-confirm.mp3
    - audio/notify-error.mp3
    - audio/notify-progress.mp3
    - generate.sh
    - test_generate_args.py
    - .gitignore
  modified:
    - generate.py

key-decisions:
  - "GENERATE_TYPES env var as argparse default -- enables generate.sh to pass types without modifying Docker CMD"
  - "TDD approach for argparse logic -- 3 unit tests cover all, valid, and invalid type scenarios"
  - "Pre-generated mp3 files committed to repo at audio/ -- users get working sounds without Docker"

patterns-established:
  - "Env var passthrough: shell script sets GENERATE_TYPES env var, Python argparse reads it as default"
  - "Smart Docker build: docker image inspect check skips rebuild when image exists"

requirements-completed: [SCRIPT-01, SCRIPT-02, SCRIPT-03]

# Metrics
duration: 1m 41s
completed: 2026-03-30
---

# Phase 02 Plan 01: Notification Audio Script Summary

**4 pre-generated mp3 notification sounds committed to repo, generate.py with selective --type generation, generate.sh orchestration for rebuild pipeline**

## Performance

- **Duration:** 1m 41s
- **Started:** 2026-03-29T18:59:15Z
- **Completed:** 2026-03-29T19:01:16Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- 4 mp3 notification sounds available immediately in audio/ without requiring Docker
- generate.py supports --type/-t argument for selective notification generation
- generate.sh orchestrates full pipeline: smart Docker build, TTS generation, output verification
- 3 unit tests covering all, selective, and invalid type scenarios

## Task Commits

Each task was committed atomically:

1. **Task 1: Copy pre-generated mp3 files to audio/ directory** - `3dc14d2` (feat)
2. **Task 2: Add --type argparse support to generate.py** - `9526ae9` (test RED), `4f8b424` (feat GREEN)
3. **Task 3: Create generate.sh orchestration script** - `738d39a` (feat)

**Plan metadata:** `248bc34` (chore: .gitignore), pending final docs commit

_Note: TDD task (Task 2) has 2 commits (test -> feat)_

## Files Created/Modified
- `audio/notify-complete.mp3` - Default task completion notification audio (11.8 KB)
- `audio/notify-confirm.mp3` - Default confirmation request notification audio (14.5 KB)
- `audio/notify-error.mp3` - Default error notification audio (10.4 KB)
- `audio/notify-progress.mp3` - Default in-progress notification audio (10.5 KB)
- `generate.py` - Added argparse with --type/-t, GENERATE_TYPES env var, notification filtering in main()
- `generate.sh` - Full pipeline orchestration: Docker build, TTS generation, MP3 verification
- `test_generate_args.py` - 3 unit tests for selective generation logic
- `.gitignore` - Python cache exclusions

## Decisions Made
- GENERATE_TYPES env var as argparse default value -- generate.sh passes types via env var, Python argparse reads it transparently, no Docker CMD changes needed
- Pre-generated mp3 files committed to audio/ -- users get working sounds immediately without needing Docker/TTS; generate.sh preserved for optional re-generation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- audio/ directory with 4 mp3 files ready for Phase 3 hooks integration
- generate.sh available for users who want to re-generate with different voice parameters
- generate.py GENERATE_TYPES interface tested and verified

## Self-Check: PASSED

All 9 files verified present. All 5 commits verified in git history.

---
*Phase: 02-generate-script*
*Completed: 2026-03-30*
