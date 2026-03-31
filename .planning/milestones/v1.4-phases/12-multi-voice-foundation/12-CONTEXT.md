# Phase 12: Multi-Voice Foundation - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Restructure audio/ from flat layout to per-voice directory structure, parameterize generate.py to accept --voice with per-voice config files, generate a second voice pack (deep/male), and commit both voice packs to the repository. Users do NOT generate audio — they select from pre-generated packs.

</domain>

<decisions>
## Implementation Decisions

### Voice Packs
- **D-01:** Two voice packs shipped: `gentle` (female/low pitch/low speed — current default) and `deep` (male/high pitch/moderate speed)
- **D-02:** Voice directory names: `audio/voices/gentle/` and `audio/voices/deep/`, each containing 4 mp3 files (notify-complete.mp3, notify-confirm.mp3, notify-error.mp3, notify-progress.mp3)
- **D-03:** Deep voice parameters: gender=male, pitch=high, speed=moderate (Spark-TTS supports gender/pitch/speed)

### Directory Migration
- **D-04:** One-time migration: `git mv audio/notify-*.mp3 → audio/voices/gentle/`. Update ALL references (install.sh line 77, tests/fixtures, generate.sh, any other paths). No backward compatibility layer — clean cutover.
- **D-05:** No flat `audio/notify-*.mp3` files remain after migration. All consumers use `audio/voices/{name}/notify-{type}.mp3`.

### generate.py Parameterization
- **D-06:** Add `--voice <name>` flag to generate.py. Load voice parameters from `voices/<name>.json` config file instead of hardcoded VOICE_PARAMS dict.
- **D-07:** `voices/gentle.json` and `voices/deep.json` config files in repo, containing gender/pitch/speed fields.
- **D-08:** Output directory becomes `audio/voices/{name}/` when `--voice` is specified, instead of flat `$OUTPUT_DIR/`.

### generate.sh Changes
- **D-09:** Add `--voice <name>` flag to generate.sh. When specified, output goes to `$REPO_ROOT/audio/voices/{name}/` instead of `~/.claude/`.
- **D-10:** Preserve existing behavior: without --voice, still outputs to `~/.claude/` (for personal use/re-generation).

### Deep Voice Generation
- **D-11:** Generate deep voice pack within this phase using existing Docker TTS pipeline (CPU, ~30 min for 4 sentences). Commit all 4 mp3 files to repo.
- **D-12:** Audio generation is ALWAYS done locally by maintainers and committed to the repo. Users never generate audio — they select from pre-generated packs at install time.

### Claude's Discretion
- voices/*.json schema design (fields, additional params beyond gender/pitch/speed)
- Whether to add a `voices.json` manifest file listing all available voices (ROADMAP mentions this)
- generate.py --output-dir vs deriving from --voice (planner decides cleanest approach)
- Whether to add `--list-voices` flag to generate.sh

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Files to Modify
- `generate.py` — Lines 20-24 VOICE_PARAMS hardcoded dict needs parameterization; line 133-134 output path needs voice-aware directory
- `generate.sh` — Lines 7, 80 OUTPUT_DIR hardcoded to ~/.claude/; no --voice support
- `scripts/install.sh` — Line 77 copies from `audio/notify-${type}.mp3` (flat path), needs `audio/voices/{voice}/`
- `scripts/notify-play.sh` — Reads mp3 from `$CLAUDE_DIR/notify-*.mp3` (not affected by audio/ restructure — install copies to ~/.claude/)

### Audio Files (to migrate)
- `audio/notify-complete.mp3`, `audio/notify-confirm.mp3`, `audio/notify-error.mp3`, `audio/notify-progress.mp3` — Current flat layout, move to `audio/voices/gentle/`

### Test Files (need path updates)
- `tests/fixtures/dummy.mp3` — Shared test fixture, may need voice-aware path
- `tests/bash/install.bats` — install.sh copies from audio/ path
- `tests/powershell/install.Tests.ps1` — install.ps1 copies from audio/ path

### Research
- `.planning/research/ARCHITECTURE.md` — Multi-voice directory structure design
- `.planning/research/STACK.md` — Spark-TTS voice parameters documentation
- `.planning/research/FEATURES.md` — Voice pack feature analysis

### Requirements
- `.planning/REQUIREMENTS.md` — VOICE-01, VOICE-02, VOICE-03

### Prior Phase Context
- `.planning/phases/07-bash/07-CONTEXT.md` — install.sh test fixtures reference flat audio/ paths
- `.planning/phases/08-powershell/08-CONTEXT.md` — install.ps1 test fixtures reference flat audio/ paths

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `generate.py`: Full TTS pipeline (model download, SparkTTS inference, wav→mp3 conversion) — add --voice param, load from voices/*.json
- `generate.sh`: Docker build + run orchestration — add --voice flag, change output volume mount
- `generate.sh` verify_output() (line 93-106): File validation pattern — reusable for voice pack verification

### Established Patterns
- VOICE_PARAMS dict at generate.py:20-24 — hardcoded, needs to become voice-config-driven
- `--type` flag for selective generation (generate.py:50-55, generate.sh:37-43) — keep this, add --voice alongside
- Docker volume mount for output (generate.sh:80) — needs voice-aware mount path
- install.sh copies from `$REPO_ROOT/audio/notify-${type}.mp3` (line 77) — update to `$REPO_ROOT/audio/voices/$VOICE/notify-${type}.mp3`

### Integration Points
- install.sh + install.ps1 both copy from `audio/` directory — both need path update
- Test fixtures (dummy.mp3, install tests) reference `audio/notify-*.mp3` — need voice-aware paths
- CI workflow may reference audio files for test matrix

</code_context>

<specifics>
## Specific Ideas

- voices/gentle.json: `{"gender": "female", "pitch": "low", "speed": "low"}`
- voices/deep.json: `{"gender": "male", "pitch": "high", "speed": "moderate"}`
- Deep voice generation: run `generate.sh --voice deep` after infrastructure is in place, commit resulting mp3 files

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 12-multi-voice-foundation*
*Context gathered: 2026-03-31*
