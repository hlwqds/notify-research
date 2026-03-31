# Phase 12: Multi-Voice Foundation - Research

**Researched:** 2026-03-31
**Domain:** Audio file restructuring, voice parameterization, Spark-TTS offline generation
**Confidence:** HIGH

## Summary

This phase restructures the audio directory from a flat layout (`audio/notify-*.mp3`) to a per-voice directory structure (`audio/voices/{name}/notify-*.mp3`), parameterizes `generate.py` to accept `--voice <name>` with per-voice JSON config files, generates a second voice pack ("deep" male voice) via the existing Docker TTS pipeline, and commits both voice packs to the repository. The work is a code/config-only refactor plus a one-time audio generation task -- no new runtime dependencies, no user-facing behavior change in existing installations.

The phase is straightforward because all building blocks exist: Spark-TTS voice parameters (gender/pitch/speed) are verified from source code, the Docker generation pipeline is battle-tested, and the directory-per-voice pattern is standard. The main risk is ensuring all path references across scripts, tests, and documentation are updated consistently during the migration -- 7 files reference `audio/notify-*.mp3` and must be changed.

**Primary recommendation:** Execute in three waves -- (1) directory migration + all path updates, (2) generate.py/generate.sh parameterization + voice config files, (3) deep voice generation + commit. Each wave is independently testable.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Two voice packs shipped: `gentle` (female/low pitch/low speed -- current default) and `deep` (male/high pitch/moderate speed)
- **D-02:** Voice directory names: `audio/voices/gentle/` and `audio/voices/deep/`, each containing 4 mp3 files (notify-complete.mp3, notify-confirm.mp3, notify-error.mp3, notify-progress.mp3)
- **D-03:** Deep voice parameters: gender=male, pitch=high, speed=moderate (Spark-TTS supports gender/pitch/speed)
- **D-04:** One-time migration: `git mv audio/notify-*.mp3 -> audio/voices/gentle/`. Update ALL references (install.sh line 77, tests/fixtures, generate.sh, any other paths). No backward compatibility layer -- clean cutover.
- **D-05:** No flat `audio/notify-*.mp3` files remain after migration. All consumers use `audio/voices/{name}/notify-{type}.mp3`.
- **D-06:** Add `--voice <name>` flag to generate.py. Load voice parameters from `voices/<name>.json` config file instead of hardcoded VOICE_PARAMS dict.
- **D-07:** `voices/gentle.json` and `voices/deep.json` config files in repo, containing gender/pitch/speed fields.
- **D-08:** Output directory becomes `audio/voices/{name}/` when `--voice` is specified, instead of flat `$OUTPUT_DIR/`.
- **D-09:** Add `--voice <name>` flag to generate.sh. When specified, output goes to `$REPO_ROOT/audio/voices/{name}/` instead of `~/.claude/`.
- **D-10:** Preserve existing behavior: without --voice, still outputs to `~/.claude/` (for personal use/re-generation).
- **D-11:** Generate deep voice pack within this phase using existing Docker TTS pipeline (CPU, ~30 min for 4 sentences). Commit all 4 mp3 files to repo.
- **D-12:** Audio generation is ALWAYS done locally by maintainers and committed to the repo. Users never generate audio -- they select from pre-generated packs at install time.

### Claude's Discretion
- voices/*.json schema design (fields, additional params beyond gender/pitch/speed)
- Whether to add a `voices.json` manifest file listing all available voices (ROADMAP mentions this)
- generate.py --output-dir vs deriving from --voice (planner decides cleanest approach)
- Whether to add `--list-voices` flag to generate.sh

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VOICE-01 | Audio files organized in `audio/{voice-name}/` directory structure with one subdirectory per voice style | Directory-per-voice pattern is standard; migration via `git mv`; 7 files need path updates (identified below) |
| VOICE-02 | `generate.py` accepts `--voice` parameter to load voice settings from `voices/*.json` config files | Spark-TTS `model.inference()` accepts gender/pitch/speed params; argparse already has --type pattern to extend; JSON config loading is trivial |
| VOICE-03 | At least 2 voice styles are pre-generated and shipped (default + 1 alternative, e.g. female voice) | Docker TTS pipeline proven; CPU generation ~8 min/sentence; deep voice params (male/high/moderate) verified valid from Spark-TTS source |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Spark-TTS | main branch (cloned in Dockerfile) | TTS model for voice generation | Already in use; voice creation API verified from source |
| Python argparse | stdlib | CLI argument parsing (already used for --type) | Extend existing pattern for --voice flag |
| Python json | stdlib | Load voice config from JSON files | Zero-dependency, standard library |
| bash | 4.x+ | Orchestration script (generate.sh) | Already in use; extend with --voice flag |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Docker | 29.x+ | Container runtime for TTS | Already in use; no changes needed |
| jq | system | JSON manipulation in install.sh | Already required; no changes needed |
| ffmpeg | 7.x (system) | WAV to MP3 conversion | Already in use in generate.py; no changes needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `voices/*.json` config files | YAML or TOML | JSON is already in the ecosystem (settings.json, package.json); no reason to add a YAML/TOML dependency |
| argparse `--voice` flag | Environment variable `VOICE_NAME` | argparse is more discoverable and consistent with existing `--type` flag |
| Derive output dir from `--voice` | Separate `--output-dir` flag | D-08 explicitly says derive from --voice; `--output-dir` would conflict with Docker volume mount logic |

**Installation:** No new packages needed. This phase uses only existing dependencies.

## Architecture Patterns

### Recommended Project Structure
```
audio/
  voices/
    gentle/                          # Current default voice (renamed from flat audio/)
      notify-complete.mp3
      notify-confirm.mp3
      notify-error.mp3
      notify-progress.mp3
    deep/                            # New voice (generated this phase)
      notify-complete.mp3
      notify-confirm.mp3
      notify-error.mp3
      notify-progress.mp3
voices/
  gentle.json                        # Voice config: {"gender": "female", "pitch": "low", "speed": "low"}
  deep.json                          # Voice config: {"gender": "male", "pitch": "high", "speed": "moderate"}
generate.py                          # Modified: --voice flag, load from voices/*.json
generate.sh                          # Modified: --voice flag, voice-aware output path
```

### Pattern 1: Voice Config Loading in generate.py
**What:** Replace hardcoded `VOICE_PARAMS` dict with JSON config file loaded based on `--voice` argument.
**When to use:** Every invocation of generate.py that needs voice-specific parameters.
**Example:**
```python
# Source: verified from generate.py existing code (lines 20-24, 45-56)
import json

VOICE_PARAMS = {
    "gender": "female",
    "pitch": "low",
    "speed": "low",
}

# Becomes:
def load_voice_config(voice_name: str) -> dict:
    """Load voice parameters from voices/{name}.json config file."""
    config_path = Path(__file__).parent / "voices" / f"{voice_name}.json"
    if not config_path.exists():
        print(f"错误：语音配置文件不存在: {config_path}")
        sys.exit(1)
    with open(config_path) as f:
        return json.load(f)

# In main():
args = parse_args()  # extended with --voice
voice_params = load_voice_config(args.voice) if args.voice else VOICE_PARAMS
```

### Pattern 2: Voice-Aware Output Directory
**What:** When `--voice` is specified, output files go to `audio/voices/{voice}/` subdirectory instead of flat output dir.
**When to use:** In generate.py main() for path construction, and in generate.sh for Docker volume mount.
**Example:**
```python
# In generate.py main():
output_subdir = OUTPUT_DIR
if args.voice:
    output_subdir = os.path.join(OUTPUT_DIR, args.voice)
os.makedirs(output_subdir, exist_ok=True)

# Then use output_subdir instead of OUTPUT_DIR for file paths:
wav_path = os.path.join(output_subdir, f"notify-{notif['name']}.wav")
mp3_path = os.path.join(output_subdir, f"notify-{notif['name']}.mp3")
```

### Pattern 3: generate.sh --voice Flag
**What:** Extend generate.sh argument parsing with `--voice <name>`, change output volume mount when voice is specified.
**When to use:** Running `./generate.sh --voice deep` to generate a voice pack directly into the repo.
**Example:**
```bash
# In generate.sh argument parsing (add to while loop at line 35):
--voice)
    VOICE_NAME="$2"
    shift 2
    ;;

# After argument parsing, override OUTPUT_DIR when --voice is used:
if [[ -n "$VOICE_NAME" ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/audio/voices/$VOICE_NAME"
    echo "==> 输出目录: $OUTPUT_DIR"
fi

# verify_output() also needs voice-aware path:
local filepath="$OUTPUT_DIR/notify-${name}.mp3"
# Already uses $OUTPUT_DIR variable, so it inherits the change automatically.
```

### Pattern 4: Clean Directory Migration with git mv
**What:** Use `git mv` to preserve file history during the rename from flat to per-voice layout.
**When to use:** One-time migration at the start of the phase.
**Example:**
```bash
mkdir -p audio/voices/gentle
git mv audio/notify-complete.mp3 audio/voices/gentle/
git mv audio/notify-confirm.mp3 audio/voices/gentle/
git mv audio/notify-error.mp3 audio/voices/gentle/
git mv audio/notify-progress.mp3 audio/voices/gentle/
```

### Anti-Patterns to Avoid
- **Keeping VOICE_PARAMS as fallback without --voice:** D-06 says "load voice parameters from voices/*.json config file instead of hardcoded VOICE_PARAMS dict." The hardcoded dict should be removed or converted to a default-only pattern. Consider: always require --voice, making gentle.json the canonical source.
- **Partial migration (some files moved, some not):** D-05 explicitly says "No flat `audio/notify-*.mp3` files remain after migration." All 4 files must move together.
- **Complex voice config schema:** Keep it minimal. Spark-TTS only uses gender/pitch/speed. Additional fields (language, description, author) are optional and can be added later (Claude's discretion).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON config parsing | Custom parser | `json.load()` from stdlib | One line, zero dependencies, handles all edge cases |
| CLI argument parsing | Manual `$1`/`$2` parsing | `argparse` (Python), bash `while/case` (already used) | Existing patterns in both generate.py and generate.sh |
| Audio file validation | Custom MP3 header check | `file` command + `grep -qi "MPEG.*layer III"` | Already used in generate.sh verify_output() (line 100); proven reliable |
| Voice config discovery | Glob + filter | `voices/*.json` with explicit --voice arg | No need for auto-discovery; user/maintainer always specifies which voice |

**Key insight:** This phase is minimal in scope. The project already avoids over-engineering. The voice config system is just JSON files read by argparse -- no framework needed.

## Common Pitfalls

### Pitfall 1: Missing Path References After Migration
**What goes wrong:** Some script or test still references `audio/notify-*.mp3` after migration, causing install or test failures.
**Why it happens:** Path references are spread across 7+ files (install.sh, install.ps1, generate.sh, 3 test files, Dockerfile comments). Easy to miss one.
**How to avoid:** Use `grep -r "audio/notify" --include="*.sh" --include="*.ps1" --include="*.bats" --include="*.py"` BEFORE migration to enumerate ALL references. Update each one. Re-run grep after to confirm zero hits.
**Warning signs:** CI fails with "file not found" for audio files; tests fail in setup fixtures.

### Pitfall 2: Dockerfile COPY Breaking After Voice Config Added
**What goes wrong:** `generate.py` is copied into the Docker image at build time (line 28), but `voices/*.json` config files are NOT copied. When `--voice` is used, generate.py inside the container can't find the config file.
**Why it happens:** The Dockerfile copies only `generate.py` and `requirements.txt`. Voice config files are outside the Docker build context if the voice-specific output mode is used (files stay on host).
**How to avoid:** Two options: (a) Also `COPY voices/ voices/` in Dockerfile, OR (b) pass voice params as environment variables from generate.sh instead of loading JSON inside the container. Option (a) is simpler and keeps config-file loading inside generate.py.
**Warning signs:** `generate.sh --voice deep` fails with "config file not found" inside Docker container.

### Pitfall 3: Voice JSON Schema Drift
**What goes wrong:** gentle.json and deep.json have different fields, or a field name doesn't match what generate.py expects.
**Why it happens:** No schema validation exists; JSON files are created manually.
**How to avoid:** Define the minimal required schema (gender, pitch, speed) and validate in generate.py's `load_voice_config()` function. Fail fast with a clear error if required keys are missing.
**Warning signs:** KeyError when loading voice config, or silent fallback to default parameters.

### Pitfall 4: install.ps1 Path Check Failure After Migration
**What goes wrong:** install.ps1 checks for audio files in `audio/` (line 56-68), but files now live in `audio/voices/{name}/`. The path check fails.
**Why it happens:** install.ps1 doesn't yet have a voice selection mechanism (that's VOICE-04 in Phase 14). For now, it needs a default voice path.
**How to avoid:** Update `$AudioSource = Join-Path $RepoPath "audio"` to `$AudioSource = Join-Path $RepoPath "audio\voices\gentle"` as a temporary default until Phase 14 adds voice selection. Same for install.sh line 77.
**Warning signs:** PowerShell install tests fail with "file not found" for audio files.

### Pitfall 5: generate.sh verify_output() Path Mismatch
**What goes wrong:** verify_output() uses `$OUTPUT_DIR/notify-${name}.mp3` but when --voice is used, files are in `$OUTPUT_DIR/voices/$VOICE/notify-${name}.mp3`.
**Why it happens:** If generate.sh changes OUTPUT_DIR to `$SCRIPT_DIR/audio/voices/$VOICE_NAME` before running Docker, verify_output() uses $OUTPUT_DIR which now points to the voice-specific directory. This should work automatically since verify_output() already uses $OUTPUT_DIR.
**How to avoid:** Verify that OUTPUT_DIR override happens BEFORE verify_output() runs. In the current generate.sh, OUTPUT_DIR is set at line 7 and verify_output() runs at line 93-117. The override should happen between argument parsing (line 59) and Docker run (line 90).
**Warning signs:** verify_output() reports "file not found" despite successful generation.

## Code Examples

### Voice Config File Format (voices/gentle.json)
```json
{
    "gender": "female",
    "pitch": "low",
    "speed": "low"
}
```

### Voice Config File Format (voices/deep.json)
```json
{
    "gender": "male",
    "pitch": "high",
    "speed": "moderate"
}
```

### Spark-TTS Inference Call (from generate.py line 80-84)
```python
# Source: verified from generate.py and Spark-TTS cli/SparkTTS.py source code
# Valid gender values: "female", "male"
# Valid pitch/speed values: "very_low", "low", "moderate", "high", "very_high"
# Source: sparktts/utils/token_parser.py LEVELS_MAP and GENDER_MAP
wav = model.inference(
    text=text,
    gender=voice_params["gender"],
    pitch=voice_params["pitch"],
    speed=voice_params["speed"],
)
```

### Complete Path Update: install.sh Line 77
```bash
# Before:
src="$REPO_ROOT/audio/notify-${type}.mp3"

# After (defaulting to gentle voice until Phase 14 adds selection):
VOICE="${VOICE:-gentle}"
src="$REPO_ROOT/audio/voices/$VOICE/notify-${type}.mp3"
```

### Complete Path Update: install.ps1 Line 18
```powershell
# Before:
$AudioSource = Join-Path $RepoPath "audio"

# After (defaulting to gentle voice):
$VoiceName = if ($Voice) { $Voice } else { "gentle" }
$AudioSource = Join-Path $RepoPath "audio\voices\$VoiceName"
```

### Files Requiring Path Updates (Complete List)
```
1. scripts/install.sh        line 77   audio/notify-${type}.mp3 -> audio/voices/$VOICE/notify-${type}.mp3
2. scripts/install.ps1       line 18   audio -> audio\voices\$VoiceName
3. tests/bash/install.bats   line 18   audio/notify-${type}.mp3 -> audio/voices/gentle/notify-${type}.mp3
4. tests/bash/notify-play.bats lines 45,65,78,96  audio/notify-complete.mp3 -> audio/voices/gentle/notify-complete.mp3
5. tests/bash/uninstall.bats line 18   audio/notify-${type}.mp3 -> audio/voices/gentle/notify-${type}.mp3
6. tests/powershell/notify-play.Tests.ps1 lines 15,35,49,58  audio/notify-complete.mp3 -> audio/voices/gentle/notify-complete.mp3
7. generate.sh               line 95   verify_output path (uses $OUTPUT_DIR, auto-inherited)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat audio/ directory with all mp3s | Per-voice `audio/voices/{name}/` directories | This phase | Enables multi-voice selection, cleaner organization |
| Hardcoded VOICE_PARAMS dict | JSON config files per voice | This phase | Enables adding voices without code changes |
| Single output directory | Voice-aware output path | This phase | generate.sh --voice outputs to correct directory |

**Deprecated/outdated:**
- `audio/notify-*.mp3` flat paths: Replaced by `audio/voices/gentle/notify-*.mp3`. No backward compatibility per D-04.

## Open Questions

1. **Should VOICE_PARAMS be kept as a fallback default?**
   - What we know: D-06 says "load voice parameters from voices/*.json config file instead of hardcoded VOICE_PARAMS dict." This implies removal.
   - What's unclear: Whether `generate.py --type complete` (without --voice) should still work for backward compatibility.
   - Recommendation: Keep `VOICE_PARAMS` as an internal default but require `--voice` in the CLI interface. If no --voice is given, print a message suggesting `--voice gentle` but use gentle.json if available. This preserves D-10 ("without --voice, still outputs to ~/.claude/") while nudging toward explicit voice selection.

2. **Should voices.json manifest be added in this phase?**
   - What we know: Claude's discretion allows it. The ROADMAP mentions it. It would be useful for install-time voice listing (Phase 14).
   - What's unclear: Whether it adds complexity now for minimal benefit.
   - Recommendation: Add a minimal `voices.json` in this phase: `{"voices": ["gentle", "deep"]}`. It's 1 line and unblocks Phase 14 voice selection. The planner should decide.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | Deep voice generation (generate.sh) | Yes | 29.3.0 | -- |
| jq | install.sh (no changes needed) | Yes | 1.7.1 | -- |
| paplay | Audio playback (no changes needed) | Yes | (PipeWire) | -- |
| ffmpeg | WAV to MP3 conversion in Docker | Yes (in Docker image) | -- | -- |
| spark-tts-notify Docker image | TTS generation | No (not built) | -- | build via generate.sh --force-rebuild |

**Missing dependencies with no fallback:**
- None. Docker image can be built on demand via `--force-rebuild`.

**Missing dependencies with fallback:**
- spark-tts-notify Docker image not currently built. Will be built automatically by generate.sh when it doesn't find the image (lines 65-70). No manual action needed.

## Sources

### Primary (HIGH confidence)
- `generate.py` (project file, 146 lines) -- current VOICE_PARAMS, argparse structure, model.inference() call
- `generate.sh` (project file, 121 lines) -- argument parsing, Docker volume mount, verify_output()
- `scripts/install.sh` (project file, 127 lines) -- audio file copy path (line 77)
- `scripts/install.ps1` (project file, 145 lines) -- audio source path (line 18)
- Spark-TTS `cli/SparkTTS.py` source code -- verified `inference()` signature: text, gender, pitch, speed
- Spark-TTS `sparktts/utils/token_parser.py` source code -- verified LEVELS_MAP and GENDER_MAP valid values
- `.planning/research/STACK.md` -- Spark-TTS voice parameter documentation
- `.planning/research/ARCHITECTURE.md` -- multi-voice directory structure design

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` -- project research summary with phase ordering rationale
- `.planning/REQUIREMENTS.md` -- VOICE-01, VOICE-02, VOICE-03 definitions
- Test files (install.bats, notify-play.bats, uninstall.bats, notify-play.Tests.ps1) -- path references enumerated

### Tertiary (LOW confidence)
- None. All findings are from project source code or directly verified Spark-TTS source.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are already in use in the project. No new dependencies needed.
- Architecture: HIGH - Directory-per-voice is a standard pattern. Migration path is clear (git mv + path updates). Spark-TTS API verified from source.
- Pitfalls: HIGH - All pitfalls identified from direct code inspection. Path references enumerated via grep. Dockerfile COPY issue identified from reading Dockerfile.

**Research date:** 2026-03-31
**Valid until:** Stable -- no external dependencies with version churn. Spark-TTS API is unlikely to change. Architecture decisions are project-internal.
