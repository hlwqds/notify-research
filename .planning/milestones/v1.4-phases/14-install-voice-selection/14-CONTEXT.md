# Phase 14: Install & Voice Selection - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can install via curl|bash (or iex+curl on Windows) fallback, choose a voice style at install time with audio preview, and legacy install scripts continue to work. Covers DIST-02, DIST-03, VOICE-04, VOICE-05.

This phase does NOT include: MIT LICENSE, README rewrite, GitHub topic tags (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Voice Selection UX (VOICE-04, VOICE-05)
- **D-01:** Interactive numbered list showing available voices from voices.json manifest. User enters number to select.
- **D-02:** Preview playback before confirming: after selecting a voice number, user can type 'p' to hear a sample, then confirm or change. User chooses which notification type to preview (complete/confirm/error/progress).
- **D-03:** install.sh adds interactive voice prompt when no --voice flag or VOICE env var is provided. install.ps1 adds -Voice parameter with interactive prompt when omitted.
- **D-04:** If no audio player is available for preview, skip preview gracefully and proceed with selection.

### Voice Swap Mechanism (VOICE-05)
- **D-05:** Voice switching = re-run install.sh --voice deep (or install.ps1 -Voice deep). Script overwrites all 4 mp3 files in ~/.claude/ atomically (write to temp, then move). Idempotent — safe to run multiple times.
- **D-06:** No separate switch-voice script needed. Re-running install is the switching mechanism.

### curl|bash Installer (DIST-02)
- **D-07:** install-online.sh downloads GitHub Release tarball (latest release tag via GitHub API), extracts, and runs install.sh.
- **D-08:** Version strategy: query GitHub API for latest release tag. No pinned version — always installs latest published release.
- **D-09:** One-liner format: `curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/install-online.sh | bash`

### Windows iex+curl Installer (DIST-02)
- **D-10:** Provide install-online.ps1 as Windows equivalent. Downloads same GitHub Release tarball, extracts, runs install.ps1 -Voice $VoiceName.
- **D-11:** One-liner format: `iex (irm https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/install-online.ps1)`
- **D-12:** iex flow mirrors bash flow: download tarball → extract to temp dir → run install.ps1 with voice selection.

### Legacy Backward Compatibility (DIST-03)
- **D-13:** Existing install.sh/install.ps1 must continue to work unchanged when called with current arguments (no --voice flag = default gentle). All existing tests must still pass.
- **D-14:** New flags (--voice, -Voice) are additive — no breaking changes to existing behavior.

### Claude's Discretion
- Exact voice selection prompt text and formatting
- Temp file naming and cleanup during atomic voice swap
- GitHub API error handling (rate limit, network failure) in install-online scripts
- tarball extraction directory and cleanup
- Whether install-online.sh detects platform and shows platform-relevant voices only
- Exact user interaction flow (prompt → select → preview → confirm sequence details)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current Installation Scripts
- `scripts/install.sh` — jq-based hook injection, VOICE env var support (line 77: `VOICE="${VOICE:-gentle}"`), copies to ~/.claude/
- `scripts/install.ps1` — PowerShell hook injection, $VoiceName hardcoded to "gentle" (line 19), copies to ~/.claude/
- `scripts/uninstall.sh` — Linux/macOS cleanup
- `scripts/uninstall.ps1` — Windows cleanup

### Plugin Files (Phase 13)
- `.claude-plugin/plugin.json` — Plugin manifest with userConfig.voice (default: "gentle")
- `hooks/hooks.json` — 8 hook entries (4 events x 2 platforms), uses `${user_config.voice}` and `${CLAUDE_PLUGIN_ROOT}`

### Audio Files
- `audio/voices/gentle/notify-{complete,confirm,error,progress}.mp3` — Default voice pack
- `audio/voices/deep/notify-{complete,confirm,error,progress}.mp3` — Deep voice pack
- `voices.json` — Voice pack manifest (lists available voices)

### Voice Config
- `voices/gentle.json` — Gentle voice parameters (gender/pitch/speed)
- `voices/deep.json` — Deep voice parameters

### Playback Scripts
- `scripts/notify-play.sh` — Linux/macOS audio player (paplay/afplay), accepts type + audio path args
- `scripts/notify-play.ps1` — Windows audio player (MediaPlayer), accepts type + audio path args

### Test Files
- `tests/bash/install.bats` — install.sh tests (must remain green)
- `tests/powershell/install.Tests.ps1` — install.ps1 tests (must remain green)

### Requirements
- `.planning/REQUIREMENTS.md` — DIST-02 (curl|bash install), DIST-03 (legacy compat), VOICE-04 (voice selection at install), VOICE-05 (atomic voice swap)

### Prior Phase Context
- `.planning/phases/12-multi-voice-foundation/12-CONTEXT.md` — voice directory structure, generate.py --voice, voices.json manifest
- `.planning/phases/13-plugin-packaging/13-CONTEXT.md` — plugin.json, hooks.json, ${CLAUDE_PLUGIN_ROOT} paths, userConfig.voice

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- install.sh `VOICE="${VOICE:-gentle}"` (line 77) — already reads VOICE env var, add --voice flag alongside
- install.sh audio copy loop (lines 74-85) — copies 4 mp3 files, already voice-aware
- install.ps1 audio copy loop (lines 72-81) — copies 4 mp3 files, needs voice parameter
- notify-play.sh/ps1 — can be reused for preview playback during voice selection
- voices.json manifest — already lists available voice packs for prompt generation

### Established Patterns
- install.sh uses `jq` for idempotent settings.json manipulation
- install.ps1 uses `ConvertFrom-Json`/`ConvertTo-Json` + BOM-free `WriteAllText`
- Both scripts do prerequisite checks (claude version, audio player, settings.json existence)
- Both scripts copy audio to ~/.claude/ and inject hooks into settings.json
- Forward-slash paths in PowerShell (per Claude Code bug #26759)

### Integration Points
- install.sh line 77: add --voice flag parsing before VOICE env var fallback
- install.ps1 line 19: change $VoiceName hardcoded to -Voice parameter with prompt
- New files: scripts/install-online.sh, scripts/install-online.ps1
- GitHub Release API: `https://api.github.com/repos/<owner>/<repo>/releases/latest`

</code_context>

<specifics>
## Specific Ideas

- Voice selection flow: list voices from voices.json → user picks number → optional preview (user picks notification type) → confirm → copy 4 mp3 + inject hooks
- install-online.sh: `GITHUB_REPO="owner/repo"; LATEST=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | jq -r .tag_name); curl -fsSL "https://github.com/$GITHUB_REPO/archive/$LATEST.tar.gz" | tar xz && cd repo-$LATEST && bash scripts/install.sh`
- install-online.ps1: mirror bash flow using Invoke-WebRequest + Expand-Archive + install.ps1
- Atomic swap: copy 4 files to temp dir first, then mv/copy to ~/.claude/ in one step

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 14-install-voice-selection*
*Context gathered: 2026-03-31*
