# Roadmap: Claude Code 语音通知

## Milestones

- ✅ **v1.0 语音通知** — Phases 1-3 (shipped 2026-03-30)
- 🚧 **v1.1 跨平台兼容** — Phases 4-5 (in progress)

## Phases

<details>
<summary>✅ v1.0 语音通知 (Phases 1-3) — SHIPPED 2026-03-30</summary>

- [x] Phase 1: Docker TTS 环境 (2/2 plans) — completed 2026-03-30
- [x] Phase 2: 生成脚本 (1/1 plans) — completed 2026-03-30
- [x] Phase 3: Hooks 集成 (1/1 plans) — completed 2026-03-30

</details>

### 🚧 v1.1 跨平台兼容 (In Progress)

**Milestone Goal:** 语音通知系统在 macOS 和 Windows 上开箱即用，保持一键安装体验。

- [ ] **Phase 4: macOS 兼容** — 扩展现有 bash 脚本支持 macOS (afplay + BSD stat 兼容)
- [ ] **Phase 5: Windows 兼容** — 新建 PowerShell 脚本实现 Windows 播放和安装

## Phase Details

<details>
<summary>✅ v1.0 语音通知 (Phases 1-3) — SHIPPED 2026-03-30</summary>

### Phase 1: Docker TTS 环境
**Goal**: Docker 化 Spark-TTS 0.5B 推理环境，能批量生成中文通知音频
**Plans**: 2 plans

Plans:
- [x] 01-01: Dockerfile + requirements.txt
- [x] 01-02: 批量生成脚本 + 音频输出验证

### Phase 2: 生成脚本
**Goal**: 一键脚本生成 4 种通知音频并提交到仓库
**Plans**: 1 plan

Plans:
- [x] 02-01: generate.sh + generate.py + 音频提交

### Phase 3: Hooks 集成
**Goal**: Claude Code hooks 4 种事件自动播放语音通知，5 秒冷却防抖
**Plans**: 1 plan

Plans:
- [x] 03-01: install.sh + uninstall.sh + notify-play.sh + hooks 配置

</details>

### Phase 4: macOS 兼容
**Goal**: 现有 bash 脚本在 macOS 上开箱即用，安装/卸载/播放全部正常工作
**Depends on**: Phase 3 (existing v1.0 scripts)
**Requirements**: MAC-01, MAC-02, INST-01, INST-02
**Success Criteria** (what must be TRUE):
  1. User runs `install.sh` on macOS and all 4 mp3 files are copied to the correct location
  2. User runs `install.sh` on macOS and hooks are injected into `~/.claude/settings.json` with the same command format as Linux
  3. Claude Code triggers a notification on macOS and the correct mp3 plays via `afplay` with no errors
  4. The 5-second cooldown prevents duplicate playback on macOS (rapid successive events only play once)
  5. User runs `uninstall.sh` on macOS and all hook entries are cleanly removed from settings.json
**Plans**: TBD

### Phase 5: Windows 兼容
**Goal**: Windows 用户通过 PowerShell 脚本实现一键安装和语音通知播放
**Depends on**: Phase 3 (existing v1.0 scripts and mp3 files)
**Requirements**: WIN-01, WIN-02, WIN-03, WIN-04, WIN-05, WIN-06
**Success Criteria** (what must be TRUE):
  1. User runs `install.ps1` on Windows and mp3 files are copied to a Windows-accessible location
  2. User runs `install.ps1` on Windows and hooks are injected with `"shell": "powershell"` and all paths use forward slashes
  3. Claude Code triggers a notification on Windows and the correct mp3 plays via MediaPlayer with no visible window
  4. The 5-second cooldown prevents duplicate playback on Windows (rapid successive events only play once)
  5. User runs `uninstall.ps1` on Windows and all hook entries are cleanly removed from settings.json
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 4 → 5

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 1. Docker TTS 环境 | v1.0 | 2/2 | Complete | 2026-03-30 |
| 2. 生成脚本 | v1.0 | 1/1 | Complete | 2026-03-30 |
| 3. Hooks 集成 | v1.0 | 1/1 | Complete | 2026-03-30 |
| 4. macOS 兼容 | v1.1 | 0/? | Not started | - |
| 5. Windows 兼容 | v1.1 | 0/? | Not started | - |

---
*Roadmap created: 2026-03-30*
*Last updated: 2026-03-30 after v1.1 roadmap creation*
