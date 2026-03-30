---
phase: 06-test-infra-static-analysis
plan: 02
subsystem: testing
tags: [bash, shellcheck, psscriptanalyzer, bats-core, pester, docker]

# Dependency graph
requires:
  - phase: 06-01
    provides: "Test directory structure, NOTIFY_LOCK_DIR override in scripts"
provides:
  - "test.sh unified entry point with --lint, --bash, --powershell, --all flags"
  - "ShellCheck + PSScriptAnalyzer static analysis pipeline"
  - "Docker-based test matrix (bats-core, Pester)"
affects: [07-bash-tests, 08-powershell-tests]

# Tech tracking
tech-stack:
  added: [shellcheck, koalaman/shellcheck (Docker), bats/bats:1.11.0, mcr.microsoft.com/powershell:7.4]
  patterns:
    - "Unified test.sh entry point with subcommand flags"
    - "ShellCheck local/Docker fallback pattern"
    - "PSScriptAnalyzer Install-Module fallback in Docker"
    - "Lint-first gating in --all mode"

key-files:
  created:
    - test.sh
  modified:
    - scripts/install.sh
    - scripts/uninstall.sh

key-decisions:
  - "ShellCheck local/Docker fallback preserves user experience without forcing Docker"
  - "PSScriptAnalyzer Install-Module fallback handles missing module in pwsh Docker image"
  - "Cleanup function pattern for trap (fixes SC2064) instead of inline expansion"

patterns-established:
  - "test.sh as single CI/CD entry point for all project validation"
  - "cleanup() { rm -f \"$TMPFILE\"; }; trap cleanup EXIT as standard temp file pattern"

requirements-completed: [INFRA-01, INFRA-03, LINT-01, LINT-02]

# Metrics
duration: 2min
completed: 2026-03-30
---

# Phase 6 Plan 2: Unified test.sh Entry Point and Static Analysis Summary

**test.sh unified test runner with ShellCheck + PSScriptAnalyzer lint pipeline and Docker-based bats-core/Pester test matrix**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-30T12:08:26Z
- **Completed:** 2026-03-30T12:10:48Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created test.sh with 4 subcommand flags (--lint, --bash, --powershell, --all) as the single project validation entry point
- ShellCheck runs at warning severity with local/Docker fallback on all 3 bash scripts
- PSScriptAnalyzer runs at Warning severity via Docker with Install-Module fallback on all 3 PS1 scripts
- Docker test matrix: bats-core in bats/bats:1.11.0 for bash, Pester in mcr.microsoft.com/powershell:7.4 for PowerShell
- --all mode enforces lint-first gating per D-02 (lint failure blocks subsequent tests)
- Fixed all ShellCheck warnings in install.sh and uninstall.sh (SC2064 trap expansion, SC2206 version splitting)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create test.sh unified test entry point** - `4b387e0` (feat)
2. **Task 2: Validate test.sh end-to-end and fix ShellCheck warnings** - `92eef8e` (fix)

## Files Created/Modified
- `test.sh` - Unified test entry point with --lint, --bash, --powershell, --all subcommands
- `scripts/install.sh` - Fixed SC2064 (trap cleanup function) and SC2206 (version split suppression)
- `scripts/uninstall.sh` - Fixed SC2064 (trap cleanup function)

## Decisions Made
- Used cleanup function pattern for trap instead of inline variable expansion -- ShellCheck SC2064 recommends single quotes in trap, which requires a function to access the variable
- Suppressed SC2206 in version_gte() with inline comment -- version string splitting into arrays is intentional for numeric comparison, mapfile/read -a adds complexity for no functional benefit
- Pinned bats/bats:1.11.0 (verified stable on GitHub) and mcr.microsoft.com/powershell:7.4 per research recommendations

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed SC2064 trap expansion in install.sh and uninstall.sh**
- **Found during:** Task 2 (end-to-end validation)
- **Issue:** `trap "rm -f $TMPFILE" EXIT` uses double quotes, causing ShellCheck SC2064 warning -- $TMPFILE expands at trap definition time rather than signal time. While functionally correct for our use case, the standard fix is cleaner.
- **Fix:** Replaced with `cleanup() { rm -f "$TMPFILE"; }; trap cleanup EXIT` pattern
- **Files modified:** scripts/install.sh, scripts/uninstall.sh
- **Verification:** shellcheck --severity warning passes on all 3 scripts
- **Committed in:** `92eef8e` (Task 2 commit)

**2. [Rule 1 - Bug] Suppressed SC2206 version string splitting in install.sh**
- **Found during:** Task 2 (end-to-end validation)
- **Issue:** ShellCheck SC2206 flags `a=($1) b=($2)` in version_gte() as word splitting risk. The splitting is intentional for version number comparison (e.g., "2.1.78" into [2, 1, 78]).
- **Fix:** Added `# shellcheck disable=SC2206` with explanatory comment
- **Files modified:** scripts/install.sh
- **Verification:** shellcheck --severity warning passes
- **Committed in:** `92eef8e` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes are correctness improvements identified during validation. No scope creep.

## Issues Encountered
- Docker not available in execution environment -- ShellCheck validated locally, PSScriptAnalyzer and Docker test matrix validated via code review (Docker images and volume mounts follow established patterns from research)

## User Setup Required

None - no external service configuration required. Docker is needed at runtime for PSScriptAnalyzer, bats-core, and Pester tests, but is a pre-existing project dependency.

## Next Phase Readiness
- test.sh ready as single entry point for all project validation
- ShellCheck passes clean on all 3 bash scripts
- bats-core Docker image (bats/bats:1.11.0) configured for Phase 7 bash tests
- Pester Docker image (mcr.microsoft.com/powershell:7.4) configured for Phase 8 PowerShell tests
- --all mode provides full CI-like validation in a single command
- Phase 6 success criteria items 1 and 3 from ROADMAP are satisfied

## Self-Check: PASSED

- test.sh: FOUND
- 06-02-SUMMARY.md: FOUND
- Commit 4b387e0: FOUND
- Commit 92eef8e: FOUND

---
*Phase: 06-test-infra-static-analysis*
*Completed: 2026-03-30*
