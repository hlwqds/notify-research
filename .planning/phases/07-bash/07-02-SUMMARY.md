---
phase: 07-bash
plan: 02
subsystem: testing
tags: [bats-core, shell-testing, install, uninstall, idempotency]

# Dependency graph
requires:
  - phase: 07-bash
    plan: 01
    provides: stub scripts, jq in container, notify-play.bats, test.sh jq fix
provides:
  - install.bats with 3 tests covering BASH-05 through BASH-07
  - uninstall.bats with 3 tests covering BASH-08 through BASH-10
  - Full Phase 7 test coverage: 10 bats-core tests across 3 files
affects: [08-powershell, test-maintenance]

# Tech tracking
tech-stack:
  added: []
  patterns: [HOME override with mktemp -d, fixture copy + restore paplay stub pattern, jq sorted JSON comparison for idempotency]

key-files:
  created: [tests/bash/install.bats, tests/bash/uninstall.bats]
  modified: []

key-decisions:
  - "HOME override via mktemp -d for install/uninstall test isolation"
  - "jq -S sorted JSON comparison for idempotency verification"

patterns-established:
  - "Paplay stub write to /usr/bin in setup, restore in teardown"
  - "do_install() helper in uninstall tests for real install/uninstall flow"
  - "settings.json fixture copy per test with PreToolUse preservation verification"

requirements-completed: [BASH-05, BASH-06, BASH-07, BASH-08, BASH-09, BASH-10]

# Metrics
duration: 1min
completed: 2026-03-30
---

# Phase 7 Plan 2: install.sh + uninstall.sh Test Coverage Summary

**6 bats-core tests for install.sh (hook injection, idempotency, prerequisite checks) and uninstall.sh (hook removal, MP3 deletion, idempotent re-run), completing Phase 7 with 10 total bash tests**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-30T12:54:26Z
- **Completed:** 2026-03-30T12:55:56Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created install.bats with 3 tests: hook injection (4 events + PreToolUse preservation), idempotency (sorted JSON comparison), and prerequisite failure detection (settings.json, paplay, mp3 missing)
- Created uninstall.bats with 3 tests: hook removal (4 events removed, PreToolUse preserved), MP3 file deletion, and idempotent double-run
- Phase 7 complete: 10 total bats-core tests across 3 test files covering all bash scripts

## Task Commits

Each task was committed atomically:

1. **Task 1: Write install.bats with 3 tests (BASH-05~07)** - `96840a5` (feat)
2. **Task 2: Write uninstall.bats with 3 tests (BASH-08~10)** - `8c71567` (feat)

## Files Created/Modified
- `tests/bash/install.bats` - 3 tests: hook injection, idempotent install, prerequisite checks
- `tests/bash/uninstall.bats` - 3 tests: hook removal, MP3 deletion, idempotent uninstall

## Decisions Made
- **HOME override via mktemp -d:** Both install.sh and uninstall.sh use `$HOME/.claude` for CLAUDE_DIR. Tests override HOME to a temp directory for isolation, copying fixture settings.json and real MP3 files into it.
- **jq -S sorted JSON comparison for idempotency:** The idempotency test (BASH-06) runs install.sh twice, captures `jq -S .` output (sorted keys) from each run, and verifies they are identical strings. This catches any duplication or mutation jq might introduce.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 7 (bash) fully complete: 10 tests across 3 files (notify-play.bats, install.bats, uninstall.bats)
- Phase 8 (PowerShell) can proceed independently with Pester tests
- All bash script core logic now has automated test coverage

---
*Phase: 07-bash*
*Completed: 2026-03-30*
