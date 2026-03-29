# Phase 1: Docker TTS 环境 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

构建可工作的 Spark-TTS Docker 环境，能够推理生成 4 种中文通知语音 mp3 文件。本阶段产出：Dockerfile + 模型管理方案 + 可执行的 docker run 命令（生成 WAV → ffmpeg 转 mp3 → 输出到 ~/.claude/）。

脚本编排（Phase 2）和 Hooks 集成（Phase 3）不在本阶段。

</domain>

<decisions>
## Implementation Decisions

### 模型管理
- **D-01:** 模型权重存储在宿主机 `~/.cache/spark-tts/`，Docker 通过 volume mount 加载
- **D-02:** 首次运行时自动下载模型（Spark-TTS 的 download 逻辑或 huggingface-cli），后续运行复用缓存
- **D-03:** 模型不打入 Docker 镜像层（~3.95GB，避免镜像膨胀）

### TTS 推理
- **D-04:** 使用 Spark-TTS 自带 CLI：`python -m cli.inference --text "..." --gender female --pitch low --speed low`
- **D-05:** 4 种固定文案：任务完成("主人，任务完成了")、请确认("主人，请确认一下")、出错("主人，出错了")、进行中("主人，还在进行中")

### 音频输出
- **D-06:** WAV → mp3 转换，使用 ffmpeg（libmp3lame, -qscale:a 2 高质量）
- **D-07:** 输出文件命名：`notify-complete.mp3`、`notify-confirm.mp3`、`notify-error.mp3`、`notify-progress.mp3`
- **D-08:** 输出目录通过 volume mount 映射到宿主机 `~/.claude/`

### Docker 镜像
- **D-09:** 基础镜像 python:3.12-slim（不用 Alpine，PyTorch 不兼容 musl）
- **D-10:** PyTorch 使用 CPU-only 版本（`--index-url https://download.pytorch.org/whl/cpu`），节省 ~2GB
- **D-11:** 安装 ffmpeg 和 libsndfile1（soundfile/torchaudio 依赖）
- **D-12:** protobuf>=4.21.0 作为安全依赖（不在 Spark-TTS requirements.txt 但需要）

### Claude's Discretion
- Dockerfile 具体层结构、构建优化（缓存层等）
- ffmpeg 转换参数微调（采样率、比特率）
- 模型自动下载的具体实现方式（huggingface-cli vs Spark-TTS 内置逻辑）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — 项目愿景、约束、已做决策
- `.planning/REQUIREMENTS.md` — v1 需求定义（DOCKER-01 ~ AUDIO-04）
- `.planning/research/STACK.md` — 技术栈研究（Docker 镜像、PyTorch 版本、依赖）
- `.planning/research/ARCHITECTURE.md` — 架构研究（组件边界、数据流、构建顺序）
- `.planning/research/PITFALLS.md` — 常见陷阱（protobuf、Alpine 兼容性、镜像膨胀）

### External
- Spark-TTS GitHub: https://github.com/SparkAudio/Spark-TTS
- Spark-TTS CLI inference: `python -m cli.inference` (项目内 cli/inference.py)
- Claude Code hooks 文档: https://docs.anthropic.com/en/docs/claude-code/hooks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- 无现有代码（greenfield 项目）

### Established Patterns
- 无现有模式

### Integration Points
- Claude Code hooks 已配置在 `~/.claude/settings.json`（Phase 3 详细集成，本阶段只确保输出文件路径匹配）
- 宿主机 `~/.claude/` 目录是输出目标

</code_context>

<specifics>
## Specific Ideas

- 用户已在 `/tmp/Spark-TTS` 有过手动运行经验，对 CLI 参数熟悉
- 用户偏好温柔低沉慵懒的语音风格（female + low pitch + low speed）
- 现有 hooks 配置播放 `notify-confirm.mp3`，需扩展为 4 种音频

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-docker-tts*
*Context gathered: 2026-03-30*
