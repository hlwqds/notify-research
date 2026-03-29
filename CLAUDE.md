<!-- GSD:project-start source:PROJECT.md -->
## Project

**Claude Code 语音通知**

为 Claude Code 提供语音通知的系统。使用 Spark-TTS 0.5B 生成中文语音通知音频，通过 Claude Code hooks 在任务完成、需要用户交互、执行出错等场景自动播放提醒用户。

**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

### Constraints

- **性能**：Spark-TTS CPU 推理约 8 分钟/句，只能预生成不能实时合成
- **环境**：使用 Docker 容器化 Spark-TTS，消除宿主机依赖
- **平台**：Linux (Fedora)，使用 `paplay` 播放音频
- **许可**：Spark-TTS 使用 Apache 2.0 许可证
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Python** | 3.12 | Runtime for Spark-TTS | Officially specified in Spark-TTS README; required by transformers 4.46.2 and PyTorch 2.5.1 |
| **PyTorch** | 2.5.1+cpu | ML inference engine | Pinned in Spark-TTS requirements.txt; CPU-only variant saves ~2GB image size vs CUDA build |
| **torchvision** | 0.20.1+cpu | Vision utilities (required peer dep) | Accompanies PyTorch install; CPU-only variant |
| **torchaudio** | 2.5.1+cpu | Audio processing for TTS | Pinned in Spark-TTS requirements.txt; needed for audio I/O |
| **Spark-TTS** | latest (main branch) | TTS model and inference code | The core TTS engine; zero-shot voice cloning via Qwen2.5-based architecture |
| **ffmpeg** | 7.x (system package) | Audio format conversion and processing | Required for soundfile/torchaudio to handle WAV files; Debian package provides all codecs |
### Docker Image
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **python:3.12-slim** | Bookworm-based | Docker base image | glibc-compatible (required for PyTorch wheels); ~75MB base; official Python image. Alpine causes musl/glibc conflicts with PyTorch -- do NOT use Alpine |
| **Multi-stage build** | -- | Separate build and runtime layers | Strips build tools from final image; saves ~500MB+ |
### Spark-TTS Python Dependencies
| Package | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| transformers | 4.46.2 | Model loading (Qwen2.5 tokenizer) | HIGH -- pinned in official requirements.txt |
| safetensors | 0.5.2 | Safe model weight loading | HIGH -- pinned in official requirements.txt |
| einops | 0.8.1 | Tensor manipulation | HIGH -- pinned in official requirements.txt |
| einx | 0.3.0 | Extended tensor notation | HIGH -- pinned in official requirements.txt |
| omegaconf | 2.3.0 | YAML configuration loading | HIGH -- pinned in official requirements.txt |
| soundfile | 0.12.1 | WAV file I/O | HIGH -- pinned in official requirements.txt |
| soxr | 0.5.0.post1 | High-quality audio resampling | HIGH -- pinned in official requirements.txt |
| numpy | 2.2.3 | Numerical computation | HIGH -- pinned in Docker PR issue comment |
| tqdm | 4.66.5 | Progress bars | HIGH -- pinned in official requirements.txt |
| packaging | 24.2 | Package version parsing | HIGH -- pinned in official requirements.txt |
| huggingface_hub | 0.29.2+ | Model download from HuggingFace | HIGH -- needed for snapshot_download() |
| protobuf | 4.21.12 | Transformers tokenizer serialization | MEDIUM -- NOT in requirements.txt but needed in some Docker builds; intermittent failure reported |
### Shell / Orchestration Tooling
| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **bash** | 4.x+ | Orchestration script | Standard on Linux; used to invoke docker run with correct args |
| **docker** | 24.x+ | Container runtime | Required to run the Spark-TTS container |
| **mpv** or **paplay** | system | Audio playback | Linux audio player for Claude Code hook to play generated WAV files |
## Model Details
### Spark-TTS 0.5B Components
| Component | File | Size | Purpose |
|-----------|------|------|---------|
| LLM (Qwen2.5) | `LLM/model.safetensors` | 2.03 GB | Core language model for speech token generation |
| BiCodec | `BiCodec/model.safetensors` | 626 MB | Speech codec for token-to-audio reconstruction |
| Speaker Encoder | `wav2vec2-large-xlsr-53/pytorch_model.bin` | 1.27 GB | Speaker embedding for voice cloning |
| **Total** | -- | **~3.95 GB** | Download via huggingface_hub |
### Model Download
## Installation
### Docker Build
# ---- Build Stage ----
# System build dependencies
# Install CPU-only PyTorch first (separate index to avoid CUDA bloat)
# Install Spark-TTS Python dependencies
# Install huggingface_hub for model download
# ---- Runtime Stage ----
# Runtime system dependencies (ffmpeg for audio I/O)
# Copy Python packages from builder
# Copy Spark-TTS source
# Create model directory (mount models at runtime)
# Default: CLI inference mode
### requirements.txt (CPU inference)
# Core ML
# Tensor ops
# Audio
# Config
# Model download
# Fix: protobuf for transformers tokenizer (may be needed in Docker)
### CLI Usage (from Spark-TTS official docs)
# Generate audio from text (GPU)
# CPU inference (set device to "cpu")
### Docker Run
# Build
# Run with model volume mount
## Alternatives Considered
| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Base image** | python:3.12-slim | python:3.12-alpine | Alpine uses musl libc; PyTorch wheels are built against glibc. Would require compiling PyTorch from source, adding hours to build time |
| **PyTorch variant** | CPU-only (2.5.1+cpu) | CUDA 12.x (2.5.1+cu124) | Notification audio is not latency-critical; CPU saves ~2GB image size and eliminates NVIDIA driver dependency |
| **TTS model** | Spark-TTS 0.5B | Kokoro ONNX / Piper | Spark-TTS is specified in the milestone; alternatives would require different architecture. Kokoro/Piper are lighter but lack zero-shot voice cloning |
| **API layer** | CLI (python -m cli.inference) | FastAPI (breakstring/PR #40) | We need single-shot invocation from shell scripts, not a persistent HTTP service. The CLI entry point is simpler and has no extra dependencies |
| **Audio format** | WAV (default) | MP3 | Spark-TTS outputs WAV natively; MP3 encoding adds latency and complexity for a notification sound. WAV plays instantly via `paplay` or `mpv` |
| **Audio playback** | paplay (PipeWire/PulseAudio) | mpv / aplay | paplay is the standard PulseAudio/PipeWire command; available on all major Linux desktop distros. aplay is ALSA-only (no mixing) |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **python:3.12-alpine** | PyTorch wheels target glibc, not musl. Building PyTorch from source on Alpine adds hours. Known compatibility issues with numpy, soundfile, and other C-extension packages | python:3.12-slim (Debian Bookworm, glibc) |
| **CUDA-enabled PyTorch** | Adds ~2GB to image, requires NVIDIA Container Toolkit and GPU drivers. Overkill for notification audio generation | torch==2.5.1+cpu via PyTorch CPU index |
| **Gradio** | The webui.py uses Gradio which pulls in ~500MB of dependencies. We only need CLI inference, not a web UI | python -m cli.inference |
| **Model baked into image** | The breakstring Docker PR shows models duplicated across layers, inflating image from ~10GB to ~17GB for the "lite" variant. Also makes updating models painful (must rebuild) | Mount model directory as Docker volume; download models once to host |
| **conda in Docker** | Conda adds ~400MB and is unnecessary in a container where you control the environment directly | pip install with pinned requirements |
| **ONNX Runtime export** | Spark-TTS does not officially support ONNX export (only proposed in llama.cpp issue). Would require significant custom work | Native PyTorch inference via the provided CLI |
## Stack Patterns by Variant
- Use `torch==2.5.1+cu124` instead of CPU variant
- Add `--gpus all` to docker run
- Set `--device 0` in CLI args
- Expect ~25-30 second inference on RTX 4090 per [GitHub Issue #78](https://github.com/SparkAudio/Spark-TTS/issues/78)
- Use `torch==2.5.1+cpu` via PyTorch CPU index
- Set `--device cpu` in CLI args
- Expect 2-5x slower than GPU (still acceptable for non-interactive notifications)
- No NVIDIA driver or Container Toolkit needed
- Check PipeWire/PulseAudio is running: `pactl info`
- Fallback: `aplay /path/to/output.wav` (ALSA direct)
- Fallback: `mpv --no-video /path/to/output.wav`
## Version Compatibility
| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| torch==2.5.1+cpu | Python 3.9-3.12 | PyTorch 2.5.1 has prebuilt wheels for Python 3.12 |
| transformers==4.46.2 | torch>=2.0 | Supports PyTorch 2.5.1; uses Qwen2 tokenizer |
| soundfile==0.12.1 | libsndfile (system) | Requires `libsndfile1` system package on Debian (pulled in by python:3.12-slim via python-soundfile) |
| torchaudio==2.5.1 | torch==2.5.1 | Must match torch version exactly |
| soxr==0.5.0.post1 | libsoxr (system) | May need `libsox-dev` on some systems |
| protobuf | transformers>=4.40 | Versions >5.0 conflict with some transformers versions; pin to 4.x range |
## Claude Code Hook Integration Pattern
## Estimated Image Sizes
| Component | Size |
|-----------|------|
| python:3.12-slim base | ~75 MB |
| PyTorch CPU (torch + torchvision + torchaudio) | ~500 MB |
| Spark-TTS Python deps | ~800 MB |
| ffmpeg (system) | ~30 MB |
| **Total image (without models)** | **~1.4 GB** |
| Model files (volume mounted, not in image) | ~3.95 GB |
| **Total disk usage (image + models)** | **~5.35 GB** |
## Sources
- [Spark-TTS Official GitHub](https://github.com/SparkAudio/Spark-TTS) -- requirements.txt, CLI usage, Docker instructions (HIGH confidence, verified 2026-03-30)
- [Spark-TTS Docker PR #40 (breakstring)](https://github.com/SparkAudio/Spark-TTS/pull/40) -- Dockerfile, Docker Compose, FastAPI integration (HIGH confidence, verified 2026-03-30)
- [SparkAudio/Spark-TTS-0.5B on HuggingFace](https://huggingface.co/SparkAudio/Spark-TTS-0.5B) -- model files and sizes (HIGH confidence, verified 2026-03-30)
- [GitHub Issue #78 -- inference speed](https://github.com/SparkAudio/Spark-TTS/issues/78) -- GPU benchmark ~25-30s on RTX 4090 (MEDIUM confidence)
- [GitHub Issue #53 -- AMD/non-CUDA](https://github.com/SparkAudio/Spark-TTS/issues/53) -- running without CUDA (MEDIUM confidence)
- [PyTorch CPU install page](https://pytorch.org/get-started/locally/) -- CPU wheel index URL (HIGH confidence)
- [breakstring/spark-tts Docker Hub](https://hub.docker.com/r/breakstring/spark-tts) -- community Docker image (LOW confidence -- page didn't render useful content)
- [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks) -- hook system and Notification event (HIGH confidence)
- [Claude Code audio hooks (ChanMeng666)](https://github.com/ChanMeng666/claude-code-audio-hooks) -- community reference for audio notification patterns (LOW confidence -- not directly reviewed)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
