# Milestones

## v1.1 跨平台兼容 (Shipped: 2026-03-30)

**Phases completed:** 2 phases, 2 plans, 6 tasks

**Key accomplishments:**

- OS-conditional stat/afplay branches in notify-play.sh, portable version_gte() and grep -oE in install.sh, uninstall.sh verified already portable
- 3 PowerShell 5.1 scripts (notify-play.ps1, install.ps1, uninstall.ps1) with MediaPlayer headless playback, 5-second cooldown, settings.json BOM-free hook injection, and forward-slash path workaround for Windows

---

## v1.0 Claude Code 语音通知 (Shipped: 2026-03-29)

**Phases completed:** 3 phases, 4 plans, 11 tasks

**Key accomplishments:**

- Docker build environment with Spark-TTS 0.5B: pinned deps, single-stage image, and batch TTS script with voice creation mode
- Docker image built and verified; 4 Chinese notification mp3 files generated via Spark-TTS CPU inference with voice creation mode
- 4 pre-generated mp3 notification sounds committed to repo, generate.py with selective --type generation, generate.sh orchestration for rebuild pipeline
- Three shell scripts providing Claude Code async notification hooks with 5-second cooldown, idempotent install/uninstall via jq

---
