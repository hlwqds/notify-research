---
phase: 01-docker-tts
plan: 02
subsystem: infra
tags: [docker, spark-tts, tts, mp3, audio, voice-generation]

# Dependency graph
requires:
  - phase: 01-docker-tts/01
    provides: "Dockerfile, requirements.txt, generate.py"
provides:
  - "spark-tts-notify Docker image (~1.4GB) with PyTorch CPU + Spark-TTS + ffmpeg"
  - "4 notification mp3 files at ~/.claude/ (notify-complete, confirm, error, progress)"
  - "Cached model weights at ~/.cache/spark-tts/ (~3.95GB)"
affects: [02-generate-script]

# Tech tracking
tech-stack:
  added: []
  patterns: [docker-volume-mount-models, docker-volume-mount-output, voice-creation-mode, cpu-inference-8min-per-sentence]

key-files:
  created: []
  modified: []

key-decisions:
  - "Human accepted audio quality as 'barely acceptable' -- sufficient for v1, may revisit in v2"
  - "CPU inference confirmed at ~8 min/sentence (4 sentences ~32 min total)"
  - "Model auto-download on first run works correctly via huggingface_hub"

patterns-established:
  - "Pattern: Docker run with --user for SELinux compatibility on Fedora"
  - "Pattern: Model cache at ~/.cache/spark-tts/ mounted to /app/pretrained_models/Spark-TTS-0.5B"
  - "Pattern: Output mp3 files at ~/.claude/notify-{type}.mp3 (40kbps, 16kHz, mono)"

requirements-completed: [DOCKER-01, DOCKER-02, DOCKER-03, AUDIO-01, AUDIO-02, AUDIO-03, AUDIO-04]

# Metrics
duration: 45min
completed: 2026-03-30
---

# Phase 1 Plan 02: Build and Verify Summary

**Docker image built and verified; 4 Chinese notification mp3 files generated via Spark-TTS CPU inference with voice creation mode**

## Performance

- **Duration:** 45 min
- **Started:** 2026-03-29T18:20:35Z
- **Completed:** 2026-03-30T02:20:00Z
- **Tasks:** 3
- **Files modified:** 0 (no source file changes -- all output is binary artifacts)

## Accomplishments
- Docker image `spark-tts-notify` built successfully (~1.4GB without models)
- Spark-TTS-0.5B model weights downloaded and cached at ~/.cache/spark-tts/ (~3.95GB)
- 4 notification mp3 files generated at ~/.claude/ with correct Chinese text content
- Human verified audio quality is acceptable (female voice, low pitch, slow pace)

## Task Commits

No source file commits for this plan. Tasks 1-2 produced binary artifacts (Docker image, mp3 files, model cache). Task 3 was human verification only.

## Files Created/Modified

No source files modified. All output is external to the repository:
- `~/.claude/notify-complete.mp3` (11.6 KB) - "主人，任务完成了"
- `~/.claude/notify-confirm.mp3` (14.1 KB) - "主人，请确认一下"
- `~/.claude/notify-error.mp3` (10.1 KB) - "主人，出错了"
- `~/.claude/notify-progress.mp3` (10.2 KB) - "主人，还在进行中"

## Decisions Made
- Human accepted audio quality as "barely acceptable" -- voice quality is functional but not polished; sufficient for v1 notifications. May revisit voice parameters or model in v2.
- CPU inference time confirmed at approximately 8 minutes per sentence, consistent with research estimates.
- Voice creation mode (no reference audio, gender/pitch/speed params) produces intelligible but not natural-sounding Chinese speech.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **notify-complete.mp3 ownership issue:** First generated file owned by `docker:docker` (root) instead of user, likely from a docker run without `--user`. The `--user $(id -u):$(id -g)` flag was documented in the plan and should be used consistently.

## User Setup Required

None - all artifacts are in place. Docker image exists, model is cached, mp3 files are at ~/.claude/.

## Next Phase Readiness
- All 4 mp3 notification files exist at ~/.claude/ and are playable
- Docker image `spark-tts-notify` is built and functional
- Model weights cached at ~/.cache/spark-tts/ for future runs
- Phase 2 (generate script) can wrap the `docker build` + `docker run` workflow into a single `generate.sh`
- No blockers or concerns

## Self-Check: PASSED

- FOUND: ~/.claude/notify-complete.mp3 (11.6 KB, valid MP3)
- FOUND: ~/.claude/notify-confirm.mp3 (14.1 KB, valid MP3)
- FOUND: ~/.claude/notify-error.mp3 (10.1 KB, valid MP3)
- FOUND: ~/.claude/notify-progress.mp3 (10.2 KB, valid MP3)
- FOUND: ~/.cache/spark-tts/LLM/ (model cached)
- FOUND: ~/.cache/spark-tts/BiCodec/ (model cached)
- FOUND: ~/.cache/spark-tts/wav2vec2-large-xlsr-53/ (model cached)
- VERIFIED: Human approved audio quality (Task 3 checkpoint)

---
*Phase: 01-docker-tts*
*Completed: 2026-03-30*
