# Phase 16: Marketplace 构建 - Research

**Researched:** 2026-03-31
**Domain:** Claude Code plugin marketplace system (marketplace.json, plugin.json, validation)
**Confidence:** HIGH

## Summary

This phase creates the `.claude-plugin/marketplace.json` catalog file and enriches the existing `plugin.json` with optional marketplace metadata fields. The work is purely configuration/manifest -- no code changes needed. The official Claude Code documentation at `code.claude.com/docs/en/plugin-marketplaces` provides the complete marketplace.json schema with clear field definitions, and the plugins reference at `code.claude.com/docs/en/plugins-reference` documents the complete plugin.json manifest schema.

The current plugin artifacts are in good shape: `plugin.json` exists with name, version, description, and userConfig; `hooks/hooks.json` already uses `${CLAUDE_PLUGIN_ROOT}` for all 8 hook paths (4 events x 2 platforms). The marketplace.json will be a new file alongside plugin.json. Claude CLI 2.1.86 is available locally for validation (`claude plugin validate .`).

**Primary recommendation:** Create marketplace.json with the locked decisions (name=hlwqds, owner info, source="./", keywords, category), enrich plugin.json with author/license/homepage/repository/keywords fields, then run `claude plugin validate .` to confirm zero errors.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** marketplace.json `name` = `hlwqds` -- matches existing README install commands (`/plugin install claude-voice-notify@hlwqds`)
- **D-02:** marketplace.json `owner.name` = user's display name, `owner.email` = public contact
- **D-03:** Plugin source = relative path `"./"` -- single-plugin repo, natural fit for relative path. Claude Code clones the entire repo, plugin files live at root level.
- **D-04:** Plugin entry includes: keywords `["notification", "audio", "voice", "chinese", "tts"]`, category `"productivity"`
- **D-05:** plugin.json enriched fields: author (name), license `"MIT"`, homepage (GitHub URL), repository (GitHub URL), keywords (same as marketplace entry)

### Claude's Discretion
- marketplace.json optional fields: `metadata.description`, `metadata.version` -- include if useful
- Plugin entry `tags` array -- include if different from keywords

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MKT-01 | Users can add marketplace via `/plugin marketplace add owner/repo` | marketplace.json schema defines `name` field used as marketplace identifier; hosting on GitHub enables `owner/repo` add syntax |
| MKT-02 | marketplace.json contains name, owner, plugin entry (source/description/version/author) | Complete schema documented with required fields (name, owner, plugins array) and plugin entry fields |
| MKT-03 | plugin.json enriched with author, license, homepage, repository, keywords | Plugin manifest schema documents these as optional metadata fields |
| MKT-04 | hooks.json uses `${CLAUDE_PLUGIN_ROOT}` for all paths (verify no regression) | Existing hooks.json verified: all 8 hook commands use `${CLAUDE_PLUGIN_ROOT}` |
| VAL-01 | `claude plugin validate .` passes with zero errors | Validation CLI available (v2.1.86), checks plugin.json syntax and hooks.json schema |
</phase_requirements>

## Standard Stack

### Core

This phase requires no npm packages or libraries. It is pure JSON manifest work.

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Claude Code CLI | 2.1.86 (local) | `claude plugin validate .` | Official validation command for plugin.json and hooks.json |

### Alternatives Considered

Not applicable -- this is configuration-only work with no library choices.

## Architecture Patterns

### marketplace.json Schema (HIGH confidence -- official docs)

Source: https://code.claude.com/docs/en/plugin-marketplaces

**Required fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Marketplace identifier (kebab-case, no spaces). Public-facing: users see it when installing. |
| `owner` | object | Marketplace maintainer information |
| `plugins` | array | List of available plugins |

**Owner fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Name of the maintainer or team |
| `email` | string | No | Contact email for the maintainer |

**Optional metadata:**

| Field | Type | Description |
|-------|------|-------------|
| `metadata.description` | string | Brief marketplace description |
| `metadata.version` | string | Marketplace version |
| `metadata.pluginRoot` | string | Base directory prepended to relative plugin source paths |

### Plugin Entry Schema (HIGH confidence -- official docs)

Each entry in `plugins` array:

**Required:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier (kebab-case, no spaces) |
| `source` | string or object | Where to fetch the plugin from |

**Optional standard metadata:**

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Brief plugin description |
| `version` | string | Plugin version (plugin.json takes priority if both set) |
| `author` | object | Author info (`name` required, `email` optional) |
| `homepage` | string | Plugin homepage or documentation URL |
| `repository` | string | Source code repository URL |
| `license` | string | SPDX license identifier (e.g., MIT, Apache-2.0) |
| `keywords` | array | Tags for discovery and categorization |
| `category` | string | Plugin category for organization |
| `tags` | array | Tags for searchability |
| `strict` | boolean | Whether plugin.json is authority for component definitions (default: true) |

### plugin.json Manifest Schema (HIGH confidence -- official docs)

Source: https://code.claude.com/docs/en/plugins-reference

The manifest is optional. If included, only `name` is required. Metadata fields:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Unique identifier (kebab-case) |
| `version` | string | Semantic version |
| `description` | string | Brief explanation of plugin purpose |
| `author` | object | `{"name": "...", "email": "...", "url": "..."}` |
| `homepage` | string | Documentation URL |
| `repository` | string | Source code URL |
| `license` | string | License identifier |
| `keywords` | array | Discovery tags |
| `userConfig` | object | User-configurable values prompted at enable time |

**Important:** `author` in plugin.json is an **object** (not a string), with `name` as the required sub-field.

### Plugin Source Types (HIGH confidence -- official docs)

For this phase, the source is a relative path (D-03):

| Source | Type | Fields | Notes |
|--------|------|--------|-------|
| Relative path | `string` | none | Must start with `./`. Resolves relative to marketplace root (repo root, not `.claude-plugin/` dir). |
| GitHub | object | `source: "github"`, `repo`, `ref?`, `sha?` | |
| Git URL | object | `source: "url"`, `url`, `ref?`, `sha?` | |
| Git subdir | object | `source: "git-subdir"`, `url`, `path`, `ref?`, `sha?` | Sparse clone |
| npm | object | `source: "npm"`, `package`, `version?`, `registry?` | |

**Critical path resolution detail:** Relative paths resolve relative to the marketplace root, which is the directory containing `.claude-plugin/`. So `"./"` points to the repo root, even though marketplace.json lives at `.claude-plugin/marketplace.json`. Do NOT use `../` to climb out.

### Strict Mode (HIGH confidence -- official docs)

| Value | Behavior |
|-------|----------|
| `true` (default) | `plugin.json` is the authority. Marketplace entry supplements it. Both merged. |
| `false` | Marketplace entry is entire definition. If plugin also has plugin.json with components, it fails to load. |

**Recommendation for this project:** Use default `strict: true` (or omit the field). The plugin already has a `plugin.json` managing its components. The marketplace entry provides supplementary metadata (keywords, category, etc.).

### Recommended marketplace.json

Based on locked decisions:

```json
{
  "name": "hlwqds",
  "owner": {
    "name": "hlwqds",
    "email": "[public contact email]"
  },
  "metadata": {
    "description": "Cross-platform voice notifications for Claude Code"
  },
  "plugins": [
    {
      "name": "claude-voice-notify",
      "source": "./",
      "description": "Chinese voice notifications for Claude Code task events. Plays audio on task complete, confirmation, error, and progress.",
      "version": "1.4.0",
      "author": {
        "name": "hlwqds"
      },
      "keywords": ["notification", "audio", "voice", "chinese", "tts"],
      "category": "productivity"
    }
  ]
}
```

**Notes:**
- `metadata.description` included (Claude's discretion -- useful for marketplace discovery, non-blocking warning if omitted)
- `metadata.version` omitted (adds no value for a single-plugin marketplace)
- `tags` omitted (same content as `keywords`, no benefit to duplication)
- No `license`, `homepage`, `repository` in marketplace entry -- these belong in `plugin.json` (D-05), and the docs state plugin.json takes priority anyway

### Recommended plugin.json enrichment

Based on locked decision D-05, add to existing plugin.json:

```json
{
  "name": "claude-voice-notify",
  "version": "1.4.0",
  "description": "Chinese voice notifications for Claude Code task events. Plays audio on task complete, confirmation, error, and progress.",
  "author": {
    "name": "hlwqds"
  },
  "license": "MIT",
  "homepage": "https://github.com/hlwqds/notify-research",
  "repository": "https://github.com/hlwqds/notify-research",
  "keywords": ["notification", "audio", "voice", "chinese", "tts"],
  "userConfig": {
    "voice": {
      "type": "string",
      "default": "gentle",
      "description": "Voice pack name (available: gentle, deep)",
      "title": "Voice"
    }
  }
}
```

**Note:** Version bump to 1.5.0 is Phase 17 (DOC-02), not this phase. Keep 1.4.0 here.

## Don't Hand-Roll

Not applicable for this phase -- it is pure configuration work with no custom logic to build.

## Common Pitfalls

### Pitfall 1: Relative path resolution confusion
**What goes wrong:** Setting `"source": "./plugin"` when the plugin files are at repo root, or using `"../"` to try to escape.
**Why it happens:** marketplace.json lives inside `.claude-plugin/` subdirectory, but paths resolve relative to the repo root (the directory containing `.claude-plugin/`).
**How to avoid:** For a single-plugin repo where files are at root, use `"source": "./"`. Never use `../`.
**Warning signs:** Validation error "Path contains '..'" or plugin installation failure "Plugin directory not found at path".

### Pitfall 2: author field type mismatch
**What goes wrong:** Writing `"author": "hlwqds"` (string) in plugin.json instead of `"author": {"name": "hlwqds"}` (object).
**Why it happens:** The marketplace plugin entry accepts a simple author object, but plugin.json requires an object with at least `name`.
**How to avoid:** Always use the object form `{"name": "..."}`.
**Warning signs:** `claude plugin validate` reports schema error.

### Pitfall 3: marketplace.json placement
**What goes wrong:** Creating marketplace.json at repo root instead of inside `.claude-plugin/`.
**Why it happens:** Confusion about directory structure -- only `plugin.json` goes in `.claude-plugin/`, not components, but `marketplace.json` also goes there.
**How to avoid:** Both `plugin.json` and `marketplace.json` live at `.claude-plugin/`. Path: `.claude-plugin/marketplace.json`.
**Warning signs:** Validation error "File not found: .claude-plugin/marketplace.json".

### Pitfall 4: Strict mode conflict with dual component definitions
**What goes wrong:** Setting `strict: false` in marketplace entry while plugin.json also declares components (hooks, commands, etc.), causing "Plugin has conflicting manifests" error.
**Why it happens:** `strict: false` means marketplace entry is the entire definition; any plugin.json components are treated as conflicts.
**How to avoid:** Use default `strict: true` (or omit it entirely). Our plugin has plugin.json managing components.
**Warning signs:** Plugin fails to load after installation.

### Pitfall 5: Validation scope
**What goes wrong:** Running `claude plugin validate .` from wrong directory or not realizing it checks both plugin.json AND hooks.json.
**Why it happens:** The validate command checks the entire plugin directory, not just the file you specify.
**How to avoid:** Run from repo root. It validates plugin.json syntax, skill/agent/command frontmatter, and hooks/hooks.json.
**Warning signs:** Unexpected errors about hooks.json when you only edited plugin.json.

## Code Examples

### Valid marketplace.json (for this project)
```json
// Source: https://code.claude.com/docs/en/plugin-marketplaces
{
  "name": "hlwqds",
  "owner": {
    "name": "hlwqds",
    "email": "[public contact]"
  },
  "metadata": {
    "description": "Cross-platform voice notifications for Claude Code"
  },
  "plugins": [
    {
      "name": "claude-voice-notify",
      "source": "./",
      "description": "Chinese voice notifications for Claude Code task events. Plays audio on task complete, confirmation, error, and progress.",
      "version": "1.4.0",
      "author": {
        "name": "hlwqds"
      },
      "keywords": ["notification", "audio", "voice", "chinese", "tts"],
      "category": "productivity"
    }
  ]
}
```

### Enriched plugin.json (additions highlighted)
```json
// Source: https://code.claude.com/docs/en/plugins-reference
{
  "name": "claude-voice-notify",
  "version": "1.4.0",
  "description": "Chinese voice notifications for Claude Code task events. Plays audio on task complete, confirmation, error, and progress.",
  "author": {
    "name": "hlwqds"
  },
  "license": "MIT",
  "homepage": "https://github.com/hlwqds/notify-research",
  "repository": "https://github.com/hlwqds/notify-research",
  "keywords": ["notification", "audio", "voice", "chinese", "tts"],
  "userConfig": {
    "voice": {
      "type": "string",
      "default": "gentle",
      "description": "Voice pack name (available: gentle, deep)",
      "title": "Voice"
    }
  }
}
```

### Validation command
```bash
# From repo root
claude plugin validate .
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual plugin install (git clone + script) | `/plugin marketplace add` + `/plugin install` | 2026 (Claude Code 2.x plugin system) | Users get auto-updates, centralized discovery |

**Relevant current state:**
- Claude Code 2.1.86 installed locally -- supports all marketplace features
- Plugin caching: installed plugins copied to `~/.claude/plugins/cache` (not used in-place)
- `${CLAUDE_PLUGIN_ROOT}` variable resolves to the cache location at runtime
- `${CLAUDE_PLUGIN_DATA}` available for persistent data across updates (not needed for this plugin)

## Open Questions

1. **Owner email value**
   - What we know: D-02 says `owner.email` = "public contact" but exact value not specified
   - What's unclear: The actual email address to use
   - Recommendation: Planner should ask user for the specific email, or use a GitHub noreply address (`<ID>+username@users.noreply.github.com`)

2. **Author email in plugin.json**
   - What we know: D-05 says "author (name)" but `author` object supports `email` too
   - What's unclear: Whether to include email in plugin.json author object
   - Recommendation: Include `name` only per D-05, omit `email` to avoid exposing personal info

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Claude Code CLI | VAL-01 (`claude plugin validate .`) | Yes | 2.1.86 | -- |
| Git | Repository hosting | Yes | (system) | -- |

No missing dependencies. All tools available for this phase.

## Validation Architecture

> SKIPPED: `nyquist_validation` is explicitly set to `false` in `.planning/config.json`.

## Sources

### Primary (HIGH confidence)
- https://code.claude.com/docs/en/plugin-marketplaces -- Complete marketplace.json schema, plugin source types, validation, hosting, strict mode
- https://code.claude.com/docs/en/plugins-reference -- Complete plugin.json manifest schema, all metadata fields, component path fields, userConfig schema
- `.claude-plugin/plugin.json` -- Current plugin manifest state (verified by Read tool)
- `hooks/hooks.json` -- Current hooks configuration (verified by Read tool, all paths use `${CLAUDE_PLUGIN_ROOT}`)

### Secondary (MEDIUM confidence)
- https://code.claude.com/docs/en/discover-plugins -- User-side marketplace discovery flow (from prior session)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official docs provide complete schema; no third-party dependencies
- Architecture: HIGH - Official docs provide exact field definitions, types, and behavior
- Pitfalls: HIGH - All pitfalls sourced from official docs troubleshooting sections and verified against our project state

**Research date:** 2026-03-31
**Valid until:** 90 days (Claude Code plugin schema is stable; marketplace system is relatively new but well-documented)
