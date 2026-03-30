# Phase 5: Windows 兼容 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Windows 用户通过 PowerShell 脚本实现一键安装和语音通知播放。新建 3 个 PowerShell 脚本（notify-play.ps1, install.ps1, uninstall.ps1），功能与现有 bash 脚本对等：复制 mp3 到 ~/.claude/、注入 hooks 到 settings.json、5 秒冷却防抖播放。

Windows 使用独立的 PowerShell 脚本，不修改现有 bash 脚本。

</domain>

<decisions>
## Implementation Decisions

### PowerShell 版本兼容
- **D-01:** 最低兼容 PowerShell 5.1（Windows 10/11 内置），不要求安装 PowerShell 7+

### 音频播放方式
- **D-02:** 使用 System.Windows.Media.MediaPlayer (.NET) 播放 MP3，通过 Add-Type 加载 PresentationCore assembly
- **D-03:** 保留 5 秒冷却防抖机制，用 $env:TEMP\claude-notify-{type}.lock 文件 + 时间戳比较，与 Linux/macOS 一致

### Settings.json 操作
- **D-04:** 使用 PowerShell 原生 JSON cmdlet（ConvertFrom-Json / ConvertTo-Json -Depth 100），用 [System.IO.File]::WriteAllText() 写入避免 BOM 问题
- **D-05:** Hook command 中路径全部使用正斜杠（按 #26759 workaround），例如 C:/Users/name/.claude/notify-complete.mp3

### 安装路径与结构
- **D-06:** PowerShell 脚本放在 scripts/ 目录，与 bash 脚本并列
- **D-07:** Windows 上使用 $env:USERPROFILE\.claude\ 作为 Claude 配置目录
- **D-08:** install.ps1 需要用户通过参数指定仓库路径（或 notify-play.ps1 位置），不假设仓库路径
- **D-09:** mp3 文件从本地仓库的 audio/ 目录复制，用户需先克隆仓库

### Claude's Discretion
- install.ps1 参数设计（-RepoPath 还是 -ScriptPath，默认值等）
- MediaPlayer 的 Add-Type 加载方式和错误处理
- uninstall.ps1 是否需要额外清理（如 $env:TEMP 下的 lock 文件）
- PowerShell 脚本的错误输出格式（Write-Warning / Write-Error）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Scripts (bash equivalents)
- `scripts/install.sh` — Hook 注入模式、jq 命令结构、事件映射、prerequisite 检查
- `scripts/uninstall.sh` — Hook 移除模式、幂等清理
- `scripts/notify-play.sh` — 冷却防抖逻辑（LOCK_FILE + COOLDOWN_SEC + stat 时间戳）

### Audio Files
- `audio/notify-complete.mp3`, `audio/notify-confirm.mp3`, `audio/notify-error.mp3`, `audio/notify-progress.mp3` — 4 个预生成 MP3 文件

### Requirements
- `.planning/REQUIREMENTS.md` — WIN-01 through WIN-06（6 条 Windows 需求）

### Known Constraints (STATE.md Blockers)
- PowerShell 5.1 Set-Content -Encoding UTF8 写入带 BOM 的 UTF-8 — 用 [System.IO.File]::WriteAllText() 规避
- GitHub issue #26759 — Windows hook command 路径必须用正斜杠
- GitHub issue #29560 — Windows Desktop App 可能不执行 hooks（不稳定）

### Phase 4 Context (prior decisions)
- `.planning/phases/04-macos/04-CONTEXT.md` — 跨平台架构决策：bash 覆盖 Linux+macOS，Windows 独立使用 PowerShell

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `install.sh` 的 jq 注入逻辑：4 种事件（Stop/Notification/StopFailure/SubagentStop）映射到 4 个 mp3 文件，async:true, timeout:10 — PowerShell 版需完全复刻此映射
- `install.sh` 的 prerequisite 检查模式：Claude Code 版本 >= 2.1.78、settings.json 存在、播放器可用 — PowerShell 版需对应实现
- `notify-play.sh` 的冷却逻辑：LOCK_FILE 时间戳比较，COOLDOWN_SEC=5 — PowerShell 版用 $env:TEMP 替代 /tmp
- 4 个预生成 mp3 文件：已提交到仓库，Windows 直接复制使用

### Established Patterns
- `set -euo pipefail` 严格模式 — PowerShell 对应 Set-StrictMode + $ErrorActionPreference = "Stop"
- jq 幂等操作 settings.json — PowerShell 用 ConvertFrom-Json / ConvertTo-Json 替代
- 临时文件 + trap 清理 — PowerShell 用 try/finally 替代
- 脚本始终 exit 0（hook 不阻塞）— PowerShell 版必须确保异常不产生非零退出码

### Integration Points
- install.ps1 注入的 hook command 需包含 `"shell": "powershell"` 标记
- hook command 格式：`powershell -File C:/path/to/notify-play.ps1 complete C:/Users/name/.claude/notify-complete.mp3`
- mp3 复制目标：$env:USERPROFILE\.claude\

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 05-windows*
*Context gathered: 2026-03-30*
