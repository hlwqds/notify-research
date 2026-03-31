# Feature Research

**Project:** Claude Code Voice Notification System
**Milestone:** v1.4 Hooks Ecosystem Distribution
**Researched:** 2026-03-31
**Confidence:** MEDIUM (Claude Code plugin system from official docs is HIGH; competitor patterns and community adoption are MEDIUM; multi-voice audio pack distribution is LOW precedent)

## Scope

This research covers ONLY the new features needed for v1.4 "Hooks ecosystem distribution." All v1.0-v1.3 features (voice notifications, cross-platform support, automated tests, CI) are already shipped.

**What we are building:**
- Packaging the notification system as a Claude Code plugin for one-line install
- Multi-voice audio style packs (install-time selection)
- GitHub community presence (awesome lists, discussions)
- Discovery and installation documentation

**What we are NOT building:**
- Real-time TTS generation (out of scope -- CPU inference too slow)
- GUI configuration interface
- Multi-language notifications
- npm/npx packaging (wrong ecosystem)

---

## Table Stakes (Users Expect These)

Features that users assume exist when installing a Claude Code hook extension. Missing these = the install experience feels broken or amateur.

| # | Feature | Why Expected | Complexity | Notes |
|---|---------|--------------|------------|-------|
| T1 | **One-line install command** | Users of CLI tools expect `curl ... \| bash` or `npx ...` or native package manager install. Having users manually edit settings.json is unacceptable for ecosystem distribution. | MEDIUM | Claude Code has a native plugin system (`/install-plugin` or `/plugin install`). This is the primary mechanism. Fallback: curl-pipe-bash like oh-my-zsh. |
| T2 | **Clean uninstall** | Any installed extension must be cleanly removable without orphaning files or breaking settings.json. Uninstall that leaves residue is a trust killer. | LOW | If using the plugin system, `/uninstall-plugin` handles cleanup. If using curl-pipe-bash, provide an `uninstall.sh` (already exists from v1.0). |
| T3 | **Cross-platform support (Linux/macOS/Windows)** | Claude Code runs on all three platforms. A notification extension must work everywhere or users on unsupported platforms will file issues immediately. | LOW | Already shipped in v1.1. Just needs to be maintained in the plugin package. Scripts exist: install.sh, install.ps1, notify-play.sh, notify-play.ps1. |
| T4 | **README with clear installation instructions** | The first thing a user sees on GitHub. Must explain what it does, how to install, and how to configure -- in under 30 seconds of reading. | LOW | README.md already exists from v1.3. Needs updating for plugin-based installation. |
| T5 | **Pre-generated audio files in the package** | Users must not need Docker, Python, or any ML tooling. Audio files must be bundled with the install so it works immediately. | LOW | Already done -- 4 mp3 files committed to repo. Ensure they are included in the plugin package. |
| T6 | **Hook configuration merged into settings.json correctly** | The plugin must inject hooks that work with Claude Code's hook system without breaking existing user hooks or project hooks. | MEDIUM | Must test hook merging behavior. Claude Code plugin hooks merge with user/project settings. Need to verify `$CLAUDE_PLUGIN_ROOT` and `$CLAUDE_PLUGIN_DATA` env vars work in our scripts. |
| T7 | **Non-blocking playback (async: true)** | Notification hooks that block Claude Code's execution are immediately noticeable and annoying. Users expect the agent to keep working while the notification plays. | LOW | Already implemented (async: true in hook config). Must preserve in plugin format. |
| T8 | **Cooldown/debounce (5-second)** | Multiple hook events firing in rapid succession must not stack audio. Users expect one notification, not a cacophony. | LOW | Already implemented in notify-play.sh/ps1. Must preserve in plugin format. |

---

## Differentiators (Competitive Advantage)

Features that set this project apart from other Claude Code notification solutions. Not required, but valuable for adoption.

| # | Feature | Value Proposition | Complexity | Notes |
|---|---------|-------------------|------------|-------|
| D1 | **Claude Code native plugin format** | Users can install via `/plugin install notify-sounds@marketplace` -- the same mechanism they use for all Claude Code extensions. This is the most discoverable and trustworthy distribution channel. | HIGH | Requires restructuring the repo to follow Claude Code plugin conventions: `hooks/hooks.json` in plugin root, `$CLAUDE_PLUGIN_ROOT` env var in scripts, `.claude-plugin/marketplace.json` for marketplace listing. |
| D2 | **Multi-voice audio style packs** | Users can choose from multiple voice styles at install time (e.g., female/male, gentle/firm, English/Chinese). This is not offered by any competitor in the Claude Code notification space. | HIGH | Requires: (a) generating audio variants with Spark-TTS using different speaker references, (b) an install-time selection mechanism, (c) a naming convention for audio files (e.g., `notify-complete-female.mp3`). Spark-TTS supports zero-shot voice cloning via speaker reference audio -- this is feasible but requires generation infrastructure. |
| D3 | **Submission to awesome-claude-code lists** | Being listed on `hesreallyhim/awesome-claude-code` (2.8K+ stars), `Chat2AnyLLM/awesome-claude-skills`, or `quemsah/awesome-claude-plugins` drives organic discovery. These lists are where Claude Code users go to find extensions. | LOW | File a PR or issue on each awesome list repo. Provide a clear description, GIF demo, and install instructions. |
| D4 | **GitHub Topic tagging and SEO** | Proper GitHub topics (`claude-code`, `claude-code-hooks`, `audio-notification`) make the repo discoverable via GitHub search. Most competitors have poor SEO. | LOW | Add topics to repo settings. Write a good repo description. |
| D5 | **Install-time voice selection (interactive)** | When users install, they hear a preview of each voice style and choose. Interactive selection is more user-friendly than editing config files after install. | MEDIUM | Can be implemented as a menu in install.sh/install.ps1: "Select voice style: [1] Female-Gentle [2] Male-Firm [3] Neutral". Copies selected audio variant to the active slot. |
| D6 | **Contextual notification sounds** | Different sounds for different event types (already done in v1.0) but enhanced with distinct audio characteristics that users can identify without looking at the screen. | LOW | Already have 4 distinct sounds (complete, confirm, error, progress). Could enhance with more distinct audio profiles per voice pack. |

---

## Anti-Features (Explicitly NOT Build)

| # | Anti-Feature | Why Avoid | What to Do Instead |
|---|--------------|-----------|-------------------|
| A1 | **npm/npx packaging** | Claude Code is not a Node.js project. Forcing Node.js packaging adds an unnecessary dependency. The Claude Code plugin system is the native distribution mechanism. | Use Claude Code's native plugin install (`/plugin install`) or curl-pipe-bash for maximum compatibility. |
| A2 | **Docker required at runtime** | Users should not need Docker installed to use notification sounds. Docker is only for audio generation (Spark-TTS), not playback. | Bundle pre-generated mp3 files in the plugin. Docker is only used in the development/generation pipeline. |
| A3 | **Real-time TTS synthesis at runtime** | Spark-TTS CPU inference takes ~8 minutes per sentence. This is unacceptable for a notification that should play instantly. | Pre-generate all audio variants and bundle them. Only use TTS when adding new voice packs (rare, developer-time operation). |
| A4 | **Custom configuration file format** | Do not invent a new config format (YAML, TOML, custom JSON). Use what Claude Code already provides: `settings.json` hooks and environment variables. | Use Claude Code's `$CLAUDE_PLUGIN_DATA` for per-plugin data storage. Use `$CLAUDE_PLUGIN_ROOT` for plugin file paths. |
| A5 | **Audio volume control in the extension** | Adding volume controls creates platform-specific complexity (PipeWire vs PulseAudio vs CoreAudio vs Windows Audio API). Users already have system-level volume control. | Users adjust volume via their OS. The extension plays audio at whatever the system volume is. |
| A6 | **GUI configuration tool** | A GUI for selecting voices or configuring hooks adds significant complexity and dependencies (Electron, Qt, etc.). The target audience is CLI power users. | Interactive terminal prompts in install scripts (bash `select`, PowerShell `Read-Host`). |
| A7 | **Notification sound from internet/URL** | Downloading audio at runtime adds latency, network dependency, and privacy concerns. Users may be offline or behind firewalls. | Bundle all audio files in the plugin package. No network calls at runtime. |
| A8 | **Hook event filtering/config per user** | Letting users configure which events trigger notifications sounds useful but creates support burden (users breaking their config, events not firing as expected). The current 4-event set (Stop, Notification, StopFailure, SubagentStop) covers the important cases. | Ship a fixed set of 4 hook events. If demand exists, add opt-out flags in a future version. |

---

## Feature Dependencies

```
T1 (Plugin packaging format)
    ├──requires──> Claude Code plugin system understanding (research complete)
    ├──requires──> hooks/hooks.json structure (adapt from current settings.json injection)
    ├──requires──> $CLAUDE_PLUGIN_ROOT usage in scripts (refactor install.sh/ps1)
    ├──enables──> D1 (Native plugin install)
    └──enables──> D3 (Awesome list submission -- need installable product first)

D2 (Multi-voice audio packs)
    ├──requires──> Spark-TTS generation pipeline (exists from v1.0)
    ├──requires──> Speaker reference audio files (need to source)
    ├──requires──> Naming convention for audio variants (design decision)
    ├──requires──> D5 (Install-time selection -- needs variants to select from)
    └──enables──> D6 (Enhanced contextual sounds)

D5 (Interactive voice selection)
    ├──requires──> D2 (Audio variants must exist)
    ├──enhances──> T1 (Plugin install becomes more useful with selection)
    └──independent from T3, T4 (cross-platform and README are separate)

D3 (Awesome list submission)
    ├──requires──> T1 (Plugin must be installable first)
    ├──requires──> T4 (README must document the install clearly)
    └──requires──> D4 (Good GitHub SEO helps approval chances)

T6 (Hook config merging)
    ├──requires──> T1 (Plugin format defines how hooks are declared)
    └──blocks──> T7, T8 (cooldown and async only work if hooks merge correctly)
```

### Dependency Notes

- **T1 (plugin packaging) is the critical path.** Everything else -- marketplace distribution, awesome lists, community adoption -- depends on having a proper plugin package that users can install with one command.
- **D2 (multi-voice) and T1 (plugin format) can be developed in parallel.** The audio generation pipeline (Spark-TTS + Docker) already exists. New voice variants can be generated independently while the plugin format is being worked on.
- **D3 (awesome lists) should come last.** Submit to awesome lists only after T1 + T4 are solid. A submission with a broken install or confusing README will be rejected and create a negative impression.
- **D5 (interactive selection) depends on D2.** No point building a selection UI if there is only one voice pack. Ship single voice first, add selection UI when multiple packs exist.

---

## Competitor Feature Analysis

| Feature | ChanMeng666/claude-code-audio-hooks | Dev-GOM/marketplace (hook-sound-notifications) | 777genius/claude-notifications-go | ctoth/claudio | Our Approach |
|---------|--------------------------------------|-----------------------------------------------|----------------------------------|-------------|--------------|
| **Install method** | Git clone + manual script run | `/plugin install` from marketplace | Go binary download (`curl \| sh`) | Git clone + Python install | `/plugin install` (native Claude Code) + curl fallback |
| **Audio source** | Pre-generated mp3 files | Pre-generated audio | Pre-generated audio (bundled in binary) | Real-time TTS via ElevenLabs API | Pre-generated mp3 (committed to repo) |
| **Voice variants** | Single voice | Unknown | Single voice | Dynamic via API | Multiple voice packs (planned differentiator) |
| **Platforms** | Linux/macOS (bash) | Unknown | Linux/macOS/Windows (Go binary) | Cross-platform (Python) | Linux/macOS/Windows (bash + PowerShell) |
| **Hook events** | 4 events (Stop, Notification, StopFailure, SubagentStop) | Unknown | Custom events | Custom events | 4 events (matching standard set) |
| **Cooldown** | Unknown | Unknown | Unknown | Unknown | 5-second debounce (built-in) |
| **Async playback** | Unknown | Unknown | Unknown | Unknown | async: true (Claude Code native) |
| **Test coverage** | None visible | None visible | None visible | None visible | 22 automated tests (bats + Pester) |
| **CI** | None visible | None visible | None visible | None visible | GitHub Actions 3-platform matrix |
| **Chinese voice** | No (English?) | Unknown | Unknown | Unknown | Yes (Spark-TTS, Chinese primary) |

### Competitor Analysis Notes

- **ChanMeng666** is the most direct competitor. Same approach (pre-generated audio, Claude Code hooks). But no plugin format, no multi-platform support visible, no tests.
- **777genius** uses Go for cross-platform binary distribution. Clever approach but adds a compilation step. Our bash/PowerShell approach is more transparent and easier to audit.
- **ctoth/claudio** uses ElevenLabs API for real-time TTS. This requires an API key and internet access. Our pre-generated approach is simpler and works offline.
- **Dev-GOM/marketplace** already has a notification plugin in a Claude Code marketplace. This validates that the marketplace distribution channel exists and works. We should study their plugin structure.
- **No competitor offers multi-voice selection.** This is a clear differentiator opportunity.
- **No competitor has visible test coverage or CI.** Our 22 tests and GitHub Actions CI are a quality differentiator.

---

## MVP Definition for v1.4

### Launch With (Must Have)

Minimum viable product for ecosystem distribution -- what users need to discover, install, and use the notification system.

- [ ] **T1: Claude Code plugin packaging** -- Restructure repo to plugin format with `hooks/hooks.json`. This is the one feature that unlocks all distribution.
- [ ] **T3: Cross-platform support preserved** -- Ensure existing Linux/macOS/Windows scripts work within the plugin package structure.
- [ ] **T4: Updated README** -- Document plugin-based install as the primary method, with curl fallback.
- [ ] **T5: Audio files bundled** -- 4 mp3 files included in the plugin package.
- [ ] **T6: Hook config merging verified** -- Test that plugin hooks merge correctly with user/project settings.
- [ ] **T7: Non-blocking playback preserved** -- async: true in plugin hook config.
- [ ] **T8: Cooldown preserved** -- 5-second debounce still works from plugin context.
- [ ] **D4: GitHub SEO** -- Add topics and description to the repo.

### Add After Validation (v1.4.x)

Features to add once the plugin is installable and getting initial users.

- [ ] **D1: Marketplace listing** -- Submit to Claude Code marketplace once plugin format is stable and tested by early users.
- [ ] **D5: Interactive voice selection** -- Add install-time menu when multiple voice packs exist.
- [ ] **D2: Multi-voice audio packs** -- Generate additional voice variants using Spark-TTS.
- [ ] **D3: Awesome list submissions** -- File PRs on awesome-claude-code repos.

### Future Consideration (v2+)

Features to defer until the plugin has a user base and demand is proven.

- [ ] **D6: Enhanced contextual sounds** -- More event types or richer audio differentiation.
- [ ] **A8 (reconsidered): Configurable event filtering** -- If users request it.

---

## Feature Prioritization Matrix

| # | Feature | User Value | Implementation Cost | Priority |
|---|---------|------------|---------------------|----------|
| T1 | Plugin packaging format | HIGH -- enables one-line install | MEDIUM -- restructure repo, adapt scripts | P1 |
| T4 | Updated README/docs | HIGH -- first impression for discoverers | LOW -- edit existing README | P1 |
| T6 | Hook config merging verified | HIGH -- broken hooks = broken product | MEDIUM -- test with plugin format | P1 |
| T5 | Audio files bundled | HIGH -- no audio = no notification | LOW -- already done | P1 |
| T7 | Non-blocking playback | MEDIUM -- users notice blocking | LOW -- already done | P1 |
| T8 | Cooldown/debounce | MEDIUM -- users notice stacking | LOW -- already done | P1 |
| T3 | Cross-platform support | HIGH -- excluded users file issues | LOW -- already done | P1 |
| D4 | GitHub SEO | MEDIUM -- improves discovery | LOW -- add topics to repo | P1 |
| D2 | Multi-voice audio packs | MEDIUM -- nice differentiation | HIGH -- generate variants, design naming | P2 |
| D5 | Interactive voice selection | MEDIUM -- improves UX | MEDIUM -- terminal menu | P2 |
| D1 | Marketplace listing | HIGH -- best distribution channel | MEDIUM -- format + submission | P2 |
| D3 | Awesome list submissions | MEDIUM -- organic discovery | LOW -- file PRs | P2 |
| D6 | Enhanced contextual sounds | LOW -- current sounds work | MEDIUM -- audio design work | P3 |

**Priority key:**
- P1: Must have for v1.4 launch
- P2: Should have, add when possible in v1.4.x
- P3: Nice to have, future consideration

---

## Claude Code Plugin Format Reference

Based on official Claude Code plugin documentation:

### Plugin Directory Structure

```
notify-sounds/
  .claude-plugin/
    marketplace.json     # Marketplace metadata
  hooks/
    hooks.json           # Hook definitions (merged into Claude Code settings)
  audio/
    notify-complete.mp3
    notify-confirm.mp3
    notify-error.mp3
    notify-progress.mp3
  scripts/
    notify-play.sh       # Linux/macOS playback wrapper
    notify-play.ps1      # Windows playback wrapper
```

### Key Environment Variables

- `$CLAUDE_PLUGIN_ROOT` -- Absolute path to the plugin's root directory. Use this to reference audio files and scripts from within hook commands.
- `$CLAUDE_PLUGIN_DATA` -- Per-plugin writable data directory (e.g., `~/.claude/plugins/data/notify-sounds/`). Use this for user-specific state.

### hooks.json Structure

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/notify-play.sh complete \"$CLAUDE_PLUGIN_ROOT/audio/notify-complete.mp3\""
      }
    ],
    "Notification": [
      {
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/notify-play.sh confirm \"$CLAUDE_PLUGIN_ROOT/audio/notify-confirm.mp3\""
      }
    ],
    "StopFailure": [
      {
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/notify-play.sh error \"$CLAUDE_PLUGIN_ROOT/audio/notify-error.mp3\""
      }
    ],
    "SubagentStop": [
      {
        "type": "command",
        "command": "$CLAUDE_PLUGIN_ROOT/scripts/notify-play.sh progress \"$CLAUDE_PLUGIN_ROOT/audio/notify-progress.mp3\""
      }
    ]
  }
}
```

**Confidence:** MEDIUM -- the plugin system is documented officially, but the exact behavior of `$CLAUDE_PLUGIN_ROOT` expansion in hook commands, how async is specified in plugin hooks, and the merge behavior with user/project settings need hands-on validation. This is a phase-specific research flag.

---

## Install Experience Comparison

| Method | User Command | Steps | Friction Level | Ecosystem Fit |
|--------|-------------|-------|----------------|---------------|
| Claude Code plugin | `/plugin install notify-sounds@marketplace` | 1 command | Minimal | Best -- native mechanism |
| curl-pipe-bash | `curl -sSL https://raw.github.com/.../install.sh \| bash` | 1 command | Low | Good -- familiar pattern (oh-my-zsh) |
| Git clone + manual | `git clone ... && cd ... && ./install.sh` | 3+ commands | High | Poor -- power-user only |
| Manual JSON edit | User edits settings.json themselves | Many steps | Very high | Worst -- error-prone |

**Recommendation:** Support both Claude Code plugin install (primary) and curl-pipe-bash (fallback for users not using a marketplace). The curl fallback also serves as the installation method for the existing v1.0-v1.3 user base who are not on a plugin system yet.

---

## Multi-Voice Audio Pack Design

### Naming Convention (proposed)

```
audio/
  packs/
    default/
      notify-complete.mp3
      notify-confirm.mp3
      notify-error.mp3
      notify-progress.mp3
    female-gentle/
      notify-complete.mp3
      notify-confirm.mp3
      notify-error.mp3
      notify-progress.mp3
    male-firm/
      ...
  active/  -> symlink to selected pack (or copied files)
```

### Precedent Analysis

| Tool | Multi-Variant Pattern | Selection Method |
|------|----------------------|-----------------|
| oh-my-zsh | `custom/themes/<name>/` directories | `ZSH_THEME="theme"` in .zshrc |
| starship | `starship preset <name> -o config.toml` | CLI command |
| bat (syntax highlighter) | `--theme=<name>` flag | CLI flag / config file |
| This project | `audio/packs/<voice>/` directories | Interactive install menu + config file |

### Generation Pipeline for New Voice Packs

1. Source a speaker reference audio file (3-10 seconds of clean speech)
2. Place reference in Docker generate environment
3. Run `generate.sh --speaker <ref.wav> --output-dir audio/packs/<voice-name>/`
4. Preview generated audio
5. Add new pack name to install script's selection menu

**Spark-TTS supports zero-shot voice cloning** -- provide a short speaker reference and it generates speech in that voice. This is the mechanism for creating new voice packs without training.

---

## Sources

### Primary (HIGH confidence)

- [Claude Code Plugin Documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) -- Plugin structure, marketplace.json, hooks/hooks.json, env vars (HIGH confidence, official Anthropic docs, verified 2026-03-31)
- [Claude Code Hooks Reference](https://docs.anthropic.com/en/docs/claude-code/hooks) -- Hook events, configuration, async behavior (HIGH confidence, official docs)
- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks-guide) -- Practical hook examples, notification patterns (HIGH confidence, official docs)
- Existing project codebase -- All scripts, tests, and CI analyzed from v1.0-v1.3

### Secondary (MEDIUM confidence)

- [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) -- 2.8K+ stars, primary awesome list for Claude Code ecosystem (MEDIUM -- repo structure and submission process not deeply verified)
- [Chat2AnyLLM/awesome-claude-skills](https://github.com/Chat2AnyLLM/awesome-claude-skills) -- 39K+ skills listed, large community (MEDIUM -- repo activity level not verified)
- [quemsah/awesome-claude-plugins](https://github.com/quemsah/awesome-claude-plugins) -- Plugins-specific awesome list (MEDIUM -- newer repo, less established)
- [ChanMeng666/claude-code-audio-hooks](https://github.com/ChanMeng666/claude-code-audio-hooks) -- Direct competitor, analyzed structure and approach (MEDIUM -- repo not deeply audited)
- [777genius/claude-notifications-go](https://github.com/777genius/claude-notifications-go) -- Go-based competitor (MEDIUM -- repo not deeply audited)
- [Dev-GOM/claude-code-marketplace](https://github.com/Dev-GOM/claude-code-marketplace) -- Community marketplace implementation (MEDIUM -- plugin structure needs deeper study)
- [Spark-TTS GitHub](https://github.com/SparkAudio/Spark-TTS) -- TTS engine for voice pack generation (HIGH from v1.0 research)

### Tertiary (LOW confidence)

- oh-my-zsh theme selection pattern -- general CLI precedent (LOW -- not directly related to audio)
- starship preset system -- general CLI precedent (LOW -- not directly related to audio)
- npm/npx distribution patterns -- Node.js ecosystem (LOW -- wrong ecosystem for Claude Code)
- Six additional competitor repos found via search (6m1w/claude-sound-fx, RonitSachdev/ccnudge, ctoth/claudio, etc.) -- surface-level analysis only

---
*Feature research for: Claude Code voice notification system v1.4 hooks ecosystem distribution*
*Researched: 2026-03-31*
