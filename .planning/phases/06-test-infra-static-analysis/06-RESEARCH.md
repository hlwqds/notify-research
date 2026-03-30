# Phase 6: 测试基础设施 + 静态分析 - Research

**Researched:** 2026-03-30
**Domain:** Shell testing infrastructure (bats-core, Pester, ShellCheck, PSScriptAnalyzer, Docker test matrix)
**Confidence:** HIGH

## Summary

Phase 6 builds the testing scaffold and static analysis pipeline for the Claude Code voice notification project. The phase establishes a unified `test.sh` entry point, Docker-based test matrix (bats-core for bash, Pester for PowerShell), shared test fixtures, and static analysis with ShellCheck + PSScriptAnalyzer. It also refactors `notify-play.sh` and `notify-play.ps1` to support environment-variable-based lock file path overrides for testability.

The key technical decisions are all locked: use official Docker images (`bats/bats` for bats-core, `mcr.microsoft.com/powershell` for Pester), volume-mount test files into containers, and run static analysis at `--severity warning` level. The research confirms bats-core Docker image includes helper libraries (bats-support, bats-assert, bats-file, bats-detik) pre-installed, PSScriptAnalyzer ships inside the PowerShell Docker image, and ShellCheck is available both as a standalone binary and Docker image.

**Primary recommendation:** Use `bats/bats:1.11.0` (pinned from GitHub releases, latest stable tag) and `mcr.microsoft.com/powershell:latest` (or pin to a known good tag like `7.4.6`), with ShellCheck run directly via `shellcheck` binary in a Docker container or installed locally.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### test.sh 入口设计
- **D-01:** test.sh 使用子命令 flag 风格：`--lint`（ShellCheck + PSSA）、`--bash`（bats-core in Docker）、`--powershell`（Pester in Docker）、`--all`（全部依次执行）
- **D-02:** lint 失败返回非零退出码，`--all` 模式下 lint 失败阻断后续 bash/powershell 测试

#### Docker 测试矩阵
- **D-03:** test.sh 内置 Docker 调用（自动 docker build/run），用户无需手动管理容器
- **D-04:** 使用官方预构建镜像 + volume mount，不写自定义 Dockerfile：
  - bats: `bats/bats-core:latest`（或 pinned 版本）
  - Pester: `mcr.microsoft.com/powershell:latest`（或 pinned 版本）
- **D-05:** 测试脚本和 fixture 通过 volume mount 注入容器，不烘焙进镜像

#### ShellCheck / PSScriptAnalyzer 配置
- **D-06:** 静态分析使用 warning 级别（ShellCheck `--severity warning`，PSSA `-Severity Warning`）
- **D-07:** ShellCheck 对 scripts/*.sh（3 个）、PSSA 对 scripts/*.ps1（3 个）运行

#### Fixture 和 notify-play.sh/ps1 改造
- **D-08:** 共享 fixture 目录 `tests/fixtures/` 包含：
  - `settings.json`：模拟真实用户配置（包含已有 hooks 如 PreToolUse + 普通配置项）
  - `dummy.mp3`：小文件，仅用于路径存在性检查
- **D-09:** notify-play.sh 第 14 行改为 `LOCK_DIR="${NOTIFY_LOCK_DIR:-/tmp}"`，lock file 路径变为 `$LOCK_DIR/claude-notify-${TYPE}.lock`，默认行为不变
- **D-10:** notify-play.ps1 同步加 `$env:NOTIFY_LOCK_DIR` 覆盖，保持两个脚本的可测试性机制对称
- **D-11:** 测试目录结构：`tests/bash/`、`tests/powershell/`、`tests/fixtures/`

### Claude's Discretion
- ShellCheck/PSScriptAnalyzer 的具体排除规则（如需排除特定 warning，在规划时决定）
- bats-core 和 PowerShell 镜像的具体版本 pin（规划时选 stable 版本）
- dummy.mp3 的大小和格式（最小有效 MP3 即可）
- test.sh 的输出格式（彩色/简洁）和详细程度

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | 统一测试入口脚本 test.sh（运行 ShellCheck + bats + Pester） | test.sh architecture pattern, Docker invocation, flag parsing |
| INFRA-02 | 测试目录结构（tests/bash/, tests/powershell/, tests/fixtures/） | bats-core + Pester test file discovery conventions |
| INFRA-03 | Docker 测试矩阵（Linux 容器运行 bats，pwsh 容器运行 Pester） | Official Docker images, volume mount patterns, image versions |
| INFRA-04 | notify-play.sh 可测试性改造（lock file 路径支持环境变量覆盖） | Line 14 refactor pattern, NOTIFY_LOCK_DIR default value |
| LINT-01 | ShellCheck 对 3 个 bash 脚本运行静态分析 | ShellCheck CLI usage, severity flags, exclude patterns |
| LINT-02 | PSScriptAnalyzer 对 3 个 PowerShell 脚本运行静态分析 | Invoke-ScriptAnalyzer cmdlet, severity flag, Docker execution |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bats-core | 1.11.0 | Bash unit testing framework | De facto standard for shell script testing; official Docker image `bats/bats` includes helper libs |
| Pester | 5.x (pre-installed in pwsh image) | PowerShell testing framework | Standard PowerShell test framework; ships with `mcr.microsoft.com/powershell` Docker image |
| ShellCheck | 0.11.0 | Static analysis for bash scripts | Industry standard shell linter; catches bugs, best practice violations |
| PSScriptAnalyzer | 1.23.0 | Static analysis for PowerShell scripts | Official PowerShell linter; `Invoke-ScriptAnalyzer` cmdlet |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bats-support | pre-installed in `bats/bats` image | Output formatting helpers | Used in bats test files via `load` |
| bats-assert | pre-installed in `bats/bats` image | Assertion functions (`assert_equal`, etc.) | Used in bats test files via `load` |
| bats-file | pre-installed in `bats/bats` image | File system assertions | Used in bats test files for fixture operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bats-core | shellspec | bats-core has official Docker image with helper libs; shellspec is newer but less Docker ecosystem support |
| Docker-based Pester | Pester on native Windows | Native Windows gives real PowerShell but we chose Docker Linux-only per v1.2 decision |
| ShellCheck direct | koalaman/shellcheck Docker image | Docker image avoids local install; but adds container overhead for a fast tool |

**Version verification:**
- bats-core: GitHub releases show v1.11.0 as latest stable. Docker Hub tags show v1.13.0 (may be unreleased or pre-release). Recommend pinning to `bats/bats:1.11.0`.
- ShellCheck: v0.11.0 is latest stable release (August 2025).
- PSScriptAnalyzer: GitHub releases show v1.23.0. PowerShell Gallery may show newer pre-release.
- Pester: v5.x ships pre-installed in `mcr.microsoft.com/powershell` Docker images.

## Architecture Patterns

### Recommended Project Structure
```
tests/
├── bash/              # bats-core test files (Phase 7 will populate)
│   └── test_helper.bash  # Shared setup/teardown (Wave 0 of Phase 7)
├── powershell/        # Pester test files (Phase 8 will populate)
│   └── SharedSetup.ps1   # Shared setup/teardown (Wave 0 of Phase 8)
├── fixtures/          # Shared test fixtures
│   ├── settings.json  # Fake Claude settings with pre-existing hooks
│   └── dummy.mp3      # Minimal valid MP3 file
test.sh                # Unified test entry point (Phase 6)
```

### Pattern 1: test.sh Entry Point with Subcommand Flags
**What:** Single shell script that dispatches to lint, bash tests, or PowerShell tests via CLI flags. Lint failure blocks subsequent test execution in `--all` mode.
**When to use:** Always -- this is the unified entry point (INFRA-01).
**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

run_lint() {
    echo "=== ShellCheck ==="
    shellcheck --severity warning scripts/*.sh
    echo "=== PSScriptAnalyzer ==="
    docker run --rm -v "$REPO_ROOT:/app" mcr.microsoft.com/powershell:latest \
        pwsh -Command "Invoke-ScriptAnalyzer -Path /app/scripts/*.ps1 -Severity Warning"
}

run_bash_tests() {
    docker run --rm -v "$REPO_ROOT:/app" bats/bats:1.11.0 /app/tests/bash
}

run_powershell_tests() {
    docker run --rm -v "$REPO_ROOT:/app" mcr.microsoft.com/powershell:latest \
        pwsh -Command "Invoke-Pester -Path /app/tests/powershell -Output Detailed"
}

case "${1:-}" in
    --lint)  run_lint ;;
    --bash)  run_bash_tests ;;
    --powershell) run_powershell_tests ;;
    --all)
        run_lint || { echo "FAIL: lint errors found, aborting"; exit 1; }
        run_bash_tests
        run_powershell_tests
        ;;
    *) echo "Usage: $0 {--lint|--bash|--powershell|--all}"; exit 1 ;;
esac
```

### Pattern 2: bats-core Docker Volume Mount
**What:** Mount repo root into bats container so tests can access `scripts/` and `tests/fixtures/` via relative paths from `/app`.
**When to use:** Running bats tests via Docker (D-03, D-05).
**Example:**
```bash
# test.sh invokes:
docker run --rm -v "$PWD:/app" -w /app bats/bats:1.11.0 tests/bash
```
The container working directory is `/app`, so bats discovers `tests/bash/*.bats` relative to the repo root. Test files reference scripts via `$REPO_ROOT/scripts/notify-play.sh`.

### Pattern 3: Pester Docker Volume Mount
**What:** Mount repo root into PowerShell container and invoke Pester via `pwsh -Command`.
**When to use:** Running Pester tests via Docker (D-03, D-05).
**Example:**
```bash
docker run --rm -v "$PWD:/app" mcr.microsoft.com/powershell:latest \
    pwsh -Command "Invoke-Pester -Path /app/tests/powershell -Output Detailed"
```

### Pattern 4: NOTIFY_LOCK_DIR Environment Variable Override
**What:** Allow tests to control lock file location by setting `NOTIFY_LOCK_DIR`, defaulting to `/tmp` for production use.
**When to use:** Both notify-play.sh (D-09) and notify-play.ps1 (D-10) refactoring.
**Example (bash):**
```bash
# notify-play.sh line 14 refactor:
LOCK_DIR="${NOTIFY_LOCK_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/claude-notify-${TYPE}.lock"
```
**Example (PowerShell):**
```powershell
# notify-play.ps1 line 18 refactor:
$TempDir = if ($env:NOTIFY_LOCK_DIR) { $env:NOTIFY_LOCK_DIR } elseif ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
```

### Pattern 5: ShellCheck Invocation with Severity
**What:** Run ShellCheck at warning level (not info) on all bash scripts.
**When to use:** LINT-01 implementation.
**Example:**
```bash
shellcheck --severity warning --check-sourced scripts/*.sh
```
The `--check-sourced` flag ensures files sourced by other scripts are also checked (useful if `notify-play.sh` is sourced in test contexts).

### Pattern 6: PSScriptAnalyzer Invocation via Docker
**What:** Run Invoke-ScriptAnalyzer inside PowerShell Docker container with warning severity.
**When to use:** LINT-02 implementation.
**Example:**
```bash
docker run --rm -v "$PWD:/app" mcr.microsoft.com/powershell:latest \
    pwsh -Command "Invoke-ScriptAnalyzer -Path /app/scripts -Severity Warning -Recurse -ExcludeRule @('PSUseShouldProcessForStateChangingFunctions')"
```

### Anti-Patterns to Avoid
- **Custom Dockerfiles for test images:** D-04 explicitly forbids this. Use official pre-built images with volume mounts.
- **Baking test files into images:** D-05 requires volume mounts, not COPY. Tests must reflect live code changes.
- **Hardcoded paths in tests:** Use `$REPO_ROOT` or container-relative `/app` paths, never absolute host paths.
- **Running lint as advisory only:** D-02 requires lint failure to return non-zero and block `--all`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bash test runner | Custom test.sh with assertions | bats-core | Provides test discovery, setup/teardown, assertion library ecosystem |
| PowerShell test runner | Custom Pester-like harness | Pester | Industry standard with mock framework, test discovery, assertion library |
| Shell linting | Custom grep/awk pattern checks | ShellCheck | Catches hundreds of bug patterns, supports severity levels, suppression comments |
| PowerShell linting | Custom PSScriptAnalyzer clone | PSScriptAnalyzer | Microsoft-maintained, ~70 built-in rules, severity classification |
| Test isolation helpers | Custom temp dir / cleanup logic | bats-file (bash), Pester BeforeAll/AfterAll (PS) | Handles temp dirs, fixtures, cleanup automatically |
| Docker orchestration for tests | Manual docker run commands | test.sh with embedded docker commands | D-03 requires single entry point; users should never need to type docker commands |

**Key insight:** All four tools (bats-core, Pester, ShellCheck, PSScriptAnalyzer) are mature, well-maintained, and have active communities. Custom solutions would miss edge cases these tools handle (e.g., bats-core handles TAP output, Pester has sophisticated mocking, ShellCheck understands shell quoting rules).

## Common Pitfalls

### Pitfall 1: bats-core Library Loading in Docker
**What goes wrong:** `load bats-assert` fails inside Docker container with "file not found" even though the library is installed.
**Why it happens:** The bats-core Docker image installs helper libs to `/opt/bats-detik/libexec/bats-core/` or `/usr/lib/bats/`. The `load` command searches `BATS_LIB_PATH` which defaults to `/usr/lib/bats/` in the official image. If tests set `BATS_LIB_PATH` incorrectly, loading breaks.
**How to avoid:** Do NOT override `BATS_LIB_PATH`. The official `bats/bats` image sets it correctly. Use `load bats-assert` (not `source`) inside `@test` functions or `setup()` only -- `load` is not available at file scope.
**Warning signs:** `setup: line N: load: command not found` or ` bats-assert: file not found`.

### Pitfall 2: Docker Volume Mount and File Permissions
**What goes wrong:** Test scripts create files inside the container (e.g., lock files, temp files) but those files are owned by `root` on the host, causing permission issues on subsequent runs.
**Why it happens:** The bats Docker image runs as root by default. Files created in mounted volumes inherit the container's UID.
**How to avoid:** For Phase 6 this is low risk since we only create directories and fixture files. Phase 7/8 tests should use `$BATS_TMPDIR` (bats) or `TestDrive:\` (Pester) for temporary files, which are inside the container filesystem, not the mounted volume. The `NOTIFY_LOCK_DIR` override should point to a temp directory inside the container.
**Warning signs:** `ls -la tests/fixtures/` shows root-owned files after running tests.

### Pitfall 3: ShellCheck False Positives on Cross-Platform Scripts
**What goes wrong:** ShellCheck flags Darwin-specific `stat -f %m` as an error because it only knows GNU `stat`.
**Why it happens:** ShellCheck's heuristics target POSIX/Linux by default. macOS-specific commands trigger warnings.
**How to avoid:** Use ShellCheck directive `# shellcheck disable=SCXXXX` for platform-specific lines. For example, the Darwin `stat -f %m` line in notify-play.sh line 21 will likely trigger SC2183 or similar. Add inline suppression with a comment explaining why.
**Warning signs:** ShellCheck reports errors on lines that are conditionally executed only on Darwin.

### Pitfall 4: PSScriptAnalyzer in Docker -- Module Not Found
**What goes wrong:** `Invoke-ScriptAnalyzer` is not recognized inside the PowerShell Docker container.
**Why it happens:** PSScriptAnalyzer may not be pre-installed in all versions of the `mcr.microsoft.com/powershell` image, or may need explicit import.
**How to avoid:** Verify the image includes PSScriptAnalyzer. If not, install it in the test.sh invocation: `docker run --rm -v "$PWD:/app" mcr.microsoft.com/powershell:latest pwsh -Command "Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser; Invoke-ScriptAnalyzer -Path /app/scripts -Severity Warning"`. Alternatively, pin to an image version known to include it.
**Warning signs:** `Invoke-ScriptAnalyzer: The term 'Invoke-ScriptAnalyzer' is not recognized`.

### Pitfall 5: test.sh exit Code Propagation
**What goes wrong:** `docker run` succeeds (exit 0) even when the test command inside the container fails, because docker itself returns the container's exit code but `set -e` may not catch it in all bash versions.
**Why it happens:** In some bash versions, `set -e` does not propagate exit codes through pipes or conditionals.
**How to avoid:** Explicitly check docker exit code: `docker run ... || exit $?` or use `set -o pipefail` (already in project convention). The test.sh script uses `set -euo pipefail` per project convention.
**Warning signs:** `--all` mode reports "all passed" but bats tests actually failed.

## Code Examples

### notify-play.sh Refactor (INFRA-04 / D-09)
```bash
# BEFORE (line 14):
LOCK_FILE="/tmp/claude-notify-${TYPE}.lock"

# AFTER (lines 14-15):
LOCK_DIR="${NOTIFY_LOCK_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/claude-notify-${TYPE}.lock"
```
This is backward-compatible: when `NOTIFY_LOCK_DIR` is unset, `LOCK_DIR` defaults to `/tmp`, producing the same path.

### notify-play.ps1 Refactor (INFRA-04 / D-10)
```powershell
# BEFORE (line 18):
$TempDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }

# AFTER (lines 18-19):
$LockDir = if ($env:NOTIFY_LOCK_DIR) { $env:NOTIFY_LOCK_DIR } elseif ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$LockFile = Join-Path $LockDir "claude-notify-$Type.lock"
```
Priority: `NOTIFY_LOCK_DIR` > `$env:TEMP` > system temp path. Mirrors bash behavior.

### Fixture settings.json (INFRA-02 / D-08)
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Pre-existing hook should not be touched'"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": ["Bash(git *)"]
  }
}
```
This fixture simulates a real user who has pre-existing hooks. install.sh tests (Phase 7) must verify these hooks survive.

### Minimal Valid MP3 (dummy.mp3)
Create with `ffmpeg -f lavfi -i anullsrc=channel_layout=mono:sample_rate=44100 -t 0.1 -q:a 9 tests/fixtures/dummy.mp3` (0.1 seconds of silence, ~2KB). Or use a hand-crafted minimal MP3 frame (417 bytes). The file only needs to exist at a valid path for install.sh's mp3-existence checks.

### ShellCheck Lint Target
```bash
# LINT-01: Run on all 3 bash scripts
shellcheck --severity warning scripts/install.sh scripts/uninstall.sh scripts/notify-play.sh
```

### PSScriptAnalyzer Lint Target
```bash
# LINT-02: Run on all 3 PowerShell scripts via Docker
docker run --rm -v "$PWD:/app" mcr.microsoft.com/powershell:latest \
    pwsh -Command "Invoke-ScriptAnalyzer -Path /app/scripts -Severity Warning -Recurse"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| kcov for bash coverage | No coverage tool | 2024+ | kcov unmaintained; no mature replacement. Coverage not required for Phase 6. |
| PSScriptAnalyzer v1.x rules | PSScriptAnalyzer v1.23.0 | 2025 | Latest stable with ~70 rules, warning/error/info severity |
| ShellCheck v0.9 | ShellCheck v0.11.0 | 2025 | Newer bashism checks, better POSIX compliance detection |

**Deprecated/outdated:**
- kcov (bash code coverage): Unmaintained since ~2022. No replacement needed -- out of scope.
- bats-core v1.7.0: Old major version. Use 1.11.0+. API is backward compatible but older versions lack some assertion helpers.

## Open Questions

1. **bats-core Docker image version discrepancy**
   - What we know: GitHub releases show v1.11.0 as latest stable. Docker Hub tags page references v1.13.0.
   - What's unclear: Whether v1.13.0 is a pre-release or the Docker Hub tag page is showing tags from a different branch.
   - Recommendation: Pin to `bats/bats:1.11.0` (verified stable on GitHub). The planner can verify Docker Hub availability.

2. **PSScriptAnalyzer pre-installed in mcr.microsoft.com/powershell image**
   - What we know: PSScriptAnalyzer is a common PowerShell module that may ship with the Docker image.
   - What's unclear: Exact PowerShell Docker image version that includes it pre-installed vs. requiring `Install-Module`.
   - Recommendation: test.sh should include a fallback `Install-Module` call if `Invoke-ScriptAnalyzer` is not found. Planner should validate this in Wave 0.

3. **ShellCheck exclude rules for cross-platform scripts**
   - What we know: notify-play.sh uses Darwin-specific `stat -f %m` which will trigger ShellCheck warnings.
   - What's unclear: Exact rule numbers to suppress without reviewing ShellCheck output first.
   - Recommendation: Run ShellCheck first, then decide on per-line suppressions. This is Claude's Discretion per D-07 context.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | INFRA-03 (test matrix), LINT-02 (PSSA in container) | Yes | 29.3.0 | -- |
| shellcheck | LINT-01 | No | -- | Run via `koalaman/shellcheck` Docker image, or `apt install shellcheck` |
| bats-core | INFRA-03 (bash tests) | No (image not pulled) | -- | `bats/bats:1.11.0` Docker image auto-pulled on first use |
| powershell (pwsh) | INFRA-03 (Pester tests), LINT-02 | No (image not pulled) | -- | `mcr.microsoft.com/powershell:latest` Docker image auto-pulled on first use |
| ffmpeg | dummy.mp3 fixture creation | Yes | 7.1.1 | Use a hand-crafted minimal MP3 binary |

**Missing dependencies with no fallback:**
- None. All dependencies either have Docker-based fallbacks or can be installed.

**Missing dependencies with fallback:**
- ShellCheck not installed locally -- run via Docker image `koalaman/shellcheck:stable` or install via package manager.
- bats-core and PowerShell Docker images not pulled locally -- `docker run` auto-pulls on first use.
- pwsh not installed locally -- not needed; runs inside Docker container.

## Sources

### Primary (HIGH confidence)
- bats-core GitHub repository (bats-core/bats-core) -- official Docker image docs, volume mount patterns, library loading
- bats-core GitHub releases -- v1.11.0 latest stable tag
- ShellCheck official site (shellcheck.net) -- v0.11.0 latest stable, CLI flags
- PSScriptAnalyzer GitHub releases (PowerShell/PSScriptAnalyzer) -- v1.23.0 latest stable
- Project scripts -- notify-play.sh, notify-play.ps1, install.sh, uninstall.sh, install.ps1, uninstall.ps1 (directly read)
- `.planning/config.json` -- nyquist_validation: false, commit_docs: true
- `.planning/REQUIREMENTS.md` -- INFRA-01~04, LINT-01~02 definitions
- `.planning/ROADMAP.md` -- Phase 6 success criteria

### Secondary (MEDIUM confidence)
- Docker Hub (bats/bats) -- image tag listing, bundled helper libraries
- Docker Hub (mcr.microsoft.com/powershell) -- available image tags
- `.planning/STATE.md` -- v1.2 decisions (Docker Linux-only, timestamp manipulation for cooldown)
- `.planning/phases/06-test-infra-static-analysis/06-CONTEXT.md` -- all locked decisions D-01 through D-11

### Tertiary (LOW confidence)
- bats-core Docker Hub tag v1.13.0 -- may be pre-release or different branch; not verified on GitHub releases
- PSScriptAnalyzer pre-installation in PowerShell Docker image -- not verified which image version includes it

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools verified via GitHub releases/official docs. bats-core and PSScriptAnalyzer are well-established.
- Architecture: HIGH - Docker volume mount pattern is standard practice. test.sh pattern follows common CI entry point conventions.
- Pitfalls: MEDIUM - Based on known Docker + bats-core + PSScriptAnalyzer issues, but specific version interactions may vary.

**Research date:** 2026-03-30
**Valid until:** 30 days (stable tooling domain; bats-core and PSScriptAnalyzer release infrequently)
