# Phase 10: CI workflow - Research

**Researched:** 2026-03-31
**Domain:** GitHub Actions CI workflow (YAML, matrix, lint, test orchestration)
**Confidence:** HIGH

## Summary

This phase creates a GitHub Actions CI workflow from scratch (no `.github/` directory exists yet). The workflow must run on a 3-platform matrix (Ubuntu, macOS, Windows), execute ShellCheck lint on Ubuntu, PSScriptAnalyzer lint on all platforms, bats-core tests on Ubuntu+macOS (10 tests), and Pester 5.6.1 tests on all 3 platforms (12 tests). The implementation is a single `ci.yml` file with two jobs: lint (Ubuntu only) that gates the test job, and test (3-platform matrix). CI runs commands directly on GitHub Actions runners -- completely independent from the Docker-based `test.sh`.

Key challenges are minimal: bats-core has an official GitHub Action (`bats-core/bats-action@v3.0.1`), PowerShell is preinstalled on all runners, and the test files are already CI-compatible after Phase 9's path adaptation. The main subtleties are the concurrency pattern (cancel PRs but queue main pushes), macOS needing `brew install jq` before bats tests (though jq 1.8.1 is actually preinstalled on macOS runners), and ensuring Pester 5.6.1 is explicitly installed rather than relying on whatever preinstalled version exists.

**Primary recommendation:** Write a single `ci.yml` with lint job (ShellCheck + PSSA) gating a matrix test job (bats + Pester), using `bats-core/bats-action@v3.0.1` for bats and explicit `Install-Module Pester -RequiredVersion 5.6.1` for Pester version pinning.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Single `ci.yml` file -- not split into separate files
- **D-02:** Lint job (Ubuntu only) gates test job -- tests don't run if lint fails
- **D-03:** Lint runs ShellCheck on 3 bash scripts + PSScriptAnalyzer on 3 PowerShell scripts in one job
- **D-04:** Use `-latest` runners (ubuntu-latest, macos-latest, windows-latest) -- not pinned versions
- **D-05:** Install jq via `brew install jq` on macOS before running bats tests (install.sh uses jq)
- **D-06:** PSScriptAnalyzer runs on all 3 platforms (matching CI-07 requirement), not just Ubuntu
- **D-07:** bats-core installed via `bats-core/bats-action@v3.0.1` official GitHub Action
- **D-08:** Pester pinned at `5.6.1` via `Install-Module -RequiredVersion 5.6.1 -Force -Scope CurrentUser` -- matching local test.sh
- **D-09:** ShellCheck installed via `apt-get install shellcheck` on Ubuntu runner
- **D-10:** CI triggers on `push` to `main` and `pull_request` targeting `main` only
- **D-11:** Concurrency group: cancel in-progress PR runs, queue main branch pushes (don't cancel)
- **D-12:** `fail-fast: false` on matrix -- don't cancel other platforms on single platform failure
- **D-13:** Minimal permissions: `permissions: contents: read`

### Claude's Discretion

- Concurrency group naming strategy
- Job timeout values
- PSScriptAnalyzer module installation method (Install-Module vs preinstalled) on each platform
- ShellCheck flags (use same `--severity warning --check-sourced` from test.sh)
- bats test output format in CI
- Whether to add step summaries / annotations

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CI-01 | GitHub Actions workflow triggered on push to main and pull_request | Standard `on: push/paths/pull_request` trigger pattern (HIGH) |
| CI-02 | 3-platform matrix (ubuntu-latest, macos-latest, windows-latest) | `runs-on: ${{ matrix.os }}` with matrix list (HIGH) |
| CI-03 | Minimal permissions (`permissions: contents: read`) | Standard GH Actions security practice (HIGH) |
| CI-04 | fail-fast: false on matrix | `strategy.fail-fast: false` key (HIGH) |
| CI-05 | Concurrency control (cancel PRs, queue main pushes) | `concurrency.cancel-in-progress: ${{ github.event_name == 'pull_request' }}` pattern (HIGH) |
| CI-06 | ShellCheck on 3 bash scripts (Ubuntu only) | `shellcheck --severity warning --check-sourced` on scripts/*.sh (HIGH) |
| CI-07 | PSScriptAnalyzer on 3 PowerShell scripts (all platforms) | `Invoke-ScriptAnalyzer -Path scripts -Severity Warning` (HIGH) |
| CI-08 | bats-core tests on Ubuntu + macOS (10 tests) | `bats-core/bats-action@v3.0.1` runs tests in tests/bash/ (HIGH) |
| CI-10 | Pester tests on all 3 platforms (12 tests) | Pester 5.6.1 explicit install + `Invoke-Pester` (HIGH) |
</phase_requirements>

## Standard Stack

### Core

| Library/Tool | Version | Purpose | Why Standard |
|---|---|---|---|
| GitHub Actions | runner labels `-latest` | CI platform | The project's CI target (locked decision D-04) |
| bats-core/bats-action | v3.0.1 | bats test runner for CI | Official GitHub Action for bats (locked decision D-07) |
| Pester | 5.6.1 | PowerShell test framework | Pinned to match local test.sh (locked decision D-08) |
| ShellCheck | stable (apt) | Bash static analysis | Standard bash linter, preinstalled on Ubuntu runners (locked decision D-09) |
| PSScriptAnalyzer | latest (via Install-Module) | PowerShell static analysis | Standard PS linter, preinstalled on macOS/Windows runners |

### Runner Preinstalled Tools (verified)

| Tool | ubuntu-latest | macos-latest | windows-latest | Source |
|---|---|---|---|---|
| PowerShell (pwsh) | 7.4.x | 7.4.x | 5.1 (Windows PowerShell) + 7.4.x (pwsh) | GitHub Actions runner docs |
| ShellCheck | YES (but D-09 uses `apt-get install` explicitly) | NO | NO | ShellCheck not preinstalled on macOS/Windows |
| jq | 1.7+ | 1.8.1 (preinstalled) | NO | macOS runner software list |
| PSScriptAnalyzer | NO (install via Install-Module) | 1.24.0+ (preinstalled) | preinstalled | macOS/Windows runner software list |
| Pester | NO | 5.7.1 (preinstalled) | 5.x (preinstalled) | Runner software lists |
| bats-core | NO | NO | NO | Not preinstalled anywhere |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| `bats-core/bats-action@v3.0.1` | `bats-core/bats-action@v4.0.0` | v4.0.0 requires explicit `token:` parameter for checkout; v3.0.1 is simpler and tested |
| `apt-get install shellcheck` | preinstalled ShellCheck | D-09 explicitly chooses apt-get; more explicit, guaranteed version |
| Single ci.yml | Split lint.yml + test.yml | D-01 locks single file; simpler to maintain |

**Installation:**

No npm packages needed. All tools are GitHub Actions features or PowerShell modules:

```bash
# bats: via GitHub Action step (no manual install)
# Pester: via Install-Module in workflow step
# ShellCheck: via apt-get in workflow step
# PSScriptAnalyzer: via Install-Module in workflow step (Ubuntu) or preinstalled (macOS/Windows)
```

**Version verification:**
- `bats-core/bats-action@v3.0.1` -- verified exists via GitHub releases page (released 2024-03-27)
- Pester 5.6.1 -- verified via PowerShell Gallery (matches test.sh pin)
- ShellCheck stable -- latest via apt-get on Ubuntu runners

## Architecture Patterns

### Recommended Workflow Structure

```
.github/
└── workflows/
    └── ci.yml          # Single workflow file (per D-01)
```

### Pattern 1: Workflow Skeleton

**What:** Standard GitHub Actions workflow with triggers, concurrency, permissions, jobs.
**When to use:** Every CI workflow.
**Example:**

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
permissions:
  contents: read
```

Source: GitHub Actions documentation, standard pattern verified across multiple open-source repos.

### Pattern 2: Lint Job Gating Test Job

**What:** Lint job runs first on Ubuntu only. Test job depends on lint via `needs: lint`, so tests only run if lint passes.
**When to use:** When lint failures should block test execution (per D-02).
**Example:**

```yaml
jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        run: |
          sudo apt-get update && sudo apt-get install -y shellcheck
          shellcheck --severity warning --check-sourced \
            scripts/install.sh \
            scripts/uninstall.sh \
            scripts/notify-play.sh
      - name: PSScriptAnalyzer
        shell: pwsh
        run: |
          if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          }
          $results = Invoke-ScriptAnalyzer -Path scripts -Severity Warning -Recurse
          if ($results) {
            $results | Format-Table -AutoSize
            Write-Error "PSScriptAnalyzer found issues"
            exit 1
          }

  test:
    name: Test (${{ matrix.os }})
    needs: lint
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      # ... checkout, setup, run tests
```

### Pattern 3: Platform-Conditional Steps

**What:** Use `if` conditions on steps to run only on specific platforms within the matrix.
**When to use:** bats tests only run on Linux and macOS (not Windows), macOS needs jq.
**Example:**

```yaml
      - name: Install jq (macOS)
        if: runner.os == 'macOS'
        run: brew install jq

      - name: Run bats tests
        if: runner.os != 'Windows'
        uses: bats-core/bats-action@v3.0.1
        with:
          path: tests/bash
```

### Pattern 4: Pester Version Pinning

**What:** Explicitly install Pester 5.6.1 regardless of preinstalled version to match test.sh behavior.
**When to use:** When consistent test behavior across local and CI is required (per D-08).
**Example:**

```yaml
      - name: Install Pester
        shell: pwsh
        run: |
          Install-Module -Name Pester -RequiredVersion 5.6.1 -Force -Scope CurrentUser
          Import-Module Pester
```

### Pattern 5: bats-action with ci.yml

**What:** The `bats-core/bats-action@v3.0.1` action runs bats tests and produces tap/junit output.
**When to use:** Running bats tests in GitHub Actions (per D-07).
**Example:**

```yaml
      - name: Run bats tests
        uses: bats-core/bats-action@v3.0.1
        with:
          bats-version: "1.11.0"
          path: tests/bash
```

### Anti-Patterns to Avoid

- **Using `macos-13` or pinned version runners:** D-04 explicitly locks `-latest`. Pinned versions become stale and require maintenance.
- **Running PSScriptAnalyzer only on Ubuntu:** D-06 requires all 3 platforms since PowerShell scripts contain platform-conditional code.
- **Relying on preinstalled Pester version:** macOS has 5.7.1 preinstalled which may behave differently from 5.6.1. Always install 5.6.1 explicitly (D-08).
- **Using `continue-on-error: true` for lint:** D-02 requires lint to gate tests. Lint failures must fail the job.
- **Splitting into multiple workflow files:** D-01 locks a single ci.yml.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| bats test runner in CI | Custom bash step to install bats from git, set up paths, run tests | `bats-core/bats-action@v3.0.1` | Official action handles installation, version pinning, TAP output, and path setup |
| Concurrency logic | Custom cancellation via GitHub API calls | `concurrency` key in workflow YAML | Built-in GH Actions feature, declarative, handles all edge cases |
| PowerShell module installation | Manual `Save-Module`, path manipulation, version checks | `Install-Module -Name X -RequiredVersion Y -Force -Scope CurrentUser` | Standard PowerShell cmdlet, handles dependencies, scope, and paths |
| Lint result formatting | Custom shell script to parse and display ShellCheck/PSSA output | ShellCheck and PSSA built-in output formatting + `::error` annotations | Both tools produce human-readable output natively; can add `$env:GITHUB_STEP_SUMMARY` for step summaries |

**Key insight:** GitHub Actions has mature built-in features for concurrency, permissions, and matrix. The only "external" tool needed is bats-action, which is the official bats GitHub Action. Everything else uses runner-preinstalled software.

## Common Pitfalls

### Pitfall 1: bats-action v4.0.0 Breaking Change
**What goes wrong:** `bats-core/bats-action@v4.0.0` (released 2025-02-08) requires an explicit `token:` parameter for `actions/checkout`. Without it, the action fails because it can't clone the repo.
**Why it happens:** v4.0.0 changed from implicit to explicit checkout token passing for security.
**How to avoid:** Use locked version `v3.0.1` (D-07) which handles checkout internally without the token parameter.
**Warning signs:** Action fails with "token not provided" or checkout errors.

### Pitfall 2: ShellCheck Timeout on ubuntu-24.04
**What goes wrong:** ShellCheck hangs or times out when running on Ubuntu 24.04 with certain shell scripts, particularly those with complex redirections or `set -euo pipefail`.
**Why it happens:** Known ShellCheck issue on newer Ubuntu versions, possibly related to the shellcheck version in apt vs the scripts' patterns.
**How to avoid:** Use `shellcheck --severity warning --check-sourced` (matching test.sh flags from D-06 context). If timeout occurs, consider running ShellCheck via a dedicated action like `ludeeus/action-shellcheck@master` instead of apt-get install.
**Warning signs:** Lint job hangs for 5+ minutes without output.

### Pitfall 3: macOS Runner jq Dependency
**What goes wrong:** bats tests fail on macOS because install.sh requires jq, and the runner's preinstalled jq is not in PATH or is an unexpected version.
**Why it happens:** D-05 explicitly adds `brew install jq` as a precaution. However, macOS runners have jq 1.8.1 preinstalled, so this step is a safety net.
**How to avoid:** Include the `brew install jq` step (D-05) as specified -- it's fast on macOS runners that already have Homebrew and is idempotent if already installed.
**Warning signs:** bats tests fail with "jq: command not found".

### Pitfall 4: PSScriptAnalyzer Install on macOS
**What goes wrong:** `Install-Module` on macOS might fail due to PSGallery trust or scope issues.
**Why it happens:** PowerShell on macOS may not have PSGallery trusted by default, or the `-Scope CurrentUser` path may differ.
**How to avoid:** Trust PSGallery first: `Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted`. Alternatively, rely on the preinstalled PSScriptAnalyzer (1.24.0+ confirmed on macOS runners) and skip installation there.
**Warning signs:** "Repository is not trusted" errors in PSSA step.

### Pitfall 5: Windows PowerShell vs pwsh
**What goes wrong:** Tests run under Windows PowerShell 5.1 instead of PowerShell 7 (pwsh), causing different behavior.
**Why it happens:** `shell: powershell` defaults to Windows PowerShell 5.1 on Windows runners. `shell: pwsh` uses PowerShell 7.
**How to avoid:** Always use `shell: pwsh` for Pester steps, not `shell: powershell`. The test.sh uses `pwsh -File` which invokes PowerShell 7.
**Warning signs:** Tests fail only on Windows with syntax errors or cmdlet-not-found errors.

### Pitfall 6: bats Tests on macOS -- stat Command Differences
**What goes wrong:** The `notify-play.bats` cooldown test (`BASH-02`) uses `date -d "@${old_epoch}"` which is GNU-specific and fails on macOS (BSD date).
**Why it happens:** macOS uses BSD date which doesn't support `-d @epoch`. The test was written for Linux.
**How to avoid:** The existing test file already uses `date -d "@${old_epoch}"` which will fail on macOS. This is a known gap -- the bats test suite (CI-08) targets Ubuntu+macOS, but BASH-02 may fail on macOS. The planner should account for this and either skip BASH-02 on macOS or fix the stat/date usage.
**Warning signs:** bats tests fail on macOS but pass on Ubuntu, specifically the "cooldown pass when lock file is older than 5 seconds" test.

### Pitfall 7: Pester Output Parsing in CI
**What goes wrong:** Pester's default output format floods the CI log, making it hard to find failures.
**Why it happens:** Pester 5.x defaults to `Normal` output which includes all passed tests.
**How to avoid:** Use `Invoke-Pester -Output Detailed` or `Invoke-Pester -Output Minimal` for CI. `Detailed` matches test.sh's local behavior. Consider adding `$env:GITHUB_STEP_SUMMARY` for a summary.
**Warning signs:** CI logs are hard to read; failures are buried in hundreds of passed test lines.

## Code Examples

### Concurrency Pattern (cancel PRs, queue main pushes)

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

Source: GitHub Actions documentation. HIGH confidence -- this is the standard pattern used across major open-source repos.

### bats-action Step

```yaml
      - name: Run bats tests
        if: runner.os != 'Windows'
        uses: bats-core/bats-action@v3.0.1
        with:
          bats-version: "1.11.0"
          path: tests/bash
```

Source: bats-core/bats-action README. HIGH confidence -- verified from GitHub releases that v3.0.1 exists.

### Pester Step with Version Pinning

```yaml
      - name: Run Pester tests
        shell: pwsh
        run: |
          if (-not (Get-Module -ListAvailable -Name Pester -ErrorAction SilentlyContinue | Where-Object Version -eq "5.6.1")) {
            Install-Module -Name Pester -RequiredVersion 5.6.1 -Force -Scope CurrentUser
          }
          Import-Module Pester -RequiredVersion 5.6.1
          Invoke-Pester -Path tests/powershell -Output Detailed
```

Source: Pester documentation and test.sh patterns. HIGH confidence.

### ShellCheck Step

```yaml
      - name: ShellCheck
        run: |
          sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
          shellcheck --severity warning --check-sourced \
            scripts/install.sh \
            scripts/uninstall.sh \
            scripts/notify-play.sh
```

Source: test.sh local lint pattern (line 27-30). HIGH confidence -- flags match the existing project convention.

### PSScriptAnalyzer Step

```yaml
      - name: PSScriptAnalyzer
        shell: pwsh
        run: |
          if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          }
          $results = Invoke-ScriptAnalyzer -Path scripts -Severity Warning -Recurse
          if ($results) {
              $results | Format-Table -AutoSize
              Write-Error "PSScriptAnalyzer found issues"
              exit 1
          }
```

Source: test.sh local lint pattern (line 50-62). HIGH confidence -- matches existing convention.

### Complete Lint + Test Workflow Skeleton

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
permissions:
  contents: read

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        run: |
          sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
          shellcheck --severity warning --check-sourced \
            scripts/install.sh \
            scripts/uninstall.sh \
            scripts/notify-play.sh
      - name: PSScriptAnalyzer
        shell: pwsh
        run: |
          if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          }
          $results = Invoke-ScriptAnalyzer -Path scripts -Severity Warning -Recurse
          if ($results) {
              $results | Format-Table -AutoSize
              Write-Error "PSScriptAnalyzer found issues"
              exit 1
          }

  test:
    name: Test (${{ matrix.os }})
    needs: lint
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4

      # --- bats tests (Linux + macOS only) ---
      - name: Install jq (macOS)
        if: runner.os == 'macOS'
        run: brew install jq

      - name: Run bats tests
        if: runner.os != 'Windows'
        uses: bats-core/bats-action@v3.0.1
        with:
          bats-version: "1.11.0"
          path: tests/bash

      # --- Pester tests (all platforms) ---
      - name: Install Pester
        shell: pwsh
        run: |
          Install-Module -Name Pester -RequiredVersion 5.6.1 -Force -Scope CurrentUser
          Import-Module Pester -RequiredVersion 5.6.1

      - name: Run Pester tests
        shell: pwsh
        run: |
          Invoke-Pester -Path tests/powershell -Output Detailed
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `set -e` only | `set -euo pipefail` | Standard best practice for years | All project bash scripts already use this |
| `shell: powershell` | `shell: pwsh` | PowerShell 7 available on all runners | Must use pwsh for cross-platform consistency |
| Multiple workflow files | Single ci.yml | -- | D-01 locks single file approach |
| Manual bats install | bats-core/bats-action | 2024 | Official action is cleaner than manual git clone + install |

**Deprecated/outdated:**
- `macos-12` runner: Apple Silicon runners (macos-13, macos-14, macos-latest) are current. D-04 uses `-latest` which auto-updates.
- `ubuntu-20.04` runner: Reached end-of-life. `-latest` currently points to ubuntu-24.04.

## Open Questions

1. **macOS bats test BASH-02 (stat/date compatibility)**
   - What we know: The `notify-play.bats` cooldown-pass test uses `date -d "@${old_epoch}"` which is GNU-specific. macOS uses BSD date which does not support `-d @epoch`.
   - What's unclear: Whether this test is expected to pass on macOS in CI-08, or whether it should be skipped on macOS.
   - Recommendation: Planner should handle this -- either (a) skip the test on macOS with `@test "..." { if [[ "$(uname -s)" == "Darwin" ]]; then skip "GNU date not available on macOS"; fi; ... }`, or (b) use a POSIX-compatible date approach. This is likely a real issue that will cause CI-08 to fail on macOS without a fix.

2. **PSScriptAnalyzer installation on macOS**
   - What we know: macOS runners have PSScriptAnalyzer 1.24.0+ preinstalled. D-06 requires PSSA on all platforms.
   - What's unclear: Whether the preinstalled version is sufficient or if a specific version should be installed.
   - Recommendation: Rely on preinstalled PSSA on macOS (it's recent enough) and only `Install-Module` on Ubuntu (where it's not preinstalled). Windows also has it preinstalled.

3. **Concurrency group name**
   - What we know: D-11 locks the behavior (cancel PRs, queue main). Claude has discretion on naming.
   - What's unclear: Exact naming convention.
   - Recommendation: Use `ci-${{ github.ref }}` which is the standard pattern -- it creates separate concurrency groups per branch, so PRs to different branches don't cancel each other.

## Environment Availability

This phase creates a GitHub Actions workflow. The CI runners provide all required tools. No local environment dependencies are needed for writing the workflow YAML. However, verifying the workflow locally requires:

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| git | Pushing ci.yml to trigger CI | Yes | system | -- |
| GitHub repo access | Workflow execution | Yes | -- | -- |
| GitHub Actions runner | All CI tools (bash, pwsh, etc.) | N/A (remote) | -- | -- |

**Step 2.6: Environment audit not applicable** -- this phase creates a CI workflow YAML file. All dependencies run on GitHub-hosted runners, not the local machine. The workflow file itself is pure YAML with no build step.

## Validation Architecture

> Skipped: `workflow.nyquist_validation` is explicitly set to `false` in `.planning/config.json`.

## Sources

### Primary (HIGH confidence)
- GitHub Actions official documentation -- workflow syntax, triggers, concurrency, permissions, matrix
- bats-core/bats-action v3.0.1 -- verified exists via GitHub releases page (released 2024-03-27)
- Pester 5.6.1 -- verified via PowerShell Gallery, matches test.sh pin
- test.sh (project file) -- reference for ShellCheck flags, PSSA flags, Pester version
- 10-CONTEXT.md -- locked decisions D-01 through D-13

### Secondary (MEDIUM confidence)
- GitHub Actions runner software lists (ubuntu-latest, macos-latest, windows-latest) -- preinstalled tools verified via web search
- macOS runner jq preinstallation (jq 1.8.1) -- confirmed via GitHub Actions runner README
- bats-core/bats-action v4.0.0 breaking change -- confirmed via release notes (requires explicit token parameter)

### Tertiary (LOW confidence)
- ShellCheck timeout on ubuntu-24.04 -- reported in community issues but not confirmed first-hand
- PSScriptAnalyzer exact preinstalled version on macOS -- verified as 1.24.0+ via software list, but exact minor version may vary

## Project Constraints (from CLAUDE.md)

- **GSD Workflow Enforcement:** All changes must go through `/gsd:execute-phase` -- do not make direct repo edits outside GSD workflow
- **Conventional commits:** Use `feat:`, `fix:`, `docs:`, `chore:` prefixes
- **Code artifacts in English:** Comments, commit messages in English
- **Small, focused changes:** Prefer small, incremental commits

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are standard CI tools with verified versions and official sources
- Architecture: HIGH - Workflow patterns are well-documented GitHub Actions patterns
- Pitfalls: MEDIUM-HIGH - Most pitfalls are from verified sources; the macOS date compatibility issue is certain but needs planner action

**Research date:** 2026-03-31
**Valid until:** 60 days (GitHub Actions runner images update ~monthly, but core patterns are stable)
