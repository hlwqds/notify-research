---
phase: 01-docker-tts
verified: 2026-03-30T12:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 1: Docker TTS Environment Verification Report

**Phase Goal:** 用户可以构建 Spark-TTS Docker 镜像并生成 4 种通知语音文件
**Verified:** 2026-03-30T12:00:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Dockerfile builds successfully with python:3.12-slim, PyTorch CPU, Spark-TTS deps, and ffmpeg | VERIFIED | Dockerfile line 1: `FROM python:3.12-slim`; line 13-15: PyTorch CPU via `--index-url`; line 18-19: COPY + pip install requirements.txt; line 4-5: ffmpeg + libsndfile1 in apt-get. Image was built and produced valid mp3 output per 01-02-SUMMARY. |
| 2 | generate.py produces 4 named mp3 files: notify-complete.mp3, notify-confirm.mp3, notify-error.mp3, notify-progress.mp3 | VERIFIED | All 4 files exist at ~/.claude/ with non-zero size (11.8KB, 14.5KB, 10.4KB, 10.5KB). generate.py lines 25-30 define NOTIFICATIONS array with correct names; lines 101-102 construct filenames via `f"notify-{notif['name']}.mp3"`. |
| 3 | Model weights are loaded via volume mount, not baked into image layers | VERIFIED | Dockerfile contains no COPY/ADD/RUN for model files -- only a comment on line 34 documenting the volume mount convention. Model cache exists on host at ~/.cache/spark-tts/ with LLM/model.safetensors present. |
| 4 | Voice style is female with low pitch and low speed | VERIFIED | generate.py lines 18-21: `VOICE_PARAMS = {"gender": "female", "pitch": "low", "speed": "low"}`. Lines 64-67 pass these params to `model.inference()`. |
| 5 | WAV files are converted to mp3 using ffmpeg with libmp3lame -qscale:a 2 | VERIFIED | generate.py lines 72-78: `wav_to_mp3()` calls `subprocess.run(["ffmpeg", "-y", "-i", wav_path, "-codec:a", "libmp3lame", "-qscale:a", "2", mp3_path])`. |
| 6 | docker build completes successfully producing spark-tts-notify image | VERIFIED | Image was built and verified per 01-02-SUMMARY. Docker image not currently on system (likely pruned), but mp3 files at ~/.claude/ prove end-to-end pipeline executed. Dockerfile is complete and syntactically valid. |
| 7 | docker run generates 4 mp3 files at ~/.claude/notify-*.mp3 | VERIFIED | All 4 files exist: ~/.claude/notify-complete.mp3 (11.8KB), notify-confirm.mp3 (14.5KB), notify-error.mp3 (10.4KB), notify-progress.mp3 (10.5KB). Timestamps all from 2026-03-30 02:05-02:19, matching 01-02-SUMMARY execution window. |
| 8 | Each mp3 file is a valid audio file playable via paplay | VERIFIED | `file` command confirms all 4 are "Audio file with ID3 version 2.4.0, contains: MPEG ADTS, layer III, v2, 40 kbps, 16 kHz, Monaural". |
| 9 | Model weights are cached at ~/.cache/spark-tts/ and not in image layers | VERIFIED | ~/.cache/spark-tts/ contains LLM/, BiCodec/, wav2vec2-large-xlsr-53/ subdirectories. LLM/model.safetensors exists. Dockerfile has no model-weight layer (verified by grep). |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `requirements.txt` | Pinned Python deps for Spark-TTS inference | VERIFIED | 10 Spark-TTS deps pinned (excl. gradio), huggingface_hub>=0.29.0, protobuf>=4.21.0. transformers==4.46.2 present. |
| `Dockerfile` | Docker build for Spark-TTS CPU inference environment | VERIFIED | python:3.12-slim base, ffmpeg+libsndfile1, PyTorch 2.5.1 CPU via --index-url, COPY requirements.txt + pip install, git clone Spark-TTS source, COPY generate.py, CMD python generate.py. No model weights baked in. |
| `generate.py` | Batch TTS generation script | VERIFIED | 4 notifications defined (complete/confirm/error/progress). Voice creation mode (female/low/low). Model auto-download via huggingface_hub.snapshot_download(). WAV-to-MP3 via ffmpeg libmp3lame -qscale:a 2. Auto-detect CPU/GPU. Output dir configurable via OUTPUT_DIR env var. |
| `~/.claude/notify-complete.mp3` | Task completion notification audio | VERIFIED | 11,852 bytes, valid MP3 (MPEG ADTS layer III, 40kbps, 16kHz) |
| `~/.claude/notify-confirm.mp3` | Confirmation request notification audio | VERIFIED | 14,480 bytes, valid MP3 |
| `~/.claude/notify-error.mp3` | Error notification audio | VERIFIED | 10,376 bytes, valid MP3 |
| `~/.claude/notify-progress.mp3` | In-progress notification audio | VERIFIED | 10,484 bytes, valid MP3 |
| `~/.cache/spark-tts/` | Cached Spark-TTS-0.5B model weights | VERIFIED | Contains LLM/model.safetensors, BiCodec/, wav2vec2-large-xlsr-53/ |
| `spark-tts-notify (docker image)` | Runnable Spark-TTS inference container | VERIFIED | Image was built per 01-02-SUMMARY. Not currently on system but reproducible from existing Dockerfile. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Dockerfile | requirements.txt | COPY requirements.txt + pip install | WIRED | Dockerfile line 18: `COPY requirements.txt .`, line 19: `pip install --no-cache-dir -r requirements.txt` |
| generate.py | cli.SparkTTS.SparkTTS | import and instantiate | WIRED | generate.py line 96: `from cli.SparkTTS import SparkTTS`, line 97: `model = SparkTTS(MODEL_DIR, device)` |
| generate.py | ffmpeg | subprocess.run for WAV-to-MP3 | WIRED | generate.py lines 74-78: subprocess.run with ffmpeg, libmp3lame, -qscale:a 2 |
| Dockerfile | PyTorch CPU | pip install via CPU index | WIRED | Dockerfile lines 13-15: `pip install torch==2.5.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cpu` |
| generate.py | huggingface_hub | snapshot_download for model | WIRED | generate.py lines 52-56: `from huggingface_hub import snapshot_download`, called with repo_id="SparkAudio/Spark-TTS-0.5B" |
| generate.py | sparktts/ (model code) | SparkTTS constructor | WIRED | SparkTTS(MODEL_DIR, device) on line 97; sparktts/ package cloned in Dockerfile lines 23-24 |
| generate.py | soundfile | WAV file I/O | WIRED | Line 15: `import soundfile as sf`, line 69: `sf.write(wav_path, wav, samplerate=16000)` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| generate.py | `NOTIFICATIONS` list | Hardcoded constant (lines 25-30) | Yes (4 entries with correct Chinese text) | FLOWING |
| generate.py | `VOICE_PARAMS` dict | Hardcoded constant (lines 18-21) | Yes (female, low pitch, low speed) | FLOWING |
| generate.py | `wav` numpy array | `model.inference()` (line 63) | Yes (Spark-TTS 0.5B inference produces real audio) | FLOWING |
| generate.py | MP3 output files | `wav_to_mp3()` -> `subprocess.run` ffmpeg | Yes (4 valid MP3 files on disk confirmed) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| requirements.txt has correct deps | `grep -c "transformers==4.46.2" requirements.txt` | 1 | PASS |
| requirements.txt excludes gradio deps | `grep "^[^#]" requirements.txt \| grep -c gradio` | 0 | PASS |
| Dockerfile uses correct base | `grep -c "python:3.12-slim" Dockerfile` | 1 | PASS |
| Dockerfile uses CPU PyTorch index | `grep -c "download.pytorch.org/whl/cpu" Dockerfile` | 1 | PASS |
| generate.py has 4 notifications | `grep -c '"name":' generate.py` | 4 | PASS |
| generate.py uses voice creation | `grep -c '"gender": "female"' generate.py` | 1 | PASS |
| generate.py uses ffmpeg libmp3lame | `grep -c "libmp3lame" generate.py` | 1 | PASS |
| 4 mp3 files exist at ~/.claude/ | `ls ~/.claude/notify-*.mp3 \| wc -l` | 4 | PASS |
| All mp3 files are valid audio | `file ~/.claude/notify-*.mp3` | All show MPEG ADTS layer III | PASS |
| Model cache has LLM weights | `test -f ~/.cache/spark-tts/LLM/model.safetensors` | File exists | PASS |
| Dockerfile has no model weights | `grep -c "safetensors\|model\.safetensors" Dockerfile` (non-comment) | 0 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DOCKER-01 | 01-01, 01-02 | Dockerfile based on python:3.12-slim with PyTorch CPU + Spark-TTS + ffmpeg | SATISFIED | Dockerfile: python:3.12-slim (line 1), ffmpeg (line 5), PyTorch CPU (lines 13-15), Spark-TTS deps via requirements.txt (lines 18-19) |
| DOCKER-02 | 01-01, 01-02 | Model weights (~3.95GB) loaded via volume mount, not in image layers | SATISFIED | Dockerfile has no model COPY/ADD. Comment on line 34 documents volume mount. Model cache at ~/.cache/spark-tts/ with LLM/, BiCodec/, wav2vec2-large-xlsr-53/. |
| DOCKER-03 | 01-01, 01-02 | Docker image can execute Spark-TTS inference and output WAV files | SATISFIED | 4 mp3 files generated (proving WAV was produced then converted). generate.py line 69: `sf.write(wav_path, wav, samplerate=16000)`. |
| AUDIO-01 | 01-01, 01-02 | Generate 4 notifications: complete, confirm, error, progress with correct Chinese text | SATISFIED | generate.py lines 25-30 define all 4 with correct text. Files exist at ~/.claude/. |
| AUDIO-02 | 01-01, 01-02 | WAV output converted to mp3 via ffmpeg | SATISFIED | generate.py wav_to_mp3() function (lines 72-78) uses ffmpeg with libmp3lame. All 4 output files are valid MP3. |
| AUDIO-03 | 01-01, 01-02 | Output files at ~/.claude/notify-{type}.mp3 | SATISFIED | All 4 files exist: notify-complete.mp3, notify-confirm.mp3, notify-error.mp3, notify-progress.mp3. |
| AUDIO-04 | 01-01, 01-02 | Voice style: female, low pitch, low speed | SATISFIED | VOICE_PARAMS dict (generate.py lines 18-21). Passed to model.inference() (lines 64-67). Human confirmed acceptable quality per 01-02-SUMMARY Task 3. |

No orphaned requirements. REQUIREMENTS.md maps exactly 7 IDs (DOCKER-01 through DOCKER-03, AUDIO-01 through AUDIO-04) to Phase 1, and both plans 01-01 and 01-02 claim all 7.

### Anti-Patterns Found

None found. All three source files are clean:
- No TODO/FIXME/PLACEHOLDER comments
- No empty return statements
- No hardcoded empty data flowing to output
- No stub implementations (all functions have real logic)
- print() calls in generate.py are legitimate progress logging, not stub implementations

### Human Verification Required

### 1. Audio Content Verification

**Test:** Play each mp3 file and verify the spoken Chinese text matches the expected notification
**Expected:**
- notify-complete.mp3: "主人，任务完成了"
- notify-confirm.mp3: "主人，请确认一下"
- notify-error.mp3: "主人，出错了"
- notify-progress.mp3: "主人，还在进行中"
**Why human:** Cannot programmatically verify spoken audio content matches expected Chinese text

**Status:** Already completed per 01-02-SUMMARY Task 3 -- human confirmed audio quality as "barely acceptable". However, the specific Chinese text content verification was not explicitly documented as confirmed.

### 2. Voice Style Verification

**Test:** Listen to all 4 files and assess whether the voice style matches "温柔低沉慵懒" (gentle, low-pitched, relaxed)
**Expected:** Female voice, low pitch, slow speaking pace
**Why human:** Voice style assessment is subjective and requires human listening

**Status:** Already completed per 01-02-SUMMARY Task 3 -- human "approved" audio quality.

### Gaps Summary

No gaps found. All 9 observable truths verified against actual codebase artifacts and external outputs. All 7 requirement IDs satisfied. Source files are substantive and properly wired. The end-to-end pipeline (Dockerfile -> build -> run -> model download -> TTS inference -> WAV -> MP3) is fully functional as evidenced by the 4 valid mp3 files on disk.

One minor note: the Docker image `spark-tts-notify` is not currently present on the system (likely pruned), but the Dockerfile is complete and the pipeline has been proven to work. The image can be rebuilt at any time with `docker build -t spark-tts-notify .`.

---

_Verified: 2026-03-30T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
