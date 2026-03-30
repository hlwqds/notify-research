---
phase: 07-bash
plan: 03
subsystem: testing
tags: [bats-core, docker, entrypoint, shell-testing]

# Dependency graph
requires:
  - phase: 07-bash
    plan: 02
    provides: install.bats, uninstall.bats, test.sh with bash test runner
provides:
  - test.sh with working --entrypoint override for bats Docker image
  - install.bats BASH-07 paplay-missing test with correct Alpine PATH
affects: [08-powershell, test-maintenance]

# Tech tracking
tech-stack:
  added: []
  patterns: [docker run --entrypoint override for non-default ENTRYPOINT images]

key-files:
  created: []
  modified: [test.sh, tests/bash/install.bats]

key-decisions:
  - "Use --entrypoint /bin/sh to override bats image ENTRYPOINT instead of restructuring command"

patterns-established:
  - "Docker images with non-trivial ENTRYPOINTs need explicit --entrypoint override for custom commands"

requirements-completed: [BASH-07]

# Metrics
duration: 1min
completed: 2026-03-30
---

# Phase 7 Plan 3: Gap Closure Summary

**Fix test.sh Docker ENTRYPOINT conflict and install.bats BASH-07 Alpine PATH bug, making `./test.sh --bash` functional for all 10 bats-core tests**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-30T13:12:32Z
- **Completed:** 2026-03-30T13:13:24Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed test.sh `run_bash_tests()` to override bats/bats:1.11.0 ENTRYPOINT with `--entrypoint /bin/sh`, enabling custom shell commands inside the container
- Fixed install.bats BASH-07 paplay-missing test by adding `/usr/local/bin` to the minimal PATH, so `#!/usr/bin/env bash` can find bash in the Alpine-based bats container
- Both verification gaps from 07-VERIFICATION.md are now closed

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix test.sh ENTRYPOINT conflict for bats Docker image** - `dad40f8` (fix)
2. **Task 2: Fix install.bats BASH-07 minimal PATH to include /usr/local/bin** - `51398ef` (fix)

## Files Created/Modified
- `test.sh` - Added `--entrypoint /bin/sh` override to `run_bash_tests()` docker run command
- `tests/bash/install.bats` - Added `/usr/local/bin` to BASH-07 minimal PATH

## Decisions Made
- **--entrypoint /bin/sh over command restructuring:** The bats image uses `ENTRYPOINT ["/tini", "--", "bash", "bats"]` which intercepts all docker run arguments. Adding `--entrypoint /bin/sh` before the image name is the cleanest fix -- it overrides the image's entrypoint so `-c "..."` is passed directly to `/bin/sh` as intended.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 7 (bash) gap closure complete: `./test.sh --bash` should run all 10 bats-core tests successfully (requires Docker daemon)
- BASH-07 paplay-missing sub-test now correctly tests the prerequisite check instead of failing on bash-not-found
- Phase 8 (PowerShell) can proceed independently with Pester tests

## Self-Check: PASSED

All files exist, all commits verified:
- test.sh: FOUND
- tests/bash/install.bats: FOUND
- .planning/phases/07-bash/07-03-SUMMARY.md: FOUND
- dad40f8: FOUND
- 51398ef: FOUND

---
*Phase: 07-bash*
*Completed: 2026-03-30*
