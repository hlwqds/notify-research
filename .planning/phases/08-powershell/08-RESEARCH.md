# Phase 8: PowerShell 单元测试 - Research

**Researched:** 2026-03-30
**Domain:** Pester 5.x testing for PowerShell scripts in Docker (Alpine Linux)
**Confidence:** HIGH

## Summary

Phase 8 requires 12 Pester tests (PS-01 through PS-12) covering three PowerShell scripts: notify-play.ps1 (cooldown + MediaPlayer playback), install.ps1 (hook injection + BOM-free JSON), and uninstall.ps1 (hook removal + file cleanup). Tests run inside a Docker container using `mcr.microsoft.com/powershell:7.4-alpine-3.20`, which does NOT have Pester pre-installed -- this is the most critical infrastructure gap to address.

The key technical challenge is mocking MediaPlayer (D-01): the scripts use `New-Object System.Windows.Media.MediaPlayer` which requires `PresentationCore` assembly, unavailable on Alpine Linux. The agreed solution is to extract the MediaPlayer playback logic into a wrapper function (`Invoke-MediaPlayer`), then Pester-Mock that function. This is a well-established pattern with HIGH confidence. A minor production code refactor of notify-play.ps1 is required before tests can be written.

**Primary recommendation:** Refactor notify-play.ps1 to extract `Invoke-MediaPlayer` function, install Pester inside the Docker container in test.sh, and follow the 1:1 file mapping pattern (3 test files mirroring 3 scripts) matching the Phase 7 bash test structure.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 重构 notify-play.ps1，将 MediaPlayer 播放逻辑提取为独立函数（如 `Invoke-MediaPlayer`）。测试时通过 Pester Mock 拦截该函数，无需真实 PresentationCore 程序集。生产代码改动最小化。

- **D-02:** 在 BeforeEach 中设置 `$env:USERPROFILE = $TestTempDir`，将 `~/.claude/settings.json` 指向临时目录中的 fixture 拷贝。与 Phase 7 bash 测试中 HOME 覆盖模式一致。

- **D-03:** PS-07 使用字节级检查：读取文件前 3 字节，验证不等于 `0xEF 0xBB 0xBF`（UTF-8 BOM 签名）。

- **D-04:** 按被测脚本 1:1 分文件：tests/powershell/notify-play.Tests.ps1（4 tests）、install.Tests.ps1（4 tests）、uninstall.Tests.ps1（4 tests）。

- **D-05:** 不使用第三方 Pester 插件模块，纯 Pester 5.x 原生功能（Mock, BeforeEach, AfterEach, It）。

- **D-06:** 每个测试独立设置临时目录和 fixture，不共享可变状态。AfterEach 清理临时文件。

### Claude's Discretion

- 重构后的函数命名（Invoke-MediaPlayer 或其他）
- Pester Describe/Context/It 嵌套层级
- BeforeAll 中共享 fixture 拷贝 vs 每个 It 独立拷贝
- 冷却时间戳操纵的具体 PowerShell API（`(Get-Item $file).LastWriteTime = ...`）

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PS-01 | notify-play.ps1 冷却跳过（lock file < 5 秒） | Cooldown logic at lines 21-28; use `Set-Content` to create recent lock file, then verify MediaPlayer NOT called via `Should -Invoke -CommandName Invoke-MediaPlayer -Times 0` |
| PS-02 | notify-play.ps1 冷却通过（lock file 旧于 5 秒） | Manipulate `LastWriteTime` via `(Get-Item $lockFile).LastWriteTime = (Get-Date).AddSeconds(-10)`, verify MediaPlayer called |
| PS-03 | notify-play.ps1 MediaPlayer mock（不调用真实音频） | Pester Mock of `Invoke-MediaPlayer` wrapper function; `Should -Invoke` to verify call with correct `$AudioFile` parameter |
| PS-04 | notify-play.ps1 始终 exit 0 | Run via `pwsh -File` in sub-process, check `$LASTEXITCODE`; mock `Invoke-MediaPlayer` to throw, verify exit 0 |
| PS-05 | install.ps1 4 个 hook 事件注入且 shell 为 powershell | Parse output settings.json with `ConvertFrom-Json`, verify 4 event keys exist, verify `shell` property equals `"powershell"` |
| PS-06 | install.ps1 forward-slash 路径转换 | Check `command` field in injected hooks contains forward slashes only; no backslash characters |
| PS-07 | install.ps1 BOM-free JSON 输出 | Read first 3 bytes via `[System.IO.File]::ReadAllBytes()`, verify not equal to `0xEF, 0xBB, 0xBF` |
| PS-08 | install.ps1 幂等重跑 | Run install twice, compare `ConvertTo-Json -Depth 100` output (use `-Sort` or property-by-property comparison) |
| PS-09 | uninstall.ps1 4 个 hook 事件移除 | After uninstall, verify Stop/Notification/StopFailure/SubagentStop keys absent; PreToolUse preserved |
| PS-10 | uninstall.ps1 空 hooks 对象清理 | When only notification hooks exist (plus PreToolUse), after removing 4 notification hooks the hooks object should still exist (because PreToolUse remains) |
| PS-11 | uninstall.ps1 mp3 文件删除 | After uninstall, verify all 4 mp3 files absent from `$env:USERPROFILE/.claude/` |
| PS-12 | uninstall.ps1 幂等重跑 | Run uninstall twice; second run should not error, output should be clean |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Pester | 5.x (latest stable) | PowerShell testing framework | De facto standard for PowerShell testing; provides Mock, Should, BeforeEach/AfterAll |
| PowerShell | 7.4 (Alpine) | Runtime for tests | Pinned in STATE.md; `mcr.microsoft.com/powershell:7.4-alpine-3.20` |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Docker | 24.x+ | Test isolation | test.sh runs Pester inside pwsh container |
| `[System.IO.File]::ReadAllBytes()` | .NET built-in | BOM detection (PS-07) | Byte-level file inspection |
| `[System.Text.UTF8Encoding]::new($false)` | .NET built-in | BOM-free verification reference | Scripts already use this for writing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pester Mock of wrapper function | New-MockObject | Requires PresentationCore assembly loaded -- not available on Alpine. Wrapper pattern is the only viable approach |
| `pwsh -File script.ps1` invocation | Dot-source `. script.ps1` | Dot-source brings script into test scope enabling direct Mock; `-File` runs in child process (can't intercept Mocks). Use dot-source for unit tests, `-File` only for PS-04 exit code check |

**Installation (in Docker):**
```powershell
Install-Module -Name Pester -Force -Scope CurrentUser -AllowPrerelease
```
Note: On Alpine pwsh, `CurrentUser` scope maps to `~/.local/share/powershell/Modules/`. The `-AllowPrerelease` flag is only needed if targeting Pester 6.x beta. For Pester 5.x stable, omit it.

**Pester availability:** NOT pre-installed in `mcr.microsoft.com/powershell:7.4-alpine-3.20`. The `run_powershell_tests()` function in test.sh (line 79-81) calls `Invoke-Pester` without first installing the module. This MUST be fixed before tests can run. See Pitfall 1.

## Architecture Patterns

### Recommended Project Structure
```
tests/powershell/
  notify-play.Tests.ps1     # PS-01~04: cooldown, MediaPlayer mock, exit code
  install.Tests.ps1         # PS-05~08: hook injection, forward-slash, BOM-free, idempotent
  uninstall.Tests.ps1       # PS-09~12: hook removal, empty hooks cleanup, file deletion, idempotent
```

### Pattern 1: Invoke-MediaPlayer Wrapper Extraction (D-01)
**What:** Extract lines 33-47 of notify-play.ps1 into a standalone function. Tests Mock this function instead of trying to intercept `New-Object` or `Add-Type`.
**When to use:** Required for PS-01, PS-02, PS-03 -- any test that needs to verify or suppress audio playback.
**Why this works:** Pester Mock works on function names within the session scope. By calling `Invoke-MediaPlayer $AudioFile` instead of inline MediaPlayer code, Pester can intercept the call with `Mock Invoke-MediaPlayer {}`. `New-Object` and `Add-Type` are cmdlets/language constructs that cannot be reliably mocked.
**Confidence:** HIGH -- standard Pester pattern for wrapping untestable .NET calls.

```powershell
# notify-play.ps1 refactored structure:
function Invoke-MediaPlayer([string]$AudioFile) {
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([System.Uri]::new($AudioFile))
    Start-Sleep -Milliseconds 500
    $player.Play()
    while ($player.NaturalDuration.HasTimeSpan -and $player.Position -lt $player.NaturalDuration.TimeSpan) {
        Start-Sleep -Milliseconds 100
    }
    $player.Close()
}

# In try block, replace lines 33-47 with:
Invoke-MediaPlayer -AudioFile $AudioFile
```

### Pattern 2: Dot-Source + Mock Scope Pattern
**What:** Dot-source the script under test inside the Pester `It` block (or `BeforeEach`) so that its functions enter the current scope where Pester Mocks are active.
**When to use:** For tests that need to Mock functions defined by the script (PS-01~03).
**Critical detail:** Pester 5 Mocks are scope-bound. The script must be dot-sourced AFTER the Mock is defined, not before. For scripts using `param()`, dot-sourcing will bind the parameters to actual arguments.

```powershell
Describe "notify-play.ps1" {
    BeforeEach {
        # Set up isolation
        $TestDir = New-TemporaryDirectory  # or mktemp equivalent
        $env:NOTIFY_LOCK_DIR = $TestDir

        # Define mock BEFORE dot-sourcing
        Mock Invoke-MediaPlayer {}
    }

    It "skips playback within cooldown window" {
        # Create recent lock file
        $lockFile = Join-Path $env:NOTIFY_LOCK_DIR "claude-notify-complete.lock"
        Set-Content -Path $lockFile -Value (Get-Date).ToString() -NoNewline

        # Dot-source the script (params will prompt for values, so invoke differently)
        . /app/scripts/notify-play.ps1 -Type "complete" -AudioFile "/app/audio/notify-complete.mp3"

        Should -Invoke Invoke-MediaPlayer -Times 0 -Exactly
    }
}
```

**Caution:** Scripts with `param()` blocks can be tricky to dot-source. An alternative is to use `& /app/scripts/notify-play.ps1 -Type ... -AudioFile ...` for PS-04 (exit code test) and use a helper function approach for PS-01~03 where the script's main logic is wrapped in a testable function.

### Pattern 3: Temp Directory Isolation (D-02, D-06)
**What:** Each test creates a temporary directory, sets `$env:USERPROFILE` to it, copies fixture `settings.json` there, and cleans up in `AfterEach`.
**When to use:** All install.ps1 and uninstall.ps1 tests.
**Pattern from Phase 7 bash tests:** `mktemp -d` + `cp fixtures/settings.json` + cleanup in teardown.

```powershell
BeforeEach {
    $TestHome = Join-Path ([System.IO.Path]::GetTempPath()) "pester-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $TestHome -Force | Out-Null
    $env:USERPROFILE = $TestHome

    $claudeDir = Join-Path $TestHome ".claude"
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    Copy-Item /app/tests/fixtures/settings.json (Join-Path $claudeDir "settings.json")

    # Copy mp3 files for install.ps1 tests
    foreach ($type in @("complete", "confirm", "error", "progress")) {
        Copy-Item "/app/audio/notify-${type}.mp3" (Join-Path $claudeDir "notify-${type}.mp3")
    }
}

AfterEach {
    Remove-Item -Path $TestHome -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue
}
```

### Pattern 4: BOM-Free Verification (D-03)
**What:** Read the first 3 bytes of a file and verify they are not the UTF-8 BOM signature.
**When to use:** PS-07.

```powershell
It "writes settings.json without UTF-8 BOM" {
    # ... run install.ps1 ...

    $settingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
    $bytes = [System.IO.File]::ReadAllBytes($settingsPath)

    if ($bytes.Length -ge 3) {
        $bytes[0] | Should -Not -Be 0xEF -Because "First byte should not be UTF-8 BOM marker"
        $bytes[1] | Should -Not -Be 0xBB -Because "Second byte should not be UTF-8 BOM marker"
        $bytes[2] | Should -Not -Be 0xBF -Because "Third byte should not be UTF-8 BOM marker"
    }
}
```

### Pattern 5: Idempotency Verification (PS-08)
**What:** Run install twice, compare JSON output.
**When to use:** PS-08 (install idempotency), PS-12 (uninstall idempotency).
**Approach:** `ConvertTo-Json -Depth 100` after each run. Since install.ps1 uses `-Force` on `Add-Member`, the second run overwrites the same keys. Compare the two JSON strings for equality.

```powershell
It "is idempotent — running twice produces same settings" {
    $settingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

    # First run
    & /app/scripts/install.ps1 -RepoPath /app
    $firstJson = (Get-Content $settingsPath -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 100)

    # Second run
    & /app/scripts/install.ps1 -RepoPath /app
    $secondJson = (Get-Content $settingsPath -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 100)

    $firstJson | Should -Be $secondJson
}
```

**Note on JSON ordering:** `ConvertTo-Json` in PowerShell 7 outputs properties in the order they were added. Since install.ps1 uses `Add-Member -Force` to overwrite the same 4 keys, the property order should be consistent across runs. If ordering is unreliable, sort keys manually before comparison or compare property-by-property.

### Pattern 6: Cooldown Timestamp Manipulation
**What:** Set a file's `LastWriteTime` to the past to bypass the cooldown check.
**When to use:** PS-02.

```powershell
It "plays audio when lock file is older than cooldown" {
    $lockFile = Join-Path $env:NOTIFY_LOCK_DIR "claude-notify-complete.lock"
    Set-Content -Path $lockFile -Value "old" -NoNewline

    # Set mtime to 10 seconds ago
    (Get-Item $lockFile).LastWriteTime = (Get-Date).AddSeconds(-10)

    # ... run notify-play.ps1 ...
    Should -Invoke Invoke-MediaPlayer -Times 1 -Exactly
}
```

### Anti-Patterns to Avoid

- **Mocking `New-Object` directly:** Pester cannot reliably mock `New-Object` because it is a language keyword, not a function. Multiple GitHub issues confirm this does not work. Use wrapper function (D-01) instead.
- **Using `Set-Content` to write JSON in tests:** `Set-Content` in PowerShell defaults to UTF-8 with BOM. If tests need to create JSON files, use `[System.IO.File]::WriteAllText()` to match production behavior.
- **Using `Should -Invoke -Times N` without `-Exactly`:** Without `-Exactly`, `-Times N` means "at least N times", not "exactly N times". Always add `-Exactly` for precise verification.
- **Dot-sourcing scripts that call `exit`:** `exit` inside a dot-sourced script will terminate the entire PowerShell session, not just the script. For PS-04 (exit code test), use `& pwsh -File script.ps1` (child process invocation) and check `$LASTEXITCODE`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test framework | Custom assertion logic | Pester 5.x `Should` assertions | Pester provides `Should -Be`, `Should -Invoke`, `Should -Not -Contain`, etc. -- battle-tested |
| Mock system | Manual function overriding / script injection | Pester `Mock` command | Handles scope, call recording, parameter matching, call counting |
| Temp directory management | Manual mkdir + variable tracking | Pester `BeforeEach`/`AfterEach` with `New-TemporaryFile` or `mktemp` | Standard cleanup pattern |
| JSON comparison | Manual string comparison | `ConvertTo-Json -Depth 100` | Handles nested objects, consistent serialization |
| BOM detection | Regex on text content | `[System.IO.File]::ReadAllBytes()` | BOM is binary, text-mode reading may normalize it away |

**Key insight:** Pester is mature and handles all testing concerns natively. The only thing requiring custom work is the `Invoke-MediaPlayer` wrapper function in notify-play.ps1 (D-01).

## Common Pitfalls

### Pitfall 1: Pester NOT Pre-Installed in Docker Image (CRITICAL)
**What goes wrong:** `test.sh --powershell` (line 79-81) runs `Invoke-Pester` without installing the module first. The `mcr.microsoft.com/powershell:7.4-alpine-3.20` image does NOT include Pester.
**Why it happens:** The `run_powershell_tests()` function was written in Phase 6 as a stub. PSScriptAnalyzer in `run_lint()` correctly installs itself before use (lines 51-53), but `run_powershell_tests()` was not updated to match.
**How to avoid:** Update `run_powershell_tests()` in test.sh to install Pester before invoking it, matching the PSScriptAnalyzer pattern:
```bash
docker run --rm -v "$REPO_ROOT:/app" "$PWSH_IMAGE" \
    pwsh -Command "
        if (-not (Get-Module -ListAvailable -Name Pester)) {
            Install-Module -Name Pester -Force -Scope CurrentUser
        }
        Import-Module Pester
        Invoke-Pester -Path /app/tests/powershell -Output Detailed
    "
```
**Warning signs:** `Invoke-Pester: The term 'Invoke-Pester' is not recognized` when running `test.sh --powershell`.

### Pitfall 2: `exit` in Dot-Sourced Script Kills Test Runner
**What goes wrong:** If notify-play.ps1 is dot-sourced and reaches `exit 0` (line 52), it terminates the entire Pester test run, not just the test.
**Why it happens:** Dot-sourcing (`.` operator) runs script code in the caller's scope. `exit` is session-scoped in PowerShell.
**How to avoid:** For PS-04 (exit code test), invoke the script as a child process: `& pwsh -File /app/scripts/notify-play.ps1 -Type X -AudioFile Y`, then check `$LASTEXITCODE`. For PS-01~03, either (a) wrap the script's main logic in a function and call that function (not the whole script), or (b) use `Mock` on the wrapper function and avoid dot-sourcing the full script.

**Recommended approach for notify-play.ps1 tests:**
- Refactor: Extract cooldown check logic into a testable function (e.g., `Test-Cooldown` or keep it inline since it only reads files).
- For PS-01~03: The cooldown logic is straightforward file I/O. Test it by setting up lock files and checking that `Invoke-MediaPlayer` is or isn't called. The main consideration is how to invoke the script. Two options:
  1. **Dot-source + remove `exit`:** Remove the bare `exit 0` from the script, replace with `return` (function-compatible). This is a small production change.
  2. **Child process + separate verification:** Run via `pwsh -File` and check side effects (lock file updated, CALLED_LOG approach from bash tests).

Option 1 is cleaner for unit testing. The `exit 0` at line 52 exists because hooks block on non-zero exit -- but when dot-sourced, `return` achieves the same effect without killing the session.

### Pitfall 3: PowerShell `ConvertTo-Json` Property Ordering
**What goes wrong:** `ConvertTo-Json` does not guarantee alphabetical property ordering. Running install.ps1 twice may produce JSON with properties in different order, causing string comparison to fail.
**Why it happens:** PowerShell serializes PSCustomObject properties in insertion order. Since install.ps1 iterates over a hashtable (`$events`), the order depends on .NET hashtable enumeration order (which is not guaranteed to be stable).
**How to avoid:** For idempotency testing (PS-08), either:
1. Parse both JSONs with `ConvertFrom-Json` and compare properties programmatically
2. Use `ConvertTo-Json -Depth 100 | Sort-Object` on individual lines (fragile for nested JSON)
3. Compare specific properties rather than full JSON strings

The most robust approach is to compare the JSON objects property by property, not as strings.

### Pitfall 4: `$env:USERPROFILE` Not Set in Alpine Docker Container
**What goes wrong:** install.ps1 and uninstall.ps1 use `$env:USERPROFILE` to locate `~/.claude/settings.json`. In the Alpine pwsh Docker container, `$env:USERPROFILE` may be unset or point to a non-existent directory.
**Why it happens:** Alpine Linux does not have Windows-style user profiles. PowerShell on Linux uses `$env:HOME` by default, but the scripts explicitly reference `$env:USERPROFILE`.
**How to avoid:** D-02 already addresses this: set `$env:USERPROFILE = $TestTempDir` in `BeforeEach`. Verify that the container does not have a conflicting `USERPROFILE` env var by default (it does not -- verified from STATE.md accumulated context).

### Pitfall 5: install.ps1 `-RepoPath` Validation Checks
**What goes wrong:** install.ps1 performs prerequisite checks (lines 22-68): settings.json existence, notify-play.ps1 existence, audio directory existence, individual mp3 file checks. If the test environment doesn't set these up correctly, install.ps1 will `exit 1` before reaching the hook injection logic.
**Why it happens:** The tests need a realistic environment where all prerequisites are met.
**How to avoid:** In `BeforeEach`, ensure:
- `$env:USERPROFILE/.claude/settings.json` exists (copy from fixture)
- `/app/scripts/notify-play.ps1` exists (already in repo, mounted at `/app`)
- `/app/audio/` directory with 4 mp3 files exists (already in repo, mounted at `/app`)
- `claude` command is available or its absence only produces a warning (lines 22-41 use `Write-Warning`, not `exit 1`)

The bash tests (Phase 7) solved this by adding `/app/tests/stubs` to PATH. PowerShell tests need a similar approach: either create a `claude` stub in PATH or ensure the script's `Get-Command "claude"` check gracefully handles absence.

## Code Examples

Verified patterns from official sources:

### Pester Mock of Wrapper Function
```powershell
# Source: Pester docs - Usage/Mocking (pester.dev/docs/usage/mocking)
BeforeDiscovery { }

Describe "MediaPlayer invocation" {
    BeforeEach {
        Mock Invoke-MediaPlayer {} -ModuleName "notify-play"
    }

    It "calls Invoke-MediaPlayer when cooldown passes" {
        # ... set up old lock file ...
        . /app/scripts/notify-play.ps1 -Type "complete" -AudioFile "/app/audio/notify-complete.mp3"
        Should -Invoke Invoke-MediaPlayer -Times 1 -Exactly
    }
}
```

**Note on `-ModuleName`:** When mocking functions in dot-sourced scripts (not modules), `-ModuleName` is not applicable. Mock the function directly by name after dot-sourcing. If the script is not dot-sourced (child process invocation), Mocks won't work at all -- use side-effect verification instead (e.g., check if a log file was written, similar to bash `$CALLED_LOG` pattern).

### Should -Invoke Verification
```powershell
# Source: Pester docs - Usage/Mocking (pester.dev/docs/usage/mocking)
Should -Invoke Invoke-MediaPlayer -Times 1 -Exactly
Should -Invoke Invoke-MediaPlayer -Times 0 -Exactly  # verify NOT called
Should -Invoke Invoke-MediaPlayer -ParameterFilter { $AudioFile -like "*complete*" }
```

### BOM Detection (D-03)
```powershell
# Source: CONTEXT.md D-03 specification
$bytes = [System.IO.File]::ReadAllBytes($settingsPath)
$bomPresent = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$bomPresent | Should -BeFalse -Because "settings.json should be written without UTF-8 BOM"
```

### Cooldown Timestamp Manipulation
```powershell
# Source: CONTEXT.md Claude's Discretion, Phase 7 pattern (busybox touch equivalent)
$lockFile = Join-Path $env:NOTIFY_LOCK_DIR "claude-notify-complete.lock"
Set-Content -Path $lockFile -Value "old" -NoNewline
(Get-Item $lockFile).LastWriteTime = (Get-Date).AddSeconds(-10)
```

### PS-04 Exit Code Test (Child Process Pattern)
```powershell
# For testing exit code -- cannot use dot-source (exit kills session)
It "always exits 0 even when playback fails" {
    # Run as child process
    $result = & pwsh -File /app/scripts/notify-play.ps1 -Type "complete" -AudioFile "/nonexistent/file.mp3"
    $LASTEXITCODE | Should -Be 0
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pester 4.x `Assert-MockCalled` | Pester 5.x `Should -Invoke` | Pester 5.0 (2020) | All test assertions use `Should -Invoke` syntax |
| Pester 3.x `Setup`/`Teardown` | Pester 5.x `BeforeAll`/`BeforeEach`/`AfterAll`/`AfterEach` | Pester 5.0 (2020) | Block-scoped lifecycle hooks |
| `Mock -CommandName X -ModuleName Y` (modules only) | Wrapper function pattern (for scripts) | Always | Scripts without module export cannot be mocked by module name |

**Deprecated/outdated:**
- Pester 4.x syntax (`Assert-MockCalled`, `Should Be`, `Set-TestInconclusive`): Pester 5.x uses `Should -Invoke`, `Should -Be`, `Set-ItResult -Inconclusive`. Tests should use Pester 5.x syntax exclusively.

## Open Questions

1. **notify-play.ps1 dot-source compatibility with `param()` block**
   - What we know: Scripts with `param()` can be dot-sourced, and the parameters will be bound from the calling scope's arguments (or prompted interactively).
   - What's unclear: Whether dot-sourcing a `param()` script inside a Pester `It` block will silently bind or throw if called without explicit arguments.
   - Recommendation: Test this in the plan phase. If problematic, wrap the script's main body in a function (e.g., `Invoke-NotifyPlay -Type $Type -AudioFile $AudioFile`) and call that function from the test, keeping the `param()` + script body as the entry point for production use.

2. **Pester version pinning in Docker**
   - What we know: `Install-Module -Name Pester -Force` installs latest stable. Pester 6.x is in beta.
   - What's unclear: Whether Pester 6.x beta has breaking changes that affect our patterns.
   - Recommendation: Pin to Pester 5.x explicitly: `Install-Module -Name Pester -RequiredVersion 5.6.1 -Force -Scope CurrentUser` (or whatever the latest 5.x version is at plan time). Avoid `-AllowPrerelease` to prevent pulling Pester 6 beta.

3. **JSON property ordering for PS-08 idempotency test**
   - What we know: `ConvertTo-Json` uses insertion order for PSCustomObject properties. install.ps1 iterates a hashtable which has non-deterministic enumeration order in .NET.
   - What's unclear: Whether PowerShell 7.4 on Alpine preserves hashtable enumeration order consistently across multiple runs of the same script.
   - Recommendation: Use property-by-property comparison rather than full JSON string comparison for the idempotency test. Or sort JSON keys programmatically before comparing.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | test.sh container execution | Needs verification | -- | -- |
| `mcr.microsoft.com/powershell:7.4-alpine-3.20` | Pester test runtime | Pre-pulled (Phase 6) | 7.4 | -- |
| Pester module | All 12 PS tests | NOT pre-installed in Docker image | -- | Install via `Install-Module` in test.sh |
| Audio files (`audio/*.mp3`) | install.ps1 tests (PS-05~08) | Yes (in repo) | -- | -- |
| Fixture `settings.json` | install/uninstall tests | Yes (in repo) | -- | -- |

**Missing dependencies with no fallback:**
- Docker runtime (cannot verify during research -- was unavailable when probed). If Docker is unavailable, tests cannot run. The planner should verify Docker availability at plan time.

**Missing dependencies with fallback:**
- Pester module: Must be installed in test.sh before `Invoke-Pester`. Add `Install-Module -Name Pester -Force -Scope CurrentUser` before the `Invoke-Pester` call in `run_powershell_tests()`.

## Sources

### Primary (HIGH confidence)
- Pester official docs (pester.dev/docs/usage/mocking) -- Mock, Should-Invoke syntax, scope behavior
- Pester official docs (pester.dev/docs/commands/Should-Invoke) -- verification patterns
- CONTEXT.md D-01~D-06 -- locked decisions
- scripts/notify-play.ps1, install.ps1, uninstall.ps1 -- source code under test
- Phase 7 bash tests (tests/bash/*.bats) -- pattern reference for test isolation, idempotency, cooldown manipulation
- STATE.md -- accumulated decisions (Docker Linux-only, pwsh image pin, NOTIFY_LOCK_DIR)

### Secondary (MEDIUM confidence)
- Pester GitHub issues -- New-Object mock limitations, dot-source scope behavior
- PowerShell `ConvertTo-Json` documentation -- property ordering behavior
- `.NET System.IO.File` docs -- ReadAllBytes for BOM detection

### Tertiary (LOW confidence)
- Pester Docker compatibility reports -- no specific issues found for Alpine Linux
- PSScriptAnalyzer Docker installation pattern (from test.sh line 51-53) -- validates the Install-Module pattern works in Alpine pwsh container

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Pester 5.x is well-documented, patterns verified against official docs
- Architecture: HIGH - wrapper function pattern is standard practice, verified against multiple sources
- Pitfalls: HIGH - Docker Pester gap is certain (confirmed by code inspection), exit-in-dot-source is well-known

**Research date:** 2026-03-30
**Valid until:** 30 days (Pester 5.x is stable, PowerShell 7.4 LTS)
