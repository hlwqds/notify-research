# Project Research Summary

**Project:** Claude Code Voice Notification System (v1.4 Hooks Ecosystem Distribution)
**Domain:** Claude Code plugin packaging, multi-voice audio distribution, GitHub community presence
**Researched:** 2026-03-31
**Confidence:** HIGH

## Executive Summary

v1.4 transforms an existing Claude Code voice notification system (v1.0-v1.3 shipped) from a manual git-clone install into a distributable ecosystem extension. The recommended approach uses the Claude Code native plugin system (`/plugin install`) as the primary distribution channel, backed by a `curl | bash` fallback for users on older Claude Code versions. Multi-voice audio support adds install-time voice selection via directory-per-voice packs under `audio/voices/{name}/`, with Spark-TTS 0.5B used offline (Docker, CPU) to pre-generate additional voice variants. Community discovery targets awesome-claude-code lists and Chinese developer communities (V2EX, Juejin), positioning the project's Chinese TTS voice as its primary differentiator in a crowded notification-hooks landscape.

The key risk is the Claude Code plugin system's maturity -- while officially documented, several integration details (CLI vs REPL commands for `claude plugin`, exact `hooks.json` variable expansion behavior, plugin update flow) have not been hands-on verified. The mitigation is to maintain the standalone `curl | bash` install path as a fully functional fallback, so the project is never dependent on plugin system quirks. The second risk is market differentiation: at least 5 competitors already offer Claude Code audio notification hooks. The mitigation is to position around Chinese TTS voice (genuinely unique) and zero-dependency pure-bash install, while targeting Chinese developer communities where this resonates most.

## Key Findings

### Recommended Stack

The stack is minimal -- this is a shell-script + audio-files project, not a runtime application. The one new technology is the Claude Code plugin system.

**Core technologies:**
- **Claude Code Plugin System** (>= 1.0.33): Official plugin packaging framework with `plugin.json` manifest, `hooks/hooks.json` auto-discovery, `${CLAUDE_PLUGIN_ROOT}` path variable, and `userConfig` for install-time prompts. Replaces manual `settings.json` manipulation.
- **Multi-voice directory structure** (`audio/voices/{name}/`): Each voice is 4 MP3 files in a subdirectory. Zero-dependency -- no database, no config format, no runtime logic beyond reading a directory name.
- **`userConfig` in plugin.json**: Claude Code-native mechanism for prompting voice selection at install time. Persists in `settings.json`, survives plugin updates.
- **`curl | bash` fallback**: `install-online.sh` serves as the one-line install entry point using `git clone --depth 1`. Covers users without plugin support or behind corporate firewalls.
- **Spark-TTS 0.5B** (Docker, CPU, offline): Used only during audio pre-generation by the maintainer. Not a runtime dependency. Generates additional voice variants via zero-shot voice cloning with speaker reference audio.

### Expected Features

**Must have (table stakes for v1.4 launch):**
- Plugin packaging format (`.claude-plugin/plugin.json` + `hooks/hooks.json`) -- enables one-line install
- Cross-platform support preserved (Linux/macOS/Windows bash + PowerShell)
- Pre-generated audio files bundled in plugin (4 MP3 per voice, ~47 KB per pack)
- Non-blocking playback (async: true) and 5-second cooldown preserved
- Hook config merging verified (plugin hooks must not break existing user/project hooks)
- Updated README with plugin-based install as primary method
- GitHub SEO (topics, repo description)

**Should have (competitive differentiators, add after validation):**
- Multi-voice audio packs (2-3 curated voices generated via Spark-TTS)
- Interactive voice selection at install time (`userConfig` prompt)
- Marketplace listing submission (after stability testing by early users)
- Awesome-list submissions (hesreallyhim, pascalporedda, quemsah)

**Defer (v2+):**
- Enhanced contextual sounds (more event types, richer audio differentiation)
- Configurable event filtering (ship fixed 4-event set; add opt-out if demand exists)
- Per-event voice selection
- npm/npx packaging (wrong ecosystem)

### Architecture Approach

The architecture introduces a dual-path distribution strategy: (1) Claude Code plugin package with auto-discovered hooks and `${CLAUDE_PLUGIN_ROOT}` path resolution, and (2) standalone install via `curl | bash` that clones the repo and delegates to `install.sh`. Both paths share the same audio files, playback scripts, and cooldown mechanism -- only the hook registration mechanism differs.

**Major components:**
1. **`.claude-plugin/plugin.json`** -- Plugin manifest (name, version, description, `userConfig` for voice). Claude Code reads this at install time.
2. **`hooks/hooks.json`** -- Maps 4 hook events (Stop, Notification, StopFailure, SubagentStop) to playback commands using `${CLAUDE_PLUGIN_ROOT}` paths. Auto-discovered by plugin system.
3. **`audio/voices/{name}/`** -- Directory-per-voice packs (4 MP3 each). Adding a voice = mkdir + 4 files + entry in `voices.json`. Install script copies selected voice to `~/.claude/`.
4. **`scripts/install.sh`** -- Modified for voice selection (interactive menu + `--voice` flag) and dual registration (plugin-aware vs legacy jq injection). Detects Claude Code plugin support and chooses path accordingly.
5. **`scripts/notify-play.sh` / `notify-play.ps1`** -- Unchanged playback wrappers. Voice-agnostic (receive absolute path to MP3 as argument).
6. **`generate.py`** -- Modified to accept `--voice` CLI arg, load params from `voices/{name}.json` instead of hardcoded `VOICE_PARAMS`.
7. **`install-online.sh`** -- New one-line install entry point: `git clone --depth 1` + delegate to `install.sh`.

**Key pattern**: Voice switching is idempotent. The install script always copies 4 files named `notify-{type}.mp3` to `~/.claude/`, but from different source directories. `settings.json` paths never change. A `~/.claude/notify-voice.txt` manifest tracks the selected voice.

### Critical Pitfalls

1. **`curl | bash` has no integrity verification** -- Pin URLs to tagged releases (not `main`), provide a two-step audit alternative, never use `sudo`. This is the industry-standard tradeoff but must be handled with care.
2. **Audio variants can bloat git history** -- Keep total committed audio under 200 KB (3 voices x 4 files x ~12 KB = ~144 KB). Do NOT use Git LFS for files under 100 KB. Generate and preview locally, only commit final selections. Use `.gitattributes` to mark MP3 as binary.
3. **`settings.json` path hardcoding breaks on non-standard setups** -- Detect `CLAUDE_CONFIG_DIR` env var, create `settings.json` if missing, let users specify `--claude-dir`. This is critical for the remote installer reaching diverse environments.
4. **Crowded competitor landscape requires sharp positioning** -- At least 5 competitors offer Claude Code notification hooks. Position around Chinese TTS voice (genuinely unique) and zero-dependency pure-bash install. Target Chinese developer communities specifically.
5. **Voice selection must preserve idempotent installation** -- Store selected voice in manifest, use consistent filenames (`notify-{type}.mp3`), clean old files before copying new voice, test voice-switching round-trip in bats tests.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Multi-Voice Audio Foundation
**Rationale:** All downstream work (plugin packaging, install scripts, community docs) depends on the audio directory structure existing first. This is the foundation that unblocks parallel development.
**Delivers:** `audio/voices/{name}/` directory structure, `voices.json` manifest, parameterized `generate.py` with `--voice` arg, 1 additional voice pack generated and committed.
**Addresses:** T5 (audio bundled), D2 (multi-voice packs -- foundation only)
**Avoids:** Pitfall 2 (repo bloat -- establish audio management policy early), Pitfall 5 (voice breaks idempotency -- design manifest and naming convention first)

### Phase 2: Plugin System Packaging
**Rationale:** The plugin format is the critical-path enabler for all distribution (marketplace, discovery, auto-updates). This should be done as early as possible so it can be tested thoroughly.
**Delivers:** `.claude-plugin/plugin.json`, `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}` paths, validated plugin structure via `claude plugin validate`.
**Uses:** Claude Code Plugin System (>= 1.0.33), `${CLAUDE_PLUGIN_ROOT}` variable, `userConfig` for voice
**Implements:** Plugin manifest, hook auto-registration
**Avoids:** Pitfall 3 (hardcoded paths -- use `${CLAUDE_PLUGIN_ROOT}` everywhere)

### Phase 3: Install Script Updates
**Rationale:** Install scripts must handle both plugin-aware and standalone paths, plus voice selection. Depends on Phase 1 (voice directory structure) and Phase 2 (plugin format understanding).
**Delivers:** Modified `install.sh`/`install.ps1` with voice selection, dual registration mode, backward-compatible cleanup in `uninstall.sh`/`uninstall.ps1`. Updated bats/Pester test fixtures.
**Addresses:** T1 (plugin packaging integration), T3 (cross-platform preserved), T6 (hook merging), T7 (async), T8 (cooldown), D5 (interactive voice selection)
**Avoids:** Pitfall 5 (voice breaks idempotency), Pitfall 3 (settings.json path issues)

### Phase 4: One-Line Install
**Rationale:** The `curl | bash` entry point depends on updated install scripts. Should come after Phase 3 so it delegates to a working install.sh.
**Delivers:** `install-online.sh` with tagged-release URL pinning, CI validation of remote URL, tested on all three platforms.
**Uses:** `git clone --depth 1` pattern, GitHub raw content URLs (pinned to release tags)
**Avoids:** Pitfall 1 (integrity verification -- pin to tag, provide two-step alternative), Pitfall 3 (robust path detection)

### Phase 5: Documentation and Community
**Rationale:** All functional pieces must be in place before going public. README, community submissions, and discovery channels come last.
**Delivers:** Updated README (plugin + curl install, voice preview, platform parity), GitHub topics/SEO, awesome-list submissions (following contribution guidelines), community posts (HN, Reddit, Chinese forums).
**Addresses:** T4 (README), D3 (awesome-lists), D4 (GitHub SEO)
**Avoids:** Pitfall 4 (crowded market -- lead with Chinese TTS differentiator), Pitfall 6 (README assumes Linux), Pitfall 7 (bad launch timing), Pitfall 8 (awesome-list PR rejected)

### Phase Ordering Rationale

- Phase 1 first because the audio directory restructure (`audio/` -> `audio/voices/default/`) is a breaking change that all other phases must account for. Getting this right early prevents rework.
- Phase 2 and Phase 3 can run in parallel (both depend only on Phase 1). Plugin packaging is independent of install script updates -- they share the same audio files but touch different code paths.
- Phase 4 depends on Phase 3 (delegates to install.sh).
- Phase 5 is the integration phase -- it brings together plugin format, install scripts, and voice selection into a coherent user-facing product. Should not begin until the install experience is stable.
- This ordering avoids Pitfall 5 (voice idempotency) by establishing the manifest and naming convention in Phase 1, and avoids Pitfall 3 (path hardcoding) by using `${CLAUDE_PLUGIN_ROOT}` in Phase 2.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Plugin Packaging):** The `hooks.json` variable expansion (`${CLAUDE_PLUGIN_ROOT}`, `${user_config.voice}`) is documented but not hands-on verified. The `claude plugin` CLI may be REPL-only (not available as shell subcommand). The plugin update flow (do hooks re-register?) is undocumented. Run `/gsd:research-phase` before this phase.
- **Phase 5 (Community):** Awesome-list contribution guidelines must be read for each target repo before submitting. Chinese developer community posting norms need research. The messaging strategy (how to position Chinese TTS differentiator) needs a draft-and-review cycle.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Multi-Voice Foundation):** Directory-per-voice is a standard pattern (themes, i18n). `generate.py` parameterization is straightforward. Spark-TTS API is already used in the codebase.
- **Phase 3 (Install Script Updates):** Shell script voice selection is well-understood. The existing install.sh patterns are proven in v1.0-v1.3.
- **Phase 4 (One-Line Install):** `curl | bash` is used by Homebrew, rustup, nvm. The pattern is established.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Claude Code plugin system documented in official Anthropic docs. `userConfig`, `${CLAUDE_PLUGIN_ROOT}`, marketplace commands all from official sources verified 2026-03-31. |
| Features | MEDIUM | Table stakes are clear (plugin format, cross-platform, audio bundled). Differentiator features (multi-voice, marketplace listing) are well-scoped but depend on plugin system details that are not hands-on verified. |
| Architecture | MEDIUM-HIGH | Dual-path distribution and directory-per-voice are sound patterns. Plugin hook structure is documented. Key uncertainty: whether `hooks.json` supports dynamic variable expansion and how plugin install lifecycle works. |
| Pitfalls | MEDIUM-HIGH | Security pitfalls (curl pipe-to-shell, path hardcoding) are well-documented in industry. Competitor landscape analysis is based on actual awesome-list repos. Some pitfalls (repo bloat thresholds, HN timing) are based on community consensus rather than hard data. |

**Overall confidence:** HIGH

The project is an incremental extension of a working v1.3 system. The core risk is plugin system integration details, but the standalone fallback path ensures the project works regardless. No novel technology is being introduced -- all components (Claude Code plugins, shell scripts, pre-generated audio, Spark-TTS) are proven individually.

### Gaps to Address

- **Plugin system hands-on validation**: `hooks.json` variable expansion, `claude plugin` CLI availability as shell subcommand, plugin update behavior. Must be validated in Phase 2 planning via `claude --plugin-dir` testing.
- **`userConfig` voice selection UX**: Whether the install-time prompt is text-based or supports menu selection. Whether `${user_config.voice}` works in hook command strings. Verify in Phase 2.
- **Awesome-list contribution guidelines**: Each target repo has different submission processes. Must read CONTRIBUTING.md for each before Phase 5. The hesreallyhim list explicitly rejects PRs from third parties (requires issues instead).
- **Chinese TTS voice quality for alternative voices**: The default voice (female, low pitch) was manually tuned. Alternative voices (male-deep, etc.) have not been generated or quality-tested yet. Plan a generation-and-review cycle in Phase 1.
- **Windows `curl | bash` equivalent**: The one-line install is bash-only. Windows users still need PowerShell manual install. Consider whether `Invoke-WebRequest | powershell` is viable for Phase 4.

## Sources

### Primary (HIGH confidence)
- [Claude Code Plugins Official Docs](https://code.claude.com/docs/en/plugins) -- plugin structure, `plugin.json` schema, marketplace submission process
- [Claude Code Plugin Marketplaces Official Docs](https://code.claude.com/docs/en/plugin-marketplaces) -- marketplace creation, distribution, validation
- [Claude Code Plugins Reference Official Docs](https://code.claude.com/docs/en/plugins-reference) -- `hooks/hooks.json` format, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, `userConfig`
- [Claude Code Hooks Official Docs](https://code.claude.com/docs/en/hooks) -- hook events, async mode, command format
- [GitHub Issue #27307](https://github.com/anthropics/claude-code/issues/27307) -- confirms hooks/hooks.json auto-discovery
- [Existing codebase](file:///home/huanglin/code/claude-config/notify-research/) -- all 6 scripts, 22 tests, CI configuration analyzed

### Secondary (MEDIUM confidence)
- [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) -- 2.8K+ stars, contribution guidelines, competitor landscape
- [pascalporedda/awesome-claude-code](https://github.com/pascalporedda/awesome-claude-code) -- hooks-specific awesome list
- [quemsah/awesome-claude-plugins](https://github.com/quemsah/awesome-claude-plugins) -- 9,600+ repos, automated indexing
- [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins) -- community curated list
- [ChanMeng666/claude-code-audio-hooks](https://github.com/ChanMeng666/claude-code-audio-hooks) -- direct competitor
- [husniadil/cc-hooks](https://github.com/husniadil/cc-hooks) -- competitor with multilingual TTS
- Spark-TTS `model.inference()` API -- `gender`, `pitch`, `speed` parameters verified in `generate.py` lines 80-84

### Tertiary (LOW confidence)
- [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills) -- plugin collection, not directly reviewed
- [Best Claude Code Plugins 2026 - BuildToLaunch](https://buildtolaunch.substack.com/p/best-claude-code-plugins-tested-review) -- plugin review, not directly reviewed
- Show HN engagement rates for developer tools -- no quantitative data found
- Chinese developer community posting norms -- not researched in depth
- Dev-GOM/claude-code-marketplace -- competitor marketplace, plugin structure needs deeper study

---
*Research completed: 2026-03-31*
*Ready for roadmap: yes*
