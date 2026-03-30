# Pitfalls Research: Test Infrastructure for Shell/PowerShell Notification Scripts

**Domain:** Adding cross-platform test infrastructure (bats, Pester, ShellCheck, PSScriptAnalyzer, Docker matrix) to shell/PowerShell notification scripts
**Researched:** 2026-03-30
**Confidence:** MEDIUM-HIGH
**Scope:** Pitfalls specific to ADDING test infrastructure to shell/PowerShell projects. Builds on the existing v1.1 PITFALLS.md which covers cross-platform runtime issues.

## Critical Pitfalls

Mistakes that cause tests to be unreliable, misleading, or impossible to run in CI/Docker.

### Pitfall 1: Testing Cooldown Logic with Real Time Produces Flaky Tests

**What goes wrong:**
Tests that exercise the 5-second cooldown mechanism (lock file timestamp check) use `sleep` and real wall-clock time. Tests pass most of the time but intermittently fail in CI under load, making the test suite unreliable. A test that asserts "within 5 seconds, playback is skipped" may fail if the CI runner is slow and the `date +%s` call happens to straddle a second boundary.

**Why it happens:**
The cooldown logic in `notify-play.sh` uses `date +%s` minus `stat` mtime to compute lock age. Testing this requires creating a lock file, waiting, then checking behavior. The 1-second granularity of epoch seconds means tests that check "is it within cooldown?" are inherently non-deterministic when the lock age is close to the 5-second threshold. CI runners under load add extra latency.

**How to avoid:**
1. **Do not use `sleep` to test cooldown.** Instead, directly manipulate the lock file timestamp to simulate aging:
   ```bash
   # Create lock file with specific age
   touch "$LOCK_FILE"
   touch -d "6 seconds ago" "$LOCK_FILE"  # GNU/Linux
   touch -A "-000600" "$LOCK_FILE"         # macOS BSD
   ```
2. If time manipulation is not feasible, make the cooldown duration injectable (e.g., via environment variable) so tests can use a very short cooldown (0 or 1 second) instead of 5 seconds.
3. Add a tolerance buffer in assertions -- never assert exactly at the boundary (e.g., assert at 6 seconds instead of 5).

**Warning signs:**
- Tests that call `sleep` are slow (2-5 seconds per test) and occasionally fail
- Test results differ between local runs and CI runs
- Running the same test 10 times produces different pass/fail outcomes

**Phase to address:**
Phase 1 (bats unit tests for shell scripts) -- this is the first logic that needs testing, and the flaky test risk is immediate.

---

### Pitfall 2: Headless CI/Docker Cannot Play Audio -- Tests Must Mock, Not Execute

**What goes wrong:**
Tests that run `notify-play.sh` or `notify-play.ps1` end-to-end try to invoke `paplay`, `afplay`, or `MediaPlayer`. In Docker containers and CI runners (no audio hardware, no PulseAudio, no desktop session), these commands either fail or hang indefinitely. The test suite becomes unusable in CI.

**Why it happens:**
The scripts hardcode absolute paths to audio players (`/usr/bin/paplay`, `/usr/bin/afplay`) and directly instantiate .NET classes (`Add-Type -AssemblyName PresentationCore; New-Object System.Windows.Media.MediaPlayer`). There is no abstraction layer that allows substituting a mock. In CI, `paplay` fails immediately (good), but `MediaPlayer` on Windows can hang waiting for a WPF dispatcher thread that never starts (bad -- test timeout).

**How to avoid:**
1. **For bats tests:** Create stub scripts for `paplay` and `afplay` that log their invocation arguments to a file and exit 0. Place stubs in a `test/fixtures/bin/` directory and prepend it to `$PATH`:
   ```bash
   setup() {
       export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
       mkdir -p "$BATS_TEST_TMPDIR/bin"
       # Create stub paplay that records calls
       cat > "$BATS_TEST_TMPDIR/bin/paplay" << 'STUB'
       echo "$@" >> "$BATS_TMPDIR/paplay.log"
       exit 0
   STUB
       chmod +x "$BATS_TEST_TMPDIR/bin/paplay"
   }
   ```
2. **For Pester tests:** Refactor `notify-play.ps1` to extract the audio playback into a wrapper function, then mock the function in tests:
   ```powershell
   # In production code
   function Invoke-AudioPlayback {
       param([string]$AudioFile)
       Add-Type -AssemblyName PresentationCore
       $player = New-Object System.Windows.Media.MediaPlayer
       # ...
   }
   ```
   ```powershell
   # In Pester test
   Mock Invoke-AudioPlayback {} -ModuleName notify-play
   ```
3. **Never instantiate MediaPlayer in tests.** It requires a WPF dispatcher thread and desktop session, neither of which exist in CI or Docker.
4. **Pester's Mock cannot mock .NET constructor calls** (`New-Object System.Windows.Media.MediaPlayer`). Only PowerShell commands/functions/cmdlets can be mocked. This is why extracting to a wrapper function is necessary.

**Warning signs:**
- Tests pass locally (with audio hardware) but fail/hang in CI
- Pester tests timeout after default 30 seconds
- Docker test matrix shows Windows container tests as "stuck"

**Phase to address:**
Phase 1 (bats unit tests) and Phase 2 (Pester unit tests) -- this affects both test frameworks.

---

### Pitfall 3: Pester Version Mismatch Between PowerShell 5.1 and pwsh 7

**What goes wrong:**
Tests written for Pester v5 on `pwsh 7` fail on Windows PowerShell 5.1, or vice versa. The project targets PowerShell 5.1 (per the existing install.ps1 constraints), but developers may test on `pwsh 7`. Pester v6 has dropped support for PS 3/4/5.0, and v5 has different syntax from v4. Loading the wrong Pester version causes cryptic type errors (`[PesterConfiguration]` not found, parameterized tests fail silently).

**Why it happens:**
Windows ships with PowerShell 5.1 pre-installed. Many developers also install PowerShell 7 (`pwsh`). VSCode may load Pester from different module paths depending on which shell is active. If Pester v4 and v5 are both installed (v4 in system modules, v5 in user modules), VSCode may load the wrong one, causing `[PesterConfiguration]` type conflicts (GitHub Issue pester/Pester#1770).

**How to avoid:**
1. **Pin Pester version explicitly** in test scripts and CI:
   ```powershell
   # At top of test file
   Import-Module Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.99 -ErrorAction Stop
   ```
2. **Do NOT use Pester v6** -- it drops PS 3/4/5.0 support. PS 5.1 support in v6 is uncertain and the migration effort is not worthwhile for notification scripts.
3. **Test on PS 5.1 specifically**, not just pwsh 7. Many cmdlets and .NET types behave differently.
4. **In Docker Windows containers**, note that Nano Server only supports `pwsh` while Server Core supports both PS 5.1 and `pwsh`. For PS 5.1 compatibility testing, use a Server Core image.
5. **Use `PSScriptAnalyzer` with the `desktop-5.1.14393.206-windows` target profile** to catch PS 5.1 incompatible syntax at lint time:
   ```powershell
   # PSScriptAnalyzerSettings.psd1
   @{
       Rules = @{
           PSUseCompatibleSyntax = @{
               Enable = $true
               TargetVersions = @("5.1")
           }
           PSUseCompatibleCommands = @{
               Enable = $true
               TargetProfiles = @("desktop-5.1.14393.206-windows")
           }
       }
   }
   ```

**Warning signs:**
- `[PesterConfiguration]` type not found error
- Parameterized tests (`-TestCases`) produce no output
- Tests pass on pwsh 7 but fail on powershell 5.1
- VSCode Pester extension shows different results than `Invoke-Pester` in terminal

**Phase to address:**
Phase 2 (Pester unit tests) -- version compatibility must be decided before writing tests. Phase 3 (PSScriptAnalyzer) can catch syntax issues early.

---

### Pitfall 4: bats `load` Path Resolution Breaks When Run from Different Directories

**What goes wrong:**
Test helper files loaded via bats `load` command cannot be found when tests are run from a directory other than the project root. `bats tests/notify-play.bats` works, but `cd tests && bats notify-play.bats` fails with "file not found" because `load` resolves paths relative to the **test file's location**, not the working directory.

**Why it happens:**
The bats `load` command sources files relative to the current test file's directory. However, the test's working directory (`$PWD`) defaults to where `bats` was invoked, not where the test file lives. If helper files are referenced using `$PWD`-relative paths (e.g., `load ../scripts/notify-play.sh`), the resolution depends on the invocation directory.

**How to avoid:**
1. Use a consistent project-root-relative structure and always invoke bats from the project root:
   ```
   project/
   ├── scripts/
   │   └── notify-play.sh
   └── tests/
       ├── helpers/
       │   └── common.bash
       └── notify-play.bats
   ```
   In `notify-play.bats`: `load helpers/common` resolves to `tests/helpers/common.bash`.
2. To source production scripts (not helpers), use absolute paths derived from the test file:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
   REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
   source "$REPO_ROOT/scripts/notify-play.sh"
   ```
3. **Never use `source` with relative paths for production code** -- always compute absolute paths first.
4. Document the expected invocation: `bats tests/` from project root.

**Warning signs:**
- `load` or `source` fails with "file not found"
- Tests pass in CI but fail locally (or vice versa) due to different working directories
- Docker `WORKDIR` causes test failures

**Phase to address:**
Phase 1 (bats unit tests) -- directory structure and file loading must be correct from the start.

---

### Pitfall 5: Lock File Pollution Between Tests -- No Temp Directory Isolation

**What goes wrong:**
Multiple test cases that exercise cooldown logic share the same lock file path (`/tmp/claude-notify-complete.lock`). If tests run in parallel (bats `--parallel` flag) or if teardown fails to clean up, a lock file created by one test affects subsequent tests. Tests become order-dependent: test A creates a lock, test B sees it and skips playback when it should not.

**Why it happens:**
The production script hardcodes the lock file path to `/tmp/claude-notify-${TYPE}.lock`. Tests that invoke the script directly use the same path. bats does not sandbox the filesystem. While bats provides `$BATS_TEST_TMPDIR` (a unique temp dir per test), the production script does not use it.

**How to avoid:**
1. **Override the lock file path in tests** by setting a test-specific temp directory:
   ```bash
   setup() {
       export LOCK_DIR="$BATS_TEST_TMPDIR"
       # Refactor notify-play.sh to use $LOCK_DIR instead of /tmp
       # Or: create a wrapper that sets TMPDIR before invoking
       export TMPDIR="$BATS_TEST_TMPDIR"
   }
   ```
2. **Better: make the lock directory configurable** in the production script via environment variable with fallback:
   ```bash
   LOCK_DIR="${NOTIFY_LOCK_DIR:-${TMPDIR:-/tmp}}"
   LOCK_FILE="$LOCK_DIR/claude-notify-${TYPE}.lock"
   ```
3. Always clean up lock files in teardown:
   ```bash
   teardown() {
       rm -f "$BATS_TEST_TMPDIR"/claude-notify-*.lock
   }
   ```
4. Never use bats `--parallel` without ensuring each test uses `$BATS_TEST_TMPDIR`.

**Warning signs:**
- Tests pass individually (`bats tests/notify-play.bats`) but fail when run as a suite
- Tests pass in one order but fail in another
- Adding a new test causes an unrelated existing test to fail

**Phase to address:**
Phase 1 (bats unit tests) -- temp directory isolation is fundamental to test reliability.

---

## Moderate Pitfalls

Mistakes that cause degraded developer experience or incomplete test coverage.

### Pitfall 6: bats `setup()` Runs Per-Test, Not Once -- Expensive Setup Repeated

**What goes wrong:**
Placing expensive operations (Docker container startup, model file copying, environment bootstrapping) in `setup()` causes them to run before every single test. A test suite with 20 tests takes 60 seconds instead of 3 seconds because Docker starts 20 times.

**Why it happens:**
bats `setup()` and `teardown()` run before and after **each individual test**, not once per test file. This is documented but counter-intuitive for developers coming from JUnit or pytest where `@BeforeAll` runs once.

**How to avoid:**
1. Use `setup_file()` / `teardown_file()` for one-time setup per test file.
2. Use `setup_suite()` / `teardown_suite()` (in a `setup_suite.bash` file) for one-time setup across the entire suite.
3. Keep `setup()` lightweight -- only create per-test temp directories and stub commands.
4. Document which setup scope is used and why.

**Phase to address:**
Phase 1 (bats unit tests) -- choose the right setup scope before writing tests.

---

### Pitfall 7: ShellCheck Suppression Without Understanding Creates False Confidence

**What goes wrong:**
Developers add `# shellcheck disable=SCXXXX` directives to silence warnings without understanding the underlying issue. The script passes ShellCheck with zero warnings but still contains bugs (unquoted variables, word splitting, glob expansion). CI shows green but the script fails in production.

**Why it happens:**
ShellCheck warnings are sometimes noisy for well-intentioned patterns. The existing scripts use `set -euo pipefail` which mitigates some issues, leading developers to suppress warnings that seem unnecessary. However, suppression directives disable the check for the entire command, not just the false positive.

**How to avoid:**
1. **Never suppress without a comment** explaining why:
   ```bash
   # shellcheck disable=SC2086  # Intentional word split: $args contains separate arguments
   some_command $args
   ```
2. **Scope suppression to single lines** -- avoid file-level `# shellcheck disable=` which disables all checks.
3. **Review every suppression** in code review. Maintain a suppression log if the project grows.
4. For the existing scripts, the most likely ShellCheck findings will be:
   - SC2086 (double quote variables) -- the scripts already quote correctly
   - SC1091 (source not following) -- expected for external dependencies
   - SC2034 (unused variable) -- check if truly unused
5. Run ShellCheck with `severity=warning` (not `error`) initially to see all findings.

**Phase to address:**
Phase 3 (ShellCheck static analysis) -- establish suppression policy before running.

---

### Pitfall 8: Docker Test Matrix for Windows Containers Is Extremely Heavy (3-11 GB Images)

**What goes wrong:**
Adding Windows containers to the Docker test matrix seems straightforward but the Windows Server Core base image is 3-5 GB and a full Nano Server image can be 1-2 GB. Downloading and building Windows containers takes 10-30 minutes, making local development painful and CI slow. The project documentation says "local-only Docker matrix" but the image sizes may make this impractical.

**Why it happens:**
Windows containers require a Windows host OS layer. Unlike Linux containers which share the host kernel, Windows containers include their own Windows kernel components. Even "minimal" Windows Server Core images are gigabytes.

**How to avoid:**
1. **Prefer WSL2 with Linux containers for PowerShell Core testing** -- `mcr.microsoft.com/powershell:latest` is a Linux image (~400 MB) that runs `pwsh`. This does NOT test PS 5.1 compatibility but is much lighter.
2. **For PS 5.1 compatibility, test natively on Windows** (not in Docker). PS 5.1 is pre-installed on all Windows 10/11 machines. Running Pester directly in PowerShell 5.1 is simpler and more reliable than Windows containers.
3. **If Windows containers are needed**, use `mcr.microsoft.com/windows/servercore:ltsc2022` (~3 GB) and accept the size. Never use full Server images.
4. **Document the Docker matrix as optional** -- Linux containers for bats, native Windows for Pester. Docker Windows containers are a "nice to have" not a requirement.
5. Use `--platform linux/amd64` to avoid pulling Windows images on Linux hosts by accident.

**Phase to address:**
Phase 4 (Docker test matrix) -- decide on matrix strategy before building Dockerfiles. This decision affects CI pipeline complexity.

---

### Pitfall 9: `teardown()` Failure Reported Against Wrong Test in bats

**What goes wrong:**
When a bats `teardown()` function fails, the error is attributed to the **next test**, not the test whose teardown actually failed. This makes debugging very confusing: "test B failed because of an error in test A's teardown" is not obvious from the output.

**Why it happens:**
This is a known bats-core behavior (GitHub Issue bats-core/bats-core#1136). The teardown failure is detected when the next test's `setup()` runs, so the error gets associated with that test.

**How to avoid:**
1. Make `teardown()` robust -- use `|| true` for cleanup operations that can fail:
   ```bash
   teardown() {
       rm -f "$BATS_TEST_TMPDIR"/claude-notify-*.lock || true
   }
   ```
2. If teardown must fail for debugging, check `$BATS_TEST_NAME` to identify which test caused the issue.
3. Be aware of this behavior when debugging -- if a test fails unexpectedly, check the previous test's teardown.

**Phase to address:**
Phase 1 (bats unit tests) -- understand this quirk before writing teardown logic.

---

### Pitfall 10: macOS-Specific `stat` and `touch` Flags Break Tests on Linux

**What goes wrong:**
Tests written on macOS use BSD `stat -f %m` and `touch -A` flags. These tests fail on Linux (CI) because Linux uses GNU `stat -c %Y` and `touch -d`. Conversely, tests written on Linux fail on macOS. The project already handles this in production code (v1.1), but test helper functions may accidentally use OS-specific flags.

**Why it happens:**
Test helper functions that manipulate file timestamps for cooldown testing need to "age" a lock file. The `touch` command for setting arbitrary timestamps is completely different between GNU and BSD:
- Linux: `touch -d "6 seconds ago" "$FILE"`
- macOS: `touch -A "-000600" "$FILE"` (the `-A` argument format is MMDDhhmm, not human-readable)

**How to avoid:**
1. Create a portable helper function in `tests/helpers/common.bash`:
   ```bash
   set_file_age() {
       local file="$1"
       local seconds_ago="$2"
       if [[ "$(uname -s)" == "Darwin" ]]; then
           # macOS: touch -A uses [[CC]YY]MMDDhhmm[.SS] format
           local now_epoch=$(date +%s)
           local target_epoch=$((now_epoch - seconds_ago))
           local target_date=$(date -r "$target_epoch" +%Y%m%d%H%M.%S)
           touch -t "$target_date" "$file"
       else
           touch -d "${seconds_ago} seconds ago" "$file"
       fi
   }
   ```
2. Alternatively, since the production script already detects the OS for stat, reuse that pattern in test helpers.
3. Test this helper on both macOS and Linux early.

**Phase to address:**
Phase 1 (bats unit tests) -- the cooldown timestamp helper is needed for the first meaningful test.

---

## Minor Pitfalls

### Pitfall 11: ShellCheck Docker Image Missing `shell` Binary for Glob Support

**What goes wrong:**
Running ShellCheck via its official Docker image (`koalaman/shellcheck`) produces false negatives for rules that require shell execution (SC2250, SC2296). The Docker image does not include a full `shell` binary for glob expansion analysis (GitHub Issue koalaman/shellcheck#2862).

**How to avoid:**
1. Install ShellCheck natively on Linux/macOS (`apt install shellcheck` or `brew install shellcheck`) rather than running via Docker.
2. If Docker is required, accept the reduced coverage and document the limitation.
3. For the existing simple scripts (no complex globbing), this is unlikely to be a practical issue.

**Phase to address:**
Phase 3 (ShellCheck integration) -- minor concern, decide native vs Docker installation.

---

### Pitfall 12: bats Parallel Mode Changes Test Timing Assumptions

**What goes wrong:**
Running `bats --parallel` to speed up CI causes tests to fail because parallel tests share the same `/tmp` directory. Lock file tests conflict, temp files collide, and timing-sensitive tests produce unpredictable results.

**How to avoid:**
1. Do NOT use `bats --parallel` for this project. The test suite is small (6 scripts, ~20 tests) and should complete in under 5 seconds without parallelism.
2. If parallelism is ever needed, ensure every test uses `$BATS_TEST_TMPDIR` exclusively (see Pitfall 5).

**Phase to address:**
Phase 1 (bats unit tests) -- document that parallel execution is not supported.

---

### Pitfall 13: PSScriptAnalyzer `UseCompatibleTypes` May Flag PresentationCore on Non-Windows

**What goes wrong:**
Running PSScriptAnalyzer with `UseCompatibleTypes` rule against the PowerShell scripts flags `System.Windows.Media.MediaPlayer` (from PresentationCore) as incompatible with non-Windows targets. This is technically correct but expected -- MediaPlayer only exists on Windows.

**How to avoid:**
1. Configure PSScriptAnalyzer to target only `desktop-5.1.14393.206-windows`, not cross-platform profiles.
2. Suppress the warning for the specific line if needed:
   ```powershell
   [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleTypes', '')]
   ```
3. This is expected behavior -- the scripts are Windows-only by design.

**Phase to address:**
Phase 3 (PSScriptAnalyzer) -- configure the correct target profile.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip mocking, use `sleep` in tests | Tests written faster | Flaky CI, slow suite (2-5s per test) | Never for cooldown tests; OK for smoke tests |
| Test only on pwsh 7, ignore PS 5.1 | Simpler test writing | Scripts break on default Windows PS | Never -- PS 5.1 is the target |
| Use Docker for all platforms including Windows | One tool for everything | 3-11 GB Windows images, slow CI, requires Windows host | Never for PS 5.1 testing; consider Linux pwsh container |
| Suppress all ShellCheck warnings to get green CI | Quick compliance | Hidden bugs, false confidence | Never without per-suppression justification |
| Run bats without temp directory isolation | Simpler test code | Order-dependent tests, parallel hazards | Never |
| Use Pester v6 for newer features | Access to latest Pester features | Drops PS 3/4/5.0 support, uncertain PS 5.1 support | Never until PS 5.1 support is explicitly confirmed |

## Integration Gotchas

Common mistakes when connecting test infrastructure to external tools and CI.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| bats + production scripts | Sourcing scripts that execute side effects (play audio, write to `$HOME/.claude`) | Set `NOTIFY_LOCK_DIR` and mock audio commands in PATH before sourcing |
| Pester + settings.json | Tests modify real `~/.claude/settings.json`, polluting the developer's environment | Use `$env:USERPROFILE = "$TestDrive"` or mock file operations |
| ShellCheck + shebang | ShellCheck may not detect the correct shell for `.ps1` files | Run ShellCheck separately: `shellcheck scripts/*.sh` and `Invoke-ScriptAnalyzer scripts/*.ps1` |
| Docker + bats | `bats` not installed in the Docker image, or wrong version | Install bats-core via npm (`npm install -g bats`) or clone from GitHub in Dockerfile |
| Docker + Pester | Pester module not pre-installed in Windows container | `pwsh -Command "Install-Module Pester -Force -Scope CurrentUser"` in Dockerfile |
| CI + lock files | Lock files persist between CI runs on self-hosted runners | Always clean `$TMPDIR`/`$TEMP` in CI setup step |

## Performance Traps

Patterns that work at small scale but fail as the test suite grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `sleep` in tests | Each cooldown test takes 5+ seconds; 10 tests = 50+ seconds | Mock time via timestamp manipulation; make cooldown configurable | Immediately at 5+ tests |
| Docker Windows pull time | CI pipeline takes 15-30 minutes for Windows container phase | Use native Windows for PS 5.1; skip Windows containers if possible | First CI run |
| No test isolation | Adding tests breaks existing tests | Use `$BATS_TEST_TMPDIR` and fresh `$TESTDRIVE` per test | At 3+ test files |
| Repeated expensive setup | Docker startup in `setup()` runs per test | Use `setup_file()` for Docker; per-test setup only for mocks | At 5+ tests |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Cooldown tests:** Do tests manipulate file timestamps instead of using `sleep`? Verify by running 10 times -- any intermittent failure indicates real-time dependency.
- [ ] **Audio mocking:** Do bats tests stub `paplay`/`afplay` in PATH? Do Pester tests mock the playback function? Verify by checking that the real audio command is never invoked (check process list).
- [ ] **Temp isolation:** Does each test use its own temp directory? Verify by running tests in random order -- any order-dependent failure indicates shared state.
- [ ] **PS 5.1 coverage:** Have tests been run on actual Windows PowerShell 5.1 (not just pwsh 7)? Verify by checking `$PSVersionTable.PSVersion` in CI output.
- [ ] **ShellCheck zero warnings:** Are all ShellCheck warnings addressed, not just suppressed? Review each `# shellcheck disable` directive.
- [ ] **PSScriptAnalyzer profile:** Is the `desktop-5.1.14393.206-windows` target profile configured? Verify by checking PSScriptAnalyzer output includes version-specific warnings.
- [ ] **Docker matrix runs locally:** Does `docker compose up` start all three platform containers and run tests? Verify on a fresh machine (no cached images).
- [ ] **settings.json not polluted:** After running all tests, is the developer's `~/.claude/settings.json` unchanged? Verify by diffing before/after.
- [ ] **Lock files cleaned up:** After test suite completes, are there leftover `/tmp/claude-notify-*.lock` files? Verify by listing `/tmp` after tests.

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Flaky time-based tests | MEDIUM | 1. Identify tests with `sleep` calls. 2. Replace with timestamp manipulation. 3. Add retry assertion if absolutely needed. |
| CI hangs on MediaPlayer | LOW | 1. Add timeout to Pester tests (`-Timeout 5`). 2. Extract MediaPlayer to wrapper function. 3. Mock wrapper in tests. |
| Pester version conflict | LOW | 1. Remove all Pester versions: `Get-Module Pester -All \| Remove-Module -Force`. 2. Install specific version: `Install-Module Pester -RequiredVersion 5.5.0 -Force`. 3. Pin version in test files. |
| bats path resolution broken | LOW | 1. Compute absolute paths using `$BATS_TEST_FILENAME`. 2. Add error checking for file existence. 3. Document required invocation directory. |
| Lock file pollution | LOW | 1. Clean `/tmp/claude-notify-*.lock`. 2. Add `$BATS_TEST_TMPDIR` to all tests. 3. Add cleanup to teardown. |
| Docker Windows too heavy | HIGH | 1. Remove Windows containers from Docker Compose. 2. Add native Windows testing instructions. 3. Keep Linux containers only. |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Pitfall 1 (flaky cooldown tests) | Phase 1 (bats tests) | Run cooldown tests 20 times locally and in CI -- zero failures |
| Pitfall 2 (headless audio) | Phase 1 (bats), Phase 2 (Pester) | Verify no real audio command runs during tests (check process list, temp logs) |
| Pitfall 3 (Pester version) | Phase 2 (Pester tests) | Run `Invoke-Pester` on PS 5.1 and pwsh 7 -- identical results |
| Pitfall 4 (bats path resolution) | Phase 1 (bats tests) | Run `bats tests/` from project root and from subdirectory -- both pass |
| Pitfall 5 (lock file pollution) | Phase 1 (bats tests) | Run tests in random order 5 times -- all pass identically |
| Pitfall 6 (setup scope) | Phase 1 (bats tests) | Verify no Docker start in `setup()`, only in `setup_file()` |
| Pitfall 7 (ShellCheck suppression) | Phase 3 (ShellCheck) | Review all suppressions in code review; zero uncommented suppressions |
| Pitfall 8 (Docker Windows size) | Phase 4 (Docker matrix) | Measure total image download time; if >5 min, reconsider strategy |
| Pitfall 9 (teardown attribution) | Phase 1 (bats tests) | Verify teardown uses `|| true` for cleanup |
| Pitfall 10 (macOS stat/touch) | Phase 1 (bats tests) | Run all bats tests on both macOS and Linux |
| Pitfall 13 (PSScriptAnalyzer types) | Phase 3 (PSScriptAnalyzer) | Configure desktop-5.1 profile; verify PresentationCore not flagged as error |

## Sources

### HIGH Confidence (Official Documentation / Verified Issues)

- [bats-core Writing Tests](https://bats-core.readthedocs.io/en/stable/writing-tests.html) -- `load`, `$BATS_TEST_TMPDIR`, `$BATS_FILE_TMPDIR`, setup/teardown scopes (verified 2026-03-30)
- [bats-core FAQ](https://bats-core.readthedocs.io/en/stable/faq.html) -- setup runs per-test, setup_suite for global setup (verified 2026-03-30)
- [bats-core Issue #1136: teardown failure attribution](https://github.com/bats-core/bats-core/issues/1136) -- teardown failure reported against wrong test (verified 2026-03-30)
- [bats-core Issue #226: temp file cleanup](https://github.com/bats-core/bats-core/issues/226) -- cleanup strategies (verified 2026-03-30)
- [bats-core Issue #283: isolated temp dir per run](https://github.com/bats-core/bats-core/issues/283) -- temp directory isolation discussion (verified 2026-03-30)
- [Pester v5 to v6 Migration Guide](https://pester.dev/docs/v6/migrations/v5-to-v6) -- dropped PS 3/4/5.0 support (verified 2026-03-30)
- [Pester Breaking Changes in v5](https://pester.dev/docs/migrations/breaking-changes-in-v5) -- v4 to v5 migration (verified 2026-03-30)
- [PSScriptAnalyzer UseCompatibleTypes](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatibletypes?view=ps-modules) -- compatibility profiles (verified 2026-03-30)
- [PSScriptAnalyzer for Version Compatibility (Microsoft Dev Blogs)](https://devblogs.microsoft.com/powershell/using-psscriptanalyzer-to-check-powershell-version-compatibility/) -- UseCompatibleSyntax, target profiles (verified 2026-03-30)
- [Microsoft: Differences between Windows PowerShell 5.1 and PowerShell 7.x](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.6) -- cmdlet and type differences (verified 2026-03-30)

### MEDIUM Confidence (Multiple Sources Agree)

- [bats-core Issue #79: load relative paths](https://github.com/bats-core/bats-core/issues/79) -- load resolves relative to test file (verified 2026-03-30)
- [bats-core Issue #171: parallel mode](https://github.com/bats-core/bats-core/issues/171) -- parallel execution limitations (verified 2026-03-30)
- [Pester Issue #1770: PesterConfiguration type conflict](https://github.com/pester/Pester/issues/1770) -- version mismatch symptoms (verified 2026-03-30)
- [PowerShell/DscResource.Tests Issue #204: Pester in Windows containers](https://github.com/PowerShell/DscResource.Tests/issues/204) -- scope isolation workarounds (verified 2026-03-30)
- [PS7CompatibilityRules (Jane Street)](https://github.com/janestreet/PS7CompatibilityRules) -- community rules for PS 5.1 to 7 migration (verified 2026-03-30)
- [How to use bats-mock to assert against calls](https://stackoverflow.com/questions/38315185/how-to-use-bats-mock-to-assert-against-calls-to-a-mocked-script-in-bash-testin) -- stub approach for external commands (verified 2026-03-30)
- [Stack Overflow: PS 5.1 using module differences](https://stackoverflow.com/questions/78359289/windows-powershell-5-1-cannot-import-local-module-file-with-using-module-but-p) -- module loading differences (verified 2026-03-30)
- [Stack Overflow: Race condition with lock file](https://stackoverflow.com/questions/325628/how-to-avoid-race-condition-when-using-a-lock-file-to-avoid-two-instances-of-a-s) -- TOCTOU prevention (verified 2026-03-30)
- [Fixing Flaky Time Based Unit Tests (Expedia Group)](https://medium.com/expedia-group-tech/fixing-flaky-time-based-unit-tests-176accf5096e) -- general time-based test flakiness patterns (MEDIUM -- not shell-specific)

### LOW Confidence (Training Data / Single Source)

- Pester Mock cannot mock .NET constructors -- based on Pester documentation knowledge and community consensus, but no single authoritative source verified
- Docker Windows container sizes (3-11 GB) -- cited in blog post (Rolling Websphere), not verified against latest Microsoft images
- ShellCheck Docker glob support limitation -- GitHub Issue koalaman/shellcheck#2862 confirmed, impact on this project's scripts not verified
- `touch -A` flag for macOS timestamp manipulation -- known BSD syntax, not verified against latest macOS version
- `faketime` tool for mocking time in bash -- known tool, not verified as available in all CI environments

---
*Pitfalls research for: Claude Code voice notification system v1.2 test infrastructure*
*Researched: 2026-03-30*
