# Phase 10: CI workflow - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 10-ci-workflow
**Areas discussed:** Workflow structure, Platform matrix details, Tool installation, Trigger & concurrency

---

## Workflow Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single ci.yml (Recommended) | One file, lint job (Ubuntu only) + test job (3-platform matrix). Lint gates tests. | ✓ |
| Single ci.yml, parallel jobs | One file, lint + test independent. Faster but less strict. | |
| Split into lint.yml + test.yml | Separate files. Better for large projects but overkill here. | |

**User's choice:** Single ci.yml — lint gates tests
**Notes:** Lint must pass before tests run. Saves CI minutes on broken code.

---

## Platform Matrix Details

### Runner versions

| Option | Description | Selected |
|--------|-------------|----------|
| latest (Recommended) | Always use latest runners, auto-updated by GitHub. | ✓ |
| Pin specific versions | Pin to ubuntu-24.04, macos-14, windows-2022 for reproducibility. | |

**User's choice:** latest runners

### macOS jq dependency

| Option | Description | Selected |
|--------|-------------|----------|
| Install jq via brew (Recommended) | brew install jq before running bats tests on macOS. | ✓ |
| Let bats-action handle it | Use a bats action that manages dependencies. | |

**User's choice:** Install jq via brew before bats tests

---

## Tool Installation

### bats-core

| Option | Description | Selected |
|--------|-------------|----------|
| bats-action (Recommended) | bats-core/bats-action@v3.0.1 official action. Roadmap suggests this. | ✓ |
| Manual git clone install | More control but more YAML. | |

**User's choice:** bats-action@v3.0.1

### Pester

| Option | Description | Selected |
|--------|-------------|----------|
| Install-Module 5.6.1 (Recommended) | Pin 5.6.1 matching local test.sh. | ✓ |
| Use preinstalled version | Simpler but may differ from local. | |

**User's choice:** Install-Module Pester 5.6.1

### ShellCheck

| Option | Description | Selected |
|--------|-------------|----------|
| apt-get install (Recommended) | Install via apt-get on Ubuntu runner. | ✓ |
| ShellCheck action | e.g., ludeeus/action-shellcheck. More opinionated defaults. | |

**User's choice:** apt-get install shellcheck

### PSScriptAnalyzer platforms

| Option | Description | Selected |
|--------|-------------|----------|
| All 3 platforms (Recommended) | Matching CI-07 requirement. | ✓ |
| Ubuntu only | Lint results are platform-independent for PS scripts. | |

**User's choice:** All 3 platforms (per requirement CI-07)

---

## Trigger & Concurrency

### Branch scope

| Option | Description | Selected |
|--------|-------------|----------|
| main branch only (Recommended) | CI runs on push to main and PRs targeting main. | ✓ |
| All branches | More coverage but wastes CI minutes. | |

**User's choice:** main branch only

### Concurrency behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel PRs, queue main (Recommended) | PR runs cancel each other. Main pushes queue. | ✓ |
| Cancel everything | Both PR and main cancel in-progress. | |
| No concurrency | All runs complete. | |

**User's choice:** Cancel PRs, queue main pushes

---

## Claude's Discretion

- Concurrency group naming strategy
- Job timeout values
- PSScriptAnalyzer module installation details per platform
- ShellCheck flags (replicate from test.sh: --severity warning --check-sourced)
- bats test output format in CI
- Step summaries / annotations

## Deferred Ideas

None.
