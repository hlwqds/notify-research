# Phase 7: Bash 单元测试 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 7-bash
**Areas discussed:** Test structure & isolation, Mocking strategy for audio players, Install/uninstall test data, Test naming & grouping

---

## Test Structure & Isolation

| Option | Description | Selected |
|--------|-------------|----------|
| Per-file setup | Each test file sets up its own LOCK_DIR and copies fixtures. No shared state. More verbose but zero coupling. | ✓ |
| Shared load helper | setup() in a shared load helper sets common vars. DRY but shared state can cause coupling. | |
| bats-plugin ecosystem | Use bats-file or bats-support for temp dir management. Adds dependency. | |

**User's choice:** Per-file setup
**Notes:** Zero coupling between test files is worth the verbosity for 10 tests across 3 files.

## Mocking Strategy for Audio Players

| Option | Description | Selected |
|--------|-------------|----------|
| PATH stub scripts | Create stubs in tests/stubs/, prepend to PATH. Clean, visible, no external deps. | ✓ |
| bats run() override | Override run() function to intercept calls. More 'bats-native' but harder to read. | |
| No mock (Docker isolation) | Rely on Docker container having no audio. Fragile. | |

**User's choice:** PATH stub scripts
**Notes:** notify-play.sh calls `/usr/bin/paplay` with absolute path — PATH stub won't intercept absolute paths. Implementation detail: stubs need to be placed at the absolute path or tests need to verify behavior differently.

### Stub Logging

| Option | Description | Selected |
|--------|-------------|----------|
| tests/stubs/ with logging | Stubs log to CALLED_LOG env var file. Tests can verify which player was called. | ✓ |
| Silent stubs | Empty scripts that exit 0 only. | |

**User's choice:** tests/stubs/ with logging

## Install/Uninstall Test Data

| Option | Description | Selected |
|--------|-------------|----------|
| Copy real audio files + fixture settings | Copy from audio/ to temp dir. Realistic simulation. | ✓ |
| Empty stub audio files | Minimal empty mp3 stubs. | |
| Skip audio file tests | Only test hook injection/removal. | |

**User's choice:** Copy real audio files + fixture settings

## Test Naming & Grouping

| Option | Description | Selected |
|--------|-------------|----------|
| Per-script (3 files) | notify-play.bats, install.bats, uninstall.bats. 1:1 mapping. | ✓ |
| Per-behavior (6+ files) | cooldown.bats, platform.bats, hooks-inject.bats, etc. | |
| Single file | All 10 tests in one file. | |

**User's choice:** Per-script (3 files)

### Test Naming Style

| Option | Description | Selected |
|--------|-------------|----------|
| Descriptive sentences | `@test "cooldown skip when lock file < 5 seconds"`. Standard bats convention. | ✓ |
| Hierarchical with separators | `@test "notify-play::cooldown::skip::young_lock_file"`. | |

**User's choice:** Descriptive sentences

## Claude's Discretion

- Temp dir strategy (mktemp / bats TMPDIR)
- setup/teardown helper implementation
- Stub log format
- How to skip claude version check in install.sh prereq tests (may need mock `claude` command)

## Deferred Ideas

None.
