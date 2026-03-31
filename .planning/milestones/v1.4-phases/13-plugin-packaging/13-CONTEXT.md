# Phase 13: Plugin Packaging - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Create Claude Code plugin packaging: `.claude-plugin/plugin.json` manifest + `hooks/hooks.json` with portable path resolution via `${CLAUDE_PLUGIN_ROOT}`. After this phase, users can install the notification system as a Claude Code plugin with one command. Audio files and scripts remain in the plugin directory (no copy to ~/.claude/).

This phase does NOT include: curl|bash fallback installer (Phase 14), interactive voice selection at install time (Phase 14), legacy backward compatibility verification (Phase 14), or community/docs (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Audio Delivery Strategy
- **D-01:** Audio files stay in plugin directory. Hooks reference `${CLAUDE_PLUGIN_ROOT}/audio/voices/{voice}/notify-*.mp3` — no copy to ~/.claude/.
- **D-02:** Install process only injects hooks into settings.json (via Claude Code plugin system or install script). No file copying needed.

### Platform Hook Handling
- **D-03:** Each hook event has TWO entries in hooks.json: one with `"shell": "bash"` (Linux/macOS) calling `scripts/notify-play.sh`, one with `"shell": "powershell"` (Windows) calling `scripts/notify-play.ps1`.
- **D-04:** Claude Code automatically selects the correct shell per platform from the `"shell"` field.

### userConfig & Voice Selection
- **D-05:** plugin.json userConfig contains only a `voice` field (default: `"gentle"`). Minimal schema — Phase 14 adds full interactive voice selection UX.
- **D-06:** `${CLAUDE_PLUGIN_ROOT}` resolves at install time. Hooks use `${CLAUDE_PLUGIN_ROOT}/audio/voices/${voice}/notify-{type}.mp3` for audio paths.

### Testing Approach
- **D-07:** Structure validation only: plugin.json schema check, hooks.json syntax check, `${CLAUDE_PLUGIN_ROOT}` path references exist in repo. No mock execution of Claude Code plugin system.
- **D-08:** Test that audio files referenced in hooks.json actually exist at the specified relative paths.

### Claude's Discretion
- plugin.json schema details beyond userConfig (name, description, version, etc.)
- Exact hooks.json format and field structure (researcher should check Claude Code plugin spec)
- Whether to create a validation script (e.g., `validate-plugin.sh`) or use inline checks
- Whether hooks.json should be a single file or follow Claude Code plugin conventions for hook organization

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Claude Code Plugin System
- Claude Code hooks documentation — hook system and plugin packaging (researcher should verify current state of `${CLAUDE_PLUGIN_ROOT}`, plugin.json schema, hooks.json format)
- STATE.md blocker note: "Claude Code plugin system maturity -- hooks.json variable expansion (${CLAUDE_PLUGIN_ROOT}), claude plugin CLI availability, plugin update flow not hands-on verified"

### Current Installation Scripts
- `scripts/install.sh` — jq-based hook injection into ~/.claude/settings.json, copies audio to ~/.claude/, 4 hook events (Stop/Notification/StopFailure/SubagentStop)
- `scripts/install.ps1` — PowerShell hook injection with forward-slash paths, `"shell": "powershell"` in hook commands
- `scripts/notify-play.sh` — Linux/macOS audio player (paplay/afplay), 5-second cooldown
- `scripts/notify-play.ps1` — Windows audio player (MediaPlayer), 5-second cooldown

### Audio Files
- `audio/voices/gentle/notify-{complete,confirm,error,progress}.mp3` — Default voice pack
- `audio/voices/deep/notify-{complete,confirm,error,progress}.mp3` — Deep voice pack

### Requirements
- `.planning/REQUIREMENTS.md` — DIST-01 (plugin install one command), DIST-04 (${CLAUDE_PLUGIN_ROOT} portable paths)

### Prior Phase Context
- `.planning/phases/12-multi-voice-foundation/12-CONTEXT.md` — audio/voices/{name}/ directory structure, voice config JSON files

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/notify-play.sh` — Ready to call from hooks with plugin-relative path, accepts notification type + audio path args
- `scripts/notify-play.ps1` — Same for Windows, already uses forward-slash paths
- `audio/voices/gentle/` and `audio/voices/deep/` — Pre-generated voice packs, no copy needed

### Established Patterns
- Hook structure: `{"hooks": [{"type": "command", "command": "...", "async": true, "timeout": 10}]}`
- 4 events: Stop → complete, Notification → confirm, StopFailure → error, SubagentStop → progress
- install.sh uses `jq` for idempotent settings.json manipulation
- install.ps1 uses `ConvertFrom-Json`/`ConvertTo-Json` + BOM-free `WriteAllText`

### Integration Points
- New `.claude-plugin/` directory at repo root — plugin manifest location
- `hooks/hooks.json` — Claude Code reads this to register hooks
- Audio paths in hooks must use `${CLAUDE_PLUGIN_ROOT}` variable expansion
- Test fixtures at `tests/fixtures/settings.json` — may need plugin-aware hooks fixture

</code_context>

<specifics>
## Specific Ideas

- plugin.json: `{"name": "claude-voice-notify", "version": "1.4.0", "userConfig": {"voice": {"type": "string", "default": "gentle"}}}`
- hooks.json: Each event has bash + powershell entries, audio path = `${CLAUDE_PLUGIN_ROOT}/audio/voices/${voice}/notify-{type}.mp3`
- No install.sh changes needed in this phase — plugin install is separate from script install

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 13-plugin-packaging*
*Context gathered: 2026-03-31*
