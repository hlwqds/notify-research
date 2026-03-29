# Architecture Research

**Domain:** Docker-containerized TTS audio generation CLI tool for Claude Code voice notifications
**Researched:** 2026-03-30
**Confidence:** HIGH

## Standard Architecture

### System Overview

This system has 4 distinct components with clear boundaries. It is NOT a long-running service -- it is a one-shot batch pipeline: build Docker image once, run container to generate audio files, files land on host for hooks to play.

```
+-----------------------------------------------------------+
|                     Host Machine (Linux/Fedora)              |
+-----------------------------------------------------------+
|                                                              |
|  +-------------------------+    +-------------------------+ |
|  |  1. Shell Orchestrator  |    |  4. Claude Code Hooks   | |
|  |  (notify-generate.sh)   |    |  (~/.claude/settings)   | |
|  |                         |    |                         | |
|  |  - docker build         |    |  - paplay ~/.claude/    | |
|  |  - docker run           |    |    notify-*.mp3         | |
|  |  - ffmpeg conversion    |    |  - PostToolUse trigger  | |
|  +----------+--------------+    +------------+------------+ |
|             |                                ^              |
|             | docker run                     | reads mp3     |
|             v                                |              |
|  +----------+-------------------------------++-----------+  |
|  |               2. Docker Container                        |  |
|  |                                                        |  |
|  |  +-------------------+  +----------------------------+ |  |
|  |  | 2a. TTS Engine    |  | 2b. Python Inference      | |  |
|  |  | Spark-TTS 0.5B    |  | (cli.SparkTTS wrapper)    | |  |
|  |  |                   |  |                            | |  |
|  |  | - Qwen2.5 base   |  | - text -> wav generation   | |  |
|  |  | - voice creation  |  | - gender/pitch/speed ctrl  | |  |
|  |  |   mode (no ref)   |  | - batch 4 notifications    | |  |
|  |  +-------------------+  +----------------------------+ |  |
|  |                                                        |  |
|  +----------------------------+---------------------------+ |
|             |                                            |
|             | volume mount: /output -> ~/.claude/         |
|             v                                            |
|  +----------+----------------------------+              |
|  |  3. Audio Pipeline                  |              |
|  |                                     |              |
|  |  - Spark-TTS outputs .wav (16kHz)  |              |
|  |  - ffmpeg converts .wav -> .mp3    |              |
|  |  - files land at ~/.claude/notify-* |              |
|  +-------------------------------------+              |
+-----------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Location | Communicates With |
|-----------|----------------|----------|-------------------|
| **Shell Orchestrator** | Build Docker image, run container, pass params, verify output | `notify-generate.sh` on host | Docker daemon, Claude Code hooks |
| **Docker Container** | Isolated Python/PyTorch environment with Spark-TTS model | Built from Dockerfile | Host via volume mounts |
| **TTS Engine** | Spark-TTS 0.5B model inference, voice creation mode | Inside container | Python wrapper script |
| **Audio Pipeline** | WAV generation (Spark-TTS) -> MP3 conversion (ffmpeg) | Inside container + host | Output directory via volume |

### Key Boundary: Container Isolation

The Docker container is the critical isolation boundary. Spark-TTS requires Python 3.12, PyTorch, and ~8.5GB of model weights. These must NEVER leak onto the host. The host only needs:
- Docker (already installed)
- `paplay` (PulseAudio, already available on Fedora)
- Shell script (bash)

Everything else runs inside the container.

## Recommended Project Structure

```
notify-research/
├── Dockerfile                  # Multi-stage: build Python deps + runtime
├── docker-compose.yml          # Optional: convenience wrapper
├── requirements.txt            # Python deps for TTS inference
├── generate.py                 # Main TTS generation script (runs inside container)
├── notify-generate.sh          # Host-side orchestration script (entry point for user)
├── notify-config.yaml          # Notification text definitions (4 notifications)
├── output/                     # Generated audio files (gitignored)
│   ├── notify-complete.mp3
│   ├── notify-confirm.mp3
│   ├── notify-error.mp3
│   └── notify-progress.mp3
└── pretrained_models/          # Model weights (downloaded on first build)
    └── Spark-TTS-0.5B/
```

### Structure Rationale

- **`Dockerfile` at root**: Standard Docker convention; `docker build .` works from project root
- **`generate.py`**: Single Python script that runs inside the container. Calls Spark-TTS API in voice creation mode, handles batch generation of 4 notifications, converts WAV to MP3
- **`notify-generate.sh`**: User-facing entry point. Hides Docker complexity. One command: `./notify-generate.sh`
- **`notify-config.yaml`**: Declarative notification definitions. Each notification has: text (Chinese), filename, voice parameters. Easy to add/modify without touching code
- **`requirements.txt`**: Pinned Python dependencies for reproducibility inside Docker
- **`pretrained_models/`**: Model weights downloaded during Docker build (via huggingface_hub). Could alternatively use a Docker volume for model caching across builds

## Architectural Patterns

### Pattern 1: Voice Creation Mode (No Reference Audio)

**What:** Spark-TTS has two modes: voice cloning (requires reference audio) and voice creation (generates a voice from parameters). This project uses voice creation mode exclusively because there is no reference audio -- the goal is to generate notification sounds, not clone a specific speaker.

**When to use:** Always for this project. Voice creation mode is simpler and does not require a reference audio file.

**Trade-offs:**
- Pro: No reference audio needed, simpler pipeline
- Con: Voice is less controllable than cloning; `--gender female --pitch low --speed low` gives a "gentle, low-pitched, relaxed" voice but results may vary between runs
- Con: Each invocation may produce a slightly different voice (unless `--seed` is specified)

**Key API parameters for voice creation:**

```python
# From Spark-TTS issue #10 and HuggingFace docs
model.inference(
    text="notification text here",
    prompt_speech_path=None,  # None = voice creation mode
    prompt_text=None,          # None = voice creation mode
    gender="female",           # "male" or "female"
    pitch="low",               # "very_low", "low", "moderate", "high", "very_high"
    speed="low",               # "very_low", "low", "moderate", "high", "very_high"
)
```

**Parameter values confirmed from GitHub issue #10 (AcTePuKc's code):**
- `pitch_map = ["very_low", "low", "moderate", "high", "very_high"]`
- `speed_map = ["very_low", "low", "moderate", "high", "very_high"]`
- `gender`: `"male"` or `"female"` (NOT `"auto"` -- auto causes failure in creation mode)

**Confidence:** HIGH -- verified from official GitHub issue #10 and HuggingFace model card

### Pattern 2: Batch Pipeline (Not a Service)

**What:** This is a batch pipeline that runs once to generate all notification audio files. It is NOT a long-running TTS service or API server.

**When to use:** Always for this project. Spark-TTS CPU inference takes ~8 minutes per sentence on CPU (per PROJECT.md constraint). Running as an on-demand API service is not viable.

**Trade-offs:**
- Pro: Simple, no server management, no GPU requirements (can run on CPU)
- Pro: Audio files are static -- notification text does not change between runs
- Con: Generating audio takes ~32 minutes total (4 notifications x ~8 min each on CPU)
- Con: If notification text changes, must re-run the pipeline

**Example pipeline:**
```bash
# User runs once to generate all notifications
./notify-generate.sh

# Script does:
# 1. docker build -t spark-tts-notify .
# 2. docker run spark-tts-notify python generate.py --config notify-config.yaml
# 3. Copies output/notify-*.mp3 to ~/.claude/
```

### Pattern 3: Multi-Stage Docker Build

**What:** Use Docker multi-stage builds to separate the heavy build environment (compilers, full PyTorch) from the lean runtime. Since Spark-TTS needs PyTorch for inference (not compilation), a multi-stage build mainly helps with image hygiene and layer caching.

**When to use:** Recommended for this project. PyTorch + model weights create large images. Multi-stage helps control this.

**Trade-offs:**
- Pro: Smaller final image if build-time-only deps can be separated
- Pro: Better Docker layer caching (requirements.txt changes don't invalidate everything)
- Con: PyTorch runtime is large regardless (~4GB with CUDA libs) -- savings from multi-stage are modest
- Con: Adds Dockerfile complexity

**Recommended approach:** Single-stage is pragmatic here. PyTorch is needed at runtime, and the model weights (~1.6GB for 0.5B) are the dominant size factor, not build deps. Multi-stage is worth doing if:
1. You want to cache pip installs separately from model downloads
2. You want to strip down to CPU-only PyTorch at runtime (save ~2GB vs CUDA)

```dockerfile
# Stage 1: Download model (cached separately)
FROM python:3.12-slim AS model-fetch
RUN pip install --no-cache-dir huggingface_hub
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('SparkAudio/Spark-TTS-0.5B', local_dir='/models/Spark-TTS-0.5B')"

# Stage 2: Runtime
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*
COPY --from=model-fetch /models /app/pretrained_models
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY generate.py /app/
WORKDIR /app
ENTRYPOINT ["python", "generate.py"]
```

### Pattern 4: Volume Mount for Output

**What:** Mount the host's `~/.claude/` directory into the container's `/output/` directory. Generated MP3 files are written directly to the host filesystem without needing `docker cp`.

**When to use:** Always. This is the standard pattern for getting batch output from containers to host.

**Trade-offs:**
- Pro: Simple, no post-processing step needed
- Pro: Files land directly where Claude Code hooks expect them
- Con: Container has write access to `~/.claude/` (mitigated: container is ephemeral, runs only when user explicitly invokes)

```bash
docker run -v ~/.claude:/output spark-tts-notify
# Container writes /output/notify-complete.mp3
# Which appears as ~/.claude/notify-complete.mp3 on host
```

## Data Flow

### Generation Pipeline Flow

```
User runs: ./notify-generate.sh
    |
    v
[1. Shell Orchestrator]
    |-- Checks Docker is installed
    |-- Checks ~/.claude/ directory exists
    |-- Reads notify-config.yaml
    |
    v
[2. Docker Build]
    |-- Stage 1: Download Spark-TTS 0.5B model weights (~1.6GB)
    |-- Stage 2: Install Python 3.12 + PyTorch + Spark-TTS deps + ffmpeg
    |   (Cached after first build -- subsequent builds are fast)
    |
    v
[3. Docker Run]
    |-- Mount ~/.claude/ -> /output/
    |-- Pass notification config as arguments or mounted file
    |-- Container starts, runs generate.py
    |
    v
[4. TTS Generation (inside container)]
    |
    For each notification in config:
    |
    [4a. Load Model]
    |   |-- Load Spark-TTS 0.5B from /app/pretrained_models/
    |   |-- Move to CPU device (no GPU required)
    |   (Load once, reuse for all notifications)
    |
    [4b. Generate WAV]
    |   |-- Call model.inference(text, gender="female", pitch="low", speed="low")
    |   |-- Output: numpy array at 16kHz sample rate
    |   |-- Save to temp .wav file
    |   (Takes ~8 min per notification on CPU)
    |
    [4c. Convert to MP3]
    |   |-- ffmpeg -i temp.wav -q:a 2 /output/notify-{name}.mp3
    |   |-- MP3 appears at ~/.claude/notify-{name}.mp3 on host
    |
    v
[5. Post-Generation Verification]
    |-- Shell script checks: ~/.claude/notify-*.mp3 files exist
    |-- Optionally plays each file to verify audio quality
    |-- Reports success/failure
    |
    v
[6. Claude Code Hooks (at runtime)]
    |-- Hooks trigger on PostToolUse/Notification events
    |-- Execute: paplay ~/.claude/notify-confirm.mp3 2>/dev/null &
    |-- PulseAudio plays the MP3 through speakers
```

### Key Data Transformations

```
Notification Text (Chinese string)
    |
    v [Spark-TTS model.inference()]
Raw Audio (numpy float32 array, 16kHz)
    |
    v [soundfile.write()]
WAV File (16-bit PCM, 16kHz, mono)
    |
    v [ffmpeg -i wav -q:a 2]
MP3 File (compressed, ~30-100KB for 2-3 second notification)
    |
    v [paplay]
Audio Output (speakers via PulseAudio)
```

### Volume Mount Points

| Host Path | Container Path | Purpose | Direction |
|-----------|---------------|---------|-----------|
| `~/.claude/` | `/output/` | MP3 output files | Write (container -> host) |
| `./notify-config.yaml` | `/app/notify-config.yaml` | Notification definitions | Read (host -> container) |
| `./pretrained_models/` (optional) | `/app/pretrained_models/` | Cached model weights | Read (host -> container) |

**Alternative for model caching:** Use a Docker named volume for model weights so they persist across `docker build` runs:
```bash
docker volume create spark-tts-models
docker run -v spark-tts-models:/app/pretrained_models -v ~/.claude:/output spark-tts-notify
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **Single user, 4 notifications** | Single container, CPU-only, batch generation. No scaling needed. |
| **Multiple notification sets** | Parameterize notify-config.yaml. Add `--set` flag to orchestrator script. |
| **Shared across machines** | Publish Docker image to registry. `notify-generate.sh` pulls image instead of building. |
| **Faster generation needed** | Add GPU support: `docker run --gpus all`. Inference drops from ~8 min to ~1 sec per notification (0.136 RTF on L20 GPU per official benchmarks). |

### Scaling Priorities

1. **First bottleneck:** CPU inference time (~8 min per notification). Mitigation: use `--seed` for reproducibility so regeneration is only needed when text changes. With GPU, this disappears entirely.
2. **Second bottleneck:** Model download time (~1.6GB). Mitigation: Docker named volume for model caching; only download once.

## Anti-Patterns

### Anti-Pattern 1: Running TTS as a Long-Running Service

**What people do:** Wrap Spark-TTS in a Flask/FastAPI server for on-demand TTS generation.

**Why it's wrong:** Spark-TTS takes ~8 minutes per sentence on CPU. An on-demand API is unusably slow without GPU. The notification text is fixed (4 predefined strings), so there is no need for on-demand generation.

**Do this instead:** Pre-generate all audio files in a batch run. Play static MP3 files from hooks. This is simple, reliable, and fast at runtime (MP3 playback is instant).

### Anti-Pattern 2: Baking Model Weights into Docker Image

**What people do:** `COPY pretrained_models/ /app/pretrained_models/` in Dockerfile, then commit the ~1.6GB model directory to the repo.

**Why it's wrong:** 1.6GB of model weights in git makes clones painful. Docker image layers bloat. Every `docker build` re-copies weights.

**Do this instead:** Download model weights in a separate Docker build stage (cached layer) or use a Docker volume for model storage. Keep model weights out of the git repo (`.gitignore`).

### Anti-Pattern 3: Generating Real-Time TTS in Hooks

**What people do:** Hook triggers TTS generation directly: `python generate_tts.py "Task complete"` inside a PostToolUse hook.

**Why it's wrong:** The hook has a timeout. Spark-TTS takes ~8 minutes on CPU. The hook would time out or block Claude Code for an unacceptable duration.

**Do this instead:** Pre-generate audio files. Hooks only play back static MP3 files with `paplay` (instant, <1 second).

### Anti-Pattern 4: Using Voice Cloning Mode Without Reference Audio

**What people do:** Pass `--prompt_speech_path=""` or omit it entirely and expect voice cloning to work.

**Why it's wrong:** Voice cloning requires a 5-20 second reference audio clip. Without it, the model either fails or produces random/chaotic voice output. The `--gender` parameter alone (without reference audio) activates "voice creation" mode, which is what this project needs.

**Do this instead:** Explicitly use voice creation mode by passing `gender="female"` (or `"male"`) with `pitch` and `speed` parameters, and leaving `prompt_speech_path=None`. Do not pass a prompt_speech_path if you have no reference audio.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **Hugging Face Hub** | Model download during Docker build | `huggingface_hub.snapshot_download("SparkAudio/Spark-TTS-0.5B")`. Requires internet during build. Cache with Docker volume or build stage. |
| **PulseAudio** | Host-side audio playback via `paplay` | Already available on Fedora. Hooks use `paplay ~/.claude/notify-*.mp3 2>/dev/null &` (backgrounded, errors suppressed). |
| **Claude Code Hooks** | Reads static MP3 files from `~/.claude/` | Hooks already configured in `~/.claude/settings.json`. No code changes needed in hooks -- just ensure MP3 files exist. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|------------|
| **Shell script -> Docker** | `docker build` and `docker run` CLI | Script orchestrates container lifecycle |
| **Host filesystem -> Container** | Docker volume mounts | Output directory mounted for file transfer |
| **generate.py -> Spark-TTS** | Python API call (`model.inference()`) | Direct function call, no HTTP needed |
| **Spark-TTS -> ffmpeg** | Filesystem (temp WAV) | generate.py writes WAV, calls ffmpeg subprocess to convert |

## Build Order and Dependencies

```
Phase 1: Dockerfile + Base Environment
    |-- Python 3.12 base image
    |-- ffmpeg installation
    |-- requirements.txt (PyTorch, transformers, soundfile, etc.)
    Depends on: Nothing
    Blocks: Everything else

Phase 2: Model Acquisition
    |-- Download Spark-TTS 0.5B model weights
    |-- Verify model integrity
    Depends on: Phase 1 (Docker build environment)
    Blocks: Phase 3

Phase 3: TTS Generation Script (generate.py)
    |-- Load model
    |-- Voice creation API call
    |-- WAV output
    |-- MP3 conversion via ffmpeg
    Depends on: Phase 1 (Python deps), Phase 2 (model weights)
    Blocks: Phase 4

Phase 4: Shell Orchestration (notify-generate.sh)
    |-- Docker build
    |-- Docker run with volume mounts
    |-- Post-generation verification
    Depends on: Phase 3 (generate.py exists in image)
    Blocks: Nothing (this is the user entry point)

Phase 5: Claude Code Hooks Integration
    |-- Verify hooks in ~/.claude/settings.json
    |-- Verify MP3 files in ~/.claude/
    Depends on: Phase 4 (audio files generated)
    Blocks: Nothing
```

**Recommended implementation order:** 1 -> 2 -> 3 -> 4 -> 5

**Note on Phase 1-3:** These all happen inside the Docker container. The user does not interact with them directly. Phase 4 is the only user-facing component.

## Notification Configuration Schema

```yaml
# notify-config.yaml
notifications:
  - name: complete
    text: "任务已完成，请查看结果"  # Task complete, please check results
    filename: "notify-complete.mp3"
    voice:
      gender: female
      pitch: low
      speed: low

  - name: confirm
    text: "需要您确认操作"  # Needs your confirmation
    filename: "notify-confirm.mp3"
    voice:
      gender: female
      pitch: low
      speed: low

  - name: error
    text: "执行出错，请检查"  # Error occurred, please check
    filename: "notify-error.mp3"
    voice:
      gender: female
      pitch: low
      speed: low

  - name: progress
    text: "正在处理中"  # Processing
    filename: "notify-progress.mp3"
    voice:
      gender: female
      pitch: low
      speed: low
```

## License Consideration

**Important:** Spark-TTS model weights are licensed under **CC BY-NC-SA 4.0** (changed from Apache 2.0 in 2025 due to training data licensing). The inference code on GitHub remains Apache 2.0.

For this project (personal use, non-commercial voice notifications), CC BY-NC-SA 4.0 is compatible. But this must be documented and the LICENSE file should note:
- Code (generate.py, Dockerfile, shell script): Apache 2.0 (own code)
- Model weights (Spark-TTS 0.5B): CC BY-NC-SA 4.0 (third-party, non-commercial)

**Confidence:** HIGH -- verified from HuggingFace model card license notice and ModelScope page.

## Sources

- [Spark-TTS Official GitHub Repository](https://github.com/SparkAudio/Spark-Tts) -- Official inference code, installation instructions, voice creation mode documentation (HIGH confidence)
- [Spark-TTS 0.5B HuggingFace Model Card](https://huggingface.co/SparkAudio/Spark-TTS-0.5B) -- Model download instructions, CLI usage, license update notice (HIGH confidence)
- [Spark-TTS CLI Voice Creation Discussion (Issue #10)](https://github.com/SparkAudio/Spark-TTS/issues/10) -- Exact voice creation API parameters: gender, pitch, speed values (HIGH confidence)
- [Spark-TTS-cli-api Fork](https://github.com/dogarrowtype/Spark-TTS-cli-api) -- Alternative CLI implementation, confirms 8.5GB VRAM requirement and voice creation pattern (MEDIUM confidence)
- [claude-code-audio-hooks](https://github.com/ChanMeng666/claude-code-audio-hooks) -- Reference implementation for Claude Code audio notification hooks (MEDIUM confidence)
- [Spark-TTS License Change (ModelScope)](https://modelscope.cn/models/AI-ModelScope/Spark-TTS-0.5B) -- Confirms CC BY-NC-SA 4.0 license for model weights (HIGH confidence)
- Docker multi-stage build best practices -- [Python Speed](https://pythonspeed.com/articles/multi-stage-docker-python/), [StackOverflow](https://stackoverflow.com/questions/77712265) (MEDIUM confidence)

---
*Architecture research for: Claude Code voice notification TTS system*
*Researched: 2026-03-30*
