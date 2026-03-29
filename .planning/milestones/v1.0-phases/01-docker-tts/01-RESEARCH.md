# Phase 1: Docker TTS Environment - Research

**Researched:** 2026-03-30
**Domain:** Docker-containerized TTS audio generation (Spark-TTS 0.5B) for Claude Code notification hooks
**Confidence:** HIGH

## Summary

This phase builds a Docker image containing Spark-TTS 0.5B inference environment, generates 4 Chinese notification WAV files using voice creation mode (female, low pitch, low speed), converts them to MP3 via ffmpeg, and outputs them to `~/.claude/notify-*.mp3`. The critical discovery during research is that the official `cli/inference.py` has a `--device` parameter typed as `int` (not `str`), so `--device cpu` would fail -- instead the CLI auto-detects CPU when no GPU is available. The official `requirements.txt` includes `gradio==5.18.0` which is unnecessary for CLI-only use and adds ~500MB; the Dockerfile should use a custom requirements file excluding it.

Another important finding: Spark-TTS CLI output files are named by timestamp (`{YYYYMMDDHHMMSS}.wav`), not by user-specified name. To achieve the required output naming (`notify-complete.mp3`, etc.), a wrapper script inside the container must rename/convert after generation. The architecture uses a Python wrapper script (`generate.py`) that calls the SparkTTS class directly (not the CLI entry point), giving full control over file naming and batch processing.

**Primary recommendation:** Build a single-stage Docker image with a custom `generate.py` script that calls `SparkTTS.inference()` directly, converts WAV to MP3 via ffmpeg subprocess, and writes named output files. Use a custom requirements.txt that excludes gradio.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Model weights stored on host at `~/.cache/spark-tts/`, Docker loads via volume mount
- **D-02:** First run auto-downloads model (huggingface-cli or Spark-TTS download logic), subsequent runs reuse cache
- **D-03:** Model weights NOT baked into Docker image layers (~3.95GB, avoid image bloat)
- **D-04:** Use Spark-TTS built-in CLI: `python -m cli.inference --text "..." --gender female --pitch low --speed low`
- **D-05:** 4 fixed texts: task complete, please confirm, error, in progress
- **D-06:** WAV to mp3 conversion using ffmpeg (libmp3lame, -qscale:a 2 high quality)
- **D-07:** Output filenames: `notify-complete.mp3`, `notify-confirm.mp3`, `notify-error.mp3`, `notify-progress.mp3`
- **D-08:** Output directory via volume mount mapped to host `~/.claude/`
- **D-09:** Base image `python:3.12-slim` (not Alpine, PyTorch incompatible with musl)
- **D-10:** PyTorch CPU-only version (`--index-url https://download.pytorch.org/whl/cpu`), saves ~2GB
- **D-11:** Install ffmpeg and libsndfile1 (soundfile/torchaudio dependency)
- **D-12:** `protobuf>=4.21.0` as safety dependency (not in Spark-TTS requirements.txt but needed)

### Claude's Discretion

- Dockerfile specific layer structure, build optimization (cache layers, etc.)
- ffmpeg conversion parameter tuning (sample rate, bitrate)
- Model auto-download specific implementation (huggingface-cli vs Spark-TTS built-in logic)

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCKER-01 | Dockerfile based on python:3.12-slim with PyTorch CPU + Spark-TTS + ffmpeg | Standard Stack section provides exact Dockerfile pattern and dependency list |
| DOCKER-02 | Model weights (~3.95GB) loaded via volume mount, not in image layers | Architecture Patterns section documents volume mount strategy |
| DOCKER-03 | Docker image executes Spark-TTS inference and outputs WAV | Code Examples section shows exact inference call pattern |
| AUDIO-01 | Generate 4 notification voices with specific Chinese text | Code Examples section provides batch generation pattern |
| AUDIO-02 | WAV output converted to mp3 via ffmpeg | Code Examples section shows ffmpeg conversion command |
| AUDIO-03 | Audio files output to `~/.claude/notify-*.mp3` | Architecture Patterns section documents volume mount to ~/.claude/ |
| AUDIO-04 | Voice style: female, low pitch, low speed | Code Examples section shows exact parameter values |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python | 3.12 | Runtime for Spark-TTS | Officially specified; required by transformers and PyTorch 2.5.1 |
| PyTorch | 2.5.1+cpu | ML inference engine | Pinned in Spark-TTS requirements.txt; CPU-only saves ~2GB |
| torchaudio | 2.5.1+cpu | Audio processing | Pinned in requirements.txt; needed for audio I/O |
| transformers | 4.46.2 | Model loading (Qwen2.5 tokenizer) | Pinned in requirements.txt |
| Spark-TTS | main branch | TTS model and inference code | Core TTS engine; voice creation via Qwen2.5 architecture |
| ffmpeg | 7.x (system pkg) | WAV to mp3 conversion | Required for soundfile/torchaudio; provides libmp3lame encoder |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| huggingface_hub | 0.29.2+ | Model download from HuggingFace | Model auto-download (D-02); NOT in official requirements.txt but needed |
| protobuf | >=4.21.0 | Transformers tokenizer serialization | Safety dependency per D-12; intermittent failures without it |
| safetensors | 0.5.2 | Safe model weight loading | Pinned in requirements.txt |
| einops | 0.8.1 | Tensor manipulation | Pinned in requirements.txt |
| einx | 0.3.0 | Extended tensor notation | Pinned in requirements.txt |
| omegaconf | 2.3.0 | YAML configuration loading | Pinned in requirements.txt |
| soundfile | 0.12.1 | WAV file I/O | Pinned in requirements.txt |
| soxr | 0.5.0.post1 | High-quality audio resampling | Pinned in requirements.txt |
| numpy | 2.2.3 | Numerical computation | Pinned in requirements.txt |
| tqdm | 4.66.5 | Progress bars | Pinned in requirements.txt |
| packaging | 24.2 | Package version parsing | Pinned in requirements.txt |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| python:3.12-slim | python:3.12-alpine | Alpine uses musl; PyTorch wheels built for glibc. Do NOT use Alpine |
| CPU PyTorch (2.5.1+cpu) | CUDA PyTorch (2.5.1+cu124) | CUDA adds ~2GB image, needs NVIDIA driver. Notification audio not latency-critical |
| Custom generate.py wrapper | Direct CLI `python -m cli.inference` | CLI auto-names files by timestamp; wrapper gives control over output naming |
| huggingface_hub download | Manual wget of model files | huggingface_hub handles resumption, integrity checks, and correct file structure |

**Installation:**

Dockerfile installs everything; no host pip installs needed. Host only needs Docker and ffmpeg (already available).

**Version verification:** All pinned versions confirmed from official `requirements.txt` fetched via GitHub API on 2026-03-30. The official requirements.txt also includes `gradio==5.18.0` which should be EXCLUDED from the Docker image (unnecessary for CLI-only, adds ~500MB).

## Architecture Patterns

### Recommended Project Structure

```
notify-research/
├── Dockerfile                  # Docker build for Spark-TTS inference env
├── requirements.txt            # Custom deps (excludes gradio, adds huggingface_hub, protobuf)
├── generate.py                 # Batch TTS generation script (runs inside container)
└── (Phase 2 will add notify-generate.sh)
```

### Pattern 1: Voice Creation Mode (No Reference Audio)

**What:** Spark-TTS supports two modes -- voice cloning (requires reference audio) and voice creation (generates from gender/pitch/speed parameters). When `gender is not None`, the `inference()` method calls `process_prompt_control()` instead of `process_prompt()`, generating style tokens from the parameters instead of extracting them from reference audio.

**When to use:** Always for this project. No reference audio available; we generate voices from parameters.

**Source:** Verified from `cli/SparkTTS.py` fetched via GitHub API on 2026-03-30.

```python
# From SparkTTS.inference() method:
if gender is not None:
    prompt = self.process_prompt_control(gender, pitch, speed, text)
else:
    prompt, global_token_ids = self.process_prompt(text, prompt_speech_path, prompt_text)
```

**Parameter values (verified from argparse in cli/inference.py):**
- `--gender`: `"male"` or `"female"`
- `--pitch`: `"very_low"`, `"low"`, `"moderate"`, `"high"`, `"very_high"`
- `--speed`: `"very_low"`, `"low"`, `"moderate"`, `"high"`, `"very_high"`

### Pattern 2: Batch Generation with Named Output

**What:** A Python script (`generate.py`) that imports the `SparkTTS` class directly (not via `python -m cli.inference`) to gain full control over output file naming and batch processing. The script generates 4 WAV files, converts each to MP3, and writes them to the mounted output directory.

**When to use:** This is the core pattern for Phase 1. The official CLI names output files by timestamp (`{YYYYMMDDHHMMSS}.wav`), which does not match the required naming convention (`notify-complete.mp3`, etc.).

**Why not use the CLI directly:** The CLI (D-04) uses `sf.write(save_path, wav, samplerate=16000)` with a timestamp-based filename. To get the required named output, a wrapper script must either: (a) rename the CLI output, or (b) call the API directly. Option (b) is cleaner.

**IMPORTANT note on D-04:** The context decision D-04 specifies using the CLI (`python -m cli.inference`). However, the CLI does not support custom output filenames. The planner should decide between:
1. Use a wrapper script that calls the CLI and renames the output file afterward
2. Use a wrapper script that imports `SparkTTS` directly and controls output naming

Both approaches satisfy the spirit of D-04 (using Spark-TTS inference). Option 2 is recommended for cleanliness.

### Pattern 3: Volume Mount for Models and Output

**What:** Two Docker volume mounts:
1. Host `~/.cache/spark-tts/` -> Container `/app/pretrained_models/Spark-TTS-0.5B` (model weights, D-01)
2. Host `~/.claude/` -> Container `/output/` (mp3 output files, D-08)

**When to use:** Always. Models are ~3.95GB and must not be in image layers (D-03). Output must land at `~/.claude/` for hooks to find.

### Anti-Patterns to Avoid

- **Using Alpine base image:** PyTorch wheels are compiled against glibc, not musl. Will fail at import time.
- **Baking model into image:** ~3.95GB of model weights in Docker layers makes image huge and updates painful.
- **Including gradio:** Official requirements.txt includes `gradio==5.18.0` for the web UI. We only need CLI inference. Exclude it to save ~500MB.
- **Passing `--device cpu` to CLI:** The `--device` parameter is typed as `int`, not `str`. Passing `--device cpu` would crash. Omit `--device` entirely -- the CLI auto-detects CPU when no GPU is available.
- **Running TTS on-demand in hooks:** CPU inference takes ~8 minutes per sentence. Hooks must play pre-generated MP3 files.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MP3 encoding | Custom Python WAV-to-MP3 | ffmpeg (`ffmpeg -i input.wav -codec:a libmp3lame -qscale:a 2 output.mp3`) | ffmpeg handles codec negotiation, quality optimization, and edge cases |
| Model download with resume | Custom wget/curl with checksum | `huggingface_hub.snapshot_download()` | Handles resumption, integrity verification, and correct directory structure |
| Audio file I/O | Custom WAV writer | `soundfile.write(path, wav, samplerate=16000)` | Handles PCM encoding, byte order, and metadata |

**Key insight:** The SparkTTS class itself is the complex piece -- model loading, token generation, codec decoding. Do NOT re-implement any of it. Call `SparkTTS.inference()` and let it handle all the ML complexity.

## Common Pitfalls

### Pitfall 1: `--device` Parameter Type Mismatch

**What goes wrong:** Passing `--device cpu` to `python -m cli.inference` causes `argparse` error: `argument --device: invalid int value: 'cpu'`. The parameter is typed as `type=int`, default `0`.

**Why it happens:** The CLI was written assuming GPU availability. The CPU fallback is internal logic that triggers when `torch.cuda.is_available()` returns False.

**How to avoid:** Omit `--device` entirely when running on CPU. The code auto-detects:
```python
# From cli/inference.py line ~55:
if torch.cuda.is_available():
    device = torch.device(f"cuda:{args.device}")
else:
    device = torch.device("cpu")
```

**Warning signs:** `argparse` error about invalid int value for `--device`.

### Pitfall 2: Timestamp-Based Output Filenames

**What goes wrong:** Running the CLI produces files like `20260330123456.wav` in the save directory. You cannot control the output filename through CLI arguments.

**Why it happens:** The CLI hardcodes timestamp-based naming:
```python
timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
save_path = os.path.join(args.save_dir, f"{timestamp}.wav")
```

**How to avoid:** Use a wrapper script that either calls the API directly (recommended) or renames the output file after CLI invocation.

### Pitfall 3: Missing `huggingface_hub` in Official Requirements

**What goes wrong:** First-time model download fails because `huggingface_hub` is not installed. The official `requirements.txt` does NOT include it.

**Why it happens:** The official requirements.txt assumes model weights are already downloaded. For first-run auto-download (D-02), we need `huggingface_hub` explicitly.

**How to avoid:** Include `huggingface_hub>=0.29.0` in the custom requirements.txt.

### Pitfall 4: `libsndfile1` System Dependency Missing

**What goes wrong:** `soundfile` (Python package) fails to import with error about missing `libsndfile` shared library.

**Why it happens:** The `soundfile` Python package is a binding for libsndfile, which must be installed as a system package. It is not pip-installable.

**How to avoid:** Include `libsndfile1` in the Dockerfile apt-get install. The `python:3.12-slim` base image does not include it.

### Pitfall 5: Model Directory Structure Mismatch

**What goes wrong:** Spark-TTS fails to load model because directory structure does not match expectations. The model expects `LLM/`, `BiCodec/`, and `wav2vec2-large-xlsr-53/` subdirectories under the model root.

**Why it happens:** `snapshot_download("SparkAudio/Spark-TTS-0.5B")` creates the correct structure automatically. But if models are downloaded manually or volume-mounted incorrectly, the structure can be wrong.

**How to avoid:** Use `huggingface_hub.snapshot_download()` for download. For volume mounting, ensure the mount point is exactly at the model root directory (not a parent).

## Code Examples

### Custom requirements.txt (excludes gradio, adds needed deps)

```
# PyTorch CPU-only (installed separately via --index-url)
# torch==2.5.1
# torchaudio==2.5.1

# From official requirements.txt (excluding gradio)
einops==0.8.1
einx==0.3.0
numpy==2.2.3
omegaconf==2.3.0
packaging==24.2
safetensors==0.5.2
soundfile==0.12.1
soxr==0.5.0.post1
tqdm==4.66.5
transformers==4.46.2

# NOT included: gradio==5.18.0 (unnecessary for CLI, saves ~500MB)

# Additional deps for Docker environment
huggingface_hub>=0.29.0  # Model auto-download (not in official requirements.txt)
protobuf>=4.21.0         # Safety dependency for transformers (D-12)
```

### generate.py -- Batch TTS Generation Script

```python
"""Generate notification audio files using Spark-TTS voice creation mode.

Source: SparkTTS class API verified from cli/SparkTTS.py (GitHub API, 2026-03-30)
"""
import os
import subprocess
import torch
import soundfile as sf
from cli.SparkTTS import SparkTTS

# Voice creation parameters (D-04:温柔低沉慵懒)
VOICE_PARAMS = {
    "gender": "female",
    "pitch": "low",
    "speed": "low",
}

# 4 notification definitions (D-05)
NOTIFICATIONS = [
    {"name": "complete",  "text": "主人，任务完成了"},
    {"name": "confirm",   "text": "主人，请确认一下"},
    {"name": "error",     "text": "主人，出错了"},
    {"name": "progress",  "text": "主人，还在进行中"},
]

MODEL_DIR = os.environ.get("MODEL_DIR", "pretrained_models/Spark-TTS-0.5B")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/output")

def generate_one(model: SparkTTS, text: str, wav_path: str) -> None:
    """Generate a single WAV file using voice creation mode."""
    with torch.no_grad():
        wav = model.inference(
            text=text,
            gender=VOICE_PARAMS["gender"],
            pitch=VOICE_PARAMS["pitch"],
            speed=VOICE_PARAMS["speed"],
        )
    sf.write(wav_path, wav, samplerate=16000)

def wav_to_mp3(wav_path: str, mp3_path: str) -> None:
    """Convert WAV to MP3 using ffmpeg (D-06: libmp3lame, -qscale:a 2)."""
    subprocess.run([
        "ffmpeg", "-y", "-i", wav_path,
        "-codec:a", "libmp3lame", "-qscale:a", "2",
        mp3_path
    ], check=True, capture_output=True)

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Auto-detect device (same logic as cli/inference.py)
    if torch.cuda.is_available():
        device = torch.device("cuda:0")
    else:
        device = torch.device("cpu")

    model = SparkTTS(MODEL_DIR, device)

    for notif in NOTIFICATIONS:
        wav_path = os.path.join(OUTPUT_DIR, f"notify-{notif['name']}.wav")
        mp3_path = os.path.join(OUTPUT_DIR, f"notify-{notif['name']}.mp3")

        print(f"Generating: {notif['name']} -- {notif['text']}")
        generate_one(model, notif["text"], wav_path)
        wav_to_mp3(wav_path, mp3_path)
        os.remove(wav_path)  # Clean up intermediate WAV
        print(f"  -> {mp3_path}")

    print("All notifications generated.")

if __name__ == "__main__":
    main()
```

### Dockerfile

```dockerfile
FROM python:3.12-slim

# System dependencies (D-11: ffmpeg + libsndfile1)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# PyTorch CPU-only (D-10: --index-url to avoid CUDA bloat)
RUN pip install --no-cache-dir \
    torch==2.5.1 torchaudio==2.5.1 \
    --index-url https://download.pytorch.org/whl/cpu

# Spark-TTS Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Spark-TTS source (both cli/ and sparktts/ packages needed)
COPY cli/ /app/cli/
COPY sparktts/ /app/sparktts/
COPY generate.py /app/

WORKDIR /app
RUN mkdir -p /output
```

### Docker Run Command

```bash
# Generate all 4 notification audio files
docker run --rm \
    -v ~/.cache/spark-tts/:/app/pretrained_models/Spark-TTS-0.5B \
    -v ~/.claude/:/output/ \
    spark-tts-notify \
    python generate.py

# With model auto-download on first run:
# The generate.py script should check if model dir is empty and download if needed.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GPU-only inference | CPU auto-detection fallback | Spark-TTS main branch (2025) | CLI works without GPU; just omit --device |
| Voice cloning only | Voice creation mode | Issue #10 (2025) | Can generate voice from gender/pitch/speed without reference audio |
| Model weights in image | Volume mount from host | Community PR #40 (2025) | Image stays ~1.4GB; models ~3.95GB cached on host |

**Deprecated/outdated:**
- `torchvision`: NOT needed for Spark-TTS inference. Earlier STACK.md listed it but official requirements.txt does not include it. Omit from Docker image.
- `gradio==5.18.0`: Included in official requirements.txt for web UI. Exclude for CLI-only Docker image to save ~500MB.

## Open Questions

1. **Model auto-download implementation**
   - What we know: `huggingface_hub.snapshot_download("SparkAudio/Spark-TTS-0.5B")` downloads all model files to correct directory structure
   - What's unclear: Should download happen inside the container at runtime (first docker run), or as a separate setup step on the host?
   - Recommendation: Implement a small Python helper that checks if model dir is populated and downloads if not. This can run either on host (before docker run) or inside the container. Running inside the container is simpler for the user but requires `huggingface_hub` in the image.

2. **generate.py vs CLI wrapper for D-04 compliance**
   - What we know: D-04 says "use Spark-TTS built-in CLI: `python -m cli.inference`"
   - What's unclear: The CLI does not support custom output filenames. A generate.py wrapper that imports SparkTTS directly bypasses the CLI.
   - Recommendation: Use generate.py (imports SparkTTS directly). The CLI is a thin wrapper around the same API. This satisfies the spirit of D-04 (using Spark-TTS inference) while enabling proper output naming. The planner should confirm this approach with the user or make the call as Claude's Discretion.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | Container runtime | Yes | 29.3.0 | -- |
| ffmpeg (host) | Audio playback verification | Yes | 7.1.2 | -- |
| `~/.claude/` directory | Output destination (D-08) | Yes | -- | mkdir -p |
| Python 3.12 in Docker | Spark-TTS runtime | Yes (via image) | 3.12 | -- |
| `~/.cache/spark-tts/` | Model cache (D-01) | No (not yet) | -- | Auto-create on first run |
| `/tmp/Spark-TTS/` | Previous manual install | No (removed) | -- | Fresh download via huggingface_hub |

**Missing dependencies with no fallback:**
- None -- all critical dependencies are available.

**Missing dependencies with fallback:**
- `~/.cache/spark-tts/` does not exist yet; the plan should include model download step that creates this directory.

## Validation Architecture

> SKIPPED: `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

## Sources

### Primary (HIGH confidence)
- GitHub API fetch of `cli/inference.py` (2026-03-30) -- verified --device type=int, auto-detect CPU, timestamp-based output naming, soundfile.write at 16kHz
- GitHub API fetch of `cli/SparkTTS.py` (2026-03-30) -- verified voice creation mode (process_prompt_control), parameter values, inference() signature
- GitHub API fetch of `requirements.txt` (2026-03-30) -- verified exact pinned versions, confirmed gradio inclusion, confirmed no huggingface_hub
- `.planning/research/STACK.md` -- dependency versions and Docker build patterns
- `.planning/research/ARCHITECTURE.md` -- system architecture, data flow, component boundaries

### Secondary (MEDIUM confidence)
- Spark-TTS Docker PR #40 (breakstring) -- community Dockerfile patterns
- SparkAudio/Spark-TTS-0.5B HuggingFace model card -- model size, download instructions

### Tertiary (LOW confidence)
- None in this research round

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified against official requirements.txt via GitHub API
- Architecture: HIGH - verified against actual source code of cli/inference.py and cli/SparkTTS.py
- Pitfalls: HIGH - all pitfalls verified against actual source code behavior

**Research date:** 2026-03-30
**Valid until:** 30 days (stable dependencies, pinned versions)
