# Phase 2: 生成脚本 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

创建编排脚本 `generate.sh`，用户一个命令完成全流程：docker build（如需）→ 模型下载（如需）→ TTS 推理 → WAV→MP3 转换 → 文件放置到 `~/.claude/`。支持验证输出文件和单独重新生成指定类型。

Hooks 集成（Phase 3）不在本阶段。

</domain>

<decisions>
## Implementation Decisions

### Selective Generation (SCRIPT-03)
- **D-01:** 改造 `generate.py` 加 `--type` 参数支持选择性生成，脚本层透传参数
- **D-02:** `--type` 支持多个类型，用逗号分隔：`./generate.sh --type confirm,error`

### Docker Rebuild Strategy
- **D-03:** 智能跳过：检测 `spark-tts-notify` 镜像存在就跳过 `docker build`，不存在才 build
- **D-04:** 提供 `--force-rebuild` 参数强制重建镜像

### Verification (SCRIPT-02)
- **D-05:** 验证深度：检查文件存在 + `file` 命令确认是有效 MP3 格式
- **D-06:** 不在脚本中播放音频（paplay 试播不适合脚本自动化场景）

### Script UX
- **D-07:** 清晰的步骤进度输出（正在 build / 正在生成 confirm...）
- **D-08:** 出错立即停止（set -e / trap）并显示错误信息
- **D-09:** 包含中文帮助信息，说明脚本用途
- **D-10:** 无需 dry-run、verbose 等高级选项

### Claude's Discretion
- generate.py 的参数传递机制（argparse / sys.argv / 环境变量）
- 进度输出格式（echo / printf 风格）
- 退出码定义
- 脚本中的变量定义和路径拼接方式

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Artifacts (inputs)
- `Dockerfile` — Phase 1 产出的 Docker 构建文件，脚本需调用 `docker build -t spark-tts-notify .`
- `generate.py` — Phase 1 产出的 TTS 生成脚本，需改造以支持 `--type` 参数
- `requirements.txt` — Phase 1 产出的 Python 依赖文件

### Phase 1 Context and Research
- `.planning/phases/01-docker-tts/01-CONTEXT.md` — Phase 1 所有决策（D-01~D-12），volume mount 路径等
- `.planning/phases/01-docker-tts/01-02-SUMMARY.md` — Phase 1 执行结果和已知问题（文件权限、性能等）
- `.planning/research/PITFALLS.md` — 已知陷阱（--device 参数、timestamp 文件名等）

### Project Context
- `.planning/PROJECT.md` — 项目愿景和约束
- `.planning/REQUIREMENTS.md` — SCRIPT-01, SCRIPT-02, SCRIPT-03 需求定义
- `.planning/ROADMAP.md` — Phase 2 成功标准

### Known Patterns from Phase 1
- Docker run pattern: `docker run --rm --user $(id -u):$(id -g) -v ~/.cache/spark-tts/:/app/pretrained_models/Spark-TTS-0.5B:z -v ~/.claude/:/output/:z spark-tts-notify`
- Volume mount `:z` flag required on Fedora (SELinux)
- CPU inference ~8 min/sentence, total ~32 min for 4 notifications

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `generate.py` — 已有完整的 TTS 生成逻辑（model download、voice creation、WAV→MP3），需加 `--type` 参数
- `Dockerfile` — 已有完整的 Docker 构建配置，脚本直接调用
- `requirements.txt` — 已有 pinned Python 依赖

### Established Patterns
- generate.py 使用 `NOTIFICATIONS` 列表定义 4 种通知（complete, confirm, error, progress）
- generate.py 使用 `VOICE_PARAMS` dict 定义语音参数（female, low pitch, low speed）
- generate.py 自动下载模型、自动检测 CPU/GPU 设备
- Docker run 使用 `--user $(id -u):$(id -g)` + `:z` 处理 SELinux

### Integration Points
- generate.py 入口是 `main()` 函数，需改造为接受命令行参数
- generate.py 已支持环境变量 `MODEL_DIR` 和 `OUTPUT_DIR`，脚本可利用
- 输出文件命名约定：`notify-{type}.mp3`

</code_context>

<specifics>
## Specific Ideas

- 用户偏好温柔低沉慵懒语音（female + low pitch + low speed）
- Phase 1 中遇到过文件权限问题（root-owned output），脚本需确保 `--user` 标志始终使用
- 音频质量"勉强可接受"，v1 够用

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-generate-script*
*Context gathered: 2026-03-30*
