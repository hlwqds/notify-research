# Phase 13: Plugin Packaging - Research

**Researched:** 2026-03-31
**Domain:** Claude Code plugin system (plugin.json manifest, hooks.json, `${CLAUDE_PLUGIN_ROOT}` variable expansion)
**Confidence:** HIGH

## Summary

Phase 13 packages the existing notification system as a Claude Code plugin. The plugin system is well-documented at code.claude.com/docs/en/plugins-reference and code.claude.com/docs/en/hooks. The key mechanism is `${CLAUDE_PLUGIN_ROOT}`, which resolves to the plugin's cached installation directory at runtime, enabling portable audio path references like `${CLAUDE_PLUGIN_ROOT}/audio/voices/gentle/notify-complete.mp3`. Plugins are installed via `claude plugin add <path-or-url>` and Claude Code caches them to `~/.claude/plugins/cache/` -- so the plugin directory must be self-contained with all audio and scripts.

The STATE.md blocker about "plugin system maturity" is resolved. The official documentation confirms full support for all required features: `hooks/hooks.json` convention, `userConfig` with `${user_config.KEY}` substitution, `shell` field for platform-specific hooks (`"bash"` and `"powershell"`), and `claude plugin validate .` for schema checking. The "everything-claude-code" repository (a widely-used community plugin) demonstrates the exact patterns needed, including `${CLAUDE_PLUGIN_ROOT}` usage in hook commands.

No new packages or dependencies are needed. This phase is purely about creating two JSON configuration files (`.claude-plugin/plugin.json` and `hooks/hooks.json`) and validating that existing audio/scripts are correctly referenced.

**Primary recommendation:** Create `.claude-plugin/plugin.json` with `userConfig.voice` and `hooks/hooks.json` with dual bash+powershell entries per event using `${CLAUDE_PLUGIN_ROOT}` and `${user_config.voice}` substitution.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Audio files stay in plugin directory. Hooks reference `${CLAUDE_PLUGIN_ROOT}/audio/voices/{voice}/notify-*.mp3` -- no copy to ~/.claude/.
- **D-02:** Install process only injects hooks into settings.json (via Claude Code plugin system or install script). No file copying needed.
- **D-03:** Each hook event has TWO entries in hooks.json: one with `"shell": "bash"` (Linux/macOS) calling `scripts/notify-play.sh`, one with `"shell": "powershell"` (Windows) calling `scripts/notify-play.ps1`.
- **D-04:** Claude Code automatically selects the correct shell per platform from the `"shell"` field.
- **D-05:** plugin.json userConfig contains only a `voice` field (default: `"gentle"`). Minimal schema -- Phase 14 adds full interactive voice selection UX.
- **D-06:** `${CLAUDE_PLUGIN_ROOT}` resolves at install time. Hooks use `${CLAUDE_PLUGIN_ROOT}/audio/voices/${voice}/notify-{type}.mp3` for audio paths.
- **D-07:** Structure validation only: plugin.json schema check, hooks.json syntax check, `${CLAUDE_PLUGIN_ROOT}` path references exist in repo. No mock execution of Claude Code plugin system.
- **D-08:** Test that audio files referenced in hooks.json actually exist at the specified relative paths.

### Claude's Discretion
- plugin.json schema details beyond userConfig (name, description, version, etc.)
- Exact hooks.json format and field structure (researcher should check Claude Code plugin spec)
- Whether to create a validation script (e.g., `validate-plugin.sh`) or use inline checks
- Whether hooks.json should be a single file or follow Claude Code plugin conventions for hook organization

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-01 | User can install the notification system as a Claude Code plugin via one command | `claude plugin add <path-or-url>` is the documented install command; plugin packaging with `.claude-plugin/plugin.json` + `hooks/hooks.json` enables this |
| DIST-04 | Plugin uses `${CLAUDE_PLUGIN_ROOT}` for portable path resolution (no hardcoded repo paths) | `${CLAUDE_PLUGIN_ROOT}` is an official env var that resolves to the plugin's cached directory; confirmed in plugins-reference docs and used in everything-claude-code example |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Claude Code plugin system | current (2026-03) | Plugin packaging and distribution | Official Anthropic plugin system; only way to achieve DIST-01 |

No external packages needed. This phase is purely configuration files (JSON).

### Supporting
None needed. All assets already exist in the repo:
- `scripts/notify-play.sh` -- bash audio player with cooldown
- `scripts/notify-play.ps1` -- PowerShell audio player with cooldown
- `audio/voices/gentle/notify-{complete,confirm,error,progress}.mp3`
- `audio/voices/deep/notify-{complete,confirm,error,progress}.mp3`

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Claude Code plugin system | Manual install.sh only | Fails DIST-01 (one-command install); existing install.sh preserved for legacy (DIST-03, Phase 14) |

**Installation:** None -- no packages to install.

## Architecture Patterns

### Recommended Plugin Directory Structure
```
repo-root/
  .claude-plugin/
    plugin.json              # Plugin manifest (name, version, userConfig)
  hooks/
    hooks.json               # Hook definitions (auto-discovered by Claude Code)
  scripts/
    notify-play.sh           # Existing -- Linux/macOS audio player
    notify-play.ps1          # Existing -- Windows audio player
  audio/
    voices/
      gentle/
        notify-complete.mp3  # Existing
        notify-confirm.mp3   # Existing
        notify-error.mp3     # Existing
        notify-progress.mp3  # Existing
      deep/
        notify-complete.mp3  # Existing
        notify-confirm.mp3   # Existing
        notify-error.mp3     # Existing
        notify-progress.mp3  # Existing
```

### Pattern 1: plugin.json Manifest
**What:** Plugin metadata file at `.claude-plugin/plugin.json`. Claude Code reads this to identify the directory as a plugin.
**When to use:** Required for all Claude Code plugins.
**Source:** https://code.claude.com/docs/en/plugins-reference

```json
{
  "name": "claude-voice-notify",
  "version": "1.4.0",
  "description": "Chinese voice notifications for Claude Code task events",
  "userConfig": {
    "voice": {
      "type": "string",
      "default": "gentle",
      "description": "Voice pack name (gentle or deep)"
    }
  }
}
```

Key fields:
- `name`: Slug-style identifier for the plugin
- `version`: Semver version string
- `userConfig`: Object defining user-configurable options. Values are prompted at `claude plugin enable` time.
- **Do NOT add a `"hooks"` field** -- Claude Code auto-discovers `hooks/hooks.json` by convention. Adding it causes duplicate hook registration errors (see Pitfall 1).

### Pattern 2: hooks.json with ${CLAUDE_PLUGIN_ROOT} and ${user_config.KEY}
**What:** Hook definitions in `hooks/hooks.json`. Claude Code reads this file and registers hooks.
**When to use:** Required for plugins that want to register hooks.
**Source:** https://code.claude.com/docs/en/hooks, https://code.claude.com/docs/en/plugins-reference

```json
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "shell": "bash",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh complete ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-complete.mp3",
          "async": true,
          "timeout": 10
        },
        {
          "hooks": [
            {
              "type": "command",
              "shell": "powershell",
              "command": "powershell -File ${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.ps1 complete ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-complete.mp3",
              "async": true,
              "timeout": 10
            }
          ]
        }
      ]
    }
  ],
  "Notification": [ /* ... same pattern with confirm type ... */ ],
  "StopFailure": [ /* ... same pattern with error type ... */ ],
  "SubagentStop": [ /* ... same pattern with progress type ... */ ]
}
```

Key points:
- **`${CLAUDE_PLUGIN_ROOT}`** resolves to the absolute path of the plugin's cached directory (e.g., `~/.claude/plugins/cache/claude-voice-notify-xxxxx/`)
- **`${user_config.voice}`** resolves to the user's selected voice (default: `"gentle"`)
- **`"shell": "bash"`** (default, Linux/macOS) and **`"shell": "powershell"`** (Windows) -- Claude Code auto-selects the correct shell per platform (D-04)
- Each event has TWO entries: one bash, one powershell (D-03)
- `"async": true` ensures hooks don't block Claude Code execution
- `"timeout": 10` matches existing install.sh behavior

### Pattern 3: userConfig Variable Expansion
**What:** User configuration values from plugin.json are available in hook commands via `${user_config.KEY}`.
**When to use:** Any hook command that needs user-configured values.
**Source:** https://code.claude.com/docs/en/plugins-reference

Variable expansion works in:
- Hook `command` strings: `${user_config.voice}` resolves to the user's value
- MCP `command` strings
- LSP `command` strings

Environment variable export: User config values are also exported as `CLAUDE_PLUGIN_OPTION_<KEY>` (e.g., `CLAUDE_PLUGIN_OPTION_VOICE=gentle`). This can be used by scripts that need to read the value programmatically.

### Anti-Patterns to Avoid
- **Adding `"hooks"` field to plugin.json:** Claude Code auto-discovers `hooks/hooks.json`. Adding a `"hooks"` field in plugin.json causes duplicate hook detection errors. This is confirmed by the everything-claude-code documentation and multiple community issues.
- **Hardcoded absolute paths in hooks.json:** Always use `${CLAUDE_PLUGIN_ROOT}`. The plugin is cached to a non-deterministic directory name under `~/.claude/plugins/cache/`.
- **Copying files to ~/.claude/:** The plugin directory IS the installation directory. Audio files live at `${CLAUDE_PLUGIN_ROOT}/audio/...` and are read in-place (D-01).
- **Using `shell &` for backgrounding:** Use `"async": true` instead. This is Claude Code's native async hook mechanism.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Plugin discovery/install | Custom install.sh to ~/.claude/ | `claude plugin add <path-or-url>` | Official plugin system handles caching, updates, enable/disable |
| Portable path resolution | Compute plugin path from repo location or env vars | `${CLAUDE_PLUGIN_ROOT}` | Official variable, always correct regardless of cache directory name |
| User config prompting | Custom interactive script | plugin.json `userConfig` | Claude Code prompts at enable time, stores in plugin state |
| Platform-specific shell selection | Detect OS in script and branch | `"shell"` field in hooks.json | Claude Code auto-selects bash/powershell per platform (D-04) |
| Hook registration | jq manipulation of settings.json | `hooks/hooks.json` convention | Claude Code auto-discovers and registers; no manual settings.json editing |
| Plugin validation | Custom lint script | `claude plugin validate .` | Official validation checks plugin.json schema, hooks.json format, frontmatter |

**Key insight:** The Claude Code plugin system handles the entire install/register/configure lifecycle. Trying to replicate any of it with custom scripts creates maintenance burden and fragility.

## Common Pitfalls

### Pitfall 1: Duplicate Hooks from plugin.json "hooks" Field
**What goes wrong:** Adding a `"hooks"` key to `.claude-plugin/plugin.json` causes Claude Code to register hooks twice -- once from plugin.json and once from auto-discovered `hooks/hooks.json`.
**Why it happens:** Claude Code has two hook loading paths: explicit `plugin.json["hooks"]` and convention-based `hooks/hooks.json` auto-discovery. Both execute.
**How to avoid:** NEVER add a `"hooks"` field to plugin.json. Only use `hooks/hooks.json`.
**Warning signs:** Duplicate hook execution (audio plays twice), or errors in Claude Code logs about duplicate hook registrations.
**Confidence:** HIGH -- confirmed in official docs and community examples (everything-claude-code).

### Pitfall 2: Non-Deterministic Plugin Cache Path
**What goes wrong:** Assuming the plugin lives at a known path like `~/.claude/plugins/claude-voice-notify/`.
**Why it happens:** Claude Code caches plugins to `~/.claude/plugins/cache/` with a non-deterministic directory name (e.g., `claude-voice-notify-a1b2c3d/`). The exact path changes on reinstall/update.
**How to avoid:** Always use `${CLAUDE_PLUGIN_ROOT}` for any self-referencing paths within hooks.
**Warning signs:** "File not found" errors from hook commands after plugin reinstall.
**Confidence:** HIGH -- documented in plugins-reference.

### Pitfall 3: User Config Default Mismatch with Available Voices
**What goes wrong:** `userConfig.voice` defaults to `"gentle"` but the audio files directory name doesn't match.
**Why it happens:** Mismatch between the default value in plugin.json and the actual directory name in `audio/voices/`.
**How to avoid:** Verify default voice name matches exactly: `"gentle"` in plugin.json must correspond to `audio/voices/gentle/` directory.
**Warning signs:** Audio file not found errors at runtime when using default voice.
**Confidence:** HIGH -- straightforward mapping verification.

### Pitfall 4: PowerShell Command Escaping in hooks.json
**What goes wrong:** PowerShell command string has incorrect escaping, causing syntax errors on Windows.
**Why it happens:** JSON string escaping interacts with PowerShell's own escaping rules.
**How to avoid:** Use simple `powershell -File <script-path> <args>` pattern (same as existing install.ps1 pattern). Avoid inline PowerShell commands with complex quoting.
**Warning signs:** Hooks fail silently on Windows; check Claude Code hook logs.
**Confidence:** MEDIUM -- existing install.ps1 already uses this pattern successfully.

### Pitfall 5: Missing Shebang or Execute Permission on Scripts
**What goes wrong:** `notify-play.sh` fails to execute when Claude Code invokes the hook command.
**Why it happens:** When Claude Code copies the plugin to cache, file permissions may not be preserved (depending on the install method).
**How to avoid:** `notify-play.sh` already has `#!/usr/bin/env bash` shebang. Ensure the file is executable in the repo (`chmod +x`). If permissions are lost during caching, Claude Code invokes bash explicitly via `"shell": "bash"` which handles this.
**Warning signs:** "Permission denied" errors in hook execution.
**Confidence:** MEDIUM -- `"shell": "bash"` mitigates this, but good practice to verify.

## Code Examples

### plugin.json (Full Example)
```json
{
  "name": "claude-voice-notify",
  "version": "1.4.0",
  "description": "Chinese voice notifications for Claude Code task events. Plays audio on task complete, confirmation, error, and progress.",
  "userConfig": {
    "voice": {
      "type": "string",
      "default": "gentle",
      "description": "Voice pack name (available: gentle, deep)"
    }
  }
}
```

Source: https://code.claude.com/docs/en/plugins-reference -- plugin.json schema section.

### hooks.json (Stop Event, Both Platforms)
```json
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "shell": "bash",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh complete ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-complete.mp3",
          "async": true,
          "timeout": 10
        },
        {
          "type": "command",
          "shell": "powershell",
          "command": "powershell -File ${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.ps1 complete ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-complete.mp3",
          "async": true,
          "timeout": 10
        }
      ]
    }
  ],
  "Notification": [
    {
      "hooks": [
        {
          "type": "command",
          "shell": "bash",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh confirm ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-confirm.mp3",
          "async": true,
          "timeout": 10
        },
        {
          "type": "command",
          "shell": "powershell",
          "command": "powershell -File ${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.ps1 confirm ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-confirm.mp3",
          "async": true,
          "timeout": 10
        }
      ]
    }
  ],
  "StopFailure": [
    {
      "hooks": [
        {
          "type": "command",
          "shell": "bash",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh error ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-error.mp3",
          "async": true,
          "timeout": 10
        },
        {
          "type": "command",
          "shell": "powershell",
          "command": "powershell -File ${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.ps1 error ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-error.mp3",
          "async": true,
          "timeout": 10
        }
      ]
    }
  ],
  "SubagentStop": [
    {
      "hooks": [
        {
          "type": "command",
          "shell": "bash",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.sh progress ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-progress.mp3",
          "async": true,
          "timeout": 10
        },
        {
          "type": "command",
          "shell": "powershell",
          "command": "powershell -File ${CLAUDE_PLUGIN_ROOT}/scripts/notify-play.ps1 progress ${CLAUDE_PLUGIN_ROOT}/audio/voices/${user_config.voice}/notify-progress.mp3",
          "async": true,
          "timeout": 10
        }
      ]
    }
  ]
}
```

Source: https://code.claude.com/docs/en/hooks -- hooks.json format and shell field; https://code.claude.com/docs/en/plugins-reference -- ${CLAUDE_PLUGIN_ROOT} and ${user_config.KEY} variable expansion.

### Validation Command
```bash
# Validate plugin structure from repo root
claude plugin validate .
```

Source: https://code.claude.com/docs/en/plugins-reference -- Plugin validation section.

### Inline Validation Script (Alternative to validate-plugin.sh)
```bash
# Quick structure checks without needing claude CLI
# 1. plugin.json is valid JSON with required fields
jq -e '.name and .version and .userConfig.voice' .claude-plugin/plugin.json

# 2. hooks.json is valid JSON with 4 event keys
jq -e '.Stop and .Notification and .StopFailure and .SubagentStop' hooks/hooks.json

# 3. Audio files exist for default voice
for type in complete confirm error progress; do
  test -f "audio/voices/gentle/notify-${type}.mp3" || echo "MISSING: audio/voices/gentle/notify-${type}.mp3"
done
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual jq injection into settings.json | `claude plugin add <path-or-url>` | Claude Code plugin system launch (2025) | One-command install, no jq dependency |
| Hardcoded absolute paths in hooks | `${CLAUDE_PLUGIN_ROOT}` variable expansion | Plugin system initial release | Portable across machines and plugin cache locations |
| OS detection in shell scripts | `"shell": "bash"` / `"shell": "powershell"` field | Claude Code hooks with shell field | Declarative platform selection, cleaner than runtime detection |

**Deprecated/outdated:**
- Pre-plugin hook installation via install.sh jq manipulation: Still works (DIST-03 legacy), but plugin-based install is the primary path going forward.
- Inline `shell &` backgrounding: Use `"async": true` instead. Claude Code's native async mechanism is more reliable.

## Open Questions

None. All STATE.md blockers resolved:
- `${CLAUDE_PLUGIN_ROOT}` variable expansion: Confirmed working (HIGH confidence, official docs)
- `claude plugin` CLI availability: Confirmed (`claude plugin add`, `claude plugin validate`, `claude plugin enable`)
- Plugin update flow: Out of scope for Phase 13 (no update mechanism needed for initial packaging)

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified -- this phase creates JSON config files only, using no external tools beyond `jq` for validation and `claude` for plugin validation, both already available on the dev machine).

## Sources

### Primary (HIGH confidence)
- https://code.claude.com/docs/en/plugins-reference -- Plugin manifest schema, directory structure, environment variables (${CLAUDE_PLUGIN_ROOT}), userConfig substitution, caching behavior, validation CLI
- https://code.claude.com/docs/en/hooks -- Hook events (Stop, Notification, StopFailure, SubagentStop), hooks.json format, shell field, async hooks, timeout
- https://code.claude.com/docs/en/plugin-marketplaces -- Marketplace distribution (informational, not needed for Phase 13)
- everything-claude-code community plugin -- Real-world example of ${CLAUDE_PLUGIN_ROOT} usage, hooks.json structure, plugin.json without hooks field

### Secondary (MEDIUM confidence)
- Existing codebase: scripts/notify-play.sh, scripts/notify-play.ps1, scripts/install.sh, scripts/install.ps1 -- confirmed hook patterns, audio paths, event mapping
- Existing audio structure: audio/voices/gentle/*, audio/voices/deep/* -- confirmed file naming convention

### Tertiary (LOW confidence)
- None -- all findings verified against official documentation or existing codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new packages; Claude Code plugin system is the only dependency, fully documented
- Architecture: HIGH - Official docs provide exact plugin.json schema, hooks.json format, and variable expansion rules. Real-world example (everything-claude-code) confirms patterns
- Pitfalls: HIGH - Duplicate hooks issue confirmed by multiple sources; cache path non-determinism documented; user config mismatch is straightforward verification

**Research date:** 2026-03-31
**Valid until:** 60 days (Claude Code plugin system is relatively stable; schema changes would be breaking and thus infrequent)
