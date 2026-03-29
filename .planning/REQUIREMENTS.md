# Requirements: Claude Code 语音通知

**Defined:** 2026-03-30
**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## v1 Requirements

### Docker 环境

- [x] **DOCKER-01**: Dockerfile 基于 python:3.12-slim 构建 Spark-TTS 运行环境（PyTorch CPU + Spark-TTS + ffmpeg）
- [x] **DOCKER-02**: 模型权重（Spark-TTS-0.5B, ~3.95GB）通过 volume mount 加载，不打入镜像层
- [x] **DOCKER-03**: Docker 镜像可正常执行 Spark-TTS 推理并输出 WAV 文件

### 音频生成

- [x] **AUDIO-01**: 生成 4 种通知语音：任务完成（"主人，任务完成了"）、请确认（"主人，请确认一下"）、出错（"主人，出错了"）、进行中（"主人，还在进行中"）
- [x] **AUDIO-02**: WAV 输出转换为 mp3 格式（ffmpeg）
- [x] **AUDIO-03**: 音频文件输出到 `~/.claude/notify-complete.mp3`、`notify-confirm.mp3`、`notify-error.mp3`、`notify-progress.mp3`
- [x] **AUDIO-04**: 语音风格为温柔低沉慵懒（`--gender female --pitch low --speed low`）

### 编排脚本

- [x] **SCRIPT-01**: 一键脚本执行完整流程：docker build → 模型下载 → TTS 推理 → 转换 → 放置文件
- [x] **SCRIPT-02**: 生成后验证音频文件存在且可播放（paplay 验证）
- [x] **SCRIPT-03**: 支持单独重新生成指定类型的通知音频

### Hooks 集成

- [ ] **HOOKS-01**: Claude Code hooks 配置 3 种事件对应不同音频：Stop → notify-complete.mp3、Notification → notify-confirm.mp3、StopFailure → notify-error.mp3

## v2 Requirements

### 增强

- **AUDIO-05**: 自定义通知文案（用户指定文本重新生成）
- **AUDIO-06**: 更多语音风格参数可调（语速、音调微调）
- **HOOKS-02**: 通知冷却/防抖（避免快速连续播放）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 实时语音合成 | CPU 推理 8 分钟/句，性能不可接受 |
| 动态文案通知 | 需要实时 TTS，超出预生成架构 |
| GUI 桌面通知 | 音频通知已足够，保持简单 |
| 多语言支持 | 中文即可，v1 不做 i18n |
| 通知队列/调度 | Claude Code 事件天然串行，PulseAudio 自动混音 |
| 音量控制 | 用户通过系统音量控制即可 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCKER-01 | Phase 1 | Complete |
| DOCKER-02 | Phase 1 | Complete |
| DOCKER-03 | Phase 1 | Complete |
| AUDIO-01 | Phase 1 | Complete |
| AUDIO-02 | Phase 1 | Complete |
| AUDIO-03 | Phase 1 | Complete |
| AUDIO-04 | Phase 1 | Complete |
| SCRIPT-01 | Phase 2 | Complete |
| SCRIPT-02 | Phase 2 | Complete |
| SCRIPT-03 | Phase 2 | Complete |
| HOOKS-01 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30 after initial definition*
