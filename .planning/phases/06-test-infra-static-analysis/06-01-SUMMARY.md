---
phase: 06-test-infra-static-analysis
plan: 01
subsystem: testing
tags: [bash, powershell, test-fixtures, env-override, notify-play]

# Dependency graph
requires:
  - phase: 05-windows
    provides: PowerShell scripts (notify-play.ps1, install.ps1, uninstall.ps1)
provides:
  - "tests/ directory structure (bash/, powershell/, fixtures/)"
  - "Shared test fixtures (settings.json with PreToolUse hook, dummy.mp3)"
  - "NOTIFY_LOCK_DIR env var override in notify-play.sh and notify-play.ps1"
affects: [07-bash-tests, 08-powershell-tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NOTIFY_LOCK_DIR env var for testable lock file paths"
    - "tests/fixtures/ as shared test data directory"

key-files:
  created:
    - tests/bash/.gitkeep
    - tests/powershell/.gitkeep
    - tests/fixtures/settings.json
    - tests/fixtures/dummy.mp3
  modified:
    - scripts/notify-play.sh
    - scripts/notify-play.ps1

key-decisions:
  - "NOTIFY_LOCK_DIR env var with /tmp default preserves backward compatibility"

patterns-established:
  - "LOCK_DIR/${NOTIFY_LOCK_DIR:-/tmp} pattern for testable temp paths in bash"
  - "$LockDir = if ($env:NOTIFY_LOCK_DIR) { ... } pattern for PowerShell"

requirements-completed: [INFRA-02, INFRA-04]

# Metrics
duration: 2min
completed: 2026-03-30
---

# Phase 6 Plan 1: Test Infrastructure and Fixture Creation Summary

**Test directory scaffold (bash/powershell/fixtures) with shared settings.json fixture and NOTIFY_LOCK_DIR env var override for lock file path testability**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-30T12:03:32Z
- **Completed:** 2026-03-30T12:05:13Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created tests/ directory structure (bash/, powershell/, fixtures/) for Phase 7/8 test suites
- Built shared fixture settings.json with pre-existing PreToolUse hook for install/uninstall testing
- Added NOTIFY_LOCK_DIR env var override to both notify-play scripts, enabling tests to control lock file location

## Task Commits

Each task was committed atomically:

1. **Task 1: Create test directory structure and shared fixtures** - `03e5781` (feat)
2. **Task 2: Refactor notify-play.sh and notify-play.ps1 for NOTIFY_LOCK_DIR override** - `d81684a` (feat)

## Files Created/Modified
- `tests/bash/.gitkeep` - Empty placeholder for bash test directory
- `tests/powershell/.gitkeep` - Empty placeholder for PowerShell test directory
- `tests/fixtures/settings.json` - Fake Claude settings with PreToolUse hook and permissions for install/uninstall test isolation
- `tests/fixtures/dummy.mp3` - Minimal valid MP3 file (746 bytes, 0.1s silence) for path-existence checks
- `scripts/notify-play.sh` - Added LOCK_DIR="${NOTIFY_LOCK_DIR:-/tmp}" with default /tmp behavior
- `scripts/notify-play.ps1` - Added $LockDir = if ($env:NOTIFY_LOCK_DIR) { ... } with $env:TEMP fallback

## Decisions Made
- Used shell parameter expansion `${NOTIFY_LOCK_DIR:-/tmp}` for bash (standard idiom, backward-compatible)
- Used PowerShell if/elseif chain for $LockDir (matches bash priority: NOTIFY_LOCK_DIR > system temp)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- tests/bash/ and tests/powershell/ directories ready for Phase 7/8 test files
- tests/fixtures/settings.json ready for install/uninstall isolation testing
- tests/fixtures/dummy.mp3 ready for path-existence checks
- NOTIFY_LOCK_DIR override enables lock file isolation in test environments
- Plan 06-02 (test.sh entry point + Docker test matrix + ShellCheck/PSSA) will add the test runner

---
*Phase: 06-test-infra-static-analysis*
*Completed: 2026-03-30*
