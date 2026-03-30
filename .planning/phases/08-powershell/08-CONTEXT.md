# Phase 8: PowerShell 单元测试 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Pester 测试覆盖 3 个 PowerShell 脚本全部核心逻辑：notify-play.ps1（冷却/MediaPlayer mock）、install.ps1（hook 注入/路径转换/BOM-free/幂等）、uninstall.ps1（hook 移除/空 hooks 清理/文件删除/幂等）。共 12 个测试用例（PS-01~12）。

不涉及 bash 测试（Phase 7 已完成），不涉及新功能开发。
需要小幅度重构 notify-play.ps1 以支持 MediaPlayer mock（把播放逻辑提取为独立函数）。

</domain>

<decisions>
## Implementation Decisions

### MediaPlayer Mock 策略
- **D-01:** 重构 notify-play.ps1，将 MediaPlayer 播放逻辑提取为独立函数（如 `Invoke-MediaPlayer`）。测试时通过 Pester Mock 拦截该函数，无需真实 PresentationCore 程序集。生产代码改动最小化。

### 测试隔离
- **D-02:** 在 BeforeEach 中设置 `$env:USERPROFILE = $TestTempDir`，将 `~/.claude/settings.json` 指向临时目录中的 fixture 拷贝。与 Phase 7 bash 测试中 HOME 覆盖模式一致。

### BOM-free 验证
- **D-03:** PS-07 使用字节级检查：读取文件前 3 字节，验证不等于 `0xEF 0xBB 0xBF`（UTF-8 BOM 签名）。

### 测试结构（继承 Phase 7 模式）
- **D-04:** 按被测脚本 1:1 分文件：tests/powershell/notify-play.Tests.ps1（4 tests）、install.Tests.ps1（4 tests）、uninstall.Tests.ps1（4 tests）。
- **D-05:** 不使用第三方 Pester 插件模块，纯 Pester 5.x 原生功能（Mock, BeforeEach, AfterEach, It）。
- **D-06:** 每个测试独立设置临时目录和 fixture，不共享可变状态。AfterEach 清理临时文件。

### Claude's Discretion
- 重构后的函数命名（Invoke-MediaPlayer 或其他）
- Pester Describe/Context/It 嵌套层级
- BeforeAll 中共享 fixture 拷贝 vs 每个 It 独立拷贝
- 冷却时间戳操纵的具体 PowerShell API（`(Get-Item $file).LastWriteTime = ...`）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 Requirements
- `.planning/REQUIREMENTS.md` — PS-01~12 详细定义和验收标准

### Scripts Under Test
- `scripts/notify-play.ps1` — 52 行，冷却逻辑 + MediaPlayer 播放（需重构提取播放函数）
- `scripts/install.ps1` — 145 行，前置检查 + ConvertTo-ForwardSlash + BOM-free JSON hook 注入
- `scripts/uninstall.ps1` — 59 行，hook 删除 + 空 hooks 对象清理 + mp3 删除

### Test Infrastructure (Phase 6)
- `test.sh` — 统一测试入口，`--powershell` flag 运行 Docker Pester
- `tests/fixtures/settings.json` — 含 PreToolUse hook 的假配置
- `tests/fixtures/dummy.mp3` — 最小有效 MP3

### Phase 6 Context (Carried Forward)
- `.planning/phases/06-test-infra-static-analysis/06-CONTEXT.md` — Docker 镜像 pin、volume mount 路径、NOTIFY_LOCK_DIR 机制
- `.planning/STATE.md` — v1.2 decisions: Docker Linux-only, 冷却测试用时间戳操纵

### Phase 7 Context (Pattern Reference)
- `.planning/phases/07-bash/07-CONTEXT.md` — 测试隔离模式、fixture 复用、stub 策略、幂等测试方法

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/fixtures/settings.json` — 已含 PreToolUse hook，可直接拷贝作为 install.ps1 测试目标
- `audio/notify-*.mp3` — 4 个真实 MP3 文件，install.ps1 测试需要这些文件存在
- `test.sh` line 79-81 — `docker run --rm -v "$REPO_ROOT:/app" "$PWSH_IMAGE" pwsh -Command "Invoke-Pester -Path /app/tests/powershell -Output Detailed"`

### Established Patterns
- 所有 PS 脚本使用 `$ErrorActionPreference = "Stop"`
- notify-play.ps1 使用 `$env:NOTIFY_LOCK_DIR` 覆盖 lock 路径（Phase 6 D-10）
- notify-play.ps1 使用 `New-Object System.Windows.Media.MediaPlayer` + `Add-Type -AssemblyName PresentationCore`
- install.ps1 使用 `ConvertFrom-Json` / `ConvertTo-Json -Depth 100` + `WriteAllText` (BOM-free)
- install.ps1 使用 `ConvertTo-ForwardSlash` 函数将反斜杠路径转为正斜杠
- install.ps1 接受 `-RepoPath` 参数（与 bash 脚本使用 $REPO_ROOT 不同）
- uninstall.ps1 使用 `PSObject.Properties.Remove` 删除 hook key，空对象时移除整个 hooks

### Integration Points
- test.sh `--powershell` 通过 Docker 运行 Pester：容器内 `/app` = 仓库根目录
- 容器镜像 `mcr.microsoft.com/powershell:7.4-alpine-3.20` 不包含 PresentationCore（.NET Desktop 不在 Alpine 上）
- install.ps1 使用 `$env:USERPROFILE` 定位 `~/.claude/` — 容器中不存在，测试需设置

</code_context>

<specifics>
## Specific Ideas

- 重构 notify-play.ps1 时，将第 33-47 行（Add-Type + New-Object + Play + 等待 + Close）提取为 `Invoke-MediaPlayer([string]$AudioFile)` 函数
- 冷却测试用 PowerShell 设置文件时间戳：`(Get-Item $LockFile).LastWriteTime = (Get-Date).AddSeconds(-10)`
- install.ps1 幂等测试：先运行一次 install，验证 hooks 存在；再运行一次，验证 hooks 未重复（ConvertTo-Json 后比较）
- uninstall.ps1 幂等测试：先 uninstall 清除 hooks，再 uninstall 一次，验证不报错
- BOM 检查：`[byte[]]$bytes = Get-Content -Path $file -Encoding Byte -TotalCount 3; $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 08-powershell*
*Context gathered: 2026-03-30*
