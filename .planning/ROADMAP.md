# Roadmap: Claude Code 语音通知

**Created:** 2026-03-30
**Phases:** 3
**Granularity:** Coarse
**Coverage:** 11/11 v1 requirements mapped

## Phase Overview

| # | Phase | Goal | Requirements | Plans | Status |
|---|-------|------|--------------|-------|--------|
| 1 | Docker TTS 环境 | 2/2 | Complete    | 2026-03-29 |
| 2 | 生成脚本 | 一键脚本完成全流程，支持单独重新生成 | SCRIPT-01, SCRIPT-02, SCRIPT-03 | 1 | Pending |
| 3 | Hooks 集成 | Claude Code 3 种事件触发不同通知音频 | HOOKS-01 | 2 | Pending |

---

## Phase 1: Docker TTS 环境

**Goal:** 用户可以构建 Spark-TTS Docker 镜像并生成 4 种通知语音文件

**Requirements:** DOCKER-01, DOCKER-02, DOCKER-03, AUDIO-01, AUDIO-02, AUDIO-03, AUDIO-04

**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md — Create Dockerfile, requirements.txt, and generate.py (source artifacts)
- [x] 01-02-PLAN.md — Build Docker image, run TTS generation, verify output (build + verify)

**Success criteria:**
1. `docker build` 成功构建镜像，包含 Python 3.12 + PyTorch CPU + Spark-TTS + ffmpeg
2. `docker run` 可执行 Spark-TTS 推理，输出 WAV 文件到指定目录
3. ffmpeg 将 WAV 转换为 mp3，输出到 `~/.claude/notify-{type}.mp3`
4. 4 种通知语音风格为温柔低沉慵懒（female, low pitch, low speed）

**UI hint:** no

---

## Phase 2: 生成脚本

**Goal:** 用户运行一个脚本即可生成所有通知音频，支持验证和单独重新生成

**Requirements:** SCRIPT-01, SCRIPT-02, SCRIPT-03

**Plans:** 1 plan

Plans:
- [x] 02-01-PLAN.md — Modify generate.py with --type argparse + create generate.sh orchestration script

**Success criteria:**
1. `./generate.sh` 一键完成：docker build（如需）→ 模型下载（如需）→ TTS 推理 → 转换 → 放置
2. 生成完毕自动验证 mp3 文件存在且格式有效（file 命令验证）
3. `./generate.sh --type confirm` 可单独重新生成指定通知音频

**UI hint:** no

---

## Phase 3: Hooks 集成

**Goal:** Claude Code 在 Stop/Notification/StopFailure 事件时播放对应通知音频

**Requirements:** HOOKS-01

**Success criteria:**
1. 任务完成时播放 `notify-complete.mp3`，需要确认时播放 `notify-confirm.mp3`，出错时播放 `notify-error.mp3`
2. 音频播放不阻塞 Claude Code 执行（后台 `&`）

**UI hint:** no

---

## Coverage

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCKER-01 | Phase 1 | Complete |
| DOCKER-02 | Phase 1 | Complete |
| DOCKER-03 | Phase 1 | Complete |
| AUDIO-01 | Phase 1 | Complete |
| AUDIO-02 | Phase 1 | Complete |
| AUDIO-03 | Phase 1 | Complete |
| AUDIO-04 | Phase 1 | Complete |
| SCRIPT-01 | Phase 2 | Pending |
| SCRIPT-02 | Phase 2 | Pending |
| SCRIPT-03 | Phase 2 | Pending |
| HOOKS-01 | Phase 3 | Pending |

**v1 requirements:** 11 total
**Mapped to phases:** 11
**Unmapped:** 0

---
*Roadmap created: 2026-03-30*
*Last updated: 2026-03-30 after completing Phase 1*
