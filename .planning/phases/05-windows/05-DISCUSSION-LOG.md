# Phase 5: Windows 兼容 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 5-Windows 兼容
**Areas discussed:** PowerShell 版本兼容, 音频播放方式, Settings.json 操作, 安装路径与结构

---

## PowerShell 版本兼容

| Option | Description | Selected |
|--------|-------------|----------|
| 5.1 最低兼容（推荐） | 覆盖最广泛的用户群（Windows 10/11 内置），无需安装。MediaPlayer 需要加载 PresentationCore assembly，ConvertTo-Json 需要注意 BOM 和 Depth 问题。 | ✓ |
| PowerShell 7+ LTS | 更现代的语法和更好的 JSON 处理，但需要用户额外安装 pwsh 7。JSON cmdlet 无 BOM 问题，但原生 Windows 10/11 无此版本。 | |
| 检测并回退 | 优先检测 pwsh 7，回退到 PowerShell 5.1。覆盖最广但代码复杂度高，需要两套 JSON 处理逻辑。 | |

**User's choice:** 5.1 最低兼容
**Notes:** 覆盖最广，无需额外安装。

---

## 音频播放方式

### 播放器选择

| Option | Description | Selected |
|--------|-------------|----------|
| MediaPlayer (.NET)（推荐） | 加载 System.Windows.Media.MediaPlayer (.NET) 播放 MP3。已有研究资料，无窗口弹出，代码轻量。需要 Add-Type 加载 PresentationCore。 | ✓ |
| WMPlayer COM | 启动 wmplayer.exe /close /play 播放。成熟稳定但可能短暂闪窗，且需处理进程关闭。社区常用但体验不够干净。 | |
| SoundPlayer + WAV | Media.SoundPlayer 只支持 WAV，需要 ffmpeg 转 WAV 或预生成 WAV。增加复杂度，但 .NET 2.0+ 都可用。 | |

**User's choice:** MediaPlayer (.NET)

### 冷却防抖

| Option | Description | Selected |
|--------|-------------|----------|
| 保留 5 秒冷却（推荐） | 和 Linux/macOS 一致，防止快速连续事件重复播放。用 $env:TEMP\claude-notify-{type}.lock 文件 + 时间戳比较。 | ✓ |
| 不需要冷却 | MediaPlayer.Play() 本身不会叠加播放（同一文件不会同时播放两次），可以不用冷却机制。但不同文件仍可能叠加。 | |

**User's choice:** 保留 5 秒冷却
**Notes:** 与 Linux/macOS 行为保持一致。

---

## Settings.json 操作

### JSON 操作方式

| Option | Description | Selected |
|--------|-------------|----------|
| PowerShell 原生 JSON cmdlet（推荐） | 内置 cmdlet，无需安装依赖。但 PS 5.1 的 Set-Content -Encoding UTF8 会写 BOM，需要用 [System.IO.File]::WriteAllText() 避免。ConvertTo-Json -Depth 100 防止截断。 | ✓ |
| 调用 jq.exe | 用和 bash 一样的 jq.exe 处理 JSON。逻辑一致，但需要用户安装 jq.exe。REQUIREMENTS.md 标记 Out of Scope。 | |
| .NET JSON 库 | 用 .NET System.Text.Json 或 Newtonsoft.Json。功能强但增加代码量，且 PS 5.1 无内置 System.Text.Json。 | |

**User's choice:** PowerShell 原生 JSON cmdlet

### 路径格式

| Option | Description | Selected |
|--------|-------------|----------|
| 正斜杠（推荐） | 按 #26759 的 workaround，hook command 中的路径全部使用正斜杠。例如 C:/Users/name/.claude/notify-complete.mp3。可避免 Windows hook 执行问题。 | ✓ |
| 反斜杠（自然路径） | 用 Join-Path 生成自然路径。但可能触发 #26759 bug。 | |

**User's choice:** 正斜杠
**Notes:** 按 GitHub issue #26759 workaround。

---

## 安装路径与结构

### 脚本位置

| Option | Description | Selected |
|--------|-------------|----------|
| scripts/ 并列（推荐） | 所有脚本在同一目录，清晰统一。Windows 用户看到 scripts/ 下有 .sh 和 .ps1 并列，一目了然。 | ✓ |
| scripts/linux/ + scripts/windows/ | 按平台分组，但增加目录层级，用户找文件不方便。 | |

**User's choice:** scripts/ 并列

### Claude 配置目录

| Option | Description | Selected |
|--------|-------------|----------|
| $env:USERPROFILE/.claude/（推荐） | 和 bash 脚本保持一致，Claude Code 在所有平台都用 $HOME/.claude/。PowerShell 5.1 中 $env:USERPROFILE 更可靠。 | ✓ |
| $env:APPDATA/claude/ | Claude Code 自己定义的路径，可能不存在。不确定跨版本一致性。 | |

**User's choice:** $env:USERPROFILE/.claude/

### 仓库路径处理

| Option | Description | Selected |
|--------|-------------|----------|
| 手动参数 | 用户必须手动指定仓库路径。可靠但增加安装步骤，用户体验不如一键。 | ✓ |
| 复制到固定位置 | install.ps1 复制自身到 $HOME/.claude/scripts/ 目录。hook command 用固定路径。安装即自包含，但需要管理脚本更新。 | |
| 要求同仓库 | 和 bash 脚本共享同一个仓库目录。但 Windows 用户可能不在同一台机器上开发。 | |

**User's choice:** 手动参数
**Notes:** 用户最初选了"复制到固定位置"后改为"手动参数"。

### mp3 文件来源

| Option | Description | Selected |
|--------|-------------|----------|
| 从本地仓库复制（推荐） | 用户必须先克隆仓库到本地，install.ps1 从本地仓库的 audio/ 目录复制。和 bash 脚本一致，但需要 git。 | ✓ |
| 从远程下载 mp3 | 安装脚本从 GitHub releases 或 raw URL 下载 mp3。用户不需要克隆仓库，但需要网络连接。 | |

**User's choice:** 从本地仓库复制

---

## Claude's Discretion

- install.ps1 参数设计（-RepoPath vs -ScriptPath，默认值等）
- MediaPlayer 的 Add-Type 加载方式和错误处理
- uninstall.ps1 是否需要额外清理（如 $env:TEMP 下的 lock 文件）
- PowerShell 脚本的错误输出格式（Write-Warning / Write-Error）

## Deferred Ideas

None.
