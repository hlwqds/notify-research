# Stack Research: Cross-Platform Testing Infrastructure (v1.2)

**Domain:** Cross-platform test tooling for shell and PowerShell notification scripts
**Researched:** 2026-03-30
**Confidence:** HIGH

## Recommended Stack

### Static Analysis

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **ShellCheck** | 0.11.0 | Static analysis for bash scripts (`install.sh`, `uninstall.sh`, `notify-play.sh`) | De facto standard for bash linting; 3.71 MB Docker image; catches quoting, word-splitting, and portability bugs. GPL-3.0 license. |
| **PSScriptAnalyzer** | 1.25.0 | Static analysis for PowerShell scripts (`install.ps1`, `uninstall.ps1`, `notify-play.ps1`) | Official Microsoft linter for PowerShell; supports both PS 5.1 and PS 7.2+; rules can be excluded via settings file or inline suppression. Apache-2.0 license. |

### Unit Testing

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **bats-core** | 1.13.0 | TAP-compliant test runner for bash scripts | Most widely adopted bash test framework (1.5k repos using it); simple `@test` syntax; CC0-1.0 license. Provides isolation via subshells per test. |
| **bats-support** | 0.3.0 | Output formatting helpers for bats-core tests | Companion library providing `fail`, `assert_equal`, and diagnostic output functions. Required by bats-assert. |
| **bats-assert** | 2.2.4 | Assertion functions for bats-core tests (`assert_success`, `assert_output`, `assert_file_exist`) | Rich assertion library turning bare exit-code checks into readable test assertions. Depends on bats-support. |
| **Pester** | 5.7.1 | BDD-style test runner for PowerShell scripts | The standard PowerShell test framework; supports mocking (wraps PowerShell commands, not .NET objects); compatible with PS 5.1 and PS 7.2+. Apache-2.0 license. |

### Docker Test Matrix

| Image | Tag | Platform | Purpose | Why This Image |
|-------|-----|----------|---------|----------------|
| **bats/bats** | `1.13.0` | Linux | Run bats-core tests for bash scripts | Official bats-core Docker image; includes bats binary pre-installed on Alpine; 15.59 MB. Mount repo and run tests directly. |
| **koalaman/shellcheck** | `v0.11.0` | Linux | Run ShellCheck against bash scripts | Official ShellCheck Docker image; static binary in Debian slim; 3.71 MB. Run as `docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:v0.11.0 scripts/*.sh`. |
| **mcr.microsoft.com/powershell** | `lts` | Linux | Run PSScriptAnalyzer and Pester for PowerShell scripts | Official PowerShell LTS image (currently 7.4.x) on Ubuntu; cross-platform so it runs on Linux host. PSScriptAnalyzer and Pester install via PowerShellGet. |
| **ubuntu** | `24.04` | Linux | General-purpose Linux test environment | Closest to the target Fedora desktop; provides `jq`, `paplay`-equivalent tools for integration testing. Install bats, shellcheck, jq via apt. |
| **mcr.microsoft.com/windows/servercore** | `ltsc2022` | Windows | PowerShell 5.1 + native Windows environment | PS 5.1 is pre-installed in Windows Server Core. Required for testing Windows-specific features (MediaPlayer, temp paths, BOM-free JSON). **Windows host only** -- cannot run on Linux Docker. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **docker compose** | Orchestrate multi-service test runs | Run ShellCheck, bats, PSScriptAnalyzer, and Pester as parallel containers via a single `docker compose up`. |
| **just** or **make** | Test runner entry points | Single command to run all test suites: static analysis + unit tests. `just test` or `make test`. Optional but recommended. |

## Installation

### ShellCheck (Docker)

```bash
# Pull once
docker pull koalaman/shellcheck:v0.11.0

# Run against all bash scripts
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:v0.11.0 scripts/*.sh

# Run with specific severity
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:v0.11.0 --severity warning scripts/*.sh
```

### bats-core + helpers (Docker)

```bash
# Pull once
docker pull bats/bats:1.13.0

# Run all bats tests
docker run --rm -v "$PWD:/mnt" bats/bats:1.13.0 test/bash/
```

For local development, bats-core and helpers install via git submodules:

```bash
# Clone bats-core and helpers into test/helpers/
git clone --depth 1 https://github.com/bats-core/bats-core.git test/helpers/bats-core
git clone --depth 1 https://github.com/bats-core/bats-support.git test/helpers/bats-support
git clone --depth 1 https://github.com/bats-core/bats-assert.git test/helpers/bats-assert
```

### PSScriptAnalyzer + Pester (Docker)

```bash
# Pull once
docker pull mcr.microsoft.com/powershell:lts

# Run PSScriptAnalyzer against all ps1 scripts
docker run --rm -v "$PWD:/mnt" mcr.microsoft.com/powershell:lts \
  pwsh -Command "Install-Module PSScriptAnalyzer -Force; Invoke-ScriptAnalyzer -Path /mnt/scripts/*.ps1"

# Run Pester tests
docker run --rm -v "$PWD:/mnt" mcr.microsoft.com/powershell:lts \
  pwsh -Command "Install-Module Pester -Force; Invoke-Pester -Path /mnt/test/powershell/"
```

### Linux Test Environment (Docker)

```bash
# Build a test image with all tools
docker build -t notify-test -f test/Dockerfile.linux .

# Run all tests
docker run --rm -v "$PWD:/workspace" notify-test
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Bash linting** | ShellCheck | bash -n (syntax check only) | `bash -n` only checks syntax; ShellCheck catches semantic bugs (word splitting, quoting, unused variables, portability issues) |
| **Bash linting** | ShellCheck | shellharden | shellharden is opinionated about quoting style and rewrites code; ShellCheck is diagnostic-only and better for existing scripts |
| **Bash testing** | bats-core | shunit2 | shunit2 is older, less maintained, requires sourcing test files instead of running them; bats-core is the modern standard |
| **Bash testing** | bats-core | pytest + shell command capture | Adds Python dependency; overkill for simple bash script tests |
| **Bash testing** | bats-core | make + diff-based testing | Fragile, hard to maintain, no assertion library; bats-core provides structured test output |
| **PS linting** | PSScriptAnalyzer | ScriptAnalyzer only (no PSScriptAnalyzer) | PSScriptAnalyzer IS ScriptAnalyzer; renamed in newer versions |
| **PS testing** | Pester | BeforeAll/AfterAll only (manual) | No assertion library, no mocking, no structured output; Pester provides all three |
| **PS testing** | Pester | xUnit (C#) | Requires compiling a test assembly; adds .NET SDK dependency; overkill for 3 PS1 scripts |
| **Test runner** | docker compose | GitHub Actions matrix | GitHub Actions is CI-only, not local. Docker compose works both locally and in CI. Use both: Docker for local, GitHub Actions for CI. |
| **Test runner** | docker compose | Taskfile | Taskfile is Go-based and adds another dependency; docker compose is likely already installed for the Spark-TTS workflow |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **ShellCheck Docker `stable` tag** | The `stable` tag may lag behind latest; pin to `v0.11.0` for reproducibility | `koalaman/shellcheck:v0.11.0` (pinned) |
| **bats-core installed via npm or apt** | Package manager versions are often outdated; git clone ensures latest | Docker image `bats/bats:1.13.0` or git submodules |
| **PSScriptAnalyzer < 1.24.0** | Versions before 1.24.0 have a minimum PS version of 3.0, which is irrelevant since we target PS 5.1+ | PSScriptAnalyzer 1.25.0 |
| **Pester 4.x** | Pester 4 is incompatible with PS 7.x; Pester 5 changed the API significantly. Pester 5.7.1 supports both PS 5.1 and PS 7.x | Pester 5.7.1 |
| **Windows Server Core on Linux host** | Windows containers require a Windows kernel -- they CANNOT run on Linux Docker. This is a fundamental OS limitation, not a configuration issue. | `mcr.microsoft.com/powershell:lts` (PS 7 on Ubuntu) for Linux-hosted PS testing |
| **Mocking .NET objects directly in Pester** | Pester mocks intercept PowerShell commands only. It cannot mock `$player.Play()` on a `System.Windows.Media.MediaPlayer` object. Attempting this will silently fail (mock is ignored) | Wrapper pattern: wrap .NET calls in PowerShell functions, then mock those functions |
| **Docker `bats/bats:latest` tag** | CVE-2025-15467 reported in 1.13.0 image base. Pin to specific version and monitor for patched release | `bats/bats:1.13.0` with awareness of CVE |
| **Running PSScriptAnalyzer on PS 7 to test PS 5.1 scripts** | PSScriptAnalyzer 1.25.0 works on both, but PS 7 may flag rules differently or miss PS 5.1-specific issues. Test on PS 5.1 for accuracy. | Use `mcr.microsoft.com/windows/servercore:ltsc2022` (PS 5.1 native) for definitive results; PS 7 Linux image for fast feedback |

## Stack Patterns by Variant

### Local Development (no Docker)

**If developing on Linux/macOS with local tools:**

```bash
# Install ShellCheck
sudo apt install shellcheck     # Debian/Ubuntu
brew install shellcheck          # macOS

# Install bats-core
git clone https://github.com/bats-core/bats-core.git ~/.local/lib/bats-core
export PATH="$HOME/.local/lib/bats-core/bin:$PATH"
```

**If developing on Windows with local PowerShell:**

```powershell
# Install PSScriptAnalyzer and Pester
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
```

### Docker-Only (recommended)

**If avoiding host dependencies entirely:**

Use `docker compose` to orchestrate all test containers. Each tool runs in its own container with zero host installation. This matches the project's existing Docker-first philosophy (Spark-TTS is also containerized).

### CI (GitHub Actions)

**If running in CI pipeline:**

Use GitHub Actions `strategy.matrix` to run tests across OS + tool combinations:

```yaml
strategy:
  matrix:
    include:
      - os: ubuntu-latest
        tool: shellcheck
        run: docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:v0.11.0 scripts/*.sh
      - os: ubuntu-latest
        tool: bats
        run: docker run --rm -v "$PWD:/mnt" bats/bats:1.13.0 test/bash/
      - os: ubuntu-latest
        tool: psscriptanalyzer
        run: docker run --rm -v "$PWD:/mnt" mcr.microsoft.com/powershell:lts pwsh -Command "Install-Module PSScriptAnalyzer -Force; Invoke-ScriptAnalyzer -Path /mnt/scripts/*.ps1"
      - os: ubuntu-latest
        tool: pester
        run: docker run --rm -v "$PWD:/mnt" mcr.microsoft.com/powershell:lts pwsh -Command "Install-Module Pester -Force; Invoke-Pester -Path /mnt/test/powershell/"
      - os: windows-latest
        tool: pester-native
        run: pwsh -Command "Install-Module PSScriptAnalyzer,Pester -Force; Invoke-ScriptAnalyzer -Path scripts/*.ps1; Invoke-Pester -Path test/powershell/"
```

Note: `windows-latest` runner is only needed for PS 5.1 native testing. PS 7 + PSScriptAnalyzer + Pester works fine on `ubuntu-latest`.

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| ShellCheck | 0.11.0 | bash 3.2+, sh | Supports macOS bash 3.2 (our target); diff output uses `/` path separator on Windows |
| bats-core | 1.13.0 | bash 3.2+ | Works on macOS bash 3.2; TAP output compatible with any test harness |
| bats-support | 0.3.0 | bats-core 1.0+ | Stable, no breaking changes expected; mature library |
| bats-assert | 2.2.4 | bats-core 1.0+, bats-support 0.3+ | Latest release; assertion API stable |
| PSScriptAnalyzer | 1.25.0 | PS 5.1, PS 7.2.11+ | Min PS 5.1 raised from PS 3 in v1.24.0 |
| Pester | 5.7.1 | PS 5.1, PS 7.2+ | Dropped support for PS 3, 4, 6, and early 7 |
| mcr.microsoft.com/powershell:lts | 7.4.x | Linux, macOS, Windows | Ubuntu-based; PS 7.4 LTS on .NET 8 |
| mcr.microsoft.com/windows/servercore:ltsc2022 | -- | Windows only | PS 5.1 pre-installed; cannot run on Linux host |

## Integration with Existing Scripts

### What Can Be Tested

The 6 existing scripts fall into clear testability categories:

| Script | Static Analysis | Unit Testable | Notes |
|--------|----------------|---------------|-------|
| `install.sh` | ShellCheck | Yes (with mocking) | Mock `jq`, `claude`, `cp` commands; test version comparison function; test jq output validation |
| `uninstall.sh` | ShellCheck | Yes (with mocking) | Mock `jq`, `rm` commands; test idempotent behavior |
| `notify-play.sh` | ShellCheck | Yes | Test cooldown logic; mock `afplay`/`paplay`; test OS detection branch (Darwin vs Linux) |
| `install.ps1` | PSScriptAnalyzer | Yes (with mocking) | Mock `Get-Command`, `Test-Path`, `Copy-Item`; mock `Get-Content`/`Set-Content` for settings.json |
| `uninstall.ps1` | PSScriptAnalyzer | Yes (with mocking) | Mock `Get-Content`/`Set-Content`; test idempotent removal; test empty hooks cleanup |
| `notify-play.ps1` | PSScriptAnalyzer | Partial (see below) | Test cooldown logic; MediaPlayer .NET calls CANNOT be mocked directly |

### Pester Mocking Limitation for notify-play.ps1

`notify-play.ps1` uses `System.Windows.Media.MediaPlayer` (a .NET object) for audio playback. **Pester cannot mock .NET object methods.** Pester's `Mock` command intercepts PowerShell commands (cmdlets, functions, advanced functions), not arbitrary .NET method calls like `$player.Open()`, `$player.Play()`, `$player.Close()`.

**Workaround -- Wrapper Pattern:**

Refactor `notify-play.ps1` to wrap .NET calls in PowerShell functions:

```powershell
function Invoke-PlayAudio([string]$Path) {
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([System.Uri]::new($Path))
    Start-Sleep -Milliseconds 500
    $player.Play()
    while ($player.NaturalDuration.HasTimeSpan -and $player.Position -lt $player.NaturalDuration.TimeSpan) {
        Start-Sleep -Milliseconds 100
    }
    $player.Close()
}
```

Then in Pester tests:

```powershell
Mock Invoke-PlayAudio {} -Verifiable
# Run the script...
Should -Invoke Invoke-PlayAudio -Times 1
```

This requires a small refactor of `notify-play.ps1` but keeps the change minimal (extract 6 lines into a function).

### bats-core Mocking Approach

For bash scripts, bats-core does not have built-in mocking. The standard approach is:

1. **PATH injection:** Create mock commands in a temporary directory and prepend it to PATH
2. **Source the script:** Instead of executing the script directly, source it so functions become available
3. **Override functions:** Redefine functions the script calls (e.g., `jq()`, `paplay()`, `afplay()`)

Example pattern for `notify-play.sh`:

```bash
# test/bash/notify-play.bats
setup() {
    # Create temp dir for mocks
    MOCK_DIR="$(mktemp -d)"
    PATH="$MOCK_DIR:$PATH"

    # Create mock paplay
    echo '#!/bin/bash' > "$MOCK_DIR/paplay"
    echo 'echo "paplay called with: $@"' >> "$MOCK_DIR/paplay"
    chmod +x "$MOCK_DIR/paplay"

    # Create mock stat (Linux)
    echo '#!/bin/bash' > "$MOCK_DIR/stat"
    echo 'echo 0' >> "$MOCK_DIR/stat"
    chmod +x "$MOCK_DIR/stat"

    # Source the script under test
    source "$BATS_TEST_DIRNAME/../../scripts/notify-play.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
    rm -f /tmp/claude-notify-*.lock
}

@test "plays audio when not in cooldown" {
    run notify_play_sh "complete" "/fake/audio.mp3"
    [ "$status" -eq 0 ]
}
```

### ShellCheck Configuration

Create a `.shellcheckrc` file at the repo root for consistent configuration:

```bash
# .shellcheckrc
# Disable rules that don't apply to our scripts
# SC1090: Can't follow non-constant source -- scripts are self-contained
# SC1091: Not following sourced file -- same reason
disable=SC1090,SC1091

# Check all scripts in scripts/
source-path=scripts
```

Alternatively, use `# shellcheck disable=SCXXXX` inline for specific lines.

### PSScriptAnalyzer Configuration

Create a `PSScriptAnalyzerSettings.psd1` file at the repo root:

```powershell
# PSScriptAnalyzerSettings.psd1
@{
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',  # Our scripts don't support -WhatIf
        'PSAvoidUsingWriteHost'                         # We intentionally use Write-Host for user output
    )
    Severity = @('Error', 'Warning')
}
```

## Estimated Docker Image Sizes

| Image | Size | Purpose |
|-------|------|---------|
| `koalaman/shellcheck:v0.11.0` | ~3.71 MB | Bash linting |
| `bats/bats:1.13.0` | ~15.59 MB | Bash unit testing |
| `mcr.microsoft.com/powershell:lts` | ~350 MB | PS linting + testing (includes PS 7.4 + .NET 8) |
| `ubuntu:24.04` + tools | ~200 MB | Full Linux test environment |
| **Total (all images)** | **~570 MB** | Complete test matrix (excluding Windows Server Core) |

Note: Windows Server Core is ~1.1 GB but only runs on Windows hosts. It is not part of the Linux test matrix.

## Sources

- [ShellCheck GitHub Releases](https://github.com/koalaman/shellcheck/releases) -- v0.11.0 release (August 2025) (HIGH confidence)
- [ShellCheck Docker Hub](https://hub.docker.com/r/koalaman/shellcheck/) -- official image, 3.71 MB (HIGH confidence)
- [bats-core GitHub Releases](https://github.com/bats-core/bats-core/releases) -- v1.13.0 release (November 2025) (HIGH confidence)
- [bats-core Documentation](https://bats-core.readthedocs.io/) -- official docs, tutorial, mocking patterns (HIGH confidence)
- [bats-support GitHub Releases](https://github.com/bats-core/bats-support/releases) -- v0.3.0 (HIGH confidence)
- [bats-assert NPM](https://www.npmjs.com/package/bats-assert) -- v2.2.4 (HIGH confidence)
- [bats/bats Docker Hub](https://hub.docker.com/r/bats/bats/tags) -- 1.13.0 image (HIGH confidence)
- [bats-core CVE-2025-15467](https://github.com/bats-core/bats-core/issues/1188) -- security issue in 1.13.0 Docker image (MEDIUM confidence -- monitor for patch)
- [PSScriptAnalyzer 1.25.0 on PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.25.0) -- minimum PS 5.1 (HIGH confidence)
- [PSScriptAnalyzer What's New (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/whats-new-in-pssa?view=ps-modules) -- v1.24.0 breaking changes (HIGH confidence)
- [PSScriptAnalyzer Invoke-ScriptAnalyzer docs (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules) -- usage and configuration (HIGH confidence)
- [PSScriptAnalyzer GitHub](https://github.com/powershell/psscriptanalyzer/releases) -- release history (HIGH confidence)
- [Pester 5.7.1 on PowerShell Gallery](https://www.powershellgallery.com/packages/Pester/5.7.1) -- PS 5.1 and PS 7.2+ compatibility (HIGH confidence)
- [Pester Documentation](https://pester.dev/docs/introduction/installation) -- installation and compatibility (HIGH confidence)
- [Pester Mocking Documentation](https://pester.dev/docs/usage/mocking) -- mock limitations, .NET objects not mockable (HIGH confidence)
- [FoxDeploy -- Hard to Test Cases in Pester](https://www.foxdeploy.com/blog/hard-to-test-cases-in-pester.html) -- confirms Pester cannot mock .NET objects (MEDIUM confidence)
- [mcr.microsoft.com/powershell tags](https://mcr.microsoft.com/product/powershell/tags) -- LTS tag = 7.4.x (HIGH confidence)
- [PowerShell 7.4 GA Blog Post](https://devblogs.microsoft.com/powershell/powershell-7-4-general-availability/) -- LTS release details (HIGH confidence)
- [mcr.microsoft.com/windows/servercore](https://mcr.microsoft.com/artifact/mar/windows/servercore) -- PS 5.1 pre-installed (HIGH confidence)
- [Docker Docs -- Multi-platform builds](https://docs.docker.com/build/building/multi-platform/) -- Windows containers on Linux host not supported (HIGH confidence)

---
*Stack research for: Cross-platform testing infrastructure (v1.2 milestone)*
*Researched: 2026-03-30*
