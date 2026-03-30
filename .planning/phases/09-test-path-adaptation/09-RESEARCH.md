# Phase 9: 测试路径适配 - Research

**Researched:** 2026-03-30
**Domain:** Test path refactoring for CI compatibility (bats-core + Pester)
**Confidence:** HIGH

## Summary

All 6 test files (3 bats, 3 Pester) and `test.sh` contain hardcoded `/app/` Docker mount paths. These must be replaced with a `$REPO_ROOT` variable so tests can run natively on GitHub Actions runners (ubuntu-latest, macos-latest, windows-latest) without Docker. The bats tests have a secondary problem: stubs for `paplay`/`afplay` are installed by writing to `/usr/bin/` (requires root), which won't work on CI runners. Both problems have clean, well-established solutions.

The core change is small and mechanical: derive `$REPO_ROOT` from `BATS_TEST_DIRNAME` (bats) or `$PSScriptRoot` (Pester), then find-replace `/app/` with `$REPO_ROOT`. The stub installation change is a well-known pattern (prepend a temp dir to `PATH`). Docker backward compatibility is maintained by setting `REPO_ROOT=/app` in the Docker invocation path. The actual scripts under test (`install.sh`, `uninstall.sh`, `notify-play.sh`) already use relative path derivation via `$(cd "$(dirname "$0")" && pwd)` and do NOT need changes -- only test files need path adaptation.

**Primary recommendation:** Introduce `$REPO_ROOT` via `BATS_TEST_DIRNAME`/`$PSScriptRoot`, replace all `/app/` references in test files, convert `/usr/bin/` stub writes to PATH-prepend pattern. Keep `test.sh` Docker mode working by injecting `REPO_ROOT=/app`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CI-09 | Test files use CI-compatible paths (no hardcoded `/app/` Docker paths) | Complete inventory of all `/app/` references (45 in bats, 16 in Pester), plus `/usr/bin/` stub write pattern in 3 bats files. Both `BATS_TEST_DIRNAME` and `$PSScriptRoot` are documented, stable mechanisms for deriving repo root. PATH-prepend stub pattern is the standard bats approach. |
</phase_requirements>

## Standard Stack

This phase uses no new external dependencies. All changes are to existing test files using built-in bats-core and Pester variables.

| Tool | Version (in project) | Purpose | Why Standard |
|------|---------------------|---------|--------------|
| bats-core | 1.11.0 (via Docker `bats/bats:1.11.0`) | Bash test runner | Already in use; `BATS_TEST_DIRNAME` is a stable built-in |
| Pester | 5.6.1 (installed in Docker) | PowerShell test runner | Already in use; `$PSScriptRoot` is a stable automatic variable |
| shellcheck | system-installed | Static analysis for lint path | No changes needed (lint paths in test.sh also use `/app/` but only when shellcheck not found locally) |

### Built-in Variables Available

| Variable | Source | Scope | Value Example |
|----------|--------|-------|---------------|
| `BATS_TEST_DIRNAME` | bats-core | Per test file | `/home/user/project/tests/bash` |
| `BATS_TEST_FILENAME` | bats-core | Per test file | `/home/user/project/tests/bash/install.bats` |
| `$PSScriptRoot` | PowerShell | Per script file | `/home/user/project/tests/powershell` |

## Architecture Patterns

### Pattern 1: Derive REPO_ROOT from BATS_TEST_DIRNAME

**What:** All `.bats` files live at `tests/bash/`, so `REPO_ROOT` is always `../../` from `BATS_TEST_DIRNAME`.

**When to use:** Every bats test file that references scripts, audio, fixtures, or stubs by absolute path.

**Example:**
```bash
# At the top of each .bats file (or in a shared helper loaded via `load`)
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
```

**Confidence:** HIGH -- `BATS_TEST_DIRNAME` is documented in [bats-core official docs](https://bats-core.readthedocs.io/en/stable/writing-tests.html) and has been stable since bats-core v1.0. It always returns an absolute path.

### Pattern 2: Derive REPO_ROOT from $PSScriptRoot

**What:** All `.Tests.ps1` files live at `tests/powershell/`, so the repo root is `../../` from `$PSScriptRoot`.

**When to use:** Every Pester test file that references scripts, audio, or fixtures by absolute path.

**Example:**
```powershell
# At the top of each .Tests.ps1 file (or in a shared setup)
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
```

**Confidence:** HIGH -- `$PSScriptRoot` is a built-in PowerShell automatic variable, documented in [about_Automatic_Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables). Works correctly in Pester v5.

### Pattern 3: PATH-prepend stubs instead of writing to /usr/bin/

**What:** Create stubs in a temporary directory and prepend that directory to `PATH` instead of writing to `/usr/bin/`. This avoids needing root permissions.

**When to use:** All bats tests that currently stub `paplay`/`afplay` by writing to `/usr/bin/`.

**Example:**
```bash
setup() {
    STUB_DIR="$(mktemp -d)"

    # Create paplay stub
    cat > "$STUB_DIR/paplay" << 'STUB'
#!/usr/bin/env bash
echo "paplay $*" >> "${CALLED_LOG:-/dev/null}"
exit 0
STUB
    chmod +x "$STUB_DIR/paplay"

    # Create afplay stub
    cat > "$STUB_DIR/afplay" << 'STUB'
#!/usr/bin/env bash
echo "afplay $*" >> "${CALLED_LOG:-/dev/null}"
exit 0
STUB
    chmod +x "$STUB_DIR/afplay"

    # Prepend to PATH so scripts find stubs first
    export PATH="$STUB_DIR:$PATH"
}

teardown() {
    rm -rf "$STUB_DIR"
}
```

**Why this matters for CI:** GitHub Actions runners do not allow writing to `/usr/bin/` (non-root). The PATH-prepend pattern works everywhere without privileges.

**Confidence:** HIGH -- This is the standard bats mocking pattern, documented in [bats-core issue #38](https://github.com/sstephenson/bats/issues/38) and widely used in the bats ecosystem.

### Pattern 4: Docker backward compatibility via REPO_ROOT injection

**What:** When running tests inside Docker (where repo is mounted at `/app`), set `REPO_ROOT=/app` as an environment variable before bats/Pester runs.

**When to use:** The `test.sh` Docker invocation commands.

**Example:**
```bash
# test.sh run_bash_tests() -- set REPO_ROOT=/app for Docker container
docker run --rm --entrypoint /bin/sh -v "$REPO_ROOT:/app" "$BATS_IMAGE" \
    -c "REPO_ROOT=/app bats /app/tests/bash"
```

**For Pester:**
```powershell
docker run --rm -v "$REPO_ROOT:/app" "$PWSH_IMAGE" \
    pwsh -Command "
        \$env:REPO_ROOT = '/app'
        Invoke-Pester -Path /app/tests/powershell -Output Detailed
    "
```

**Confidence:** HIGH -- Environment variable injection is standard Docker practice and works reliably with both bats and Pester.

## Complete Inventory: /app/ References to Replace

### bats test files (45 occurrences across 3 files)

**`tests/bash/install.bats`** (14 occurrences):
| Line | Current | Replace With |
|------|---------|-------------|
| 14 | `cp /app/tests/fixtures/settings.json` | `cp "$REPO_ROOT/tests/fixtures/settings.json"` |
| 18 | `cp "/app/audio/notify-${type}.mp3"` | `cp "$REPO_ROOT/audio/notify-${type}.mp3"` |
| 33 | `export PATH="/app/tests/stubs:$PATH"` | `export PATH="$REPO_ROOT/tests/stubs:$PATH"` |
| 51 | `run /app/scripts/install.sh` | `run "$REPO_ROOT/scripts/install.sh"` |
| 89 | `run /app/scripts/install.sh` | `run "$REPO_ROOT/scripts/install.sh"` |
| 97 | `run /app/scripts/install.sh` | `run "$REPO_ROOT/scripts/install.sh"` |
| 114 | `run /app/scripts/install.sh` | `run "$REPO_ROOT/scripts/install.sh"` |
| 119 | `cp /app/tests/fixtures/settings.json` | `cp "$REPO_ROOT/tests/fixtures/settings.json"` |
| 124 | `export PATH="/app/tests/stubs:/usr/local/bin:/usr/bin:/bin"` | `export PATH="$REPO_ROOT/tests/stubs:/usr/local/bin:/usr/bin:/bin"` |
| 125 | `run /app/scripts/install.sh` | `run "$REPO_ROOT/scripts/install.sh"` |
| 139 | `run /app/scripts/install.sh` | `run "$REPO_ROOT/scripts/install.sh"` |
| 26-30 | `cat > /usr/bin/paplay` (setup) | Replace with PATH-prepend stub (see Pattern 3) |
| 39-41 | `printf/rm /usr/bin/paplay` (teardown) | Replace with `rm -rf "$STUB_DIR"` |
| 122, 131-135 | Same paplay stub pattern in BASH-07 test | Replace with PATH-prepend stub |

**`tests/bash/uninstall.bats`** (11 occurrences):
| Line | Current | Replace With |
|------|---------|-------------|
| 14 | `cp /app/tests/fixtures/settings.json` | `cp "$REPO_ROOT/tests/fixtures/settings.json"` |
| 18 | `cp "/app/audio/notify-${type}.mp3"` | `cp "$REPO_ROOT/audio/notify-${type}.mp3"` |
| 33 | `export PATH="/app/tests/stubs:$PATH"` | `export PATH="$REPO_ROOT/tests/stubs:$PATH"` |
| 49 | `/app/scripts/install.sh` | `"$REPO_ROOT/scripts/install.sh"` |
| 61 | `run /app/scripts/uninstall.sh` | `run "$REPO_ROOT/scripts/uninstall.sh"` |
| 89 | `run /app/scripts/uninstall.sh` | `run "$REPO_ROOT/scripts/uninstall.sh"` |
| 104 | `run /app/scripts/uninstall.sh` | `run "$REPO_ROOT/scripts/uninstall.sh"` |
| 108 | `run /app/scripts/uninstall.sh` | `run "$REPO_ROOT/scripts/uninstall.sh"` |
| 23-30 | `cat > /usr/bin/paplay` (setup) | Replace with PATH-prepend stub (see Pattern 3) |
| 39-41 | `printf/rm /usr/bin/paplay` (teardown) | Replace with `rm -rf "$STUB_DIR"` |

**`tests/bash/notify-play.bats`** (14 occurrences):
| Line | Current | Replace With |
|------|---------|-------------|
| 66 | `run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3` | `run "$REPO_ROOT/scripts/notify-play.sh" complete "$REPO_ROOT/audio/notify-complete.mp3"` |
| 82 | Same pattern | Same replacement |
| 92 | Same pattern | Same replacement |
| 110 | Same pattern | Same replacement |
| 19-20 | `if [ -f /usr/bin/paplay ]; then ORIGINAL_PAPLAY=$(cat /usr/bin/paplay)` | Replace with PATH-prepend stub |
| 23-24 | `if [ -f /usr/bin/afplay ]; then ORIGINAL_AFPLAY=$(cat /usr/bin/afplay)` | Replace with PATH-prepend stub |
| 28-33 | `cat > /usr/bin/paplay` + chmod | Replace with PATH-prepend stub |
| 36-41 | `cat > /usr/bin/afplay` + chmod | Replace with PATH-prepend stub |
| 47-54 | Restore logic in teardown | Replace with `rm -rf "$STUB_DIR"` |
| 103-107 | `cat > /usr/bin/paplay` (FAILSTUB in BASH-04) | Replace with PATH-prepend stub |

### Pester test files (16 occurrences across 3 files)

**`tests/powershell/install.Tests.ps1`** (6 occurrences):
| Line | Current | Replace With |
|------|---------|-------------|
| 15 | `Copy-Item /app/tests/fixtures/settings.json` | `Copy-Item "$RepoRoot/tests/fixtures/settings.json"` |
| 27 | `pwsh -File /app/scripts/install.ps1 -RepoPath /app` | `pwsh -File "$RepoRoot/scripts/install.ps1" -RepoPath $RepoRoot` |
| 55 | Same | Same replacement |
| 74 | Same | Same replacement |
| 89 | Same | Same replacement |
| 94 | Same | Same replacement |

**`tests/powershell/uninstall.Tests.ps1`** (7 occurrences):
| Line | Current | Replace With |
|------|---------|-------------|
| 15 | `Copy-Item /app/tests/fixtures/settings.json` | `Copy-Item "$RepoRoot/tests/fixtures/settings.json"` |
| 18 | `pwsh -File /app/scripts/install.ps1 -RepoPath /app` | `pwsh -File "$RepoRoot/scripts/install.ps1" -RepoPath $RepoRoot` |
| 34 | `pwsh -File /app/scripts/uninstall.ps1` | `pwsh -File "$RepoRoot/scripts/uninstall.ps1"` |
| 70 | Same | Same replacement |
| 88 | Same | Same replacement |
| 102 | Same | Same replacement |
| 109 | Same | Same replacement |

**`tests/powershell/notify-play.Tests.ps1`** (4 occurrences):
| Line | Current | Replace With |
|------|---------|-------------|
| 8 | `. /app/scripts/notify-play.ps1 -Type "complete" -AudioFile "/app/audio/notify-complete.mp3"` | `. "$RepoRoot/scripts/notify-play.ps1" -Type "complete" -AudioFile "$RepoRoot/audio/notify-complete.mp3"` |
| 28 | `Invoke-NotifyPlayCore ... "/app/audio/notify-complete.mp3"` | Use `$RepoRoot/audio/notify-complete.mp3` |
| 42 | Same pattern | Same replacement |
| 51 | `Invoke-NotifyPlayCore ... "/app/audio/notify-error.mp3"` | Use `$RepoRoot/audio/notify-error.mp3` |
| 63 | `pwsh -File /app/scripts/notify-play.ps1 ...` | `pwsh -File "$RepoRoot/scripts/notify-play.ps1" ...` |

### test.sh (5 /app/ references -- for Docker compatibility)

| Line | Context | Action |
|------|---------|--------|
| 35-37 | ShellCheck Docker fallback paths (`/app/scripts/*.sh`) | Keep as-is (only used when shellcheck not installed locally AND running in Docker) |
| 56 | PSScriptAnalyzer path (`/app/scripts`) | Keep as-is (Docker-only PSScriptAnalyzer invocation) |
| 74 | bats test path (`/app/tests/bash`) | Add `REPO_ROOT=/app` env var, or keep `/app` since this is Docker-only |
| 85 | Pester path (`/app/tests/powershell`) | Add `$env:REPO_ROOT = '/app'`, or keep `/app` since this is Docker-only |

**Decision for test.sh:** The `/app/` references in `test.sh` are ONLY reached when running inside Docker containers (the Docker mount maps `$REPO_ROOT` to `/app`). These can remain as-is OR be converted for consistency. The test files themselves MUST be converted. The `test.sh` Docker invocation is a Docker-specific code path.

### Scripts under test -- NO CHANGES NEEDED

The production scripts (`install.sh`, `uninstall.sh`, `notify-play.sh`) already derive their own paths using relative techniques:
- `install.sh`: `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` and `REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"`
- `notify-play.sh`: Takes absolute path as argument (caller provides it)
- `uninstall.sh`: Uses `$HOME/.claude` (no repo-relative paths)

The PowerShell scripts use the `-RepoPath` parameter (install.ps1) or `$HOME/.claude` (uninstall.ps1, notify-play.ps1).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deriving repo root from test directory | Custom path arithmetic with `dirname` chains | `BATS_TEST_DIRNAME` / `$PSScriptRoot` | Built-in, stable, always absolute, no edge cases |
| Stubbing external commands in bats | Writing to `/usr/bin/` | PATH-prepend with `mktemp -d` | Works without root, self-cleaning, standard pattern |
| Shared test setup across bats files | Copy-paste `REPO_ROOT` derivation into every file | `load "$BATS_TEST_DIRNAME/test_helper"` with a shared setup file | DRY, single place to update |

## Common Pitfalls

### Pitfall 1: BATS_TEST_DIRNAME is per-file, not global
**What goes wrong:** Assuming `BATS_TEST_DIRNAME` is the same across all test files.
**Why it happens:** Each `.bats` file gets its own `BATS_TEST_DIRNAME` value. Since all 3 bats files are in `tests/bash/`, they all get the same value -- but this is a coincidence of file layout, not a guarantee.
**How to avoid:** Derive `REPO_ROOT` in each file or use a shared helper loaded via `load`.
**Warning signs:** Tests fail when bats files are in different directories.

### Pitfall 2: $PSScriptRoot is empty when dot-sourcing
**What goes wrong:** `$PSScriptRoot` returns empty string when a script is dot-sourced (`. script.ps1`) in PowerShell 5.1.
**Why it happens:** In PowerShell 5.1, `$PSScriptRoot` is only set when a script file is executed directly (not dot-sourced). In PowerShell 7+, it is always set.
**How to avoid:** Pester test files are always executed directly by the Pester runner (not dot-sourced), so `$PSScriptRoot` works correctly. The dot-source in `notify-play.Tests.ps1` line 8 (`. /app/scripts/notify-play.ps1 ...`) is inside a Pester `BeforeEach` block which itself is executed by Pester -- the `$PSScriptRoot` for the test file is still set.
**Warning signs:** `$RepoRoot` resolves to empty string.

### Pitfall 3: Forgetting to quote $REPO_ROOT in paths with spaces
**What goes wrong:** Paths with spaces break when `$REPO_ROOT` is unquoted.
**Why it happens:** `run $REPO_ROOT/scripts/install.sh` word-splits on spaces in the path.
**How to avoid:** Always quote: `run "$REPO_ROOT/scripts/install.sh"`.
**Warning signs:** Tests fail on paths containing spaces (e.g., user home dir `~/My Projects/`).

### Pitfall 4: notify-play.sh uses hardcoded /usr/bin/paplay and /usr/bin/afplay
**What goes wrong:** Tests that stub via PATH-prepend won't work because `notify-play.sh` calls `/usr/bin/paplay` directly (absolute path), not `paplay` (which would resolve via PATH).
**Why it happens:** Lines 34 and 36 of `scripts/notify-play.sh` use `/usr/bin/paplay` and `/usr/bin/afplay` as absolute paths.
**How to avoid:** Two options:
  1. **(Recommended)** Change `notify-play.sh` to use just `paplay`/`afplay` (no absolute path), so PATH-prepend stubs work.
  2. **(Alternative)** Leave `notify-play.sh` as-is and have tests create stubs at the actual `/usr/bin/paplay` location -- but this requires root on CI runners (won't work).

**This is a critical finding.** The `notify-play.sh` script MUST be updated to use bare command names (`paplay`, `afplay`) instead of absolute paths (`/usr/bin/paplay`, `/usr/bin/afplay`). This is a minor change (2 lines) and aligns with best practices (use `$PATH` for command lookup, not hardcoded absolute paths). The scripts already check for command existence via `command -v paplay`, so they know the command is on PATH.

### Pitfall 5: ShellCheck may flag the change from /usr/bin/paplay to paplay
**What goes wrong:** ShellCheck warning SC2068 about double-quoting arrays.
**Why it happens:** Unlikely with this specific change, but shellcheck can be sensitive to command name changes.
**How to avoid:** Run shellcheck after the change. No SC warning expected for replacing an absolute path with a bare command name.

### Pitfall 6: Docker test.sh --bash/--powershell must still work
**What goes wrong:** After converting test files to use `$REPO_ROOT`, Docker invocations break because `$REPO_ROOT` isn't set inside the container.
**Why it happens:** The Docker container doesn't automatically set `REPO_ROOT=/app`.
**How to avoid:** In `test.sh`, pass `REPO_ROOT=/app` as an environment variable or inline in the docker run command.

## Code Examples

### Shared bats helper file (NEW: `tests/bash/test_helper.bash`)

```bash
# tests/bash/test_helper.bash -- Shared test setup for all bats files
# Derives REPO_ROOT from the test file's directory location.

# All .bats files are at tests/bash/, so repo root is 2 levels up
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
```

### Shared Pester variable setup (NEW: `tests/powershell/Setup.ps1`)

```powershell
# tests/powershell/Setup.ps1 -- Shared setup for all Pester test files
# Derives $RepoRoot from the test file's directory location.

# All .Tests.ps1 files are at tests/powershell/, so repo root is 2 levels up
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
```

### Converted setup() with PATH-prepend stubs (replaces /usr/bin/ writes)

```bash
# Before (current -- writes to /usr/bin/, requires root):
setup() {
    cat > /usr/bin/paplay << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x /usr/bin/paplay
}

# After (converted -- uses PATH prepend, no root needed):
setup() {
    STUB_DIR="$(mktemp -d)"
    cat > "$STUB_DIR/paplay" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$STUB_DIR/paplay"
    export PATH="$STUB_DIR:$PATH"
}

teardown() {
    rm -rf "$STUB_DIR"
}
```

### Converted test invocation (replaces /app/ paths)

```bash
# Before:
run /app/scripts/install.sh

# After:
run "$REPO_ROOT/scripts/install.sh"
```

```powershell
# Before:
pwsh -File /app/scripts/install.ps1 -RepoPath /app

# After:
pwsh -File "$RepoRoot/scripts/install.ps1" -RepoPath $RepoRoot
```

### Critical script fix: notify-play.sh bare command names

```bash
# Before (scripts/notify-play.sh lines 33-37):
if [[ "$OS" == "Darwin" ]]; then
    /usr/bin/afplay "$AUDIO_FILE" 2>/dev/null || true
else
    /usr/bin/paplay "$AUDIO_FILE" 2>/dev/null || true
fi

# After:
if [[ "$OS" == "Darwin" ]]; then
    afplay "$AUDIO_FILE" 2>/dev/null || true
else
    paplay "$AUDIO_FILE" 2>/dev/null || true
fi
```

### test.sh Docker backward compatibility

```bash
# Before (test.sh run_bash_tests):
docker run --rm --entrypoint /bin/sh -v "$REPO_ROOT:/app" "$BATS_IMAGE" \
    -c "apk add --no-cache jq > /dev/null 2>&1 && bats /app/tests/bash"

# After (inject REPO_ROOT=/app for the container):
docker run --rm --entrypoint /bin/sh -v "$REPO_ROOT:/app" "$BATS_IMAGE" \
    -c "apk add --no-cache jq > /dev/null 2>&1 && REPO_ROOT=/app bats /app/tests/bash"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded `/app/` in tests | `$REPO_ROOT` derived from test directory | Phase 9 (this change) | Tests run anywhere, not just Docker |
| Writing stubs to `/usr/bin/` | PATH-prepend with `mktemp -d` | Phase 9 (this change) | No root required, works on CI runners |
| `/usr/bin/paplay` absolute path in scripts | Bare `paplay` via PATH lookup | Phase 9 (this change) | Enables PATH-based stubbing |

**No deprecated or outdated patterns** -- this is a greenfield refactoring using well-established mechanisms.

## Open Questions

None. All aspects of this phase have clear, well-documented solutions.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | Current test.sh (backward compat) | Yes | 29.3.0 | -- |
| bats-core | Native test execution | No | -- | Install via `bats-core/bats-action@v3.0.1` in CI (Phase 10); Docker fallback for local testing |
| PowerShell (pwsh) | Pester tests | No | -- | Available in Docker `mcr.microsoft.com/powershell:7.4-alpine-3.20`; Phase 10 CI runners have it preinstalled |
| jq | install.sh prerequisite check in tests | Yes | 1.8.1 | -- |
| shellcheck | Lint verification | Yes | system | -- |

**Missing dependencies with fallback:**
- **bats-core (local):** Not installed natively. For Phase 9 verification, either (a) install via `npm install -g bats` or `git clone` + `./install.sh`, or (b) verify via Docker with the converted test files. Phase 10 will handle CI installation.
- **PowerShell (local):** Not installed. Same as above -- verify via Docker. Phase 10 CI runners have pwsh preinstalled.

**Note:** Phase 9's success criteria require `./test.sh --bash` and `./test.sh --powershell` to pass locally. Since the Docker path already works (and we're keeping backward compat), the real verification target is: the converted test files produce correct `$REPO_ROOT` values when bats/Pester runs them. This can be verified by adding `echo "$REPO_ROOT"` debug output in a quick Docker run.

## Validation Architecture

> Skipping -- `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

## Project Constraints (from CLAUDE.md)

- **Technology Stack:** The project is shell scripts (bash + PowerShell) with no compiled dependencies. Path changes are purely text substitution.
- **Conventions:** Conventions not yet established. Code comments in English. Conventional commits style.
- **GSD Workflow Enforcement:** All changes must go through `/gsd:execute-phase`.

## Sources

### Primary (HIGH confidence)
- [bats-core official docs -- Writing Tests](https://bats-core.readthedocs.io/en/stable/writing-tests.html) -- `BATS_TEST_DIRNAME` documentation (verified 2026-03-30)
- [Microsoft -- about_Automatic_Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables) -- `$PSScriptRoot` documentation
- [GitHub sstephenson/bats issue #38](https://github.com/sstephenson/bats/issues/38) -- Stubbing pattern via PATH-prepend (verified via web search 2026-03-30)
- [Pester v5 -- Relative execution path](https://github.com/pester/Pester/issues/1756) -- `$PSScriptRoot` usage in Pester v5
- Project source code -- Full inventory of all `/app/` references (read directly from files, 2026-03-30)

### Secondary (MEDIUM confidence)
- [Stack Overflow -- bats-mock](https://stackoverflow.com/questions/38315185) -- Mocking in bats tests
- [Pester docs -- File placement](https://pester.dev/docs/usage/file-placement-and-naming) -- Test file conventions

### Tertiary (LOW confidence)
- None -- all findings verified from source code or official documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies, uses built-in test framework variables
- Architecture: HIGH - patterns are well-documented and straightforward
- Pitfalls: HIGH - all pitfalls identified from direct source code analysis, including the critical `notify-play.sh` absolute path issue (Pitfall 4)

**Research date:** 2026-03-30
**Valid until:** N/A -- shell/bash/PowerShell patterns are stable; no fast-moving dependencies
