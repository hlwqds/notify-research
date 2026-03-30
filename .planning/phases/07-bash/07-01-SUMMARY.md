---
phase: 07-bash
plan: 01
subsystem: testing
tags: [bats-core, shell-testing, stubs, notify-play]

# Dependency graph
requires:
  - phase: 06-test-infra-static-analysis
    provides: test.sh runner, bats/bats:1.11.0 container, Docker test matrix
provides:
  - 3 executable stub scripts (paplay, afplay, claude) for test mocking
  - notify-play.bats with 4 tests covering BASH-01 through BASH-04
  - jq installation in bats container for install.sh/uninstall.sh tests
affects: [08-powershell, future test plans]

# Tech tracking
tech-stack:
  added: [bats-core test infrastructure]
  patterns: [absolute-path stubs via /usr/bin write in container, BusyBox-safe timestamp manipulation]

key-files:
  created: [tests/stubs/paplay, tests/stubs/afplay, tests/stubs/claude, tests/bash/notify-play.bats]
  modified: [test.sh]

key-decisions:
  - "Write stubs to /usr/bin inside container (absolute paths in notify-play.sh bypass PATH)"
  - "BusyBox-safe touch -t with date -d @epoch for cooldown timestamp manipulation"

patterns-established:
  - "Stubs in tests/stubs/ with CALLED_LOG logging pattern"
  - "setup() installs absolute-path stubs, teardown() restores originals"
  - "mktemp -d for isolated lock directories per test"

requirements-completed: [BASH-01, BASH-02, BASH-03, BASH-04]

# Metrics
duration: 1min
completed: 2026-03-30
---

# Phase 7 Plan 1: notify-play.sh Test Infrastructure Summary

**bats-core test infrastructure with 3 mock stubs, jq container fix, and 4 tests covering cooldown skip/pass, platform branching, and always-exit-0 behavior for notify-play.sh**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-30T12:51:19Z
- **Completed:** 2026-03-30T12:52:37Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Created 3 executable stub scripts (paplay, afplay, claude) for test mocking via CALLED_LOG pattern
- Fixed test.sh to install jq via apk in bats container before running tests
- Wrote 4 bats-core tests covering all BASH-01 through BASH-04 requirements for notify-play.sh
- Used BusyBox-safe timestamp manipulation (date -d @epoch + touch -t) for cooldown tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Create stub scripts and fix test.sh for jq + container setup** - `49d1424` (feat)
2. **Task 2: Write notify-play.bats with 4 tests (BASH-01~04)** - `0a27b52` (feat)

## Files Created/Modified
- `tests/stubs/paplay` - Mock paplay that logs calls to $CALLED_LOG
- `tests/stubs/afplay` - Mock afplay that logs calls to $CALLED_LOG
- `tests/stubs/claude` - Mock claude command printing version string
- `tests/bash/notify-play.bats` - 4 bats-core tests for notify-play.sh (BASH-01~04)
- `test.sh` - Modified run_bash_tests() to install jq via apk before running bats

## Decisions Made
- **Absolute-path stubs via /usr/bin write:** notify-play.sh calls `/usr/bin/paplay` and `/usr/bin/afplay` using absolute paths, so PATH-based stubs won't intercept. The bats container runs as root with writable /usr/bin, so setup() writes stubs directly to /usr/bin and teardown() restores originals.
- **BusyBox-safe timestamp manipulation:** The bats container is Alpine-based with BusyBox where `touch -d` does not work. Used `date -d @epoch` (which IS supported in BusyBox) to compute the formatted timestamp and `touch -t` to apply it.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Stub scripts and test infrastructure ready for 07-02 (install.sh/uninstall.sh tests)
- jq installation in bats container unblocks any tests that invoke install.sh or uninstall.sh
- CALLED_LOG pattern established for verifying player invocations

---
*Phase: 07-bash*
*Completed: 2026-03-30*
