# Phase 2: 生成脚本 - Research

**Researched:** 2026-03-30
**Domain:** Bash orchestration scripting, Docker workflow automation, Python argparse
**Confidence:** HIGH

## Summary

This phase wraps the Phase 1 artifacts (Dockerfile, generate.py, requirements.txt) into a single `generate.sh` script that orchestrates the full pipeline: Docker image build (smart skip), model download, TTS inference, WAV-to-MP3 conversion, and output file verification. The key technical challenge is modifying `generate.py` to accept a `--type` argument for selective generation (SCRIPT-03), then building a Bash wrapper that handles Docker lifecycle, progress output, and error handling (SCRIPT-01, SCRIPT-02).

The existing `generate.py` has no argument parsing -- it always generates all 4 notifications in sequence. Adding `argparse` for `--type` is a small, well-understood change. The Bash script is pure orchestration: checking Docker image existence, running `docker build` conditionally, passing the correct `--type` argument through to `generate.py` via `docker run`, and verifying output files with `file` command. No new dependencies are needed.

**Primary recommendation:** Use Python `argparse` for generate.py's `--type` parameter, and write a straightforward Bash script with `set -euo pipefail` for error handling and `trap` for cleanup. Keep it simple -- no frameworks, no YAML config files, no dry-run modes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** 改造 `generate.py` 加 `--type` 参数支持选择性生成，脚本层透传参数
- **D-02:** `--type` 支持多个类型，用逗号分隔：`./generate.sh --type confirm,error`
- **D-03:** 智能跳过：检测 `spark-tts-notify` 镜像存在就跳过 `docker build`，不存在才 build
- **D-04:** 提供 `--force-rebuild` 参数强制重建镜像
- **D-05:** 验证深度：检查文件存在 + `file` 命令确认是有效 MP3 格式
- **D-06:** 不在脚本中播放音频（paplay 试播不适合脚本自动化场景）
- **D-07:** 清晰的步骤进度输出（正在 build / 正在生成 confirm...）
- **D-08:** 出错立即停止（set -e / trap）并显示错误信息
- **D-09:** 包含中文帮助信息，说明脚本用途
- **D-10:** 无需 dry-run、verbose 等高级选项

### Claude's Discretion
- generate.py 的参数传递机制（argparse / sys.argv / 环境变量）
- 进度输出格式（echo / printf 风格）
- 退出码定义
- 脚本中的变量定义和路径拼接方式

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCRIPT-01 | 一键脚本执行完整流程：docker build → 模型下载 → TTS 推理 → 转换 → 放置文件 | Bash wrapper around docker commands; smart build skip via `docker image inspect`; generate.py already handles model download and inference |
| SCRIPT-02 | 生成后验证音频文件存在且可播放（paplay 验证） | Use `file` command (D-05) to verify MP3 format; paplay NOT used in script (D-06); check file existence + MIME type |
| SCRIPT-03 | 支持单独重新生成指定类型的通知音频 | Add `--type` arg to generate.py via argparse; support comma-separated types (D-02); pass through docker run to python |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 4.x+ (system) | Orchestration script | Standard Linux shell; fish is the user's login shell but bash is universal for scripts |
| argparse | stdlib (Python 3.12) | CLI argument parsing for generate.py | Built-in, zero dependencies, well-documented |
| docker CLI | 29.3.0 (installed) | Image build and container run | Required for Spark-TTS execution |
| file | 5.46 (installed) | MP3 format verification | Standard Unix tool for file type detection |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| docker image inspect | via docker CLI | Check if spark-tts-notify image exists | Smart build skip (D-03) |
| id | system | Get current user/group for --user flag | SELinux-compatible docker run |
| trap / set -euo pipefail | bash builtins | Error handling and cleanup | Script reliability (D-08) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| argparse | click / typer | Overkill for one `--type` flag; argparse is stdlib with zero install cost |
| bash | python script as wrapper | Bash is simpler for Docker CLI orchestration; Python adds a layer of indirection |
| `file` command | ffprobe | `file` is lighter and already available; ffprobe would work but is heavier |

**Installation:**
None needed -- all tools are pre-installed on the target system.

**Version verification:**
```bash
bash --version        # 5.2.37(1)-release (Fedora 43)
python3 --version     # Already in Docker image (3.12)
docker --version      # 29.3.0
file --version        # 5.46
```

## Architecture Patterns

### Recommended Project Structure
```
notify-research/
├── generate.sh           # NEW - orchestration script (Phase 2)
├── generate.py           # MODIFY - add --type argparse support
├── Dockerfile            # EXISTING - no changes needed
├── requirements.txt      # EXISTING - no changes needed
├── .planning/            # Planning artifacts
└── CLAUDE.md             # Project instructions
```

### Pattern 1: generate.py argparse for selective generation
**What:** Add `argparse` to generate.py so it accepts `--type complete,confirm` to generate only specified notification types. When `--type` is omitted, generate all 4.
**When to use:** SCRIPT-03 -- user wants to regenerate a single notification without spending 32 minutes regenerating all 4.
**Example:**
```python
# Source: Standard Python argparse pattern
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="生成 Claude Code 语音通知音频")
    parser.add_argument(
        "--type", "-t",
        type=str,
        default=None,
        help="要生成的通知类型，逗号分隔 (complete,confirm,error,progress)。默认全部生成。",
    )
    return parser.parse_args()

def main():
    args = parse_args()

    # Parse types
    if args.type:
        requested = set(t.strip() for t in args.type.split(","))
        valid_names = {n["name"] for n in NOTIFICATIONS}
        invalid = requested - valid_names
        if invalid:
            print(f"错误：未知的通知类型: {', '.join(sorted(invalid))}")
            print(f"有效类型: {', '.join(sorted(valid_names))}")
            sys.exit(1)
        notifications = [n for n in NOTIFICATIONS if n["name"] in requested]
    else:
        notifications = NOTIFICATIONS
    # ... rest of generation loop
```

### Pattern 2: Bash script with Docker lifecycle management
**What:** `generate.sh` orchestrates the full pipeline with smart build skip and parameter passthrough.
**When to use:** SCRIPT-01 -- user runs `./generate.sh` for full pipeline or `./generate.sh --type confirm` for selective generation.
**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="spark-tts-notify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="$HOME/.cache/spark-tts"
OUTPUT_DIR="$HOME/.claude"

# Parse arguments
FORCE_REBUILD=false
NOTIFY_TYPES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force-rebuild) FORCE_REBUILD=true; shift ;;
        --type|-t)        NOTIFY_TYPES="$2"; shift 2 ;;
        --help|-h)        # print help and exit ;;
        *)                echo "未知参数: $1"; exit 1 ;;
    esac
done

# Step 1: Docker build (smart skip)
if [[ "$FORCE_REBUILD" == true ]]; then
    echo "==> 强制重建 Docker 镜像..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
elif docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "==> Docker 镜像已存在，跳过构建"
else
    echo "==> Docker 镜像不存在，开始构建..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Step 2: Run generation
DOCKER_ARGS=(
    --rm
    --user "$(id -u):$(id -g)"
    -v "$MODEL_DIR:/app/pretrained_models/Spark-TTS-0.5B:z"
    -v "$OUTPUT_DIR:/output:z"
)

if [[ -n "$NOTIFY_TYPES" ]]; then
    DOCKER_ARGS+=( --env GENERATE_TYPES="$NOTIFY_TYPES" )
fi

echo "==> 开始生成通知音频..."
docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME"
```

### Pattern 3: Environment variable for type passthrough
**What:** generate.sh passes `--type` value as environment variable `GENERATE_TYPES` to the Docker container, since `docker run` command args go to the CMD. generate.py reads it and overrides the default "generate all" behavior.
**When to use:** SCRIPT-03 -- clean separation between shell argument parsing and Python argument parsing. Avoids complex shell quoting issues.
**Example:**
```python
# In generate.py, read from env var (set by generate.sh via docker run --env)
GENERATE_TYPES = os.environ.get("GENERATE_TYPES", None)

def parse_args():
    # argparse for --type, but also support GENERATE_TYPES env var
    parser = argparse.ArgumentParser(...)
    parser.add_argument("--type", default=GENERATE_TYPES, ...)
```

**Recommendation:** Use environment variable passthrough. This is simpler than trying to override the Dockerfile CMD with custom arguments. The `CMD` stays as `python generate.py`, and the env var controls behavior. argparse can use the env var as its default value.

### Pattern 4: Verification with file command
**What:** After generation, verify each expected output file exists and is valid MP3 using `file` command.
**When to use:** SCRIPT-02 -- post-generation validation.
**Example:**
```bash
verify_output() {
    local name="$1"
    local filepath="$OUTPUT_DIR/notify-${name}.mp3"

    if [[ ! -f "$filepath" ]]; then
        echo "错误：文件不存在 $filepath"
        return 1
    fi

    if ! file "$filepath" | grep -qi "MPEG.*layer III\|MP3\|Audio"; then
        echo "错误：文件格式无效 $filepath"
        file "$filepath"
        return 1
    fi

    echo "  [OK] notify-${name}.mp3"
}

echo "==> 验证输出文件..."
for name in complete confirm error progress; do
    verify_output "$name"
done
echo "==> 验证通过"
```

### Anti-Patterns to Avoid
- **Modifying Dockerfile CMD to accept arbitrary args:** The Dockerfile CMD is `python generate.py`. Don't change it to a shell entrypoint that parses arguments -- that adds complexity and error-prone quoting. Use env vars instead.
- **Hardcoding paths in generate.sh:** Use `$SCRIPT_DIR` (derived from `${BASH_SOURCE[0]}`) for the repo root and `$HOME` for user directories. This works regardless of where the user clones the repo.
- **Using `docker build --no-cache` by default:** Only use `--no-cache` with `--force-rebuild`. Normal rebuilds should use Docker layer caching.
- **Silencing docker build output:** Keep `docker build` output visible so the user can see build progress and diagnose failures.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI argument parsing | Custom `while [[ $# -gt 0 ]]` for generate.py | Python `argparse` | Handles --help, validation, error messages, type parsing automatically |
| Docker image existence check | Parse `docker images` output | `docker image inspect <name>` (exit code 0/1) | Standard Docker CLI subcommand, designed for this exact purpose |
| File type detection | Parse file magic bytes manually | `file` command | Already installed, handles all audio format variations |
| Error handling in Bash | Manual `if [ $? != 0 ]` chains | `set -euo pipefail` + `trap` | Catches all unhandled errors, provides cleanup on exit |

**Key insight:** This phase is thin orchestration over existing working components. The hardest part is adding `--type` to generate.py, which is a 15-line argparse addition. The Bash script is straightforward Docker CLI plumbing. Resist the urge to over-engineer -- no YAML configs, no logging frameworks, no progress bars.

## Common Pitfalls

### Pitfall 1: Docker volume mount :z flag missing on Fedora/SELinux
**What goes wrong:** Script runs fine on Ubuntu but fails silently on Fedora with "permission denied" when Docker tries to write to mounted volumes.
**Why it happens:** Fedora uses SELinux in enforcing mode. Docker volume mounts require the `:z` (shared) or `:Z` (private) label flag to relabel files for container access.
**How to avoid:** Always append `:z` to volume mount paths in `docker run`:
```bash
-v "$MODEL_DIR:/app/pretrained_models/Spark-TTS-0.5B:z"
-v "$OUTPUT_DIR:/output:z"
```
**Warning signs:** `PermissionError` or `OSError` inside container when trying to write files.

### Pitfall 2: File ownership mismatch (root-owned output)
**What goes wrong:** Generated mp3 files are owned by `root:root` and the user cannot delete or overwrite them.
**Why it happens:** Running `docker run` without `--user $(id -u):$(id -g)` causes the container process to run as root, which creates files owned by root on the host via volume mount.
**How to avoid:** Always include `--user "$(id -u):$(id -g)"` in the docker run command. This was an issue in Phase 1 (documented in 01-02-SUMMARY.md) and must not regress.
**Warning signs:** `ls -la ~/.claude/notify-*.mp3` shows `root root` owner instead of user.

### Pitfall 3: generate.sh run from wrong directory
**What goes wrong:** `docker build` fails because it can't find Dockerfile, or relative paths in the script break.
**Why it happens:** User runs `./generate.sh` from a directory other than the project root, and the script uses relative paths.
**How to avoid:** Derive `SCRIPT_DIR` from `${BASH_SOURCE[0]}` and use absolute paths for docker build context:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
```
**Warning signs:** `docker build: unable to prepare context: unable to evaluate symlinks in Dockerfile path`.

### Pitfall 4: Docker image inspect output changes between versions
**What goes wrong:** Script uses `docker images | grep spark-tts-notify` to check image existence, but this is fragile and can match partial names.
**Why it happens:** Parsing `docker images` text output is version-dependent and unreliable.
**How to avoid:** Use `docker image inspect spark-tts-notify &>/dev/null` which returns exit code 0 if image exists, 1 if not. This is the standard Docker pattern.
**Warning signs:** Script incorrectly detects or misses the image.

### Pitfall 5: Trap cleanup runs on successful exit
**What goes wrong:** Script prints cleanup messages on successful exit, confusing the user.
**Why it happens:** `trap` without exit code checking runs on all exits including normal completion.
**How to avoid:** Check exit code in the trap handler, or use `trap cleanup EXIT` only for truly idempotent cleanup (like removing temp files). For error messages, use the ERR trap instead:
```bash
trap 'echo "错误：脚本执行失败，请检查上方输出" >&2' ERR
```
**Warning signs:** Error messages appear even when script succeeds.

### Pitfall 6: Generating subset forgets to clean old files
**What goes wrong:** User runs `./generate.sh --type confirm` to regenerate only confirm notification. The script runs but old mp3 files for other types remain untouched (which is correct behavior -- selective generation should NOT delete unrelated files).
**Why it happens:** Not a bug, but a clarification: selective generation is additive/regenerative, not destructive.
**How to avoid:** This is expected behavior. The verification step should only verify the files that were requested, not all 4.
**Warning signs:** User expects `--type confirm` to remove other notification files.

## Code Examples

Verified patterns from existing codebase:

### Existing Docker run pattern (from Phase 1)
```bash
# Source: Phase 1 01-02-SUMMARY.md -- established Docker run pattern
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$HOME/.cache/spark-tts/:/app/pretrained_models/Spark-TTS-0.5B:z" \
    -v "$HOME/.claude/:/output/:z" \
    spark-tts-notify
```

### Existing generate.py NOTIFICATIONS structure (to be filtered by --type)
```python
# Source: generate.py lines 25-30
NOTIFICATIONS = [
    {"name": "complete",  "text": "主人，任务完成了"},
    {"name": "confirm",   "text": "主人，请确认一下"},
    {"name": "error",     "text": "主人，出错了"},
    {"name": "progress",  "text": "主人，还在进行中"},
]
```

### File command verification output (verified on existing files)
```
# Source: Actual file command output from ~/.claude/notify-*.mp3
notify-complete.mp3: Audio file with ID3 version 2.4.0, contains: MPEG ADTS, layer III, v2, 40 kbps, 16 kHz, Monaural
notify-confirm.mp3:  Audio file with ID3 version 2.4.0, contains: MPEG ADTS, layer III, v2, 40 kbps, 16 kHz, Monaural
```
The grep pattern for verification should match `MPEG.*layer III` to confirm valid MP3.

### Environment variable handling in generate.py (existing pattern)
```python
# Source: generate.py lines 32-39 -- existing env var usage
MODEL_DIR = os.environ.get("MODEL_DIR", "/app/pretrained_models/Spark-TTS-0.5B")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/output")
```
Add `GENERATE_TYPES = os.environ.get("GENERATE_TYPES", None)` in the same pattern.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Parsing docker images output | `docker image inspect` (exit code check) | Docker 1.12+ (2016) | Use `docker image inspect <name> &>/dev/null` -- universally supported |
| `if [ $? != 0 ]; then` chains | `set -euo pipefail` | Best practice for years | Catches all unhandled errors automatically |
| Manual `while [ $# -gt 0 ]` for Python | `argparse` | Python 3.2+ (2011) | argparse is stdlib, handles validation, --help, errors |

**Deprecated/outdated:**
- `docker inspect` (without `image` subcommand): Still works as alias but `docker image inspect` is the canonical modern form.
- Backtick command substitution: Use `$(...)` instead. Backticks are harder to nest and read.

## Open Questions

1. **Should generate.sh be executable (chmod +x) or run with `bash generate.sh`?**
   - What we know: Best practice is `chmod +x` with shebang line
   - What's unclear: User preference
   - Recommendation: Make it executable with `#!/usr/bin/env bash` shebang. Document both invocation methods in help text.

2. **Should generate.sh support a `--list` or `--help-types` flag to show available notification types?**
   - What we know: D-10 says no advanced options
   - What's unclear: Whether listing types counts as "advanced"
   - Recommendation: Include type names in the `--help` output. Don't add a separate `--list` flag -- keep it simple per D-10.

3. **Should the verification step only check requested types or all 4 types?**
   - What we know: When using `--type confirm`, only confirm should be generated
   - What's unclear: Whether verification should check all 4 mp3 files or only the requested ones
   - Recommendation: Verify only the requested types. If `--type confirm` is used, only verify `notify-confirm.mp3`. If no `--type`, verify all 4. This matches user expectation and avoids false failures when other types haven't been generated yet.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | SCRIPT-01 (image build, container run) | Yes | 29.3.0 | -- |
| bash | SCRIPT-01 (orchestration script) | Yes | 5.2.37 | -- |
| file | SCRIPT-02 (MP3 format verification) | Yes | 5.46 | -- |
| paplay | Available but NOT used per D-06 | Yes | -- | -- |
| Model cache (~/.cache/spark-tts/) | Phase 1 model weights | Yes | 3.7GB | Auto-download via generate.py if missing |
| Output dir (~/.claude/) | MP3 file destination | Yes | -- | Auto-created by generate.py |

**Missing dependencies with no fallback:**
- None

**Missing dependencies with fallback:**
- None

Note: Docker image `spark-tts-notify` is NOT currently built (was likely pruned after Phase 1). The script's smart build skip (D-03) handles this correctly -- it will detect the missing image and trigger a build.

## Project Constraints (from CLAUDE.md)

### Must Follow
- GSD workflow enforcement: All file changes must go through `/gsd:execute-phase` workflow
- Audio output goes to `~/.claude/notify-{type}.mp3`
- Voice parameters: female, low pitch, low speed
- Docker volume mount uses `:z` flag for SELinux on Fedora
- Docker run uses `--user $(id -u):$(id -g)` for correct file ownership
- Spark-TTS CPU inference: ~8 min/sentence, ~32 min total for 4 notifications

### Technology Constraints
- Base image: python:3.12-slim (NOT Alpine)
- PyTorch: CPU-only variant
- Audio format: MP3 (not WAV) for final output
- No Gradio/web UI -- CLI inference only

## Sources

### Primary (HIGH confidence)
- Phase 1 generate.py (existing code, lines 1-114) -- current implementation with NOTIFICATIONS structure, env var handling, Docker volume paths
- Phase 1 Dockerfile (existing code) -- CMD is `python generate.py`, no changes needed
- Phase 1 01-02-SUMMARY.md -- established Docker run pattern, known file ownership issue, performance metrics
- CONTEXT.md 02-CONTEXT.md -- all locked decisions (D-01 through D-10)
- `file` command output on existing mp3 files -- verified MP3 format detection pattern

### Secondary (MEDIUM confidence)
- Docker CLI documentation for `docker image inspect` exit code behavior
- Python argparse documentation for `--type` with comma-separated values
- Bash `set -euo pipefail` best practices

### Tertiary (LOW confidence)
- None -- all findings are from direct code inspection or first-party tool verification

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools verified as installed and versioned
- Architecture: HIGH - patterns derived from existing Phase 1 code with minimal changes needed
- Pitfalls: HIGH - two of six pitfalls directly experienced in Phase 1 and documented in summaries

**Research date:** 2026-03-30
**Valid until:** 90 days (shell scripting and Docker CLI patterns are stable; Python argparse is stdlib)
