# Architecture Patterns: v1.4 Hooks Ecosystem Distribution

**Domain:** Claude Code hooks extension packaging, multi-voice audio packs, one-line install, community distribution
**Researched:** 2026-03-31
**Confidence:** MEDIUM-HIGH

## Executive Summary

v1.4 transforms this project from a standalone repo (git clone + manual install) into a distributable Claude Code hooks ecosystem extension with two install paths: the official Claude Code plugin system (`/plugin install`) and a one-line curl install for users not yet on a Claude Code version that supports plugins. The architecture introduces a multi-voice audio pack system that adds voice selection at install time while preserving backward compatibility with the existing single-voice flat layout.

The recommended approach uses a dual-path distribution strategy: (1) a Claude Code plugin package with `.claude-plugin/plugin.json` manifest and `hooks/hooks.json` for marketplace distribution, and (2) a lightweight `install.sh` served via GitHub raw content for one-line `curl | bash` installs. Multi-voice support requires restructuring `audio/` from flat files to `audio/{voice}/` subdirectories, parameterizing `VOICE_PARAMS` in `generate.py`, and adding a voice selection step to install scripts.

The key architectural insight is that the Claude Code plugin system provides `${CLAUDE_PLUGIN_ROOT}` for path resolution, which eliminates the need for absolute path injection into `settings.json`. However, the plugin system may not be available to all users immediately, so the standalone install path must remain functional as a fallback. Both paths share the same audio files, playback scripts, and cooldown mechanism -- only the hook registration mechanism differs.

## System Overview

```
                        Distribution Layer
                    +-----------------------+
                    |  GitHub Release /     |
                    |  Plugin Marketplace   |
                    +-----------------------+
                           |         |
              plugin path  |         |  standalone path
                           v         v
                +--------+   +-------------+
                | Plugin  |   | curl | bash |
                | Install |   | install.sh  |
                +--------+   +-------------+
                     |               |
                     v               v
                +-----------------------------+
                |    Voice Selection Step      |
                |  (interactive or --voice arg) |
                +-----------------------------+
                           |
                +----------+----------+
                |          |          |
                v          v          v
           +-------+  +-------+  +-------+
           | female |  | male  |  | cute  |  ... (voice packs)
           |  low   |  |  mid  |  |  high |
           +-------+  +-------+  +-------+
                |          |          |
                v          v          v
                +-----------------------------+
                |    Audio Copy Layer         |
                |  ~/.claude/notify-*.mp3     |
                +-----------------------------+
                           |
                +----------+----------+
                |          |          |
                v          v          v
           +-------+  +-------+  +-------+
           | bash  |  |  pwsh |  |  afplay |
           | paplay|  | MediaP|  | (macOS) |
           +-------+  +-------+  +-------+
```

## Recommended Project Structure

```
notify-research/
├── .claude-plugin/                  # NEW — Plugin manifest for marketplace distribution
│   └── plugin.json                  # Plugin metadata (name, version, description)
│
├── audio/                           # RESTRUCTURED — Multi-voice audio packs
│   ├── default/                     # Existing voice (female, low pitch, low speed)
│   │   ├── notify-complete.mp3
│   │   ├── notify-confirm.mp3
│   │   ├── notify-error.mp3
│   │   └── notify-progress.mp3
│   ├── male-deep/                   # NEW — Example alternative voice pack
│   │   ├── notify-complete.mp3
│   │   ├── notify-confirm.mp3
│   │   ├── notify-error.mp3
│   │   └── notify-progress.mp3
│   └── voices.json                  # NEW — Voice manifest (name, params, description)
│
├── hooks/                           # NEW — Plugin hooks definition
│   └── hooks.json                   # Hook event -> command mapping (plugin install path)
│
├── scripts/                         # MODIFIED — Install scripts gain voice selection
│   ├── install.sh                   # MODIFIED — Voice selection + dual registration
│   ├── install.ps1                  # MODIFIED — Voice selection + dual registration
│   ├── uninstall.sh                 # MODIFIED — Clean up voice-augmented paths
│   ├── uninstall.ps1                # MODIFIED — Clean up voice-augmented paths
│   ├── notify-play.sh               # UNCHANGED — Playback wrapper
│   └── notify-play.ps1              # UNCHANGED — Playback wrapper
│
├── generate.py                      # MODIFIED — Parameterized VOICE_PARAMS
├── generate.sh                      # MODIFIED — Voice pack generation support
├── voices/                          # NEW — Voice parameter definitions
│   ├── default.json                 # Female, low pitch, low speed (existing params)
│   └── male-deep.json               # Male, medium pitch, medium speed (example)
│
├── audio/                           # (see above)
├── tests/                           # EXISTING — Test infrastructure (unchanged)
├── Dockerfile                       # UNCHANGED — TTS generation
├── requirements.txt                 # UNCHANGED
├── test.sh                          # UNCHANGED — Test runner
├── .github/workflows/ci.yml         # MODIFIED — Add voice generation CI step
└── README.md                        # MODIFIED — Updated install instructions
```

### Structure Rationale

- **`.claude-plugin/`**: Required by Claude Code plugin system. Contains only `plugin.json` metadata -- the actual hooks and scripts live at the repo root where they already are.
- **`hooks/hooks.json`**: Plugin system hook definitions. Separated from scripts because the plugin system reads this file to know which hooks to register. The commands reference scripts by path relative to the plugin root.
- **`audio/{voice}/`**: Each voice pack is a self-contained directory with 4 MP3 files. This makes adding new voices trivial (drop a directory with 4 files + an entry in `voices.json`).
- **`voices/`**: Voice parameter JSON files consumed by `generate.py`. Separating voice params from the generation script makes it easy to add voices without modifying Python code.
- **`audio/voices.json`**: Runtime voice manifest for install scripts. Contains voice metadata (display name, description, directory name) used during voice selection.

## Component Boundaries

### New Components

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `.claude-plugin/plugin.json` | Plugin metadata for marketplace: name, version, description, author | Claude Code plugin system (read at install time) |
| `hooks/hooks.json` | Maps Claude Code hook events to playback commands using `${CLAUDE_PLUGIN_ROOT}` | Claude Code hooks engine, `scripts/notify-play.*` |
| `audio/voices.json` | Runtime voice manifest: available voices, display names, descriptions | `scripts/install.sh`, `scripts/install.ps1` |
| `voices/*.json` | Voice generation parameters for `generate.py`: gender, pitch, speed | `generate.py` |
| `audio/{voice}/` | Voice pack audio files (4 MP3 each) | `scripts/install.sh` (copies to `~/.claude/`) |

### Modified Components

| Component | Current Responsibility | v1.4 Change | Why |
|-----------|----------------------|-------------|-----|
| `scripts/install.sh` | Copy flat `audio/` files, inject hooks via jq | Add voice selection, read from `audio/{voice}/`, dual registration mode | Supports multi-voice and plugin path |
| `scripts/install.ps1` | Same as install.sh for Windows | Same changes as install.sh | Cross-platform parity |
| `scripts/uninstall.sh` | Remove hooks and audio from `~/.claude/` | Handle both legacy flat paths and new voice-specific paths | Clean removal regardless of install method |
| `scripts/uninstall.ps1` | Same as uninstall.sh for Windows | Same changes as uninstall.sh | Cross-platform parity |
| `generate.py` | Generate audio with hardcoded `VOICE_PARAMS` | Accept `--voice` CLI arg, read params from `voices/*.json` | Parameterized voice generation |
| `generate.sh` | Orchestrate Docker TTS generation | Accept `--voice` flag, pass to `generate.py` | Multi-voice generation support |

### Unchanged Components

| Component | Why Unchanged |
|-----------|--------------|
| `scripts/notify-play.sh` | Takes absolute path to MP3 as argument. Multi-voice only changes which MP3 is copied to `~/.claude/`. The playback script does not care which voice pack generated the audio. |
| `scripts/notify-play.ps1` | Same rationale as notify-play.sh. |
| `Dockerfile` | TTS inference container. Voice params are passed at runtime via env vars, not baked into the image. |
| `requirements.txt` | Spark-TTS dependencies unchanged. |
| Test infrastructure | Tests validate script behavior, not audio content. Existing tests for install/uninstall/notify-play remain valid with minor fixture updates. |

## Data Flow: Install with Voice Selection

```
User runs: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
    |
    v
install.sh downloads/clones repo
    |
    v
install.sh reads audio/voices.json
    |
    +-- Interactive mode: prompt user to select voice --+
    |                                                   |
    +-- Non-interactive mode: --voice <name> flag ------+
    |                                                   |
    v                                                   v
Selected voice: "male-deep"                             |
    |                                                   |
    v                                                   |
Copy audio/male-deep/notify-*.mp3 to ~/.claude/         |
    |                                                   |
    v                                                   |
Detect Claude Code hooks system?                         |
    |                                                   |
    +-- Yes: Write hooks/hooks.json entries +---------->|
    |      inject into settings.json via jq             |
    |                                                   |
    +-- No: Inject hooks directly into                  |
    |      settings.json via jq (legacy path)           |
    |                                                   |
    v                                                   v
Done. 4 hooks registered pointing to ~/.claude/notify-*.mp3
```

## Data Flow: Plugin Install Path

```
User runs: /plugin install notify-voice@my-marketplace
    |
    v
Claude Code fetches plugin package
    |
    v
Reads .claude-plugin/plugin.json
    |
    v
Reads hooks/hooks.json
    |
    v
Claude Code sets ${CLAUDE_PLUGIN_ROOT} to plugin install location
    |
    v
Hooks registered with commands using ${CLAUDE_PLUGIN_ROOT}:
    "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh complete ${CLAUDE_PLUGIN_ROOT}/audio/default/notify-complete.mp3"
    |
    v
When hook fires, Claude Code expands ${CLAUDE_PLUGIN_ROOT} and executes command
    |
    v
notify-play.sh plays audio with cooldown
```

## Pattern 1: Dual-Path Hook Registration

**What:** Install scripts support two modes -- standalone (jq injection into `settings.json`) and plugin-aware (write `hooks/hooks.json` for the plugin system). Both produce the same runtime behavior.

**When:** `install.sh` detects Claude Code version and plugin support. If `/plugin` subcommand exists, offer plugin install. Otherwise, fall back to direct `settings.json` injection.

**Why:** Not all Claude Code users will have plugin support immediately. The standalone path ensures zero-dependency adoption. The plugin path enables marketplace distribution and automatic updates.

**Implementation sketch (install.sh):**

```bash
# After voice selection and audio copy...

# Check if Claude Code supports plugins
SUPPORTS_PLUGINS=false
if command -v claude &>/dev/null; then
    if claude plugin --help 2>/dev/null | grep -q "install"; then
        SUPPORTS_PLUGINS=true
    fi
fi

if [ "$SUPPORTS_PLUGINS" = true ]; then
    # Plugin path: hooks are auto-registered from hooks/hooks.json
    # No settings.json modification needed
    echo "Plugin mode: hooks will be registered automatically."
else
    # Standalone path: inject hooks via jq (existing logic)
    jq --arg complete_cmd "$NOTIFY_PLAY complete $CLAUDE_DIR/notify-complete.mp3" \
       ... "$SETTINGS" > "$TMPFILE"
fi
```

**Confidence:** MEDIUM. The plugin system commands (`/plugin install`, `/plugin marketplace add`) were documented in official Anthropic docs fetched during research. However, the exact CLI interface for detecting plugin support from a shell script is not documented -- the `/plugin` commands may be Claude Code slash commands only available in the Claude Code REPL, not as `claude plugin` subcommands. This needs validation during Phase planning.

## Pattern 2: Voice Pack Directory Structure

**What:** Each voice is a subdirectory under `audio/` containing 4 MP3 files. A `voices.json` manifest provides metadata for install-time selection.

**When:** Adding new voice styles without modifying install scripts.

**Example `audio/voices.json`:**

```json
{
  "default": {
    "name": "Gentle Female",
    "description": "Soft female voice, low pitch (default)",
    "gender": "female",
    "pitch": "low",
    "speed": "low",
    "dir": "default"
  },
  "male-deep": {
    "name": "Calm Male",
    "description": "Deep male voice, medium pitch",
    "gender": "male",
    "pitch": "medium",
    "speed": "medium",
    "dir": "male-deep"
  }
}
```

**Why directory-per-voice:**
1. Adding a voice is `mkdir audio/{name}` + 4 MP3 files + entry in `voices.json`. Zero script changes.
2. `generate.sh --voice male-deep` outputs to `audio/male-deep/`. Generation and runtime use the same layout.
3. Easy to preview voices before install: `ls audio/` shows all available packs.
4. Git tracks voice packs as directories. Adding/removing a voice is a clear diff.

**Backward compatibility:** The existing flat `audio/notify-*.mp3` files become `audio/default/notify-*.mp3` after migration. Install scripts should check for legacy flat layout and auto-migrate or fall back gracefully.

**Confidence:** HIGH. This is a standard pattern used by theme packs, i18n bundles, and asset collections. No external dependencies required.

## Pattern 3: Parameterized Voice Generation

**What:** `generate.py` accepts `--voice <name>` CLI argument and reads voice parameters from `voices/<name>.json` instead of hardcoded `VOICE_PARAMS`.

**When:** Generating audio for a new or existing voice pack.

**Example `voices/default.json`:**

```json
{
  "gender": "female",
  "pitch": "low",
  "speed": "low"
}
```

**Modified generate.py (key changes):**

```python
# Replace hardcoded VOICE_PARAMS with:
def load_voice_params(voice_name: str) -> dict:
    """Load voice parameters from voices/{voice_name}.json."""
    voice_file = os.path.join("voices", f"{voice_name}.json")
    with open(voice_file) as f:
        return json.load(f)

# In main():
args = parse_args()  # Add --voice argument
voice_name = args.voice or "default"
voice_params = load_voice_params(voice_name)

# In generate_one():
wav = model.inference(
    text=text,
    gender=voice_params["gender"],
    pitch=voice_params["pitch"],
    speed=voice_params["speed"],
)

# Output to voice-specific directory:
output_dir = os.path.join(OUTPUT_DIR, voice_name)
os.makedirs(output_dir, exist_ok=True)
mp3_path = os.path.join(output_dir, f"notify-{notif['name']}.mp3")
```

**Confidence:** HIGH. Straightforward refactor of `generate.py`. The Spark-TTS `model.inference()` API accepts `gender`, `pitch`, `speed` as keyword arguments (verified in `generate.py` lines 80-84).

## Pattern 4: One-Line Install via curl

**What:** A lightweight install script served via GitHub raw content URL. Users run `curl -fsSL <url> | bash` to install without cloning the repo.

**When:** Standalone install path for users who do not use the plugin marketplace.

**How it works:**

1. Host `install-online.sh` at the repo root (or in a `install/` directory).
2. User runs: `curl -fsSL https://raw.githubusercontent.com/hlwqds/notify-research/main/install-online.sh | bash`
3. The script:
   - Downloads the repo as a tarball from GitHub (`git clone --depth 1` is simpler but requires git).
   - OR downloads just the needed files: `install.sh`, `uninstall.sh`, `notify-play.sh`, and the selected voice's 4 MP3 files.
   - Runs the local install.sh with voice selection.

**Recommended approach -- clone-based (simpler):**

```bash
#!/usr/bin/env bash
# install-online.sh — One-line install for Claude Code voice notifications
set -euo pipefail

REPO="hlwqds/notify-research"
BRANCH="main"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading notify-research..."
git clone --depth 1 "https://github.com/${REPO}.git" "$TMPDIR/notify-research"

# Delegate to local install script
bash "$TMPDIR/notify-research/scripts/install.sh" "$@"

# Copy scripts to a permanent location for hook commands
INSTALL_DIR="$HOME/.claude/notify-hooks"
mkdir -p "$INSTALL_DIR"
cp "$TMPDIR/notify-research/scripts/notify-play.sh" "$INSTALL_DIR/"
cp "$TMPDIR/notify-research/scripts/uninstall.sh" "$INSTALL_DIR/"

echo "Scripts installed to $INSTALL_DIR"
echo "Note: keep this directory for uninstall and updates."
```

**Trade-offs:**
- `git clone --depth 1` requires git installed (already required for Claude Code development).
- Downloads entire repo (~50KB scripts + ~47KB audio). Minimal bandwidth.
- Install scripts reference the cloned location for `notify-play.sh`. After install, the scripts must be copied to a permanent location so the clone can be deleted.

**Alternative -- tarball-only (no git dependency):**

```bash
#!/usr/bin/env bash
# Downloads only the needed files as a tarball from GitHub API
REPO="hlwqds/notify-research"
BRANCH="main"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# GitHub tarball URL
TARBALL="https://api.github.com/repos/${REPO}/tarball/${BRANCH}"
curl -fsSL "$TARBALL" | tar xz --strip-components=1 -C "$TMPDIR"

bash "$TMPDIR/scripts/install.sh" "$@"
```

**Recommendation:** Use the `git clone --depth 1` approach. It is simpler, more transparent (users can inspect the repo), and git is a prerequisite for Claude Code users. The tarball approach requires parsing GitHub API response and the directory structure inside GitHub tarballs is non-obvious (`<sha>-<repo>/` prefix).

**Confidence:** HIGH. The `curl | bash` pattern is used by Homebrew, Rust (rustup), Node.js (nvm), and Claude Code's own install scripts. It is well-understood and has established security conventions (show the script first with `curl -fsSL <url> | bash -s -- --help`).

## Pattern 5: Plugin hooks.json Structure

**What:** A `hooks/hooks.json` file that the Claude Code plugin system reads to register hook events automatically.

**When:** Plugin install path. Users who install via `/plugin install` get hooks registered automatically without manual `settings.json` editing.

**Example `hooks/hooks.json`:**

```json
{
  "Stop": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh complete ${CLAUDE_PLUGIN_ROOT}/audio/default/notify-complete.mp3",
      "description": "Play notification sound when Claude Code task completes",
      "async": true,
      "timeout": 10
    }
  ],
  "Notification": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh confirm ${CLAUDE_PLUGIN_ROOT}/audio/default/notify-confirm.mp3",
      "description": "Play notification sound when Claude Code needs user input",
      "async": true,
      "timeout": 10
    }
  ],
  "StopFailure": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh error ${CLAUDE_PLUGIN_ROOT}/audio/default/notify-error.mp3",
      "description": "Play notification sound when Claude Code task fails",
      "async": true,
      "timeout": 10
    }
  ],
  "SubagentStop": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh progress ${CLAUDE_PLUGIN_ROOT}/audio/default/notify-progress.mp3",
      "description": "Play notification sound when a sub-agent completes",
      "async": true,
      "timeout": 10
    }
  ]
}
```

**Key detail:** `${CLAUDE_PLUGIN_ROOT}` is an environment variable set by Claude Code at runtime when executing plugin hooks. It resolves to the absolute path where the plugin is installed. This eliminates the need for install scripts to inject absolute paths into `settings.json`.

**Limitation:** `hooks/hooks.json` is static -- it cannot dynamically select a voice at install time. The voice must be chosen before plugin creation (or the plugin must provide all voices and the user selects at runtime via a wrapper script). This is a fundamental constraint of the plugin system.

**Workaround for voice selection with plugins:**

Option A: Create separate plugins per voice (`notify-voice-female`, `notify-voice-male`).
Option B: Use a default voice in `hooks.json` and provide a `select-voice.sh` script that rewrites `~/.claude/settings.json` with the chosen voice's audio paths.
Option C: Use a wrapper script that reads a voice config file and dispatches to the correct audio path.

**Recommendation:** Option B is most practical. The plugin installs with the default voice. A post-install command (`/plugin-voice-select`) or environment variable (`NOTIFY_VOICE=male-deep`) lets users switch voices. The wrapper script in Option C adds complexity without clear benefit.

**Confidence:** MEDIUM. The `hooks/hooks.json` structure and `${CLAUDE_PLUGIN_ROOT}` variable are documented in official Anthropic docs (fetched during research). However, the exact mechanics of plugin installation, marketplace setup, and voice selection at plugin install time are not fully documented. The plugin system may still be evolving. Plan for both plugin and standalone paths.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Hardcoding Absolute Paths in hooks.json

**What:** Writing absolute paths like `/home/user/.claude/notify-complete.mp3` in `hooks/hooks.json`.

**Why wrong:** Absolute paths break when the plugin is installed to a different location, when the user's home directory changes, or when the plugin is shared across machines.

**Do instead:** Use `${CLAUDE_PLUGIN_ROOT}` for plugin hooks. For standalone installs, use `$HOME/.claude/` which install scripts already resolve correctly. Never bake the full path into a static config file.

### Anti-Pattern 2: Bundling Audio in Binary Size Without Check

**What:** Adding many voice packs (each ~47KB, 4 files) without checking cumulative size impact on the repo.

**Why wrong:** Each voice pack adds ~47KB to the repo. 10 voices = ~470KB. Still small, but without a manifest and size check, the repo can accumulate unused voice packs over time.

**Do instead:** `voices.json` tracks available voices. `generate.sh --voice` produces a specific pack. Include only 2-3 curated voices in the repo by default. Additional voices can be generated on demand.

### Anti-Pattern 3: Breaking Existing Install Path During Migration

**What:** Moving `audio/notify-*.mp3` to `audio/default/` without updating install scripts or providing a migration path.

**Why wrong:** Users who installed v1.0-v1.3 have audio at `~/.claude/notify-*.mp3` (flat layout). If install.sh suddenly expects `audio/default/`, existing users break.

**Do instead:** Keep backward-compatible flat layout as the fallback. Install scripts check for both `audio/{voice}/` (new) and `audio/` (legacy) paths. Uninstall scripts clean up both layouts.

### Anti-Pattern 4: Requiring Docker for End-User Install

**What:** Making the one-line install script run Docker to generate audio on the user's machine.

**Why wrong:** Docker is only needed for audio generation, which should happen in CI or by the maintainer. End users should never need Docker. The pre-generated MP3 files are committed to the repo.

**Do instead:** The install script copies pre-generated MP3 files. Docker + generate.py are maintainer-only tools. Document this clearly in README.

### Anti-Pattern 5: Plugin-Only Distribution (No Fallback)

**What:** Distributing exclusively via the Claude Code plugin marketplace with no standalone install option.

**Why wrong:** The plugin system may not be available to all Claude Code versions or in all environments. Users behind corporate firewalls may not reach the marketplace. The standalone path provides a universal fallback.

**Do instead:** Maintain both distribution paths. The plugin path is the recommended one. The `curl | bash` path is the fallback.

## Integration Points with Existing Code

### What Gets Modified

| Existing File | Modification | Scope | Risk |
|---------------|-------------|-------|------|
| `scripts/install.sh` | Add voice selection logic, read from `audio/{voice}/` instead of `audio/`, dual registration mode | Medium -- add ~30 lines | LOW -- existing hooks injection logic unchanged |
| `scripts/install.ps1` | Same changes as install.sh for Windows | Medium -- add ~30 lines | LOW -- existing logic unchanged |
| `scripts/uninstall.sh` | Handle both flat and voice-specific audio paths in cleanup | Small -- ~5 line change | LOW -- additive cleanup |
| `scripts/uninstall.ps1` | Same as uninstall.sh | Small -- ~5 line change | LOW |
| `generate.py` | Replace hardcoded `VOICE_PARAMS` with `--voice` arg + JSON loading | Medium -- refactor ~20 lines | MEDIUM -- changes generation logic, must verify Spark-TTS API compatibility |
| `generate.sh` | Add `--voice` flag passthrough to `generate.py` | Small -- ~10 lines | LOW |
| `README.md` | Update install instructions for one-line and plugin paths | Small -- documentation only | NONE |
| `.github/workflows/ci.yml` | Add step to verify `audio/voices.json` schema and voice pack completeness | Small -- add 1 job step | LOW |

### What Gets Created (New Files)

| File | Purpose | Size Estimate |
|------|---------|---------------|
| `.claude-plugin/plugin.json` | Plugin manifest metadata | ~15 lines JSON |
| `hooks/hooks.json` | Plugin hooks definition | ~40 lines JSON |
| `audio/voices.json` | Voice pack manifest | ~20 lines JSON |
| `voices/default.json` | Default voice parameters (extracted from generate.py) | ~5 lines JSON |
| `voices/male-deep.json` | Alternative voice parameters | ~5 lines JSON |
| `audio/default/notify-*.mp3` | Voice pack directory (migrated from `audio/`) | 4 files, ~47KB total |
| `audio/male-deep/notify-*.mp3` | New voice pack | 4 files, ~47KB total |
| `install-online.sh` | One-line install entry point | ~30 lines bash |

### What Stays Unchanged

| File | Why Unchanged |
|------|--------------|
| `scripts/notify-play.sh` | Receives absolute path to MP3 as argument. Voice selection only changes which MP3 gets copied to `~/.claude/`. Playback logic is voice-agnostic. |
| `scripts/notify-play.ps1` | Same rationale as notify-play.sh. |
| `Dockerfile` | TTS inference container. Voice params passed at runtime, not baked in. |
| `requirements.txt` | No new Python dependencies. |
| `test.sh` | Test runner. Tests may need fixture updates but the runner itself is unchanged. |
| Test files (`tests/bash/*.bats`, `tests/powershell/*.Tests.ps1`) | Test the script behavior, not audio content. May need minor fixture path updates for `audio/{voice}/` structure. |

## Scalability Considerations

| Concern | Current (v1.3) | v1.4 Target | v2.0 Future |
|---------|---------------|-------------|-------------|
| Voice packs | 1 (hardcoded) | 2-3 curated | User-contributed, community voices |
| Distribution | git clone only | Plugin marketplace + curl install | npm registry? Homebrew tap? |
| Install complexity | 2-step (clone + install) | 1-step (curl or plugin install) | Zero-step (auto-installed via team settings) |
| Audio file size in repo | ~47KB (4 files) | ~141KB (12 files, 3 voices) | Could grow; consider Git LFS or release assets at 20+ voices |
| settings.json footprint | 4 hook entries | 4 hook entries (same) | Same -- voice selection does not change hook count |
| Plugin marketplace visibility | N/A | Listed in marketplace | Featured, with screenshots and ratings |

## Build Order and Dependencies

```
Phase A: Multi-Voice Audio Foundation
    |-- Create voices/ directory with default.json (extracted from generate.py)
    |-- Create audio/voices.json manifest
    |-- Migrate audio/notify-*.mp3 to audio/default/notify-*.mp3
    |-- Modify generate.py to accept --voice arg and load voices/*.json
    |-- Modify generate.sh to accept --voice flag
    |-- Generate male-deep voice pack (or another alternative)
    Depends on: Nothing
    Blocks: Phase B, Phase C, Phase D

Phase B: Plugin System Packaging
    |-- Create .claude-plugin/plugin.json
    |-- Create hooks/hooks.json with ${CLAUDE_PLUGIN_ROOT} paths
    |-- Test plugin install/uninstall flow
    Depends on: Phase A (voice directory structure must exist)
    Blocks: Phase E (README update)

Phase C: Install Script Updates
    |-- Modify install.sh for voice selection + dual registration
    |-- Modify install.ps1 for voice selection + dual registration
    |-- Update uninstall.sh/uninstall.ps1 for voice paths
    |-- Maintain backward compatibility with flat audio layout
    Depends on: Phase A (voices.json must exist)
    Blocks: Phase E, Phase F

Phase D: One-Line Install
    |-- Create install-online.sh (curl entry point)
    |-- Test one-line install on Linux, macOS, Windows
    |-- Verify cleanup (tmp dir, permanent script location)
    Depends on: Phase C (install.sh must handle voice selection)
    Blocks: Phase E

Phase E: Documentation and Community
    |-- Update README.md with both install paths
    |-- Add voice preview section
    |-- Submit to awesome-claude-code lists
    |-- Create GitHub discussion or issue template for voice requests
    Depends on: Phase B, Phase C, Phase D
    Blocks: Nothing

Phase F: Test Updates
    |-- Update bats test fixtures for audio/{voice}/ paths
    |-- Update Pester test fixtures for audio/{voice}/ paths
    |-- Add tests for voice selection logic in install.sh/install.ps1
    |-- Add CI step for voices.json schema validation
    Depends on: Phase A, Phase C
    Blocks: Nothing
```

**Parallelism:** Phase B and Phase C can run in parallel (both depend on Phase A only). Phase F can start after Phase C completes. Phase E is the final integration phase.

## GitHub Community Distribution Strategy

### Submission Targets

| Channel | Type | Effort | Expected Impact |
|---------|------|--------|----------------|
| Claude Code community discussions | Discussion post | Low (1 post) | Direct exposure to Claude Code users |
| awesome-claude-code (community list) | PR or issue | Low (1 PR) | Discovery via curated list |
| Claude Code subreddit | Post | Low (1 post) | Broad developer audience |
| GitHub Topics (`claude-code`, `hooks`, `notifications`) | Repo metadata | None (add tags) | Search discoverability |
| Claude Code Discord/Slack (if exists) | Share | Low (1 message) | Targeted audience |

### Packaging for Discovery

The repo needs these elements for community adoption:

1. **Clear README with quick start** -- One-line install at the top, voice preview section, screenshot/GIF of hook in action
2. **GitHub Topics** -- `claude-code`, `hooks`, `notifications`, `tts`, `voice`
3. **Repo description** -- "Cross-platform voice notifications for Claude Code hooks"
4. **Release tags** -- `v1.4.0` for the plugin-compatible release with multi-voice support
5. **LICENSE file** -- Already Apache 2.0 (matches Spark-TTS license)

## Competitor Reference Architecture

Two known competitor projects implement Claude Code audio notification hooks. Their architectures inform our approach:

### husniadil/cc-hooks

- **Approach:** Monorepo with multilingual TTS feedback using a Python script
- **Distribution:** Git clone + Python setup
- **Voice:** Uses Google TTS or similar for dynamic generation
- **Our differentiator:** Pre-generated audio (zero runtime dependencies), multi-voice packs, plugin system integration

### ChanMeng666/claude-code-audio-hooks

- **Approach:** Simple shell scripts with bundled audio files
- **Distribution:** Git clone + bash install
- **Voice:** Single voice, English-language
- **Our differentiator:** Chinese-language voice, multi-voice selection, plugin marketplace distribution, cross-platform (Windows PowerShell)

## Open Questions and Research Flags

| Question | Confidence | Impact | Resolution Needed |
|----------|-----------|--------|-------------------|
| Does `claude plugin` work as a shell subcommand or only as a REPL slash command? | LOW | HIGH -- affects install.sh detection logic | Phase B planning: test with actual Claude Code CLI |
| Can `hooks.json` use environment variables like `${CLAUDE_PLUGIN_ROOT}` in command strings? | MEDIUM | HIGH -- affects hooks.json structure | Phase B planning: verify against official docs or test |
| Can plugin install prompt user for voice selection interactively? | LOW | MEDIUM -- affects whether voice selection works in plugin path | Phase B planning: check plugin install hooks/lifecycle |
| What happens when a plugin update changes `hooks.json`? Are hooks re-registered? | LOW | MEDIUM -- affects voice switching after update | Phase B planning: test plugin update flow |
| Maximum recommended repo size for `curl | bash` install? | MEDIUM | LOW -- 3 voices = ~141KB, well within limits | No action needed unless 20+ voices |

## Sources

### Primary (HIGH confidence)

- [Claude Code official plugins documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) -- plugin structure, `hooks/hooks.json`, plugin.json manifest, `${CLAUDE_PLUGIN_ROOT}` variable, marketplace commands (fetched 2026-03-31)
- [Claude Code official hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) -- hook events, settings.json structure, async mode, command format (fetched 2026-03-31)
- [Existing codebase](file:///home/huanglin/code/claude-config/notify-research/) -- all 6 scripts analyzed for integration points (read 2026-03-31)

### Secondary (MEDIUM confidence)

- [husniadil/cc-hooks](https://github.com/husniadil/cc-hooks) -- competitor project with multilingual TTS (identified via WebSearch)
- [ChanMeng666/claude-code-audio-hooks](https://github.com/ChanMeng666/claude-code-audio-hooks) -- competitor project with audio hooks (identified via WebSearch)
- Spark-TTS voice creation API parameters -- `gender`, `pitch`, `speed` accepted by `model.inference()` (verified in `generate.py` lines 80-84)

### Tertiary (LOW confidence)

- Claude Code plugin marketplace availability and launch timeline -- not verified, may be in beta or planned release
- Exact `hooks.json` schema and supported fields -- documented in official docs but schema may evolve
- Community awesome-claude-code list existence and submission process -- identified via WebSearch, not verified

---
*Architecture research for: Claude Code voice notification system v1.4 hooks ecosystem distribution*
*Researched: 2026-03-31*
