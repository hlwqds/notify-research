# Stack Research: Hooks Ecosystem Distribution & Multi-Voice Audio Packs (v1.4)

**Domain:** Claude Code plugin packaging, multi-voice audio distribution, GitHub community presence
**Researched:** 2026-03-31
**Confidence:** HIGH

## Recommended Stack

### Core: Claude Code Plugin System

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Claude Code Plugins** | 1.0.33+ | Official plugin packaging and distribution framework | First-class support for hooks, skills, agents bundled into installable units. Replaces manual `settings.json` manipulation with `/plugin install`. Auto-update support. `${CLAUDE_PLUGIN_ROOT}` variable for portable paths. Requires Claude Code >= 1.0.33. |
| **Plugin Marketplace** | -- | Self-hosted catalog of plugins via `.claude-plugin/marketplace.json` | GitHub-hosted marketplace with `/plugin marketplace add owner/repo`. Provides version tracking, auto-updates, discovery. Users install with `/plugin install notify@your-marketplace`. |

### Plugin Packaging Artifacts

| Artifact | Location | Purpose | Why This Structure |
|----------|----------|---------|-------------------|
| **plugin.json** | `.claude-plugin/plugin.json` | Plugin manifest: name, version, description, author, hooks reference | Claude Code auto-discovers components; manifest provides metadata for marketplace listing. The `name` field becomes the namespace prefix. |
| **hooks.json** | `hooks/hooks.json` | Hook event definitions (Stop, Notification, StopFailure, SubagentStop) | Auto-discovered by Claude Code from `hooks/` directory. No explicit declaration needed in plugin.json unless custom path. JSON format with event matchers and command actions. |
| **Audio files** | `audio/` | Pre-generated mp3 notification sounds (12-15 KB each) | Committed to repo alongside plugin. 4 files per voice style. At 11-15 KB each, even 4 voice styles = ~200 KB total -- trivial git overhead. |
| **Scripts** | `scripts/` | Cross-platform notify-play wrappers (bash + PowerShell) | Reuse existing `notify-play.sh` and `notify-play.ps1` with paths rewritten to `${CLAUDE_PLUGIN_ROOT}`. No script rewrite needed -- only path references change. |
| **LICENSE** | `LICENSE` | Required for marketplace submission and awesome-list inclusion | Anthropic official marketplace requires license field in plugin.json. Most awesome lists require open-source license. MIT recommended for maximum adoption. |
| **CHANGELOG.md** | Root | Version history for users and auto-update detection | Plugin versioning uses semver; changelog documents what changed per release. Also used by awesome-list maintainers when reviewing submissions. |

### Plugin Directory Structure

```
claude-code-notify/                    # Repo root (marketplace source)
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── hooks/
│   └── hooks.json                     # 4 event hooks (Stop, Notification, StopFailure, SubagentStop)
├── audio/
│   └── voices/
│       ├── default/                   # Default voice (existing 4 mp3 files)
│       │   ├── notify-complete.mp3
│       │   ├── notify-confirm.mp3
│       │   ├── notify-error.mp3
│       │   └── notify-progress.mp3
│       ├── female/                    # Female voice style
│       │   └── ... (4 files)
│       └── calm/                      # Calm/soft voice style
│           └── ... (4 files)
├── scripts/
│   ├── notify-play.sh                 # Linux/macOS playback (existing, path-updated)
│   └── notify-play.ps1                # Windows playback (existing, path-updated)
├── README.md                          # Installation + usage docs
├── LICENSE                            # MIT
└── CHANGELOG.md                       # Version history
```

### Multi-Voice Audio Management

| Technology | Purpose | Why Recommended |
|------------|---------|-----------------|
| **Directory-per-voice** | `audio/voices/{voice-name}/` structure | Simple, zero-dependency approach. Each voice is 4 mp3 files in a directory. No database, no config format, no runtime selection logic beyond reading a directory name. |
| **`userConfig` in plugin.json** | Prompt user to select voice at install time | Claude Code plugin system provides `userConfig` for user-configurable values. The selected voice name is available as `${user_config.voice}` in hook commands. Stored in settings.json. |
| **Symlink at install** | Link selected voice files to `audio/active/` | Symlinks avoid duplicating audio files. `${CLAUDE_PLUGIN_DATA}` (persistent across updates) stores the user's voice selection. A `SessionStart` hook or install-time script creates symlinks. |
| **Spark-TTS 0.5B** (Docker) | Generate additional voice styles offline | Reuse existing Docker TTS pipeline from `generate.sh`. Each voice requires different speaker reference audio. CPU inference ~8 min/sentence -- acceptable for offline pre-generation. |

### Voice Selection Architecture

The `userConfig` mechanism in plugin.json provides the cleanest UX:

```json
{
  "name": "claude-code-notify",
  "version": "1.4.0",
  "userConfig": {
    "voice": {
      "description": "Voice style for notifications (default, female, calm)",
      "sensitive": false
    }
  },
  "hooks": "hooks/hooks.json"
}
```

Hook commands reference the selected voice:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh complete ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-complete.mp3",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Why `userConfig` over alternatives:**

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| `userConfig` in plugin.json | Built-in Claude Code UX; persisted in settings.json; survives plugin updates via `${CLAUDE_PLUGIN_DATA}` | Only one selection per install (no runtime switching without reinstall) | **Recommended** -- simple, supported, no extra code |
| Environment variable (`NOTIFY_VOICE`) | Familiar pattern; easy to test | Not prompted at install time; users must read docs; lost across sessions unless set in shell profile | Not recommended -- discovery problem |
| Separate CLI command | Full flexibility; could support per-event voice | Requires adding a skill/command; more complex; users must manually run | Not recommended -- over-engineering for v1.4 |

### GitHub Community Presence

| Channel | Purpose | Effort | Impact |
|---------|---------|--------|--------|
| **Claude Code Official Marketplace** (`claude-plugins-official`) | Primary distribution channel; appears in `/plugin` Discover tab | Submit via `claude.ai/settings/plugins/submit` after plugin is published | HIGH -- built-in discovery for all Claude Code users |
| **Self-hosted Marketplace** (this repo) | Fallback distribution; gives full control over versions and releases | Add `.claude-plugin/marketplace.json` to repo root | HIGH -- enables `/plugin marketplace add owner/repo` |
| **quemsah/awesome-claude-plugins** | Community curated list (9,600+ repos indexed, 2026) | PR with repo link + description | MEDIUM -- automated indexing, likely included automatically |
| **ComposioHQ/awesome-claude-plugins** | Most popular fork of awesome-claude-plugins list | PR following their contribution guidelines | MEDIUM -- actively maintained, accepts community submissions |
| **r/ClaudeCode** (Reddit) | Community discussion and announcement | Post a showcase thread with demo | LOW-MEDIUM -- audience is engaged but transient |
| **GitHub Topics** | Discoverability within GitHub search | Add topics to repo: `claude-code`, `claude-code-plugin`, `notification`, `hooks`, `tts` | LOW effort, MEDIUM impact |
| **GitHub Releases** | Versioned distribution points | Tag releases with `v1.4.0`, include audio files in release assets | HIGH -- enables marketplace ref pinning to specific SHAs |

### Development & Validation Tools

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **claude plugin validate** | Claude Code CLI | Validate plugin.json, hooks.json, skill/agent frontmatter | Built-in validator catches schema errors before submission. Run as part of CI. |
| **claude --plugin-dir** | Claude Code CLI | Test plugin locally without installation | Loads plugin directly from directory. Use during development to iterate without install/uninstall cycle. |
| **jq** | System | Validate hooks.json syntax | Already a project dependency; use `jq . hooks/hooks.json` in CI to catch malformed JSON. |

### Installation: Plugin Packaging

The plugin system replaces manual install scripts. Users install via:

```bash
# Add marketplace (one-time)
/plugin marketplace add your-org/claude-code-notify

# Install the plugin
/plugin install claude-code-notify@your-org

# Reload to activate
/reload-plugins
```

The old install.sh/install.ps1 scripts are no longer needed for plugin users. Keep them as a **fallback** for users who prefer manual installation or have Claude Code < 1.0.33.

### Installation: CI Validation

```bash
# Validate plugin structure (add to CI)
claude plugin validate .

# Test plugin locally
claude --plugin-dir ./path/to/plugin

# Validate hooks.json syntax
jq . hooks/hooks.json > /dev/null

# Validate plugin.json syntax
jq . .claude-plugin/plugin.json > /dev/null
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Distribution** | Claude Code Plugin System | npm package | npm adds Node.js dependency; our plugin is pure shell + audio. npm source type is available but unnecessary for shell-only plugins. |
| **Distribution** | Claude Code Plugin System | curl + bash install script (current approach) | Current approach requires users to clone repo, run scripts manually, and trust `curl | bash`. Plugin system provides trust via marketplace signing, auto-updates, and one-command install. |
| **Distribution** | Claude Code Plugin System | Git submodule / .claude/ directory | `.claude/` is per-project only; not shareable. Plugins are user-scoped (cross-project) with marketplace distribution. |
| **Voice storage** | Directory-per-voice in repo | Download on demand via GitHub Releases | Adds network dependency at install time; breaks offline use. With 4 voices x 4 files x ~12 KB = ~192 KB total, in-repo storage is negligible. |
| **Voice storage** | Directory-per-voice in repo | Git LFS for audio files | Overkill for 12 KB files. Git LFS adds complexity (pointer files, LFS bandwidth limits) for no benefit. |
| **Voice selection** | `userConfig` in plugin.json | Environment variable | Not prompted at install time; users must set it manually in shell profile. `userConfig` is the Claude Code-native approach. |
| **Voice selection** | `userConfig` in plugin.json | CLI command for runtime switching | Adds complexity (need a skill/command); voice preference rarely changes after initial setup. Defer to v2.0 if requested. |
| **License** | MIT | Apache-2.0 | Both are permissive. MIT is shorter and more widely recognized. Spark-TTS (the generation tool) uses Apache-2.0 but our generated audio and scripts can be MIT. |
| **Community list** | quemsah/awesome-claude-plugins | ComposioHQ/awesome-claude-plugins | Both are good targets. Submit to both via PR. quemsah auto-indexes so may be included automatically. |
| **Plugin scope** | User scope (default) | Project scope | Notification preference is personal, not team-wide. User scope = install once, works everywhere. Project scope would force all collaborators to use the same notification settings. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`strict: false` in marketplace entry** | Means the marketplace operator (you) controls all component definitions. Good for curated marketplaces but prevents the plugin from having its own identity. You want `strict: true` (default) so plugin.json is the authority. | Default `strict: true` -- plugin.json manages its own components |
| **Hardcoded absolute paths in hooks.json** | Plugins are copied to `~/.claude/plugins/cache` after install. Hardcoded paths like `/home/user/...` break. Use `${CLAUDE_PLUGIN_ROOT}` for all paths. | `${CLAUDE_PLUGIN_ROOT}/audio/voices/.../notify-complete.mp3` |
| **`${CLAUDE_PLUGIN_ROOT}` for persistent state** | Plugin cache is deleted on update. Any user preference stored here is lost. | `${CLAUDE_PLUGIN_DATA}` for persistent data (voice selection cache) |
| **`.claude-plugin/` for component directories** | Only `plugin.json` belongs in `.claude-plugin/`. Components (hooks/, scripts/, audio/) must be at plugin root. Claude Code auto-discovers them there but not inside `.claude-plugin/`. | Place `hooks/`, `scripts/`, `audio/` at repo root |
| **Git submodules for audio files** | Adds clone complexity; submodules are a common source of "empty directory" issues. Audio files are tiny (12 KB each). | Commit audio files directly to repo |
| **`../` path traversal in plugin paths** | Marketplace validator rejects paths with `..`. Plugins cannot reference files outside their directory after installation (they are copied to cache). | Keep all files within plugin root |
| **Gradio or FastAPI for voice selection UI** | Adds Python server dependency; over-engineering for selecting one of 4 options. Claude Code's `userConfig` handles this natively with a text prompt. | `userConfig` in plugin.json |
| **GitHub Actions for voice audio generation** | Spark-TTS requires 8 min/sentence on CPU and ~5 GB model files. CI runners would time out and waste resources. | Generate locally via `generate.sh` with Docker, commit resulting mp3 files |

## Stack Patterns by Variant

### Plugin-Only Distribution (recommended for v1.4)

**If the user has Claude Code >= 1.0.33:**

```bash
# One-time marketplace add
/plugin marketplace add owner/claude-code-notify

# Install (prompts for voice selection via userConfig)
/plugin install claude-code-notify@owner

# Reload to activate
/reload-plugins
```

No install.sh needed. No jq dependency. No Claude version check needed (plugin system handles compatibility). Audio files come from the plugin cache.

### Hybrid: Plugin + Legacy Scripts (backward compatible)

**If supporting users with Claude Code < 1.0.33:**

Keep existing `install.sh` and `install.ps1` as fallback. Document both installation methods in README:

1. **Plugin install** (recommended): `/plugin install claude-code-notify@owner`
2. **Manual install** (legacy): `bash scripts/install.sh` or `powershell -File scripts/install.ps1 -RepoPath .`

The plugin hooks.json and the legacy install.sh produce identical `settings.json` entries. Both approaches can coexist -- the plugin just makes it zero-effort.

### Multi-Voice Audio Generation

**If adding a new voice style:**

```bash
# 1. Generate audio with different speaker reference
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v ~/.cache/spark-tts:/app/pretrained_models/Spark-TTS-0.5B:z \
  -e SPEAKER_REF=/path/to/reference.wav \
  -e GENERATE_TYPES=complete,confirm,error,progress \
  spark-tts-notify

# 2. Copy output to new voice directory
mkdir -p audio/voices/new-voice
mv ~/.claude/notify-*.mp3 audio/voices/new-voice/

# 3. Commit and tag release
git add audio/voices/new-voice/
git commit -m "feat: add new-voice style"
```

## Version Compatibility

| Component | Required Version | Notes |
|-----------|-----------------|-------|
| Claude Code (plugin system) | >= 1.0.33 | Plugin system introduced in this version. `/plugin` command available. |
| Claude Code (StopFailure hook) | >= 2.1.78 | StopFailure event support. Current install.sh checks this. Plugin system does not enforce version constraints -- hooks simply won't fire for unsupported events. |
| Claude Code (`userConfig`) | >= 1.0.33 | `userConfig` in plugin.json is part of the plugin system. Prompts user at install time. |
| `${CLAUDE_PLUGIN_ROOT}` | >= 1.0.33 | Environment variable provided by plugin system at runtime. |
| `${CLAUDE_PLUGIN_DATA}` | >= 1.0.33 | Persistent data directory. Resolves to `~/.claude/plugins/data/{id}/`. |
| `claude plugin validate` | >= 1.0.33 | CLI command for validating plugin structure. |
| jq (legacy path only) | Any | Only needed for install.sh/uninstall.sh fallback. Not needed for plugin install path. |
| Spark-TTS 0.5B (generation only) | Latest main | Only used during audio pre-generation via Docker. Not a runtime dependency. |
| Docker (generation only) | 24.x+ | Only needed when running `generate.sh`. End users never need Docker. |

## Migration Path: Existing Hooks to Plugin

The current install.sh writes hooks directly to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "/path/to/notify-play.sh complete /path/to/notify-complete.mp3", "async": true}]}]
  }
}
```

The plugin approach uses `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}`:

```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh complete ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-complete.mp3", "async": true, "timeout": 10}]}]
  }
}
```

**Key changes for migration:**

1. **Paths**: Replace `$REPO_ROOT` / `$NOTIFY_PLAY` with `${CLAUDE_PLUGIN_ROOT}`
2. **Voice directory**: Change `audio/notify-${type}.mp3` to `audio/voices/${user_config.voice}/notify-${type}.mp3`
3. **No settings.json manipulation**: Plugin system handles hook injection automatically
4. **No audio file copying**: Audio stays in plugin cache, not in `~/.claude/`
5. **uninstall.sh becomes `/plugin uninstall`**: Plugin system handles cleanup

**What install.sh does that plugin system does not:**
- Claude version check (>= 2.1.78) -- plugin system does not validate hook event support
- Platform-specific audio player check (paplay/afplay) -- plugin system does not validate prerequisites
- These checks could move to a `SessionStart` hook that warns users if prerequisites are missing

## GitHub Release Strategy

| Version | Content | Marketplace Ref |
|---------|---------|-----------------|
| `v1.4.0` | Plugin packaging + default voice + 1 additional voice | `ref: "v1.4.0"` or `sha: "<commit>"` |
| `v1.4.1` | Bug fixes, documentation improvements | `ref: "v1.4.1"` |
| `v1.5.0` | Additional voice styles | `ref: "v1.5.0"` |

Marketplace entries can pin to specific SHAs for stability, or follow tags for automatic updates.

## Sources

- [Claude Code Plugins - Official Docs](https://code.claude.com/docs/en/plugins) -- plugin creation, structure, submit process (HIGH confidence, verified 2026-03-31)
- [Claude Code Plugin Marketplaces - Official Docs](https://code.claude.com/docs/en/plugin-marketplaces) -- marketplace creation, distribution, hosting, validation (HIGH confidence, verified 2026-03-31)
- [Claude Code Plugins Reference - Official Docs](https://code.claude.com/docs/en/plugins-reference) -- complete schema, hooks format, CLAUDE_PLUGIN_ROOT, CLAUDE_PLUGIN_DATA, userConfig, caching behavior (HIGH confidence, verified 2026-03-31)
- [Discover and Install Plugins - Official Docs](https://code.claude.com/docs/en/discover-plugins) -- official marketplace (claude-plugins-official), CLI commands, scopes (HIGH confidence, verified 2026-03-31)
- [GitHub Issue #27307 - Plugin hooks path format](https://github.com/anthropics/claude-code/issues/27307) -- confirms hooks/hooks.json auto-discovery (HIGH confidence)
- [quemsah/awesome-claude-plugins](https://github.com/quemsah/awesome-claude-plugins) -- automated Claude Code plugin indexing, 9,600+ repos (MEDIUM confidence -- not directly reviewed)
- [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins) -- community curated list, accepts PRs (MEDIUM confidence)
- [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills) -- 340 plugins + 1367 skills collection (MEDIUM confidence -- not directly reviewed)
- [All 26 Claude Code Hooks Lifecycle - Reddit r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1s72jgp/all_26_claude_code_hooks_lifecycle_explained/) -- comprehensive hooks reference (MEDIUM confidence)
- [Best Claude Code Plugins 2026 - BuildToLaunch](https://buildtolaunch.substack.com/p/best-claude-code-plugins-tested-review) -- plugin marketplace review framework (LOW confidence -- not directly reviewed)

---
*Stack research for: Hooks ecosystem distribution & multi-voice audio packs (v1.4 milestone)*
*Researched: 2026-03-31*
