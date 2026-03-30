# Phase 7: Bash Unit Testing - Research

**Researched:** 2026-03-30
**Domain:** bats-core testing for bash scripts (notify-play.sh, install.sh, uninstall.sh)
**Confidence:** HIGH

## Summary

Phase 7 writes bats-core tests for all 3 bash scripts in the project. The tests run inside a Docker container (bats/bats:1.11.0, Alpine-based) via `test.sh --bash`. The core challenge is mocking: PATH-based stub scripts intercept calls to `paplay`/`afplay` and `claude`, while `NOTIFY_LOCK_DIR` and timestamp manipulation handle cooldown testing.

Two critical findings affect the plan: (1) the bats Docker image does NOT have `jq` installed, but both `install.sh` and `uninstall.sh` require it -- the plan must either modify `test.sh` to install jq in the container or add a Dockerfile. (2) Alpine's BusyBox `touch` does not support `-d "date string"` syntax; cooldown tests must use `touch -t [[CC]YY]MMDDhhmm[.ss]` to set lock file timestamps. CONTEXT.md's mention of `touch -d` is incompatible with the test runtime environment.

**Primary recommendation:** Write 3 `.bats` files with inline setup/teardown, PATH-based stubs in `tests/stubs/`, and modify `test.sh` to install jq in the bats container before running tests.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Each test file independently sets up LOCK_DIR, settings.json fixture copies, etc. No shared mutable state between files. Each test function uses a temp directory, teardown cleans up.
- **D-02:** No bats-file/bats-support plugins. Pure bats-core + bash only. Minimize external dependencies.
- **D-03:** PATH stub scripts to mock paplay/afplay. Create stubs in `tests/stubs/` directory (exit 0). Prepend `tests/stubs/` to PATH before tests.
- **D-04:** Stub scripts record call logs to `$CALLED_LOG` env var pointing to a temp file, so tests can verify which player was called (BASH-03 platform branch). Log written to `$(mktemp)` or specified file.
- **D-05:** No bats `run()` override or Docker audio isolation for mocking.
- **D-06:** Tests copy real MP3 files from `audio/` to temp CLAUDE_DIR. Install script checks file existence; real files simulate actual install flow.
- **D-07:** settings.json uses copy of `tests/fixtures/settings.json` as test target. Fixture has existing PreToolUse hook, ensuring install.sh does not overwrite non-notification hooks.
- **D-08:** Test files organized by script under test: `tests/bash/notify-play.bats` (4 tests), `install.bats` (3 tests), `uninstall.bats` (3 tests). 1:1 mapping to scripts.
- **D-09:** Descriptive sentence-style test names: `@test "cooldown skip when lock file is younger than 5 seconds"`. Standard bats convention.

### Claude's Discretion
- Specific temp directory path strategy (mktemp / bats TMPDIR)
- setup/teardown helper implementation (inline or extracted function)
- Stub script log format (one-line-per-entry or JSON)
- How to skip/bypass `claude` version check in install.sh prerequisite tests (may need to mock `claude` command)

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BASH-01 | notify-play.sh cooldown skip (lock file exists and < 5s) | NOTIFY_LOCK_DIR override + `touch -t` for timestamp setting |
| BASH-02 | notify-play.sh cooldown pass (lock file older than 5s) | NOTIFY_LOCK_DIR override + `touch -t` for old timestamp |
| BASH-03 | notify-play.sh platform branch (Darwin afplay vs Linux paplay) | PATH stubs with call logging via $CALLED_LOG |
| BASH-04 | notify-play.sh always exits 0 (even on player failure) | Stub that exits 1, verify $status == 0 |
| BASH-05 | install.sh 4 hook events injected to settings.json | Fixture copy + jq verification of output |
| BASH-06 | install.sh idempotent re-run (no duplicate hooks) | Run install twice, verify single set of hooks |
| BASH-07 | install.sh prerequisite checks (missing jq/paplay/settings.json/mp3 errors) | Remove each dependency, verify exit 1 + stderr |
| BASH-08 | uninstall.sh 4 hook events removed | Install first, then uninstall, verify hooks gone |
| BASH-09 | uninstall.sh MP3 files deleted | Install first, then uninstall, verify files gone |
| BASH-10 | uninstall.sh idempotent re-run (no hooks, no error) | Uninstall twice, verify second run succeeds |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bats-core | 1.11.0 | Bash testing framework | Pinned in test.sh; runs in Docker container `bats/bats:1.11.0` |
| bash | 5.2.26 | Runtime inside bats container | Provided by `bats/bats:1.11.0` image (Alpine) |
| jq | 1.7+ | JSON manipulation (install.sh/uninstall.sh dependency) | Required by scripts under test; NOT pre-installed in container (see Pitfall 1) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| coreutils (BusyBox) | Alpine default | stat, touch, date, mktemp | All filesystem operations in tests |
| docker | 24.x+ | Test execution environment | `test.sh --bash` runs bats in container |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bats-core | bashunit / shunit2 | bats-core is the de facto standard for bash testing; wider community, Docker support |
| PATH stubs | bats `run()` override | PATH stubs are simpler and per D-05 explicitly forbidden to override `run()` |
| `touch -t` (BusyBox) | `faketime` / `libfaketime` | Additional Alpine package; `touch -t` is built-in and sufficient for our needs |

**Installation:**
No npm install needed. All testing runs via Docker:
```bash
# Run bash tests
bash test.sh --bash
```

**Version verification:** The bats Docker image `bats/bats:1.11.0` is pinned in `test.sh` line 7. jq must be installed in the container (see Pitfall 1).

## Architecture Patterns

### Recommended Test Structure
```
tests/
├── bash/
│   ├── notify-play.bats    # 4 tests: BASH-01~04
│   ├── install.bats        # 3 tests: BASH-05~07
│   └── uninstall.bats      # 3 tests: BASH-08~10
├── stubs/
│   ├── paplay              # Mock player (logs to $CALLED_LOG)
│   └── afplay              # Mock player (logs to $CALLED_LOG)
├── fixtures/
│   ├── settings.json       # Pre-existing PreToolUse hook + permissions
│   └── dummy.mp3           # Minimal valid MP3 (746 bytes)
└── helpers/
    └── common.bash         # (optional) Shared helper functions loaded via `load`
```

### Pattern 1: PATH-Based Stub Mocking
**What:** Create executable stub scripts that log calls to a file. Prepend stub directory to PATH so scripts under test call stubs instead of real commands.
**When to use:** Mocking external commands (paplay, afplay, claude) that scripts invoke.
**Example:**
```bash
# tests/stubs/paplay
#!/usr/bin/env bash
echo "paplay $*" >> "${CALLED_LOG:-/dev/null}"
exit 0
```
**Test usage:**
```bash
setup() {
    export CALLED_LOG="$(mktemp)"
    export PATH="$BATS_TEST_DIRNAME/../stubs:$PATH"
}
teardown() {
    rm -f "$CALLED_LOG"
}
```

### Pattern 2: Timestamp Manipulation for Cooldown Testing
**What:** Use `touch -t` to set lock file mtime to a specific value, controlling whether the cooldown check passes or skips.
**When to use:** BASH-01 (cooldown skip, lock < 5s) and BASH-02 (cooldown pass, lock old).
**CRITICAL:** Alpine BusyBox does NOT support `touch -d "date string"`. Must use `touch -t [[CC]YY]MMDDhhmm[.ss]`.
**Example:**
```bash
@test "cooldown skip when lock file is younger than 5 seconds" {
    # Create lock file with current timestamp (within cooldown)
    touch "$LOCK_DIR/claude-notify-complete.lock"
    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
    # Player should NOT have been called
    ! grep -q "paplay" "$CALLED_LOG"
}

@test "cooldown pass when lock file is older than 5 seconds" {
    # Create lock file with timestamp 10 seconds ago
    OLD_TIME=$(date -d '10 seconds ago' +%Y%m%d%H%M.%S 2>/dev/null || \
               date -v-10S +%Y%m%d%H%M.%S 2>/dev/null || \
               $(($(date +%s) - 10))_manual)  # BusyBox fallback below
    # BusyBox-safe approach: compute seconds-ago timestamp
    local old_epoch=$(( $(date +%s) - 10 ))
    local old_time=$(date -d "@$old_epoch" +%Y%m%d%H%M.%S)
    touch -t "$old_time" "$LOCK_DIR/claude-notify-complete.lock"
    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
    grep -q "paplay" "$CALLED_LOG"
}
```

### Pattern 3: Install/Uninstall with Fixture Isolation
**What:** Copy fixture settings.json to a temp directory, set HOME to that directory so install.sh/uninstall.sh operate on the copy.
**When to use:** BASH-05~10 (install.sh and uninstall.sh tests).
**Example:**
```bash
setup() {
    CLAUDE_DIR="$(mktemp -d)"
    export HOME="$CLAUDE_DIR"  # install.sh uses $HOME/.claude
    mkdir -p "$HOME/.claude"
    cp /app/tests/fixtures/settings.json "$HOME/.claude/settings.json"
    # Copy real MP3s so install.sh finds them
    for type in complete confirm error progress; do
        cp "/app/audio/notify-${type}.mp3" "/app/audio/notify-${type}.mp3"
    done
}
teardown() {
    rm -rf "$CLAUDE_DIR"
}
```

### Pattern 4: Absolute Path Stub Problem (notify-play.sh)
**What:** notify-play.sh uses absolute paths `/usr/bin/paplay` and `/usr/bin/afplay` (lines 34, 36). PATH-based stubs will NOT intercept these calls.
**When to use:** BASH-03 (platform branch), BASH-04 (always exit 0).
**Solution:** Create stubs AT the absolute paths inside a writable overlay. The Docker volume mount (`/app`) is writable. Options:
1. Write stubs to `/usr/bin/paplay` inside the container (requires test setup to write there -- Alpine image may have read-only /usr)
2. Modify test.sh to pass `--privileged` or use a writable tmpfs overlay
3. Create a wrapper layer: write a test-specific notify-play.sh variant that uses `command paplay` instead of `/usr/bin/paplay`

**RECOMMENDATION:** The simplest approach is to check if the container's `/usr/bin` is writable. If it is, write stubs directly to `/usr/bin/paplay` in setup and restore in teardown. If not writable, the plan needs to either: (a) add `--user root` to the Docker run command in test.sh, or (b) modify notify-play.sh to use `command -v paplay` paths instead of hardcoded absolute paths (but this changes production code for testability).

### Anti-Patterns to Avoid
- **Using bats-file or bats-assert:** D-02 explicitly forbids these. Use plain bash `[ condition ]` and `grep` for assertions.
- **Shared mutable state between test files:** D-01 requires each file to be independent. No shared lock files or settings.json.
- **Using `run()` override for mocking:** D-05 explicitly forbids this. Use PATH stubs instead.
- **Relying on `touch -d` for timestamps:** BusyBox in the bats container does not support this. Always use `touch -t` with computed time.
- **Using `$BATS_RUN_TMPDIR` for test data:** This is a bats-internal directory. Use `mktemp` for test-specific temp dirs.
- **Hardcoding paths to test scripts:** The container maps repo root to `/app`. Use `/app/scripts/...` for script paths inside Docker.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test runner / TAP output | Custom exit-code checker | bats-core `run` + `$status`/`$output` | bats provides TAP output, isolation, parallel execution |
| Temp directory management | Manual mkdir/cleanup | `mktemp -d` + teardown `rm -rf` | Idempotent, no collisions, no stale dirs |
| File change detection | Custom diff | `grep` / `jq` on output files | Simpler, well-understood, no edge cases |
| JSON verification | Custom string matching | `jq` to extract and compare values | Handles whitespace, ordering, escaping correctly |
| Stub call logging | Custom IPC / named pipes | Write to `$CALLED_LOG` file | Simple, reliable, no race conditions |

**Key insight:** bats-core's built-in `run` helper, `setup`/`teardown` lifecycle, and `$status`/`$output` capture eliminate the need for any custom test infrastructure. Combined with PATH stubs and jq verification, the entire test suite uses zero hand-rolled test utilities.

## Common Pitfalls

### Pitfall 1: jq Not Installed in bats Container (CRITICAL)
**What goes wrong:** `install.sh` and `uninstall.sh` both invoke `jq`. The `bats/bats:1.11.0` Docker image is based on `bash:5.2.26-alpine3.20` and only installs `parallel` and `ncurses` via `apk`. jq is NOT installed. Tests that source or run these scripts will fail with "jq: not found".
**Why it happens:** The bats Docker image is minimal by design -- it only includes what bats-core itself needs.
**How to avoid:** Modify `test.sh` `run_bash_tests()` to install jq in the container before running tests:
```bash
run_bash_tests() {
    echo "=== bats-core tests (Docker) ==="
    docker run --rm -v "$REPO_ROOT:/app" "$BATS_IMAGE" sh -c \
        "apk add --no-cache jq > /dev/null 2>&1 && /app/tests/bash"
}
```
Or create a custom Dockerfile that extends bats/bats:1.11.0 with jq.
**Warning signs:** Any test involving install.sh or uninstall.sh fails with exit code 127 or "command not found: jq".

### Pitfall 2: `touch -d` Does Not Work on Alpine BusyBox
**What goes wrong:** CONTEXT.md says "cooldown tests use `touch -d` directly to set lock file timestamps", but BusyBox `touch` does not support the `-d` flag with date strings. It only supports `-t [[CC]YY]MMDDhhmm[.ss]` format (and `-r` for reference file).
**Why it happens:** BusyBox provides a minimal implementation of `touch` that omains GNU extensions. The bats Docker image uses Alpine which ships BusyBox.
**How to avoid:** Compute the desired timestamp using `date` and format it for `touch -t`:
```bash
# Set lock file to 10 seconds ago (BusyBox-safe)
local old_epoch=$(( $(date +%s) - 10 ))
local old_time
if date --date="@${old_epoch}" +%Y%m%d%H%M.%S >/dev/null 2>&1; then
    # GNU date (not available on Alpine, but kept as pattern)
    old_time=$(date --date="@${old_epoch}" +%Y%m%d%H%M.%S)
elif date -r "$old_epoch" +%Y%m%d%H%M.%S >/dev/null 2>&1; then
    # BSD date
    old_time=$(date -r "$old_epoch" +%Y%m%d%H%M.%S)
else
    # BusyBox date with @epoch (verify support)
    old_time=$(date -d "@${old_epoch}" +%Y%m%d%H%M.%S)
fi
touch -t "$old_time" "$LOCK_FILE"
```
**Note:** BusyBox `date -d @epoch` IS supported. The key is that `touch -d` is NOT supported, but `date -d @epoch` IS.
**Warning signs:** `touch: invalid date format` or `touch: unrecognized option: d`.

### Pitfall 3: notify-play.sh Uses Absolute Player Paths
**What goes wrong:** notify-play.sh calls `/usr/bin/paplay` and `/usr/bin/afplay` (lines 34, 36). PATH-based stubs in `tests/stubs/` will NOT intercept these calls because absolute paths bypass PATH lookup.
**Why it happens:** The script was written with hardcoded absolute paths for reliability.
**How to avoid:** Several options (see Pattern 4 above). The recommended approach is to write stubs directly to `/usr/bin/paplay` inside the container during setup, since the Docker container runs as root by default and `/usr/bin` should be writable.
**Warning signs:** Stub logs remain empty even though notify-play.sh should have called a player.

### Pitfall 4: install.sh Uses `$HOME` for CLAUDE_DIR
**What goes wrong:** install.sh hardcodes `CLAUDE_DIR="$HOME/.claude"` (line 11). In Docker, `$HOME` is `/root`. Tests that don't override `$HOME` will write to `/root/.claude`, polluting the container and making cleanup unreliable.
**Why it happens:** install.sh uses `$HOME` like a normal user-facing script would.
**How to avoid:** Override `HOME` in setup to a temp directory:
```bash
setup() {
    export HOME="$(mktemp -d)"
    mkdir -p "$HOME/.claude"
}
teardown() {
    rm -rf "$HOME"
}
```
**Warning signs:** Tests leave files in `/root/.claude` or settings.json gets corrupted between tests.

### Pitfall 5: `set -euo pipefail` Causes Silent Failures in Tests
**What goes wrong:** All 3 scripts use `set -euo pipefail`. If any command in the script fails unexpectedly, the script exits immediately with no output. In a test, this can look like the script didn't run at all.
**Why it happens:** `set -e` causes immediate exit on error. `set -u` causes exit on undefined variable.
**How to avoid:** Always use `run` to capture both status and output. Check `$status` first (expect non-zero for error cases), then inspect `$output` for error messages.
**Warning signs:** Test assertions on `$output` fail with empty string when the script exits early.

### Pitfall 6: bats Subshell Scope for Variables
**What goes wrong:** Variables set inside `run` are not visible outside. The `run` command executes in a subshell. This is standard bats behavior but can confuse developers new to the framework.
**Why it happens:** `run` uses a subshell to capture stdout/stderr and exit code.
**How to avoid:** Use `run` only for capturing script output/status. Set up environment variables (PATH, HOME, CALLED_LOG, NOTIFY_LOCK_DIR) before calling `run`, not inside it.
**Warning signs:** Variables like `$CALLED_LOG` appear empty after `run` completes.

## Code Examples

Verified patterns from official bats-core documentation and project code:

### Basic Test Structure with Setup/Teardown
```bash
#!/usr/bin/env bats
# tests/bash/notify-play.bats

setup() {
    LOCK_DIR="$(mktemp -d)"
    export NOTIFY_LOCK_DIR="$LOCK_DIR"
    export CALLED_LOG="$(mktemp)"
    export PATH="$BATS_TEST_DIRNAME/../stubs:$PATH"
}

teardown() {
    rm -rf "$LOCK_DIR"
    rm -f "$CALLED_LOG"
}

@test "cooldown skip when lock file is younger than 5 seconds" {
    touch "$LOCK_DIR/claude-notify-complete.lock"
    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
    ! grep -q "paplay" "$CALLED_LOG"
}
```

### Stub Script with Call Logging
```bash
#!/usr/bin/env bash
# tests/stubs/paplay
echo "paplay $*" >> "${CALLED_LOG:-/dev/null}"
exit 0
```

### Verify Hook Injection via jq
```bash
@test "install injects 4 hook events into settings.json" {
    setup_install_env
    run /app/scripts/install.sh
    [ "$status" -eq 0 ]

    # Verify all 4 hooks exist
    jq -e '.hooks.Stop' "$SETTINGS" >/dev/null
    jq -e '.hooks.Notification' "$SETTINGS" >/dev/null
    jq -e '.hooks.StopFailure' "$SETTINGS" >/dev/null
    jq -e '.hooks.SubagentStop' "$SETTINGS" >/dev/null

    # Verify PreToolUse hook is preserved (D-07)
    jq -e '.hooks.PreToolUse' "$SETTINGS" >/dev/null
}
```

### Prerequisite Check Failure Test
```bash
@test "install fails when jq is not found" {
    setup_install_env
    # Remove jq from PATH
    PATH_BACKUP="$PATH"
    export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v jq | tr '\n' ':')"
    run /app/scripts/install.sh
    export PATH="$PATH_BACKUP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"jq not found"* ]]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| shunit2 | bats-core | ~2015 | bats-core is now the de facto standard; active development, Docker support |
| bats 0.x `run` (no status) | bats 1.x `run` with `$status`/`$output` | bats 1.0 (2017) | Modern `run` captures exit code; no need for manual temp files |
| Inline assertion helpers | `load` for shared helpers | bats-core 1.0+ | `load` relative to test file; use `load helpers/common` |

**Deprecated/outdated:**
- bats 0.x: No longer maintained; migration guide available in bats-core docs
- shunit2: Unmaintained since 2015; no Docker support
- kcov for bash coverage: Unmaintained; listed as out of scope in REQUIREMENTS.md

## Open Questions

1. **Absolute path stubs for notify-play.sh**
   - What we know: notify-play.sh uses `/usr/bin/paplay` (absolute), PATH stubs won't intercept
   - What's unclear: Whether `/usr/bin` is writable in the bats Docker container at runtime
   - Recommendation: Plan should include a task to verify writability and write stubs to `/usr/bin/paplay` + `/usr/bin/afplay` in setup, restore originals in teardown. Fallback: modify test.sh to run container with write access.

2. **`claude` command mock for install.sh version check**
   - What we know: install.sh checks `claude --version` (lines 29-41) but only warns, doesn't exit
   - What's unclear: Whether BASH-07 needs to test the claude version check specifically, or if it's sufficient to test the hard-exit checks (jq, paplay, settings.json)
   - Recommendation: Since the version check only warns (doesn't exit 1), it's not a blocker. The `claude` command simply won't be found in the Docker container, and install.sh will print a warning but continue. BASH-07 should focus on checks that cause exit 1. Add a stub `claude` script in tests/stubs/ that prints a valid version string if needed.

## Environment Availability

> Step 2.6: SKIPPED (all testing runs inside Docker container; no host dependencies beyond Docker itself)

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | Test execution (test.sh --bash) | Depends on host | -- | N/A |
| bats/bats:1.11.0 image | bats-core runtime | Pull from Docker Hub | 1.11.0 | -- |
| jq (in container) | install.sh, uninstall.sh | NOT in image | -- | Install via `apk add jq` in test.sh |

**Missing dependencies with no fallback:**
- None (Docker can pull images; jq can be installed via apk inside container)

**Missing dependencies with fallback:**
- jq in bats container: Install via `apk add --no-cache jq` in test.sh Docker run command (see Pitfall 1)

## Validation Architecture

> SKIPPED: `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

## Sources

### Primary (HIGH confidence)
- bats-core official documentation (bats-core 1.11.0) -- `setup`/`teardown`, `run`, `$status`/`$output`, `load`
- Project source files: `scripts/notify-play.sh`, `scripts/install.sh`, `scripts/uninstall.sh`, `test.sh`
- `tests/fixtures/settings.json` -- fixture content verified by reading
- CONTEXT.md decisions (D-01 through D-09) -- locked user decisions

### Secondary (MEDIUM confidence)
- bats/bats:1.11.0 Docker image contents -- confirmed via Docker Hub layer info: Alpine 3.20, bash 5.2.26, no jq
- BusyBox `touch` man page -- `touch -t` supported, `touch -d` NOT supported on Alpine
- BusyBox `stat` -- `stat -c %Y` IS supported (confirmed from BusyBox source)

### Tertiary (LOW confidence)
- Exact writability of `/usr/bin` in bats Docker container at runtime -- needs runtime verification (marked for validation in Open Question 1)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components verified (bats image pinned, jq absence confirmed, Alpine BusyBox behavior verified)
- Architecture: HIGH - patterns are well-established bats-core conventions; 3 specific gotchas identified (absolute paths, jq, touch -d)
- Pitfalls: HIGH - all 6 pitfalls verified against source code and BusyBox documentation; solutions provided

**Research date:** 2026-03-30
**Valid until:** 30 days (stable domain; bats-core 1.11.0 is a pinned Docker image)
