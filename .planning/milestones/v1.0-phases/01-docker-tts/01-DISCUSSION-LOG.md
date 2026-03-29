# Phase 1: Docker TTS 环境 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 01-docker-tts
**Areas discussed:** 模型管理策略, TTS 推理方式, 音频输出格式

---

## 模型管理策略

| Option | Description | Selected |
|--------|-------------|----------|
| 自动下载+缓存 | 模型存在 ~/.cache/spark-tts/，Docker 通过 volume mount 加载。首次运行自动下载 | ✓ |
| 项目内 models/ 目录 | 模型存在项目目录下的 models/ 文件夹 | |
| 手动管理 | 手动下载到指定位置 | |

**User's choice:** 自动下载+缓存
**Notes:** 用户希望开箱即用，不需要手动操作

---

## TTS 推理方式

| Option | Description | Selected |
|--------|-------------|----------|
| CLI (cli.inference) | 用 Spark-TTS 自带 CLI：python -m cli.inference | ✓ |
| Python 脚本调用 API | 写 Python 脚本调用 Spark-TTS API | |

**User's choice:** CLI (cli.inference)
**Notes:** 简单直接，用户已在 /tmp/Spark-TTS 手动使用过 CLI

---

## 音频输出格式

| Option | Description | Selected |
|--------|-------------|----------|
| mp3 (ffmpeg 转换) | ffmpeg 转为 mp3，通用格式体积小 | ✓ |
| WAV 直出 | 直接输出 WAV，paplay 原生支持 | |

**User's choice:** mp3 (ffmpeg 转换)
**Notes:** 与现有 hooks 配置的 .mp3 格式保持一致

---

## Claude's Discretion

- Dockerfile 构建优化细节
- ffmpeg 转换参数微调
- 模型自动下载具体实现

## Deferred Ideas

None
