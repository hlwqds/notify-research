# Phase 10: CI workflow - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `.github/workflows/ci.yml` with 3-platform matrix (Ubuntu/macOS/Windows), push/PR triggers on main branch, ShellCheck + PSScriptAnalyzer lint job, and bats + Pester test job. CI runs commands directly on runners — independent from test.sh.

Requirements covered: CI-01 through CI-10 (CI-09 already done in Phase 9).

</domain>

<decisions>
## Implementation Decisions

### Workflow Structure
- **D-01:** Single `ci.yml` file — not split into separate files
- **D-02:** Lint job (Ubuntu only) gates test job — tests don't run if lint fails
- **D-03:** Lint runs ShellCheck on 3 bash scripts + PSScriptAnalyzer on 3 PowerShell scripts in one job

### Platform Matrix
- **D-04:** Use `-latest` runners (ubuntu-latest, macos-latest, windows-latest) — not pinned versions
- **D-05:** Install jq via `brew install jq` on macOS before running bats tests (install.sh uses jq)
- **D-06:** PSScriptAnalyzer runs on all 3 platforms (matching CI-07 requirement), not just Ubuntu

### Tool Installation
- **D-07:** bats-core installed via `bats-core/bats-action@v3.0.1` official GitHub Action
- **D-08:** Pester pinned at `5.6.1` via `Install-Module -RequiredVersion 5.6.1 -Force -Scope CurrentUser` — matching local test.sh
- **D-09:** ShellCheck installed via `apt-get install shellcheck` on Ubuntu runner

### Trigger & Concurrency
- **D-10:** CI triggers on `push` to `main` and `pull_request` targeting `main` only
- **D-11:** Concurrency group: cancel in-progress PR runs, queue main branch pushes (don't cancel)
- **D-12:** `fail-fast: false` on matrix — don't cancel other platforms on single platform failure
- **D-13:** Minimal permissions: `permissions: contents: read`

### Claude's Discretion
- Concurrency group naming strategy
- Job timeout values
- PSScriptAnalyzer module installation method (Install-Module vs preinstalled) on each platform
- ShellCheck flags (use same `--severity warning --check-sourced` from test.sh)
- bats test output format in CI
- Whether to add step summaries / annotations

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — CI-01 through CI-10 detailed definitions
- `.planning/ROADMAP.md` — Phase 10 goal, success criteria, requirements mapping

### Existing CI-Adjacent Code
- `test.sh` — Current test entry point (Docker-based). CI will NOT use this — runs commands directly on runners, but test.sh shows tool versions and flags to replicate
- `scripts/install.sh` — ShellCheck target, uses jq (needs brew install on macOS)
- `scripts/uninstall.sh` — ShellCheck target
- `scripts/notify-play.sh` — ShellCheck target
- `scripts/install.ps1` — PSScriptAnalyzer target
- `scripts/uninstall.ps1` — PSScriptAnalyzer target
- `scripts/notify-play.ps1` — PSScriptAnalyzer target

### Test Files
- `tests/bash/*.bats` — 4 bats test files (10 tests), run on ubuntu + macos
- `tests/powershell/*.Tests.ps1` — 3 Pester test files (12 tests), run on all 3 platforms
- `tests/fixtures/settings.json` — Shared test fixture
- `tests/fixtures/dummy.mp3` — Shared test fixture
- `tests/stubs/` — Mock stubs (paplay, afplay, claude)

### Prior Phase Context
- `.planning/phases/06-test-infra-static-analysis/06-CONTEXT.md` — D-06/D-07: ShellCheck warning severity + --check-sourced, PSSA Warning severity, tool version pins
- `.planning/phases/09-test-path-adaptation/09-CONTEXT.md` — CI-compatible paths ($REPO_ROOT/$RepoRoot)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test.sh` — Reference for tool versions (bats 1.11.0 image, Pester 5.6.1, PWSH 7.4-alpine) and flags (ShellCheck `--severity warning --check-sourced`, PSSA `-Severity Warning`)
- `tests/stubs/` — PATH-prepend stub pattern already in place for CI compatibility

### Established Patterns
- All bash scripts use `set -euo pipefail`
- PowerShell scripts use `$ErrorActionPreference = "Stop"`
- jq used for settings.json manipulation in bash scripts
- Lock file paths overridden via `NOTIFY_LOCK_DIR` environment variable for test isolation

### Integration Points
- No `.github/` directory exists yet — creating from scratch
- Repo: `hlwqds/notify-research` on GitHub (owner for badge URLs if needed)
- Audio files in `audio/` committed to repo — tests reference them via `$REPO_ROOT/audio/`

</code_context>

<specifics>
## Specific Ideas

- CI runs commands directly on runners, NOT via Docker (unlike test.sh which uses Docker containers)
- bats-action@v3.0.1 replaces the Docker-based `bats/bats:1.11.0` image approach
- macOS needs `brew install jq` as a setup step before bats tests
- Pester 5.6.1 must be explicitly installed (don't rely on preinstalled version which may differ)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 10-ci-workflow*
*Context gathered: 2026-03-31*
