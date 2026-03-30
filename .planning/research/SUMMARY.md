# Project Research Summary

**Project:** Claude Code Voice Notification System -- v1.2 Cross-Platform Testing Infrastructure
**Domain:** Test tooling for shell (bash) and PowerShell notification scripts
**Researched:** 2026-03-30
**Confidence:** HIGH

## Executive Summary

This project adds a cross-platform test infrastructure to the existing Claude Code voice notification system. The system ships 6 scripts (3 bash for Linux/macOS, 3 PowerShell for Windows) that handle installation, uninstallation, and audio playback of notification sounds triggered by Claude Code hooks. The research targets ONLY the test infrastructure for v1.2 -- all voice notification and cross-platform features from v1.0 and v1.1 are already shipped.

The recommended approach uses a dual-track test architecture: bats-core for bash scripts and Pester for PowerShell scripts, with ShellCheck and PSScriptAnalyzer providing static analysis. Both tracks run inside Docker containers (Linux for bats, PowerShell Core on Linux for Pester) orchestrated by a single `test.sh` entry point. Mocking relies on filesystem isolation via temp directory overrides (bats `$HOME` override, Pester `TestDrive`) and command shadowing (PATH-prepend stubs for bats, `Mock` cmdlet for Pester). A single production script change is needed -- making the lock file directory configurable via `NOTIFY_LOCK_DIR` env var in `notify-play.sh`.

The key risks are concentrated in test reliability: time-dependent cooldown tests must avoid `sleep` (use timestamp manipulation instead), audio player commands must be fully mocked (headless CI has no audio hardware), and Pester tests must target PowerShell 5.1 (not just pwsh 7) since that is the production runtime on Windows. Docker-based Windows container testing is impractical (3-11 GB images, requires Windows host) -- PowerShell tests should run in a Linux pwsh container for fast feedback, with native PS 5.1 testing on actual Windows machines.

## Key Findings

### Recommended Stack

A Docker-first testing approach with four tool categories: static analysis for both languages, unit test frameworks per platform, container orchestration, and a unified test runner.

**Core technologies:**
- **ShellCheck 0.11.0**: Bash static analysis -- catches quoting, word-splitting, and POSIX compatibility bugs that `bash -n` misses
- **PSScriptAnalyzer 1.25.0**: PowerShell static analysis -- official Microsoft linter, supports both PS 5.1 and PS 7.2+
- **bats-core 1.13.0** + bats-support 0.3.0 + bats-assert 2.2.4: Bash unit testing -- de facto standard with 1.5k+ repos, TAP-compliant output, rich assertion library
- **Pester 5.7.1**: PowerShell unit testing -- only serious PS test framework, supports both PS 5.1 and PS 7.x, built-in mocking via `Mock` cmdlet
- **Docker test images**: `bats/bats:1.13.0` (16 MB), `koalaman/shellcheck:v0.11.0` (4 MB), `mcr.microsoft.com/powershell:lts` (350 MB) -- total ~570 MB for complete test matrix
- **test.sh orchestrator**: Single entry point running all tracks, supports `--bash`, `--powershell`, `--all`, and `--no-docker` flags

Critical version note: Pin Pester to v5.x range (5.5.0-5.99.99). Pester v6 drops PS 3/4/5.0 support and PS 5.1 compatibility is uncertain. Never use Pester v6.

### Expected Features

The research defines 9 table-stakes features, 6 differentiators, and 7 explicit anti-features across 48 total test cases.

**Must have (table stakes):**
- T1: ShellCheck static analysis for bash -- zero test code to write, purely configuration (`.shellcheckrc`)
- T2: PSScriptAnalyzer static analysis for PowerShell -- zero test code, configuration only (`PSScriptAnalyzerSettings.psd1`)
- T3-T5: bats unit tests for all 3 bash scripts (notify-play.sh, install.sh, uninstall.sh) -- 22 test cases total
- T6-T8: Pester unit tests for all 3 PowerShell scripts (notify-play.ps1, install.ps1, uninstall.ps1) -- 26 test cases total
- T9: Test runner script (`test.sh`) -- single command to run everything

**Should have (competitive -- v1.2.x):**
- D2: install/uninstall round-trip integration test -- catches state leakage unit tests miss
- D3: settings.json structure validation -- prevents regressions when Claude Code updates its schema
- D4: Event mapping consistency test -- ensures Linux/macOS and Windows scripts use identical event-to-audio mappings

**Defer (v2+):**
- D1: Docker test matrix -- macOS Docker is impossible, PowerShell in Linux Docker does not test real Windows behavior. bats on Linux already catches most issues. Limited ROI for 6 short scripts.
- D5: Pester code coverage -- scripts are under 150 lines each, coverage tracking adds overhead without proportional value
- D6: GitHub Actions Windows runner -- requires CI pipeline that does not exist yet, scope is local-only

**Explicitly NOT build:**
- E2E audio playback testing (requires real hardware, cannot run in CI/Docker)
- macOS Docker container testing (technically impossible -- no macOS Docker image runs on Linux)
- bash code coverage via kcov (unmaintained since 2019, poor bash 5.x support)
- Snapshot testing for settings.json (fragile -- any formatting change breaks tests)

### Architecture Approach

A dual-track test architecture with two independent Dockerfile stages (one for bash, one for PowerShell) orchestrated by a single shell script entry point. The key architectural decision is filesystem isolation as the primary mocking strategy, since the scripts under test are standalone executables invoked as subprocesses, not sourced libraries.

**Major components:**
1. **test.sh** -- Top-level orchestrator that selects bash/PowerShell tracks, builds Docker images if needed, falls back to local execution with `--no-docker`
2. **Bash test track** (`tests/bash/*.bats`) -- bats-core tests using HOME override for filesystem isolation and PATH-prepend stubs for command mocking. Vendored bats-support and bats-assert (not git submodules).
3. **PowerShell test track** (`tests/powershell/*.Tests.ps1`) -- Pester tests using TestDrive for file I/O isolation and `Mock` cmdlet for external dependency interception. Scripts invoked as black-box subprocesses.
4. **Shared fixtures** (`tests/test_helpers/fixtures/`) -- Fake settings.json files, fake MP3 files, shared by both tracks to avoid duplication
5. **Static analysis configs** (`.shellcheckrc`, `PSScriptAnalyzerSettings.psd1`) -- Tool-specific rule configuration, targeting PS 5.1 compatibility profile
6. **Dockerfile.test-bash** and **Dockerfile.test-powershell** -- Two separate Dockerfiles (not multi-platform in one file), built independently

One production code change is required: `notify-play.sh` line 14 should use `LOCK_FILE="${NOTIFY_LOCK_DIR:-/tmp}/claude-notify-${TYPE}.lock"` to make the lock file directory configurable for tests. This is backward-compatible (defaults to `/tmp`).

### Critical Pitfalls

Five pitfalls that can make the test infrastructure unreliable or unusable if not addressed from the start.

1. **Flaky cooldown tests via `sleep`** -- Tests that use real time to verify 5-second cooldown produce intermittent failures in CI. Fix: manipulate file timestamps directly with `touch -d` (Linux) or `touch -t` (macOS) via a portable helper function. Never `sleep` in tests.
2. **Headless CI cannot play audio** -- `paplay`, `afplay`, and `MediaPlayer` all fail or hang without audio hardware/session. Fix: create PATH-prepend stubs for bats (fake scripts that log arguments and exit 0), extract MediaPlayer calls into a wrapper function for Pester and mock the wrapper. Never instantiate MediaPlayer in tests.
3. **Pester version mismatch between PS 5.1 and pwsh 7** -- Pester v4/v5/v6 have different APIs and PS version support. Fix: pin Pester to v5.x range with `Import-Module Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.99`. Never use Pester v6. Test on PS 5.1 specifically.
4. **bats `load` path resolution depends on invocation directory** -- Tests that work from project root break when run from subdirectories. Fix: always compute absolute paths from `$BATS_TEST_FILENAME`. Always invoke `bats tests/` from project root. Document this constraint.
5. **Lock file pollution between tests** -- Hardcoded `/tmp` lock paths cause order-dependent test failures when tests share the same path. Fix: use `$BATS_TEST_TMPDIR` with the `NOTIFY_LOCK_DIR` env var override. Always clean up in teardown with `|| true`.

## Implications for Roadmap

Based on research, the work naturally divides into 4 phases ordered by dependency and risk reduction.

### Phase 1: Static Analysis and Test Infrastructure Setup

**Rationale:** ShellCheck and PSScriptAnalyzer are zero-dependency entry points that provide immediate value with zero test code to write. Configuring them first ensures the production scripts are lint-clean before writing any tests. Creating the directory structure and shared fixtures is also prerequisite for all subsequent phases.

**Delivers:** `.shellcheckrc`, `PSScriptAnalyzerSettings.psd1`, `tests/` directory structure, shared fixture files (fake settings.json, fake MP3)

**Addresses:** T1, T2 (static analysis), fixture creation

**Avoids:** Pitfall 7 (ShellCheck suppression without understanding -- establish policy before running), Pitfall 13 (PSScriptAnalyzer type flags -- configure PS 5.1 target profile upfront)

### Phase 2: Bash Unit Tests (bats-core)

**Rationale:** Bash scripts are the primary development target (Linux/macOS). Testing `notify-play.sh` first addresses the highest-risk script (invoked on every hook event, cooldown logic with platform branching). `install.sh` is the most critical-state script (modifies `~/.claude/settings.json`). `uninstall.sh` is simplest and completes bash coverage.

**Delivers:** `tests/bash/notify_play.bats` (8 tests), `tests/bash/install.bats` (9 tests), `tests/bash/uninstall.bats` (5 tests), vendored bats-support and bats-assert

**Uses:** bats-core 1.13.0, bats-support 0.3.0, bats-assert 2.2.4

**Implements:** Bash test track from architecture -- HOME override pattern, PATH-prepend stubs, timestamp manipulation helper for cooldown tests

**Avoids:** Pitfalls 1 (flaky cooldown via timestamp manipulation), 2 (headless audio via PATH stubs), 4 (path resolution via absolute paths), 5 (lock pollution via `NOTIFY_LOCK_DIR`), 6 (setup scope -- use `setup()` per-test for mocks, `setup_file()` for expensive setup), 9 (teardown attribution -- use `|| true` in cleanup), 10 (macOS stat/touch -- portable helper function)

### Phase 3: PowerShell Unit Tests (Pester)

**Rationale:** PowerShell tests are fully independent from bash tests (different runtime, different framework). Can be developed in parallel with Phase 2. Tests the same patterns (cooldown, install/uninstall) on the Windows side using Pester's built-in `Mock` and `TestDrive`.

**Delivers:** `tests/powershell/notify_play.Tests.ps1` (8 tests), `tests/powershell/install.Tests.ps1` (11 tests), `tests/powershell/uninstall.Tests.ps1` (7 tests)

**Uses:** Pester 5.7.1 (pinned to v5.x range), `mcr.microsoft.com/powershell:lts` Docker image

**Implements:** PowerShell test track from architecture -- TestDrive isolation, Mock cmdlet for external dependencies, black-box subprocess invocation for install/uninstall scripts

**Avoids:** Pitfall 2 (MediaPlayer mocking -- extract to wrapper function), Pitfall 3 (Pester version -- pin to v5.x, test on PS 5.1)

### Phase 4: Docker Integration and Test Runner

**Rationale:** Docker test images and the test.sh orchestrator depend on all tests being written and passing. This is the integration phase that ties everything together. The Docker matrix should use Linux containers only (bash on Debian, Pester on PowerShell Linux image). Windows containers are explicitly excluded (3-11 GB images, require Windows host).

**Delivers:** `Dockerfile.test-bash`, `test.sh` orchestrator, verified `./test.sh --all` end-to-end execution

**Uses:** `bats/bats:1.13.0` Docker image, `koalaman/shellcheck:v0.11.0` Docker image, `mcr.microsoft.com/powershell:lts` Docker image

**Avoids:** Pitfall 8 (Docker Windows size -- skip Windows containers entirely, use Linux pwsh for Pester Docker tests, native Windows for PS 5.1 validation)

### Phase Ordering Rationale

- Phase 1 has zero dependencies and provides lint-clean scripts as a foundation for all testing
- Phase 2 and Phase 3 are independent and could run in parallel -- bash and PowerShell tests share only fixtures
- Phase 4 depends on both Phase 2 and Phase 3 being complete and passing locally
- This ordering front-loads the highest-risk work (bash cooldown tests in Phase 2) when developer context is freshest
- Each phase produces a runnable, verifiable increment -- not a big-bang integration at the end

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** bats mocking approach for `install.sh` -- the script uses `jq` extensively and HOME override must redirect all file operations correctly. The `SCRIPT_DIR` resolution via `dirname "$0"` needs careful handling in the test fixture layout. Standard bats patterns but non-trivial fixture setup.
- **Phase 3:** Pester Mock syntax for `New-Object` with complex .NET type names -- research flagged this as MEDIUM confidence. The MediaPlayer mock requires careful setup and may need iteration.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Static analysis configuration is well-documented. `.shellcheckrc` and `PSScriptAnalyzerSettings.psd1` have established patterns.
- **Phase 4:** Docker test matrix and shell script orchestration are standard infrastructure patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All tools have official documentation, pinned versions, and are verified against source repos. ShellCheck, bats-core, PSScriptAnalyzer, and Pester are the de facto standards in their respective domains. |
| Features | HIGH | 48 test cases derived from direct analysis of all 6 production scripts. Every test case maps to specific code paths identified in the scripts. |
| Architecture | HIGH | Dual-track bats/Pester pattern is well-established. Filesystem isolation and PATH-prepend mocking are standard approaches. One minor concern: Pester Mock for `New-Object` with complex .NET types needs validation. |
| Pitfalls | MEDIUM-HIGH | 13 pitfalls identified from official docs, verified GitHub issues, and community sources. Most have clear prevention strategies. Two gaps: Docker Windows image sizes not verified against latest Microsoft images (cited from blog post), and `touch -A` macOS flag syntax not verified against latest macOS version. |

**Overall confidence:** HIGH

### Gaps to Address

- **Pester Mock for `New-Object System.Windows.Media.MediaPlayer`:** Research flags this as MEDIUM confidence. The mock syntax for constructor calls with complex .NET types may need iteration. Mitigation: extract MediaPlayer calls into a wrapper function first, then mock the wrapper (simpler and more reliable).
- **Windows container practicality:** Research recommends against Docker Windows containers but the final decision should be validated during Phase 4 planning. If native Windows testing is impractical, the fallback is Linux pwsh container only.
- **macOS test coverage:** macOS-specific code paths (BSD stat, afplay) can only be tested via mocked `uname -s` and PATH stubs on Linux. There is no way to run bats tests on actual macOS in CI with this project's infrastructure. This is acceptable but should be documented as a known gap.
- **bats-core CVE-2025-15467:** A CVE was reported in the 1.13.0 Docker image base. Pin to 1.13.0 but monitor for patched release. Low impact -- the CVE is in the Docker image base, not bats-core itself.

## Sources

### Primary (HIGH confidence)

- [bats-core GitHub](https://github.com/bats-core/bats-core) -- installation, setup/teardown, $BATS_TEST_TMPDIR, helper libraries
- [bats-core documentation](https://bats-core.readthedocs.io/) -- test structure, load path resolution, parallel mode limitations
- [bats-core Issue #1136](https://github.com/bats-core/bats-core/issues/1136) -- teardown failure attribution to wrong test
- [bats-support GitHub](https://github.com/bats-core/bats-support) -- output formatting companion library
- [bats-assert GitHub](https://github.com/bats-core/bats-assert) -- assertion functions (assert_success, assert_output, assert_equal)
- [Pester documentation -- Mocking](https://pester.dev/docs/usage/mocking) -- Mock cmdlet, .NET object limitation, TestDrive
- [Pester documentation -- TestDrive](https://pester.dev/docs/usage/testdrive) -- temporary file isolation
- [Pester v5 to v6 Migration Guide](https://pester.dev/docs/v6/migrations/v5-to-v6) -- dropped PS version support
- [Pester Issue #1770](https://github.com/pester/Pester/issues/1770) -- PesterConfiguration type conflict from version mismatch
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck) -- configuration, severity levels, SC rule catalog
- [ShellCheck Docker Hub](https://hub.docker.com/r/koalaman/shellcheck/) -- official image (3.71 MB)
- [PSScriptAnalyzer on PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.25.0) -- v1.25.0 minimum PS 5.1
- [PSScriptAnalyzer UseCompatibleTypes](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatibletypes?view=ps-modules) -- PS 5.1 compatibility profiles
- [Microsoft: PS 5.1 vs PS 7.x differences](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.6) -- cmdlet and type differences
- [Docker Docs -- Multi-platform builds](https://docs.docker.com/build/building/multi-platform/) -- Windows containers on Linux host not supported
- Existing codebase -- all 6 scripts analyzed for testability (notify-play.sh: 38 lines, install.sh: 124 lines, uninstall.sh: 36 lines, notify-play.ps1: 52 lines, install.ps1: 145 lines, uninstall.ps1: 60 lines)

### Secondary (MEDIUM confidence)

- [bats-mock (jasonkarns)](https://github.com/jasonkarns/bats-mock) -- alternative mocking approach (reference only, using function shadows instead)
- [mcr.microsoft.com/powershell Docker image](https://hub.docker.com/r/mcr/microsoft/powershell) -- official PowerShell Docker image
- [PowerShell/DscResource.Tests Issue #204](https://github.com/PowerShell/DscResource.Tests/issues/204) -- Pester in Windows containers
- [Fixing Flaky Time Based Unit Tests (Expedia Group)](https://medium.com/expedia-group-tech/fixing-flaky-time-based-unit-tests-176accf5096e) -- time-based test flakiness patterns
- [FoxDeploy -- Hard to Test Cases in Pester](https://www.foxdeploy.com/blog/hard-to-test-cases-in-pester.html) -- confirms Pester cannot mock .NET objects

### Tertiary (LOW confidence)

- Docker Windows container sizes (3-11 GB) -- cited from blog post, not verified against latest Microsoft images
- `touch -A` macOS BSD flag syntax -- known BSD syntax, not verified against latest macOS version
- bats-core CVE-2025-15467 -- security issue in 1.13.0 Docker image base, impact not fully assessed

---
*Research completed: 2026-03-30*
*Ready for roadmap: yes*
