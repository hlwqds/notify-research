# Feature Research

**Project:** Claude Code Voice Notification System
**Milestone:** v1.2 Cross-Platform Testing
**Researched:** 2026-03-30
**Confidence:** HIGH (verified with official docs for all tools; script analysis from codebase)

## Scope

This research covers ONLY the new test infrastructure needed for v1.2. All v1.0 (voice notifications) and v1.1 (cross-platform) features are already shipped.

**What we are testing (6 scripts):**
- `scripts/install.sh` -- Linux/macOS install (copies mp3 + jq hook injection)
- `scripts/uninstall.sh` -- Linux/macOS uninstall (jq hook removal + mp3 cleanup)
- `scripts/notify-play.sh` -- Linux/macOS playback (cooldown + paplay/afplay)
- `scripts/install.ps1` -- Windows install (copies mp3 + PowerShell JSON hook injection)
- `scripts/uninstall.ps1` -- Windows uninstall (JSON hook removal + mp3 cleanup)
- `scripts/notify-play.ps1` -- Windows playback (cooldown + MediaPlayer)

**What we are NOT testing:**
- Spark-TTS Docker environment (generation-time only, not runtime)
- `generate.sh` (rarely used, manual invocation only)
- `audio/notify-*.mp3` files (binary assets, not code)

---

## Table Stakes (Must Have)

Test categories that any project shipping shell/PowerShell scripts should have. Missing these = regression risk is unmanaged.

| # | Feature | Why Expected | Complexity | Notes |
|---|---------|--------------|------------|-------|
| T1 | **ShellCheck static analysis for bash scripts** | ShellCheck is the de facto standard for bash/sh linting. Not running it means bugs like unquoted variables, unused variables, and POSIX compatibility issues go undetected. | LOW | Run `shellcheck scripts/*.sh`. Config: `.shellcheckrc` to exclude expected warnings (SC1090 for sourced files, SC2312 for `command -v`). Zero test code to write -- purely configuration. |
| T2 | **PSScriptAnalyzer static analysis for PowerShell scripts** | PSScriptAnalyzer (v1.25.0) is the official Microsoft static analysis tool for PowerShell. Not running it means potential issues like unused variables, improper error handling, and style violations go undetected. | LOW | Run `Invoke-ScriptAnalyzer scripts/*.ps1`. Config: `PesterConfiguration` or `.PSScriptAnalyzerSettings.psd1` to exclude specific rules. Zero test code to write -- purely configuration. |
| T3 | **bats unit tests for notify-play.sh** | `notify-play.sh` is the most frequently invoked script (runs on every hook event). Its cooldown logic and platform branching (Darwin vs Linux stat flags) are the highest-risk code paths. | MEDIUM | Test cooldown skip (lock file exists, age < 5s), cooldown pass (lock file old), lock file creation, Darwin stat path, Linux stat path, exit 0 always (even on audio player failure). Requires mocking `date`, `stat`, `afplay`, `paplay`. |
| T4 | **bats unit tests for install.sh** | install.sh modifies `~/.claude/settings.json` -- a critical user config file. Idempotency and correctness of jq transformations must be verified. | MEDIUM | Test: settings.json hook injection (4 events), idempotent re-run, prerequisite checks (missing jq, missing paplay, missing settings.json, missing mp3), version check warning. Requires mocking `jq`, `cp`, `command -v`, `claude`. |
| T5 | **bats unit tests for uninstall.sh** | uninstall.sh removes hooks from settings.json and deletes mp3 files. Must verify it cleans up exactly what install.sh created and nothing more. | LOW | Test: hook removal (4 events removed), audio file deletion, missing settings.json error, idempotent re-run (no hooks = no error). Requires mocking `jq`, `rm`, `mv`. |
| T6 | **Pester unit tests for notify-play.ps1** | Parallel to T3. Windows cooldown logic and MediaPlayer invocation must be verified without requiring actual Windows audio hardware. | MEDIUM | Test: cooldown skip, cooldown pass, lock file creation, fallback temp path, exit 0 always, MediaPlayer mock. Use Pester `Mock` for `Add-Type`, `New-Object`, `Get-Item`, `Set-Content`, `Test-Path`. |
| T7 | **Pester unit tests for install.ps1** | Parallel to T4. Windows hook injection with forward-slash paths, BOM-free JSON writing, and `shell: "powershell"` field must be verified. | MEDIUM | Test: 4 events injected with correct structure, forward-slash path normalization, BOM-free output, idempotent re-run, prerequisite checks. Use Pester `Mock` for `Copy-Item`, `Test-Path`, `Get-Content`, `ConvertFrom-Json`, `ConvertTo-Json`, `[System.IO.File]::WriteAllText`. |
| T8 | **Pester unit tests for uninstall.ps1** | Parallel to T5. Hook removal and mp3 cleanup must work correctly, including the empty-hooks-object cleanup path. | LOW | Test: 4 event removal, empty hooks object removal, audio file deletion, missing settings.json error, idempotent re-run. Use Pester `Mock` for `Test-Path`, `Remove-Item`, `Get-Content`, `ConvertFrom-Json`. |
| T9 | **Test runner script** | A single entry point to run all tests (static analysis + bats + Pester). CI and developers need one command, not three. | LOW | A bash script at `tests/run-all.sh` or `Makefile` target. Runs ShellCheck, then bats, then (on Linux with pwsh) Pester. Exits non-zero if any step fails. |

---

## Differentiators (Nice to Have)

Test features that go beyond basic coverage. Valuable but not blocking.

| # | Feature | Value Proposition | Complexity | Notes |
|---|---------|-------------------|------------|-------|
| D1 | **Docker test matrix (Linux/macOS/Windows containers)** | Run bats tests in Ubuntu and macOS Docker containers, Pester tests in PowerShell Docker image. Catches platform-specific regressions (e.g., GNU vs BSD stat) without needing actual macOS/Windows hardware. | HIGH | Linux: `ubuntu:latest` with bats-core + bats-support + bats-assert + bats-file. macOS: no official Docker image exists (macOS is not containerizable). Windows PowerShell: `mcr.microsoft.com/powershell:latest` (Linux-based pwsh, not real Windows). The macOS gap means this matrix has limited value -- bats on Linux already catches most issues, and the real differences (Darwin stat, afplay) cannot be tested in Docker. |
| D2 | **install.sh + uninstall.sh integration test (round-trip)** | Install, verify hooks exist, uninstall, verify hooks gone, reinstall -- full lifecycle test. Catches state leakage between install/uninstall that unit tests miss. | MEDIUM | Create a temp settings.json fixture, run install.sh against it, verify output with jq, run uninstall.sh, verify hooks removed. Must mock `cp` and audio player commands. |
| D3 | **settings.json structure validation** | After install, validate that the generated settings.json conforms to Claude Code's expected schema (correct hook array nesting, required fields present). | LOW | A bats/Pester test that parses the output JSON and asserts on field types and values. Catches regressions in hook format when Claude Code updates its schema. |
| D4 | **Event mapping consistency test** | Verify that install.sh and install.ps1 use the exact same event-to-audio mapping (Stop->complete, Notification->confirm, StopFailure->error, SubagentStop->progress). A single test that asserts both scripts produce equivalent mappings. | LOW | Extract mapping from each script's test output and compare. Prevents divergence between Linux/macOS and Windows event handling. |
| D5 | **Code coverage reporting** | Track which lines of each script are exercised by tests. | MEDIUM | bash has no native coverage tool. `kcov` exists but is unmaintained. For PowerShell, `Pester` has `-CodeCoverage` parameter (works on `.ps1` files). Recommend Pester coverage only, skip bash coverage. |
| D6 | **Cross-platform test on actual Windows (CI)** | Run Pester tests on `windows-latest` in GitHub Actions to catch real Windows-specific issues (path separators, BOM encoding, MediaPlayer assembly loading). | HIGH | Requires a GitHub Actions workflow with `runs-on: windows-latest`. But we have no CI pipeline currently, and the project milestone says "Docker test matrix, local only." |

---

## Anti-Features (Explicitly NOT Build)

| # | Anti-Feature | Why Avoid | What to Do Instead |
|---|--------------|-----------|-------------------|
| A1 | **End-to-end audio playback test** | Requires actual audio hardware and PulseAudio/PipeWire/CoreAudio running. Cannot run in CI or Docker. Fails unpredictably. | Mock the audio player command. Test that the correct player is called with correct arguments. Audio playback is an integration concern, not a unit test concern. |
| A2 | **macOS Docker container testing** | macOS cannot run in Docker containers (licensing, kernel differences). No `macos:latest` image exists. | Test Darwin stat path with mocked `uname -s` and `stat` in bats on Linux. This is what bats mocking is for. |
| A3 | **bash code coverage (kcov)** | `kcov` is unmaintained (last release 2019), does not support bash 5.x well, and adds complexity for marginal value. Our scripts are short (<150 lines each). | Rely on test completeness (all code paths listed in T3-T8) rather than coverage metrics. |
| A4 | **Snapshot testing for settings.json** | Snapshot tests compare full JSON output against a golden file. Fragile: any formatting change (whitespace, key order) breaks the test. | Assert specific fields (event names, command structure, async flag) rather than comparing entire JSON. Use jq to extract and compare individual values. |
| A5 | **Property-based testing** | Shell scripts are imperative, not functional. Property-based testing (like bash-fuzz) adds complexity with little benefit for 6 short scripts. | Explicit test cases covering each code path (normal, error, edge). |
| A6 | **Test framework other than bats for bash** | Alternatives (shunit2, roundup, bash_unit) are less maintained and have smaller ecosystems than bats-core. | bats-core is the de facto standard with the largest ecosystem (bats-support, bats-assert, bats-file). |
| A7 | **Test framework other than Pester for PowerShell** | No other PowerShell test framework has meaningful adoption. Pester is the only serious option. | Pester 5.x is built into some PowerShell images and is the official recommendation from Microsoft. |

---

## Feature Dependencies

```
T1 (ShellCheck)
    └── independent ──> no dependencies

T2 (PSScriptAnalyzer)
    └── independent ──> no dependencies

T3 (bats: notify-play.sh)
    └── requires ──> bats-core + bats-support + bats-assert installed
    └── independent from T4, T5 (tests different script)

T4 (bats: install.sh)
    └── requires ──> bats-core + bats-support + bats-assert + bats-file installed
    └── independent from T3, T5 (tests different script)

T5 (bats: uninstall.sh)
    └── requires ──> bats-core + bats-support + bats-assert installed
    └── independent from T3, T4 (tests different script)

T6 (Pester: notify-play.ps1)
    └── requires ──> pwsh + Pester module installed
    └── independent from T7, T8 (tests different script)

T7 (Pester: install.ps1)
    └── requires ──> pwsh + Pester module installed
    └── independent from T6, T8 (tests different script)

T8 (Pester: uninstall.ps1)
    └── requires ──> pwsh + Pester module installed
    └── independent from T6, T7 (tests different script)

T9 (test runner)
    └── requires ──> T1, T2, T3-T5, T6-T8 (orchestrates all)

D1 (Docker matrix)
    └── requires ──> T3, T4, T5 (bats tests runnable in container)
    └── requires ──> T6, T7, T8 (Pester tests runnable in container)
    └── enhances ──> T9 (test runner becomes container-aware)

D2 (install/uninstall round-trip)
    └── requires ──> T4, T5 (individual tests exist first)

D3 (JSON schema validation)
    └── enhances ──> T4, T7 (additional assertions in existing tests)

D4 (event mapping consistency)
    └── requires ──> T4, T7 (both install scripts tested first)

D5 (Pester code coverage)
    └── enhances ──> T6, T7, T8 (adds coverage to existing Pester tests)
```

### Dependency Notes

- **T1 and T2 are zero-dependency entry points.** Static analysis needs no test framework, no fixtures, no mocks. Start here.
- **T3/T4/T5 are independent from T6/T7/T8.** Bash tests and PowerShell tests use completely different tools and runtimes. Implement in parallel.
- **T9 depends on everything.** The test runner is the final integration piece that ties all test categories together.
- **D1 (Docker matrix) is the last thing to build.** It wraps existing tests in containers. Build it only after all tests pass locally.
- **D3 and D4 enhance existing tests rather than requiring new infrastructure.** Add them as additional `@test` blocks within T4 and T7 test files.

---

## Test Category Breakdown by Script

### notify-play.sh (highest-risk script)

**Why highest risk:** Invoked on every hook event. Cooldown logic has platform branching (Darwin vs Linux). Must always exit 0.

| Test Case | Category | What It Verifies | Mocking Required |
|-----------|----------|-----------------|-----------------|
| Cooldown skip (fresh lock) | Unit | Exit 0 without playing when lock file age < 5s | `stat`, `date` |
| Cooldown pass (stale lock) | Unit | Plays audio when lock file age >= 5s | `stat`, `date`, `afplay`/`paplay` |
| Lock file creation | Unit | `touch` creates lock file before playback | `stat`, `date`, `afplay`/`paplay` |
| Darwin stat path | Unit | Uses `stat -f %m` on macOS | Mock `uname -s` to return `Darwin`, mock `stat` |
| Linux stat path | Unit | Uses `stat -c %Y` on Linux | Mock `uname -s` to return `Linux`, mock `stat` |
| Exit 0 on audio failure | Unit | Always exits 0 even when player fails | Mock `afplay`/`paplay` to exit 1 |
| Missing arguments | Error | Should fail (set -u) when called without args | None |
| Type-specific lock files | Unit | Different types use different lock files | `stat`, `date` |

**Complexity:** MEDIUM -- 8 test cases, mocking `stat` requires function override since bats runs in subshell.

### install.sh (critical-state script)

**Why critical:** Modifies `~/.claude/settings.json`, a file Claude Code depends on. A bug here breaks Claude Code.

| Test Case | Category | What It Verifies | Mocking Required |
|-----------|----------|-----------------|-----------------|
| Hook injection (4 events) | Unit | settings.json gets correct hook entries for Stop, Notification, StopFailure, SubagentStop | `jq` (mock to verify filter expression), `cp`, `mv` |
| Idempotent re-run | Unit | Running twice produces same result | `jq`, `cp`, `mv` |
| Missing jq (exit 1) | Error | Exits 1 with error message when jq not found | `command -v` mock |
| Missing paplay (exit 1) | Error | Exits 1 when paplay not found | `command -v` mock |
| Missing settings.json (exit 1) | Error | Exits 1 when ~/.claude/settings.json missing | File fixture |
| Missing mp3 files (exit 1) | Error | Exits 1 when audio source files missing | File fixture |
| Claude version check (warning) | Unit | Prints warning when version < 2.1.78 | `claude --version` mock |
| jq empty output protection | Unit | Does not clobber settings.json when jq fails | `jq` mock returning empty |
| Absolute paths in hook commands | Unit | Hook commands use absolute path to notify-play.sh | `jq` output verification |

**Complexity:** MEDIUM -- 9 test cases, requires temp directory fixtures and jq output verification.

### uninstall.sh (simplest bash script)

| Test Case | Category | What It Verifies | Mocking Required |
|-----------|----------|-----------------|-----------------|
| Hook removal (4 events) | Unit | All 4 event entries deleted from hooks | `jq` (verify del filter) |
| Audio file cleanup | Unit | All 4 mp3 files deleted | `rm` mock |
| Missing settings.json (exit 1) | Error | Exits 1 gracefully | File fixture |
| Idempotent re-run | Unit | Running twice does not error | `jq` (script handles missing properties) |
| Empty hooks cleanup | Unit | If hooks object becomes empty, removes it entirely | `jq` output verification |

**Complexity:** LOW -- 5 test cases, straightforward assertions.

### notify-play.ps1 (highest-risk PowerShell script)

**Why highest risk:** Invoked on every hook event. MediaPlayer interaction and cooldown logic are Windows-specific and hard to debug without mocks.

| Test Case | Category | What It Verifies | Mocking Required |
|-----------|----------|-----------------|-----------------|
| Cooldown skip (fresh lock) | Unit | Exits 0 when lock file age < 5s | `Test-Path`, `Get-Item`, `Get-Date` |
| Cooldown pass (stale lock) | Unit | Plays audio when lock file age >= 5s | `Test-Path`, `Get-Item`, `Get-Date`, `Add-Type`, `New-Object` |
| Lock file creation | Unit | Sets lock file timestamp before playback | `Set-Content`, mock audio playback |
| Fallback temp path | Unit | Uses `[System.IO.Path]::GetTempPath()` when `$env:TEMP` is empty | Environment variable manipulation |
| Exit 0 on error | Unit | catch block swallows errors, always exits 0 | Mock `Add-Type` to throw |
| MediaPlayer mock | Unit | Verifies MediaPlayer.Open called with correct URI | `Add-Type`, `New-Object` mocks |
| Missing arguments | Error | Mandatory params fail when not provided | None |
| Type-specific lock files | Unit | Different types use different lock file paths | `Test-Path`, `Get-Item` |

**Complexity:** MEDIUM -- 8 test cases, Pester mocking of .NET types (Add-Type, New-Object) requires careful setup.

### install.ps1 (critical-state PowerShell script)

| Test Case | Category | What It Verifies | Mocking Required |
|-----------|----------|-----------------|-----------------|
| Hook injection (4 events) | Unit | settings.json gets correct hook entries | `Get-Content`, `ConvertFrom-Json`, `ConvertTo-Json`, `[System.IO.File]::WriteAllText` |
| shell: "powershell" field | Unit | Each hook entry has `shell: "powershell"` | JSON output verification |
| Forward-slash paths | Unit | Hook commands use forward slashes, not backslashes | JSON output verification |
| BOM-free JSON output | Unit | Written file has no UTF-8 BOM | `[System.IO.File]::WriteAllText` mock |
| Idempotent re-run | Unit | Running twice produces same result | All mocks |
| Missing settings.json (exit 1) | Error | Exits 1 gracefully | `Test-Path` mock |
| Missing notify-play.ps1 (exit 1) | Error | Exits 1 when script not found | `Test-Path` mock |
| Missing audio dir (exit 1) | Error | Exits 1 when audio source dir missing | `Test-Path` mock |
| Missing mp3 files (exit 1) | Error | Exits 1 when any mp3 missing | `Test-Path` mock |
| Claude version warning | Unit | Warns when version < 2.1.78 | `Get-Command`, `claude --version` mocks |
| -Depth 100 in ConvertTo-Json | Unit | Prevents truncation of nested objects | `ConvertTo-Json` mock |

**Complexity:** MEDIUM -- 11 test cases, BOM detection requires reading raw bytes.

### uninstall.ps1 (simplest PowerShell script)

| Test Case | Category | What It Verifies | Mocking Required |
|-----------|----------|-----------------|-----------------|
| Hook removal (4 events) | Unit | All 4 event entries deleted | `Get-Content`, `ConvertFrom-Json`, `ConvertTo-Json` |
| Empty hooks cleanup | Unit | Removes hooks object when all entries gone | JSON output verification |
| Audio file cleanup | Unit | Deletes all 4 mp3 files | `Remove-Item`, `Test-Path` |
| Missing settings.json (exit 1) | Error | Exits 1 gracefully | `Test-Path` mock |
| No hooks section | Unit | Handles missing hooks gracefully | JSON fixture without hooks |
| Idempotent re-run | Unit | Running twice does not error | All mocks |
| BOM-free output | Unit | Written file has no UTF-8 BOM | `[System.IO.File]::WriteAllText` mock |

**Complexity:** LOW -- 7 test cases, simpler than install.ps1.

---

## Total Test Case Count

| Script | Test Cases | Complexity |
|--------|-----------|------------|
| notify-play.sh | 8 | MEDIUM |
| install.sh | 9 | MEDIUM |
| uninstall.sh | 5 | LOW |
| notify-play.ps1 | 8 | MEDIUM |
| install.ps1 | 11 | MEDIUM |
| uninstall.ps1 | 7 | LOW |
| **Total** | **48** | -- |

---

## MVP Recommendation for v1.2

### Launch With (Must Have)

Core test infrastructure that prevents regressions on the 6 shipped scripts.

- [ ] **T1: ShellCheck** -- Zero effort, instant value. Add `.shellcheckrc`, run on CI.
- [ ] **T2: PSScriptAnalyzer** -- Zero effort, instant value. Add settings file, run via pwsh.
- [ ] **T3: bats tests for notify-play.sh** -- Highest-risk script, most frequently invoked.
- [ ] **T4: bats tests for install.sh** -- Modifies critical user config, needs verification.
- [ ] **T5: bats tests for uninstall.sh** -- Simple, low effort, completes bash coverage.
- [ ] **T6: Pester tests for notify-play.ps1** -- Windows equivalent of T3.
- [ ] **T7: Pester tests for install.ps1** -- Windows equivalent of T4.
- [ ] **T8: Pester tests for uninstall.ps1** -- Windows equivalent of T5.
- [ ] **T9: Test runner script** -- Single command to run everything.

### Add After Core Tests Pass (v1.2.x)

Enhancements that add confidence but are not blocking.

- [ ] **D2: install/uninstall round-trip test** -- Once T4 and T5 pass, add lifecycle test.
- [ ] **D3: settings.json structure validation** -- Additional assertions within T4/T7.
- [ ] **D4: Event mapping consistency** -- Cross-script consistency check.

### Future Consideration (v2+)

Expensive features with diminishing returns for 6 short scripts.

- [ ] **D1: Docker test matrix** -- bats already runs on Linux; macOS Docker is impossible; PowerShell in Linux Docker does not test real Windows behavior. Limited ROI.
- [ ] **D5: Pester code coverage** -- Scripts are <150 lines each. Coverage tracking adds overhead without proportional value.
- [ ] **D6: GitHub Actions Windows runner** -- Requires CI pipeline that does not exist yet. Local-only testing is the stated scope.

### Defer Indefinitely

- [ ] **A1: Audio playback E2E test** -- Cannot run in CI/Docker. Manual verification only.
- [ ] **A2: macOS container testing** -- Technically impossible.

---

## Test Tool Summary

| Tool | Purpose | Version | Install | Confidence |
|------|---------|---------|---------|------------|
| **ShellCheck** | Bash static analysis | 0.10+ | `apt install shellcheck` / `brew install shellcheck` | HIGH -- de facto standard, actively maintained |
| **PSScriptAnalyzer** | PowerShell static analysis | 1.25.0 | `Install-Module PSScriptAnalyzer` (bundled in pwsh 7.x) | HIGH -- official Microsoft tool |
| **bats-core** | Bash test runner | 1.10+ | `npm install -g bats` or git clone to `test/libs/bats-core` | HIGH -- most widely used bash test framework |
| **bats-support** | bats output formatting | 0.3+ | Git submodule to `test/libs/bats-support` | HIGH -- official bats companion |
| **bats-assert** | bats assertion functions | 2.1+ | Git submodule to `test/libs/bats-assert` | HIGH -- official bats companion |
| **bats-file** | bats filesystem assertions | 0.3+ | Git submodule to `test/libs/bats-file` | MEDIUM -- useful for file existence tests |
| **Pester** | PowerShell test framework | 5.5+ | Bundled in pwsh 7.x / `Install-Module Pester` | HIGH -- official recommendation from Microsoft |

---

## Mocking Strategy Summary

### bash (bats)

Mocking in bats is done by defining shell functions that shadow external commands. Since each test runs in a subshell, mocks are automatically scoped.

```bash
# Example: mock jq to capture its arguments and return predefined JSON
setup() {
    # Create temp settings.json fixture
    SETTINGS_FIXTURE=$(mktemp --suffix=.json)
    echo '{"hooks": {}}' > "$SETTINGS_FIXTURE"

    # Shadow jq with a function
    jq() {
        # Call real jq with the filter to produce valid output
        command jq "$@"
    }
}

teardown() {
    rm -f "$SETTINGS_FIXTURE"
}
```

For commands that should NOT run (paplay, afplay, cp), shadow them with no-op functions:
```bash
paplay() { :; }
afplay() { :; }
cp() { :; }
```

### PowerShell (Pester)

Pester has built-in `Mock` that intercepts any cmdlet or function call:

```powershell
BeforeAll {
    # Mock file system commands
    Mock Test-Path { $true }
    Mock Copy-Item { }
    Mock Get-Content { '{"hooks": {}}' }
    Mock ConvertFrom-Json { [PSCustomObject]@{ hooks = [PSCustomObject]@{} } }
    Mock ConvertTo-Json { '{"hooks": {}}' }
}
```

Key Pester mocking capabilities needed:
- `Mock <CommandName> { <return value> }` -- replace command with stub
- `Assert-MockCalled -CommandName <name> -Times <n>` -- verify call count
- `Assert-MockCalled -ParameterFilter { $param -eq 'value' }` -- verify call arguments

---

## Sources

### Primary (HIGH confidence)
- [bats-core official docs](https://bats-core.readthedocs.io/en/stable/writing-tests.html) -- test structure, setup/teardown, `run` helper
- [bats-support](https://github.com/bats-core/bats-support) -- output formatting companion
- [bats-assert](https://github.com/bats-core/bats-assert) -- `assert_success`, `assert_output`, `assert_equal`
- [bats-file](https://github.com/bats-core/bats-file) -- `assert_file_exist`, `assert_file_not_exist`
- [Pester official docs - Mocking](https://pester.dev/docs/usage/mocking) -- Mock, Assert-MockCalled, ParameterFilter
- [Pester GitHub](https://github.com/pester/pester) -- v5.x is current, v6 in development
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck) -- v0.10+, GPLv3, actively maintained
- [PSScriptAnalyzer on PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.25.0) -- latest release v1.25.0

### Secondary (MEDIUM confidence)
- [bats-mock (jasonkarns)](https://github.com/jasonkarns/bats-mock) -- alternative mocking approach (not needed if using function shadows)
- [mcr.microsoft.com/powershell Docker image](https://hub.docker.com/r/mcr/microsoft/powershell) -- official PowerShell Docker image for Linux
- [Testing Bash with BATS - Opensource.com](https://opensource.com/article/19/2/testing-bash-bats) -- practical examples
- [Practical PowerShell Unit-Testing: Mock Objects - Red Gate](https://www.red-gate.com/simple-talk/sysadmin/powershell/practical-powershell-unit-testing-mock-objects/) -- Pester mocking patterns

### Verified Through Code Analysis
- All 6 scripts read and analyzed (see Scope section)
- notify-play.sh: 38 lines, platform branching on `uname -s`, cooldown via timestamp file
- install.sh: 124 lines, jq-based JSON manipulation, prerequisite checks, version comparison
- uninstall.sh: 36 lines, jq-based hook removal, file cleanup
- notify-play.ps1: 52 lines, MediaPlayer via PresentationCore, cooldown via temp file
- install.ps1: 145 lines, ConvertFrom-Json/ConvertTo-Json, BOM-free writing, forward-slash paths
- uninstall.ps1: 60 lines, hook property removal, empty hooks cleanup

---
*Feature research for: Claude Code voice notification system v1.2 cross-platform testing*
*Researched: 2026-03-30*
