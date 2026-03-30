# Architecture Research: Cross-Platform Test Infrastructure (v1.2)

**Domain:** Test infrastructure for shell (bash) and PowerShell notification scripts
**Researched:** 2026-03-30
**Confidence:** HIGH

## Executive Summary

This research covers how to build a cross-platform test infrastructure for the 6 existing notification scripts (3 bash + 3 PowerShell). The architecture uses a dual-track approach: bats-core for bash tests and Pester for PowerShell tests, with ShellCheck and PSScriptAnalyzer for static analysis. The Docker test matrix runs both tracks in containers (Linux for bash, Windows Server Core for PowerShell) orchestrated by a single `test.sh` entry point. Mocking strategy relies on filesystem isolation via temp directories (bats `$BATS_TMPDIR` / Pester `TestDrive`) rather than function mocking, because the scripts under test are standalone executables invoked as subprocesses, not sourced libraries.

## What Gets Tested (and What Does Not)

### In Scope

| File | Type | What to Test |
|------|------|-------------|
| `scripts/install.sh` | bash | jq hook injection, audio file copy, prerequisite checks, version comparison |
| `scripts/uninstall.sh` | bash | jq hook removal, audio file deletion, idempotency |
| `scripts/notify-play.sh` | bash | Cooldown logic, OS detection, lock file creation, exit code always 0 |
| `scripts/install.ps1` | PowerShell | JSON hook injection, audio copy, BOM-free write, prerequisite checks |
| `scripts/uninstall.ps1` | PowerShell | JSON hook removal, audio deletion, empty hooks cleanup |
| `scripts/notify-play.ps1` | PowerShell | Cooldown logic, MediaPlayer mock, lock file, exit code always 0 |

### Out of Scope

| Component | Why Excluded |
|-----------|-------------|
| `Dockerfile` (TTS) | Separate concern -- audio generation, not notification logic |
| `generate.sh` / `generate.py` | Already has `test_generate_args.py` -- Python unit tests |
| `audio/notify-*.mp3` | Binary files, no logic to test |
| Claude Code itself | Not our code, cannot test hook dispatch |

## Architecture Overview

```
+------------------------------------------------------------------+
|                    test.sh (Entry Point)                         |
|                                                                  |
|  Usage: ./test.sh [--shell] [--powershell] [--all]               |
|  Runs static analysis + unit tests for selected platform(s)      |
+------------------------------------------------------------------+
        |                              |
        v                              v
+-------------------+    +----------------------------+
| Bash Track       |    | PowerShell Track           |
|                   |    |                            |
| 1. ShellCheck     |    | 1. PSScriptAnalyzer        |
|    scripts/*.sh   |    |    scripts/*.ps1           |
|                   |    |                            |
| 2. bats-core      |    | 2. Pester                  |
|    tests/bash/    |    |    tests/powershell/       |
+-------------------+    +----------------------------+
        |                              |
        v                              v
+------------------------------------------------------------------+
|                    Docker Test Matrix                            |
|                                                                  |
|  Container 1: debian:bookworm-slim   (bash track)                |
|  Container 2: mcr.microsoft.com/.../nanoserver (PS track)        |
|                                                                  |
|  Orchestrated by test.sh via docker run for each track           |
+------------------------------------------------------------------+
```

## Recommended Project Structure

```
notify-research/
├── audio/                          # (UNCHANGED)
│   ├── notify-complete.mp3
│   ├── notify-confirm.mp3
│   ├── notify-error.mp3
│   └── notify-progress.mp3
├── scripts/                        # (UNCHANGED -- files under test)
│   ├── install.sh
│   ├── uninstall.sh
│   ├── notify-play.sh
│   ├── install.ps1
│   ├── uninstall.ps1
│   └── notify-play.ps1
├── tests/                          # (NEW -- all test infrastructure)
│   ├── test_helpers/               # Shared fixtures and test data
│   │   ├── fixtures/               # Static test data files
│   │   │   ├── settings-empty.json     # Minimal valid settings.json
│   │   │   ├── settings-with-hooks.json # settings.json with existing hooks
│   │   │   └── fake-audio.mp3          # Small MP3 file for testing copy/play
│   │   ├── common.bash              # Shared bash test utilities
│   │   └── common.ps1              # Shared PowerShell test utilities
│   ├── bash/                       # bats-core tests
│   │   ├── install.bats            # Tests for install.sh
│   │   ├── uninstall.bats          # Tests for uninstall.sh
│   │   ├── notify_play.bats        # Tests for notify-play.sh
│   │   └── test_helper/            # bats-core helper libraries
│   │       ├── bats-support/       # (git submodule or vendored)
│   │       └── bats-assert/        # (git submodule or vendored)
│   └── powershell/                 # Pester tests
│       ├── install.Tests.ps1       # Tests for install.ps1
│       ├── uninstall.Tests.ps1     # Tests for uninstall.ps1
│       └── notify_play.Tests.ps1   # Tests for notify-play.ps1
├── Dockerfile.test                 # (NEW) Multi-stage test runner image
├── test.sh                         # (NEW) Local test orchestrator
├── .shellcheckrc                   # (NEW) ShellCheck configuration
├── .bats.yaml                      # (NEW) bats-core configuration (optional)
├── PSScriptAnalyzerSettings.psd1   # (NEW) PSScriptAnalyzer rules config
├── Dockerfile                      # (UNCHANGED) TTS generation
├── generate.sh                     # (UNCHANGED)
├── generate.py                     # (UNCHANGED)
├── test_generate_args.py           # (UNCHANGED) Existing Python tests
└── requirements.txt                # (UNCHANGED)
```

### Structure Rationale

- **`tests/` top-level:** Separates test infrastructure from production code. The existing `test_generate_args.py` stays at root because it tests `generate.py` at root -- moving it would break its relative import. New test infrastructure goes in `tests/`.
- **`tests/bash/` and `tests/powershell/`:** Parallel directories for each test runner. This makes it easy to run one track independently (`bats tests/bash/` or `Invoke-Pester tests/powershell/`).
- **`tests/test_helpers/fixtures/`:** Shared test data (fake JSON, fake MP3). Both bash and PowerShell tests reference the same fixture files, avoiding duplication.
- **`tests/bash/test_helper/`:** Vendored bats-support and bats-assert. These are small libraries (2-3 files each). Vendoring avoids network dependency at test time and pins versions. Alternative: git submodules. Vendoring is simpler for a small project.
- **`test.sh` at root:** Single entry point. Matches the pattern of `generate.sh` -- a shell script at the project root that orchestrates the workflow. Developers run `./test.sh` and everything happens.

## Docker Test Matrix Architecture

The test matrix uses two separate Docker containers, one per platform track. There is no multi-platform Docker build (no need for ARM emulation). Both containers run on the host Linux machine.

### Container 1: Bash Test Runner

```dockerfile
# Dockerfile.test (partial -- bash stage)
FROM debian:bookworm-slim

# Install test dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    jq \
    shellcheck \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install bats-core + helpers from source
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core && \
    /tmp/bats-core/install.sh /usr/local && \
    rm -rf /tmp/bats-core

RUN git clone --depth 1 https://github.com/bats-core/bats-support.git /tmp/bats-support && \
    cp -r /tmp/bats-support/* /usr/local/lib/bats-support/ && \
    rm -rf /tmp/bats-support

RUN git clone --depth 1 https://github.com/bats-core/bats-assert.git /tmp/bats-assert && \
    cp -r /tmp/bats-assert/* /usr/local/lib/bats-assert/ && \
    rm -rf /tmp/bats-assert

# Copy project
COPY . /app
WORKDIR /app

# Default: run bash test track
CMD ["bash", "-c", "shellcheck scripts/*.sh && bats tests/bash/"]
```

**Key decisions:**
- `debian:bookworm-slim` matches the existing Dockerfile base. Keeps consistency.
- `jq` is installed because `install.sh` and `uninstall.sh` require it.
- `shellcheck` runs as a separate step before bats, failing fast on lint errors.
- bats-core installed from git (latest stable) rather than Debian package because the Debian version (`bats` package) is often outdated.

**Confidence: HIGH** -- bats-core Docker installation is documented in the [official README](https://github.com/bats-core/bats-core). ShellCheck is available in Debian repos.

### Container 2: PowerShell Test Runner

```dockerfile
# Dockerfile.test (partial -- PowerShell stage)
FROM mcr.microsoft.com/powershell:lts-nanoserver-ltsc2022

# Install Pester and PSScriptAnalyzer
RUN pwsh -Command "Install-Module -Name Pester -Force -Scope AllUsers; \
                   Install-Module -Name PSScriptAnalyzer -Force -Scope AllUsers"

# Copy project
COPY . /app
WORKDIR /app

# Default: run PowerShell test track
CMD ["pwsh", "-Command", "Invoke-ScriptAnalyzer -Path scripts -Recurse -EnableExit; \
                        Invoke-Pester -Path tests/powershell -Output Detailed"]
```

**Key decisions:**
- `mcr.microsoft.com/powershell:lts-nanoserver-ltsc2022` provides PowerShell 7 LTS on Windows Nano Server. This is the smallest Windows container image with pwsh. Nano Server does NOT have `presentationCore` (MediaPlayer) -- this is acceptable because `notify-play.ps1` MediaPlayer tests will be mocked.
- Pester and PSScriptAnalyzer installed from PowerShell Gallery via `Install-Module`.
- `Invoke-ScriptAnalyzer -EnableExit` makes lint errors fail the container (non-zero exit code).
- **Nano Server caveat:** Nano Server lacks full .NET Framework. `System.Windows.Media.MediaPlayer` (presentationCore) is NOT available in Nano Server containers. Tests that mock MediaPlayer are fine; tests that actually play audio must be skipped in Docker and only run natively on Windows.

**Confidence: MEDIUM** -- Nano Server limitation on presentationCore is documented in Microsoft docs. This means notify-play.ps1 audio playback tests must be conditional (mocked in Docker, integration-tested on real Windows only).

### Alternative: Two Separate Dockerfiles

Instead of a multi-stage Dockerfile.test, use two separate files:

```
Dockerfile.test-bash      # Debian + bash + shellcheck + bats
Dockerfile.test-powershell # Windows + pwsh + Pester + PSScriptAnalyzer
```

**Recommendation:** Use two separate Dockerfiles. Rationale:
1. Multi-platform Dockerfiles (Linux + Windows in one file) require `--platform` argument on every build, which is error-prone.
2. The two containers share no build stages -- they are completely independent.
3. `test.sh` simply selects which Dockerfile to build and run.
4. Simpler to understand and maintain.

### test.sh Orchestrator

```bash
#!/usr/bin/env bash
# test.sh -- Run all tests (static analysis + unit tests)
# Usage: ./test.sh [--bash] [--powershell] [--all] [--no-docker]
set -euo pipefail

RUN_BASH=false
RUN_POWERSHELL=false
USE_DOCKER=true

# Parse args (simplified)
for arg in "$@"; do
    case "$arg" in
        --bash)       RUN_BASH=true ;;
        --powershell) RUN_POWERSHELL=true ;;
        --all)        RUN_BASH=true; RUN_POWERSHELL=true ;;
        --no-docker)  USE_DOCKER=false ;;
    esac
done

# Default: run bash tests (since we're on Linux)
if [ "$RUN_BASH" = false ] && [ "$RUN_POWERSHELL" = false ]; then
    RUN_BASH=true
fi

if [ "$RUN_BASH" = true ]; then
    if [ "$USE_DOCKER" = true ]; then
        docker build -f Dockerfile.test-bash -t notify-test-bash .
        docker run --rm notify-test-bash
    else
        shellcheck scripts/*.sh
        bats tests/bash/
    fi
fi

if [ "$RUN_POWERSHELL" = true ]; then
    if [ "$USE_DOCKER" = true ]; then
        docker build -f Dockerfile.test-powershell -t notify-test-powershell .
        docker run --rm notify-test-powershell
    else
        pwsh -Command "Invoke-ScriptAnalyzer -Path scripts -Recurse -EnableExit; \
                        Invoke-Pester -Path tests/powershell -Output Detailed"
    fi
fi
```

**Confidence: HIGH** -- this is a standard shell test orchestration pattern.

## Mocking Strategy

The fundamental challenge: scripts are invoked as subprocesses (`./scripts/install.sh`), not sourced as functions. This means you cannot mock internal functions -- you must mock external dependencies instead.

### Bash Track: Temp Directory Isolation

**Pattern:** Redirect all filesystem operations to a temp directory via environment variable overrides or wrapper scripts.

```
Real script reads:  $HOME/.claude/settings.json
Test provides:      $TEST_HOME/.claude/settings.json  (temp dir)

Real script writes: /tmp/claude-notify-complete.lock
Test provides:      $TEST_TMP/claude-notify-complete.lock (temp dir)
```

**Implementation for each script:**

#### install.sh Mocking

`install.sh` hardcodes `$HOME/.claude/settings.json`. The script uses `$HOME` directly, not a variable we can override. Two approaches:

**Approach A (recommended): Override HOME in test.**
```bash
@test "install.sh copies audio files to claude dir" {
    TEST_HOME="$(mktemp -d)"
    # Create fake settings.json
    echo '{}' > "$TEST_HOME/.claude/settings.json"
    # Create fake audio source
    mkdir -p "$TEST_HOME/repo/audio"
    for type in complete confirm error progress; do
        echo "fake" > "$TEST_HOME/repo/audio/notify-${type}.mp3"
    done
    # Copy script under test
    cp "$BATS_TEST_DIRNAME/../../scripts/install.sh" "$TEST_HOME/repo/scripts/"

    run env HOME="$TEST_HOME" bash "$TEST_HOME/repo/scripts/install.sh"

    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/notify-complete.mp3" ]
}
```

**Why HOME override works:** `install.sh` line 10 sets `CLAUDE_DIR="$HOME/.claude"`. By overriding `$HOME`, all paths redirect to the temp directory. The script also references `SCRIPT_DIR` and `REPO_ROOT` via `dirname "$0"`, so we must place the script at the expected location relative to the fake repo structure.

**Approach B (not recommended): Refactor scripts to accept configurable paths.**
This changes production code for testability. Not worth it for 6 small scripts.

#### uninstall.sh Mocking

Same HOME override pattern. After install, run uninstall and verify files are gone and settings.json has no hook entries.

#### notify-play.sh Mocking

`notify-play.sh` uses `/tmp/claude-notify-${TYPE}.lock` (hardcoded path). Two sub-problems:

1. **Lock file path:** Can override by setting `LOCK_FILE` -- but the script hardcodes it on line 14. For unit testing, we need to either:
   - Patch the script to use an env var for the lock file path (minor refactor)
   - Or accept writing to `/tmp` in tests (harmless for CI)

   **Recommendation:** Add a one-line refactor to notify-play.sh: `LOCK_FILE="${NOTIFY_LOCK_DIR:-/tmp}/claude-notify-${TYPE}.lock"`. This lets tests set `NOTIFY_LOCK_DIR` to a temp directory without changing production behavior (defaults to `/tmp`).

2. **Audio player mocking:** The script calls `/usr/bin/paplay` or `/usr/bin/afplay`. In tests, mock the player command:
   ```bash
   setup() {
       # Create a fake player that succeeds
       echo '#!/bin/bash' > "$TEST_TMP/fake-player"
       echo 'exit 0' >> "$TEST_TMP/fake-player"
       chmod +x "$TEST_TMP/fake-player"
       export PATH="$TEST_TMP:$PATH"
       # Create fake audio file
       echo "fake mp3 data" > "$TEST_TMP/test.mp3"
   }

   @test "notify-play.sh calls player when not in cooldown" {
       run bash scripts/notify-play.sh complete "$TEST_TMP/test.mp3"
       [ "$status" -eq 0 ]
   }
   ```

   By prepending a directory with a fake `paplay` and `afplay` to `$PATH`, the script calls the fake instead of the real player.

### PowerShell Track: TestDrive + Mock

Pester provides two mocking mechanisms:

1. **TestDrive:** A temporary PSDrive that is automatically cleaned up. Use it for file I/O tests.
2. **Mock:** Intercepts PowerShell cmdlet calls. Use it for external dependencies.

#### install.ps1 Mocking

**TestDrive for settings.json:**
```powershell
Describe "install.ps1" {
    BeforeAll {
        # Source the script (dot-source)
        . "$PSScriptRoot/../../scripts/install.ps1" -RepoPath (Join-Path $PSScriptRoot "../../")
    }

    Context "hook injection" {
        BeforeAll {
            # Create fake settings.json in TestDrive
            $fakeSettings = '{"hooks": {}}'
            Set-Content -Path "TestDrive:/.claude/settings.json" -Value $fakeSettings
            Set-Content -Path "TestDrive:/.claude/settings.json" -Value '{"hooks":{}}' -NoNewline

            # Create fake audio files in TestDrive
            foreach ($type in @("complete", "confirm", "error", "progress")) {
                Set-Content -Path "TestDrive:/audio/notify-$type.mp3" -Value "fake"
            }
        }

        It "injects Stop hook into settings.json" {
            # Mock Get-Content to read from TestDrive instead of real path
            Mock Get-Content -MockWith {
                Get-Content "TestDrive:/.claude/settings.json" -Raw
            } -ParameterFilter { $Path -like "*settings.json" }
            # ... assertions
        }
    }
}
```

**However**, `install.ps1` is written as a script with `param()` and top-level code, not as a function. This makes it harder to unit test because running the script triggers all its side effects immediately.

**Practical approach for install.ps1:** Test it as a black-box subprocess, similar to the bash approach:

```powershell
It "installs hooks and copies audio files" {
    $result = pwsh -File "$PSScriptRoot/../../scripts/install.ps1" `
        -RepoPath $TestDrive
    $result | Should -Be 0
    "$TestDrive/../.claude/notify-complete.mp3" | Should -Exist
}
```

**Recommendation:** Use subprocess invocation for install.ps1 and uninstall.ps1 (they are installers -- testing their observable behavior, not internal functions). Use `Mock` only for notify-play.ps1 where we can intercept `Add-Type`, `New-Object`, and `Get-Item`.

#### notify-play.ps1 Mocking

```powershell
Describe "notify-play.ps1" {
    Context "cooldown" {
        It "skips playback when within cooldown" {
            # Create a recent lock file
            $lockFile = Join-Path $env:TEMP "claude-notify-test.lock"
            Set-Content -Path $lockFile -Value (Get-Date).ToString() -NoNewline

            Mock Get-Item -MockWith {
                [PSCustomObject]@{ LastWriteTime = (Get-Date).AddSeconds(-2) }
            } -ParameterFilter { $Path -like "*test.lock" }

            $result = pwsh -File "$PSScriptRoot/../../scripts/notify-play.ps1" `
                -Type test -AudioFile "fake.mp3"
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "audio playback" {
        It "calls MediaPlayer when not in cooldown" {
            Mock Add-Type {}  # No-op the assembly load
            Mock New-Object -MockWith {
                [PSCustomObject]@{
                    Open = { param($u) }
                    Play = {}
                    Close = {}
                    Position = [TimeSpan]::Zero
                    NaturalDuration = [PSCustomObject]@{
                        HasTimeSpan = $false
                    }
                }
            } -ParameterFilter { $TypeName -like "*MediaPlayer*" }

            pwsh -File "$PSScriptRoot/../../scripts/notify-play.ps1" `
                -Type test -AudioFile "fake.mp3"
            $LASTEXITCODE | Should -Be 0
        }
    }
}
```

**Confidence: MEDIUM** -- Pester's `Mock` for `New-Object` with complex type names can be tricky. The exact mock syntax may need adjustment. This is a known Pester limitation when mocking constructor calls.

## Static Analysis Configuration

### ShellCheck (.shellcheckrc)

```bash
# .shellcheckrc
# Exclude rules that are acceptable for this project
exclude=SC2312  # Invoke command as 'command ...' -- intentional direct invocations
shell=bash
severity=warning
source-path=scripts
```

**Why severity=warning:** Start with warnings. Errors (severity=error) are too permissive for a small project -- would miss real issues like unquoted variables. Info (severity=info) is too noisy for initial adoption.

**Recommendation for install.sh:** The script uses `[ "$1" = "$2" ]` in `version_gte()` which ShellCheck flags as SC3010 (not POSIX). Since the shebang is `#!/usr/bin/env bash`, this is fine. Add `# shellcheck disable=SC3010` inline or configure in `.shellcheckrc`.

### PSScriptAnalyzer (PSScriptAnalyzerSettings.psd1)

```powershell
# PSScriptAnalyzerSettings.psd1
@{
    Severity = @('Error', 'Warning')
    Rules    = @{
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $false
        }
        PSUseApprovedVerbs = @{
            Enable = $false
        }
    }
}
```

**Why disable PSUseShouldProcessForStateChangingFunctions:** install.ps1 and uninstall.ps1 modify settings.json (state change) but are scripts, not functions. They don't need `-WhatIf`/`-Confirm`. This rule is designed for PowerShell modules/cmdlets, not standalone scripts.

**Confidence: HIGH** -- PSScriptAnalyzer settings are documented at [GitHub](https://github.com/PowerShell/PSScriptAnalyzer).

## Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|----------------|-------------------|
| `test.sh` | Top-level orchestrator; builds Docker images if needed; selects test tracks | Docker CLI, bats-core, Pester, ShellCheck |
| `Dockerfile.test-bash` | Builds Linux container with shellcheck + bats + jq | Host filesystem (mounts project via COPY) |
| `Dockerfile.test-powershell` | Builds Windows container with Pester + PSScriptAnalyzer | Host filesystem (mounts project via COPY) |
| `tests/bash/*.bats` | Unit tests for bash scripts; temp dir isolation | bats-support, bats-assert, scripts/*.sh |
| `tests/powershell/*.Tests.ps1` | Unit tests for PowerShell scripts; TestDrive + Mock | Pester framework, scripts/*.ps1 |
| `tests/test_helpers/fixtures/` | Shared test data (fake JSON, fake MP3) | Both bash and PowerShell test tracks |
| `.shellcheckrc` | ShellCheck rule configuration | ShellCheck binary |
| `PSScriptAnalyzerSettings.psd1` | PSScriptAnalyzer rule configuration | Invoke-ScriptAnalyzer cmdlet |

## Data Flow: Test Execution

```
Developer runs: ./test.sh --all
    |
    v
test.sh checks: Docker available?
    |           |
    | Yes       | No
    v           v
Docker path   Local path
    |           |
    v           v
+-- Bash Track --+
|  shellcheck    |     shellcheck scripts/*.sh
|  scripts/*.sh  |     bats tests/bash/*.bats
|  bats          |
|  tests/bash/   |
+----------------+
    |
    v
+-- PowerShell Track --+
|  Invoke-ScriptAnalyzer |     pwsh -c "Invoke-ScriptAnalyzer ..."
|  scripts/*.ps1         |     pwsh -c "Invoke-Pester ..."
|  Invoke-Pester         |
|  tests/powershell/     |
+------------------------+
    |
    v
Exit 0 = all passed
Exit 1 = any failure
```

## Architectural Patterns

### Pattern 1: HOME Override for Filesystem Isolation

**What:** Override `$HOME` environment variable when invoking scripts to redirect all `$HOME/.claude/` operations to a temp directory.
**When:** Testing install.sh and uninstall.sh (both use `$HOME` for path resolution).
**Trade-offs:** Works because scripts use `$HOME` directly. Breaks if scripts ever resolve `$HOME` via `getent` or other indirection. Safe for this project because all scripts use `$HOME` as a simple variable.

### Pattern 2: PATH Prepend for Command Mocking

**What:** Create a fake command (e.g., fake `paplay`) in a temp directory, prepend that directory to `$PATH`. The script calls the fake instead of the real command.
**When:** Mocking `paplay`, `afplay`, `jq`, `claude` in bash tests. Equivalent to Pester's `Mock` for PowerShell.
**Trade-offs:** Only works for commands invoked without absolute path. notify-play.sh uses `/usr/bin/paplay` (absolute path), so PATH prepend does NOT work there -- must use a different approach (temp directory override or minor script refactor).

### Pattern 3: TestDrive for PowerShell File I/O

**What:** Use Pester's built-in `TestDrive:` PSDrive for file operations in tests. Files are automatically cleaned up.
**When:** Creating fake settings.json, fake MP3 files, fake lock files in PowerShell tests.
**Trade-offs:** TestDrive paths are different from real paths, so scripts that hardcode paths need the path to be parameterized or the script must be invoked with overridden environment variables.

### Pattern 4: Dual Dockerfile Test Matrix

**What:** Separate Dockerfiles for each platform track, orchestrated by a shell script.
**When:** Testing cross-platform scripts on a single host. Avoids needing a macOS machine or Windows machine for CI.
**Trade-offs:** Windows containers require Docker Desktop with Windows containers enabled (not available on Linux without emulation). PowerShell tests in Docker use Nano Server which lacks presentationCore. Some tests must be skipped or mocked in Docker.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Sourcing Scripts Instead of Invoking Them

**What:** Using `source scripts/install.sh` or `. scripts/install.sh` in tests instead of running them as subprocesses.

**Why wrong:** install.sh has top-level side effects (copies files, modifies settings.json). Sourcing executes all side effects immediately in the test process. Also, `set -euo pipefail` in the script will kill the test runner on any error.

**Do instead:** Always invoke scripts as subprocesses: `run bash scripts/install.sh` (bats) or `pwsh -File scripts/install.ps1` (Pester). Capture exit code and output.

### Anti-Pattern 2: Testing Against Real ~/.claude/settings.json

**What:** Running install.sh without mocking and letting it modify the developer's actual settings.json.

**Why wrong:** Destructive. Every test run modifies real settings. Non-reproducible (depends on developer's current settings).

**Do instead:** Always override `$HOME` to a temp directory. Never test against real user data.

### Anti-Pattern 3: Relying on Docker for macOS Testing

**What:** Trying to run macOS-specific tests (afplay, BSD stat) in a Docker container.

**Why wrong:** Docker on Linux cannot run macOS binaries. There is no macOS Docker image that runs on Linux hosts.

**Do instead:** macOS tests in Docker test Linux behavior only (paplay, GNU stat). Test the `Darwin` code path via environment variable overrides (set `OS=Darwin` before sourcing the OS detection logic, or test the stat command selection separately).

### Anti-Pattern 4: Installing bats-core from npm

**What:** Using `npm install @bats-core/bats` in Docker.

**Why wrong:** The npm package is a repackaging of the shell script. It adds Node.js as a dependency just to install a bash test runner. The `install.sh` method from the GitHub repo is the canonical and lighter approach.

**Do instead:** `git clone && install.sh /usr/local` in the Dockerfile. Pin to a specific tag for reproducibility.

### Anti-Pattern 5: Git Submodules for bats-support/bats-assert

**What:** Using git submodules to track bats-support and bats-assert.

**Why wrong:** Submodules add complexity (detached HEAD state, submodule init/update). For 2-3 small files, submodules are overkill. They also require `.gitmodules` management.

**Do instead:** Vendor the files directly into `tests/bash/test_helper/`. Update by copying from upstream when needed. For a project with 6 scripts under test, the maintenance cost of submodules exceeds the benefit.

## Build Order and Dependencies

```
Phase 1: Create test directory structure and fixtures
    |-- Create tests/bash/, tests/powershell/, tests/test_helpers/fixtures/
    |-- Create fake-audio.mp3, settings-empty.json, settings-with-hooks.json
    Depends on: Nothing
    Blocks: All subsequent phases

Phase 2: Configure static analysis tools
    |-- Create .shellcheckrc, PSScriptAnalyzerSettings.psd1
    |-- Run shellcheck and PSScriptAnalyzer against existing scripts
    |-- Fix or suppress legitimate findings
    Depends on: Nothing (independent of Phase 1)
    Blocks: Phase 4, Phase 5

Phase 3: Write bash unit tests (bats-core)
    |-- tests/bash/notify_play.bats (simplest, test cooldown logic first)
    |-- tests/bash/uninstall.bats (test jq hook removal)
    |-- tests/bash/install.bats (most complex, full integration test)
    Depends on: Phase 1 (fixtures), Phase 2 (shellcheck clean)
    Blocks: Phase 6

Phase 4: Write PowerShell unit tests (Pester)
    |-- tests/powershell/notify_play.Tests.ps1 (mock MediaPlayer)
    |-- tests/powershell/uninstall.Tests.ps1 (test JSON removal)
    |-- tests/powershell/install.Tests.ps1 (most complex)
    Depends on: Phase 1 (fixtures), Phase 2 (PSScriptAnalyzer clean)
    Blocks: Phase 6

Phase 5: Create Docker test images
    |-- Dockerfile.test-bash
    |-- Dockerfile.test-powershell
    Depends on: Phase 3 (bash tests exist), Phase 4 (PowerShell tests exist)
    Blocks: Phase 6

Phase 6: Create test.sh orchestrator
    |-- Wire up all tracks
    |-- Verify ./test.sh --all works end-to-end
    Depends on: Phase 3, Phase 4, Phase 5
    Blocks: Nothing
```

**Parallelism:** Phase 2 and Phase 3 can run in parallel. Phase 3 and Phase 4 can run in parallel (bash and PowerShell tests are independent).

## Integration Points with Existing Code

### What Gets Modified

| Existing File | Modification | Reason |
|---------------|-------------|--------|
| `scripts/notify-play.sh` | Add env var override for LOCK_FILE path | Allows tests to control lock file location. One-line change: `LOCK_FILE="${NOTIFY_LOCK_DIR:-/tmp}/claude-notify-${TYPE}.lock"` |
| `.gitignore` | Add `__pycache__/`, test artifacts | Already has `__pycache__/`. May need no changes. |

### What Stays Unchanged

| Existing File | Why No Changes |
|---------------|---------------|
| `scripts/install.sh` | Tested as black box via HOME override. No source changes needed. |
| `scripts/uninstall.sh` | Same as install.sh. |
| `scripts/install.ps1` | Tested as black box. No source changes needed. |
| `scripts/uninstall.ps1` | Same. |
| `scripts/notify-play.ps1` | MediaPlayer mocked via Pester Mock. No source changes needed. |
| `Dockerfile` | TTS generation is a separate concern. Not involved in testing. |
| `audio/notify-*.mp3` | Binary files. Tests use fake audio from fixtures. |

### New Files Created

| File | Purpose |
|------|---------|
| `tests/bash/install.bats` | bats tests for install.sh |
| `tests/bash/uninstall.bats` | bats tests for uninstall.sh |
| `tests/bash/notify_play.bats` | bats tests for notify-play.sh |
| `tests/bash/test_helper/bats-support/` | Vendored bats-support library |
| `tests/bash/test_helper/bats-assert/` | Vendored bats-assert library |
| `tests/powershell/install.Tests.ps1` | Pester tests for install.ps1 |
| `tests/powershell/uninstall.Tests.ps1` | Pester tests for uninstall.ps1 |
| `tests/powershell/notify_play.Tests.ps1` | Pester tests for notify-play.ps1 |
| `tests/test_helpers/fixtures/settings-empty.json` | Empty settings.json for tests |
| `tests/test_helpers/fixtures/settings-with-hooks.json` | Settings with pre-existing hooks |
| `tests/test_helpers/fixtures/fake-audio.mp3` | Minimal valid MP3 for file copy tests |
| `Dockerfile.test-bash` | Docker image for bash test track |
| `Dockerfile.test-powershell` | Docker image for PowerShell test track |
| `test.sh` | Top-level test orchestrator |
| `.shellcheckrc` | ShellCheck configuration |
| `PSScriptAnalyzerSettings.psd1` | PSScriptAnalyzer configuration |

## Sources

- [bats-core GitHub](https://github.com/bats-core/bats-core) -- installation, usage, TAP output format (HIGH confidence)
- [bats-core documentation (ReadTheDocs)](https://bats-core.readthedocs.io/) -- setup/teardown, $BATS_TMPDIR, helper libraries (HIGH confidence)
- [bats-support GitHub](https://github.com/bats-core/bats-support) -- foundational helper library (HIGH confidence)
- [bats-assert GitHub](https://github.com/bats-core/bats-assert) -- assertion functions (HIGH confidence)
- [bats-file GitHub](https://github.com/ztombol/bats-file) -- filesystem assertions, temp dir helpers (HIGH confidence)
- [Pester official docs -- Test file structure](https://pester.dev/docs/usage/test-file-structure) -- Describe/Context/It blocks (HIGH confidence)
- [Pester official docs -- Mocking](https://pester.dev/docs/usage/mocking) -- Mock cmdlets and functions (HIGH confidence)
- [Pester official docs -- TestDrive](https://pester.dev/docs/usage/testdrive) -- temporary file isolation (HIGH confidence)
- [PSScriptAnalyzer GitHub](https://github.com/PowerShell/PSScriptAnalyzer) -- installation, configuration (HIGH confidence)
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck) -- configuration, severity levels (HIGH confidence)
- [Bats Testing Patterns (GitHub)](https://github.com/wshobson/agents/blob/main/plugins/shell-scripting/skills/bats-testing-patterns/SKILL.md) -- setup/teardown, temp directory patterns (MEDIUM confidence)
- [PowerShell Docker Hub](https://hub.docker.com/_/microsoft-powershell) -- available images (MEDIUM confidence)
- [Existing codebase](file:///home/huanglin/code/claude-config/notify-research/) -- all 6 scripts analyzed for testability (HIGH confidence, read 2026-03-30)

---
*Architecture research for: Claude Code voice notification system v1.2 test infrastructure*
*Researched: 2026-03-30*
