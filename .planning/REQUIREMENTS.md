# Requirements: Claude Code 语音通知

**Defined:** 2026-03-30
**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## v1.1 Requirements (跨平台兼容)

### macOS 播放

- [x] **MAC-01**: notify-play.sh 在 macOS 上使用 `afplay` 播放音频
- [x] **MAC-02**: notify-play.sh 的 `stat` 调用兼容 BSD (macOS)

### Windows 播放

- [ ] **WIN-01**: notify-play.ps1 使用 MediaPlayer 播放 MP3，不弹出窗口
- [ ] **WIN-02**: notify-play.ps1 实现与 Linux 相同的 5 秒冷却防抖机制

### Windows 安装

- [ ] **WIN-03**: install.ps1 将 hooks 注入 Claude Code settings.json
- [ ] **WIN-04**: install.ps1 使用 `shell: powershell` 标记 Windows hooks
- [ ] **WIN-05**: install.ps1 中所有路径使用正斜杠（避免 #26759 bug）
- [ ] **WIN-06**: uninstall.ps1 从 settings.json 中移除 hooks

### 安装脚本兼容

- [x] **INST-01**: install.sh 支持 macOS（`uname -s` 检测，复制到 macOS 路径）
- [x] **INST-02**: uninstall.sh 支持 macOS

## v1.0 Requirements (Shipped)

### Docker TTS 环境

- ✓ **TTS-01**: Docker 化 Spark-TTS 环境
- ✓ **TTS-02**: 批量生成中文通知音频

### 音频生成

- ✓ **GEN-01**: 4 种通知语音（任务完成、请确认、出错、进行中）
- ✓ **GEN-02**: 一键脚本生成所有音频文件

### Hooks 集成

- ✓ **HOOK-01**: Claude Code hooks 4 种事件通知
- ✓ **HOOK-02**: 非阻塞播放 + 5 秒冷却防抖

## Out of Scope

| Feature | Reason |
|---------|--------|
| 实时语音合成 | CPU 推理 8 分钟/句，性能不可接受 |
| 动态文案通知 | 需要实时 TTS，超出预生成架构 |
| GUI 界面 | 音频通知已足够，保持简单 |
| 多语言支持 | 中文即可 |
| 音量控制 | 用户通过系统音量控制即可 |
| Homebrew paplay fallback | afplay 已内置，无必要 |
| jq.exe for Windows | PowerShell ConvertFrom-Json 即可，减少依赖 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MAC-01 | Phase 4 | Complete |
| MAC-02 | Phase 4 | Complete |
| INST-01 | Phase 4 | Complete |
| INST-02 | Phase 4 | Complete |
| WIN-01 | Phase 5 | Pending |
| WIN-02 | Phase 5 | Pending |
| WIN-03 | Phase 5 | Pending |
| WIN-04 | Phase 5 | Pending |
| WIN-05 | Phase 5 | Pending |
| WIN-06 | Phase 5 | Pending |

**Coverage:**
- v1.1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30 after v1.1 roadmap creation*
