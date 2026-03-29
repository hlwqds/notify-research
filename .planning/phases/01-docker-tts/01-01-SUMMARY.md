---
phase: 01-docker-tts
plan: 01
subsystem: infra
tags: [docker, python, spark-tts, pytorch, ffmpeg, tts]

# Dependency graph
requires:
  - phase: none (greenfield)
    provides: project research and context decisions (D-01 through D-12)
provides:
  - "Dockerfile: python:3.12-slim + PyTorch CPU + Spark-TTS deps + ffmpeg"
  - "requirements.txt: pinned deps excluding gradio, with huggingface_hub and protobuf"
  - "generate.py: batch TTS generation with model auto-download and WAV-to-MP3 conversion"
affects: [02-build-verify]

# Tech tracking
tech-stack:
  added: [python:3.12-slim, pytorch-2.5.1-cpu, transformers-4.46.2, spark-tts-0.5b, ffmpeg, huggingface_hub]
  patterns: [voice-creation-mode, batch-tts-generation, model-auto-download, docker-volume-mount]

key-files:
  created: [requirements.txt, Dockerfile, generate.py]
  modified: []

key-decisions:
  - "Custom requirements.txt excludes gradio (~500MB savings) and torch (installed via --index-url)"
  - "SparkTTS class used directly instead of CLI for output naming control"
  - "Single-stage Docker build (PyTorch needed at runtime, no build-only deps to separate)"
  - "Model auto-download via huggingface_hub.snapshot_download() inside container"
  - "Auto-detect CPU/GPU device instead of hardcoded --device (avoids Pitfall 1)"

patterns-established:
  - "Pattern: Voice creation mode with gender/pitch/speed params (no reference audio)"
  - "Pattern: Batch notification generation with named output files"
  - "Pattern: Docker volume mount for models (~/.cache/spark-tts/) and output (~/.claude/)"

requirements-completed: [DOCKER-01, DOCKER-02, DOCKER-03, AUDIO-01, AUDIO-02, AUDIO-03, AUDIO-04]

# Metrics
duration: 2min
completed: 2026-03-30
---

# Phase 1 Plan 01: Source Artifacts Summary

**Docker build environment with Spark-TTS 0.5B: pinned deps, single-stage image, and batch TTS script with voice creation mode**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-29T17:07:51Z
- **Completed:** 2026-03-29T17:09:06Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created requirements.txt with 10 pinned Spark-TTS deps (excluding gradio) plus huggingface_hub and protobuf
- Created Dockerfile: single-stage python:3.12-slim with PyTorch CPU via --index-url, ffmpeg, git for Spark-TTS source clone
- Created generate.py: batch TTS generation for 4 Chinese notifications with voice creation mode, model auto-download, WAV-to-MP3 conversion

## Task Commits

Each task was committed atomically:

1. **Task 1: Create requirements.txt** - `2f95131` (feat)
2. **Task 2: Create Dockerfile and generate.py** - `0be2baa` (feat)

## Files Created/Modified
- `requirements.txt` - Pinned Python dependencies for Spark-TTS inference (10 official deps + huggingface_hub + protobuf, excludes gradio)
- `Dockerfile` - Single-stage Docker build: python:3.12-slim, PyTorch 2.5.1 CPU, Spark-TTS source clone, ffmpeg
- `generate.py` - Batch TTS generation script with model auto-download, voice creation mode, WAV-to-MP3 conversion, 4 named outputs

## Decisions Made
- Custom requirements.txt excludes gradio (~500MB savings) and torchvision (not needed for TTS inference)
- PyTorch installed separately in Dockerfile via `--index-url https://download.pytorch.org/whl/cpu` (D-10) -- not in requirements.txt because torch version string is CPU-specific
- SparkTTS class used directly instead of CLI (`python -m cli.inference`) because CLI hardcodes timestamp-based filenames (Pitfall 2 from RESEARCH)
- Single-stage Docker build chosen over multi-stage: PyTorch is needed at inference time, so no build-only deps to strip
- Model auto-download implemented inside container using `huggingface_hub.snapshot_download()` with presence check on `LLM/` subdirectory
- Auto-detect CPU/GPU device pattern instead of hardcoded `--device cpu` (avoids Pitfall 1 where `--device` expects int not str)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Plan 02 will handle `docker build` and `docker run`.

## Next Phase Readiness
- All three source artifacts (requirements.txt, Dockerfile, generate.py) are ready for `docker build .`
- Plan 02 can proceed with building the image, running TTS generation, and verifying output audio files
- No blockers or concerns

## Self-Check: PASSED

- FOUND: requirements.txt
- FOUND: Dockerfile
- FOUND: generate.py
- FOUND: 01-01-SUMMARY.md
- FOUND: 2f95131 (Task 1 commit)
- FOUND: 0be2baa (Task 2 commit)

---
*Phase: 01-docker-tts*
*Completed: 2026-03-30*
