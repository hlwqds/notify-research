# Phase 16: Marketplace 构建 - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `.claude-plugin/marketplace.json` marketplace catalog and enrich `plugin.json` with optional marketplace fields. The result must pass `claude plugin validate .` with zero errors.

</domain>

<decisions>
## Implementation Decisions

### Marketplace Identifier
- **D-01:** marketplace.json `name` = `hlwqds` — matches existing README install commands (`/plugin install claude-voice-notify@hlwqds`)
- **D-02:** marketplace.json `owner.name` = user's display name, `owner.email` = public contact

### Plugin Source
- **D-03:** Plugin source = relative path `"./"` — single-plugin repo, natural fit for relative path. Claude Code clones the entire repo, plugin files live at root level.

### Discovery Metadata
- **D-04:** Plugin entry includes: keywords `["notification", "audio", "voice", "chinese", "tts"]`, category `"productivity"`
- **D-05:** plugin.json enriched fields: author (name), license `"MIT"`, homepage (GitHub URL), repository (GitHub URL), keywords (same as marketplace entry)

### Claude's Discretion
- marketplace.json optional fields: `metadata.description`, `metadata.version` — include if useful
- Plugin entry `tags` array — include if different from keywords

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Claude Code Plugin Marketplace Docs
- `https://code.claude.com/docs/en/plugin-marketplaces` — marketplace.json schema, plugin source types, validation, hosting on GitHub
- `https://code.claude.com/docs/en/discover-plugins` — user-side marketplace discovery and install flow

### Existing Plugin Artifacts
- `.claude-plugin/plugin.json` — current plugin manifest (name, version, description, userConfig.voice)
- `hooks/hooks.json` — hooks configuration (4 events × 2 platforms, all ${CLAUDE_PLUGIN_ROOT} paths)
- `README.md` — existing install instructions (references `/plugin marketplace add hlwqds/notify-research`)

### Project Context
- `.planning/REQUIREMENTS.md` — v1.5 requirements (MKT-01 through VAL-01)
- `.planning/ROADMAP.md` — Phase 16 success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.claude-plugin/plugin.json` — existing manifest, needs enrichment not replacement
- `hooks/hooks.json` — already portable, no changes needed (MKT-04 is verify-only)
- `README.md` — already has marketplace install instructions, updated in Phase 15

### Established Patterns
- kebab-case naming for plugin identifier (`claude-voice-notify`)
- `${CLAUDE_PLUGIN_ROOT}` for all file references in hooks
- MIT License (Phase 15)
- GitHub repo: `hlwqds/notify-research`

### Integration Points
- `.claude-plugin/` directory — marketplace.json goes alongside existing plugin.json
- No code changes needed — this phase is purely configuration/manifest work

</code_context>

<specifics>
## Specific Ideas

- Marketplace name `hlwqds` must match README references exactly
- Relative path `"./"` means the entire repo root IS the plugin directory
- Keywords should cover both English discoverability (`notification`, `audio`) and language (`chinese`)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 16-marketplace*
*Context gathered: 2026-03-31*
