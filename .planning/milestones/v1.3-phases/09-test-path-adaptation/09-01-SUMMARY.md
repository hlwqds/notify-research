---
phase: 09-test-path-adaptation
plan: 01
subsystem: testing
tags: [bats, pester, ci, docker, path-adaptation]

# Dependency graph
requires:
  - phase: 08-powershell
    provides: "12 Pester tests for PowerShell scripts, all passing in Docker"
provides:
  - "CI-compatible test paths using $REPO_ROOT (bats) and $RepoRoot (Pester)"
  - "PATH-prepend stub pattern for bats tests (no root required)"
  - "Shared test_helper.bash for bats REPO_ROOT derivation"
  - "Docker backward compatibility via REPO_ROOT env var injection in test.sh"
affects: [ci, github-actions, future-test-plans]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bats test_helper.bash with REPO_ROOT from BATS_TEST_DIRNAME"
    - "Pester $RepoRoot from $PSScriptRoot (Split-Path -Parent x2)"
    - "PATH-prepend stub pattern (STUB_DIR + mktemp + export PATH)"
    - "REPO_ROOT=/app Docker injection for backward compatibility"

key-files:
  created:
    - tests/bash/test_helper.bash
  modified:
    - scripts/notify-play.sh
    - tests/bash/install.bats
    - tests/bash/uninstall.bats
    - tests/bash/notify-play.bats
    - tests/powershell/install.Tests.ps1
    - tests/powershell/uninstall.Tests.ps1
    - tests/powershell/notify-play.Tests.ps1
    - test.sh

key-decisions:
  - "BATS_TEST_DIRNAME derivation for REPO_ROOT (standard bats pattern)"
  - "Split-Path -Parent x2 from $PSScriptRoot for $RepoRoot (standard Pester pattern)"
  - "PATH-prepend via mktemp STUB_DIR instead of writing to /usr/bin/ (root-free)"
  - "REPO_ROOT=/app env var injection in test.sh for Docker backward compat"

patterns-established:
  - "test_helper.bash: shared setup loaded via 'load test_helper' in all bats files"
  - "$RepoRoot at Describe scope: derived once, used throughout Pester tests"
  - "STUB_DIR cleanup in teardown: rm -rf $STUB_DIR replaces /usr/bin/ restore"

requirements-completed: [CI-09]

# Metrics
duration: 3min
completed: 2026-03-31
---

# Phase 09 Plan 01: Test Path Adaptation Summary

**Converted 8 test files from hardcoded Docker /app/ paths to CI-compatible variable paths ($REPO_ROOT for bats, $RepoRoot for Pester) with root-free PATH-prepend stub pattern**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-30T16:00:29Z
- **Completed:** 2026-03-31T00:03:42Z
- **Tasks:** 2/2
- **Files modified:** 9 (1 created, 8 modified)

## Accomplishments
- Eliminated all hardcoded `/app/` paths from bats and Pester test files
- Created shared `test_helper.bash` with `REPO_ROOT` derivation from `BATS_TEST_DIRNAME`
- Converted bats stub installation from writing to `/usr/bin/` (requires root) to PATH-prepend pattern using `STUB_DIR=$(mktemp -d)` + `export PATH="$STUB_DIR:$PATH"`
- Fixed `notify-play.sh` to use bare `paplay`/`afplay` commands (enables PATH-based stubbing)
- Converted all 3 Pester files to derive `$RepoRoot` from `$PSScriptRoot`
- Updated `test.sh` to inject `REPO_ROOT=/app` and `$env:REPO_ROOT='/app'` for Docker backward compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix notify-play.sh bare commands + create bats helper + convert all 3 bats test files** - `98826e0` (feat)
2. **Task 2: Convert all 3 Pester test files + update test.sh Docker backward compatibility** - `d4711c4` (feat)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `tests/bash/test_helper.bash` - Shared REPO_ROOT derivation from BATS_TEST_DIRNAME
- `scripts/notify-play.sh` - Changed `/usr/bin/afplay` and `/usr/bin/paplay` to bare commands
- `tests/bash/install.bats` - Replaced all /app/ with $REPO_ROOT, PATH-prepend stubs, load test_helper
- `tests/bash/uninstall.bats` - Replaced all /app/ with $REPO_ROOT, PATH-prepend stubs, load test_helper
- `tests/bash/notify-play.bats` - Replaced all /app/ with $REPO_ROOT, dual stubs via STUB_DIR, load test_helper
- `tests/powershell/install.Tests.ps1` - Added $RepoRoot derivation, replaced all /app/ references
- `tests/powershell/uninstall.Tests.ps1` - Added $RepoRoot derivation, replaced all /app/ references
- `tests/powershell/notify-play.Tests.ps1` - Added $RepoRoot derivation, replaced all /app/ references
- `test.sh` - Added REPO_ROOT=/app injection for Docker bats and Pester containers

## Decisions Made
- **BATS_TEST_DIRNAME for REPO_ROOT**: Standard bats pattern; tests live at `tests/bash/` so repo root is `../..`. All .bats files load shared helper.
- **Split-Path -Parent x2 for $RepoRoot**: Standard Pester pattern; tests live at `tests/powershell/` so two levels up reaches repo root. Placed at Describe scope for use in BeforeEach/It blocks.
- **PATH-prepend stub pattern**: Uses `STUB_DIR=$(mktemp -d)` + `export PATH="$STUB_DIR:$PATH"` instead of writing to `/usr/bin/`. This works on CI runners without root privileges and is cleaned up with `rm -rf "$STUB_DIR"` in teardown.
- **REPO_ROOT env var for Docker**: `test.sh` injects `REPO_ROOT=/app` before running bats, and `$env:REPO_ROOT='/app'` before Pester invocation. This ensures Docker-mounted `/app` paths still work when running inside containers.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Tests are now CI-compatible and can run natively on GitHub Actions runners (no Docker required for the test files themselves)
- Docker backward compatibility preserved via test.sh REPO_ROOT injection
- No blockers for subsequent CI integration work

## Self-Check: PASSED

---
*Phase: 09-test-path-adaptation*
*Completed: 2026-03-31*
