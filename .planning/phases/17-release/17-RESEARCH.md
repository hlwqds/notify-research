# Phase 17: release - Research

**Researched:** 2026-03-31
**Domain:** Plugin release verification, version bump, documentation audit
**Confidence:** HIGH

## Summary

This is a lightweight release phase with three categories of work: (1) a mechanical version bump from 1.4.0 to 1.5.0 in exactly 2 files, (2) a README audit to confirm DOC-01 compliance (which is already satisfied), and (3) manual E2E verification that the plugin installs correctly via `/plugin install` and registers hooks properly. No new code, no new dependencies, no architecture changes.

The version bump affects only `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` -- confirmed by a full grep of the repository. No other source files reference the version number. The README already shows `/plugin marketplace add` as "Plugin Installation (Recommended)" at the very top, satisfying DOC-01. VAL-02 and VAL-03 require a live Claude Code environment and are manual verification steps documented in the official troubleshooting guide.

**Primary recommendation:** Execute this phase as a single plan: bump version in 2 files, audit README (likely no changes), commit, then provide E2E verification instructions for the user.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Bump version to `"1.5.0"` in exactly 2 files: `plugin.json` and `marketplace.json` plugin entry. No other files reference the version number in a way that requires updating.
- **D-02:** DOC-01 is largely satisfied already -- README has `/plugin marketplace add` as "Plugin Installation (Recommended)" at top. Verify-only: if any sections still reference old install methods as primary, adjust. Otherwise no changes needed.
- **D-03:** VAL-02 and VAL-03 are human verification items -- they require an actual Claude Code environment to run `/plugin install`. Include as manual verification steps in VERIFICATION.md, not automated tests.

### Claude's Discretion
- Whether README needs any wording improvements beyond DOC-01 compliance
- How to present VAL-02/VAL-03 verification instructions

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VAL-02 | User can install plugin via `/plugin install claude-voice-notify@marketplace-name` | Official docs confirm `/plugin install <name>@<marketplace>` syntax. Marketplace name is `hlwqds` (from marketplace.json `name` field). Full E2E steps documented below. |
| VAL-03 | After install, hooks correctly registered (visible in `/plugin` Installed tab) | Official docs confirm installed plugins show in `/plugin` list. hooks.json has 4 event types (Stop, Notification, StopFailure, SubagentStop) each with bash+powershell entries. |
| DOC-01 | README shows `/plugin marketplace add` as primary installation method | **Already satisfied.** README line 7: "## Plugin Installation (Recommended)" is the first section. Contains both `/plugin marketplace add` and `/plugin install` commands. One-liner install is positioned as "Alternative" (line 19). |
| DOC-02 | Version bumped to 1.5.0 in plugin.json | Confirmed: exactly 2 files need `"1.4.0"` changed to `"1.5.0"`: plugin.json line 3 and marketplace.json line 15. No other source files contain the version. |
</phase_requirements>

## Standard Stack

No new stack required. This phase touches only existing config files.

| File | Current Version | Target Version | Change Type |
|------|----------------|----------------|-------------|
| `.claude-plugin/plugin.json` | `"1.4.0"` | `"1.5.0"` | Single line edit (line 3) |
| `.claude-plugin/marketplace.json` | `"1.4.0"` | `"1.5.0"` | Single line edit (line 15) |
| `README.md` | -- | -- | Audit-only (DOC-01 already satisfied) |

**No installation commands needed.** No packages, no dependencies, no tools.

## Architecture Patterns

### Version Bump Pattern
This is a mechanical string replacement. Use `jq` for atomic, parse-safe JSON edits rather than sed:

```bash
# plugin.json
jq '.version = "1.5.0"' .claude-plugin/plugin.json > /tmp/plugin.json.tmp && mv /tmp/plugin.json.tmp .claude-plugin/plugin.json

# marketplace.json (nested path: plugins[0].version)
jq '.plugins[0].version = "1.5.0"' .claude-plugin/marketplace.json > /tmp/marketplace.json.tmp && mv /tmp/marketplace.json.tmp .claude-plugin/marketplace.json
```

### Verification-Only Pattern (DOC-01)
README already satisfies DOC-01. The plan should include a step that **asserts** current state rather than making changes:

- "Plugin Installation (Recommended)" heading exists at line 7
- `/plugin marketplace add hlwqds/notify-research` appears before any other install method
- One-liner install is labeled "Alternative" (line 19)
- No section presents a non-plugin method as primary

### Manual E2E Verification Pattern (VAL-02, VAL-03)
Per CONTEXT.md D-03, these are human verification items. The plan should produce a VERIFICATION.md with step-by-step instructions the user follows in a live Claude Code session.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Version bump tooling | Custom script to edit JSON files | `jq` one-liners | jq handles JSON safely, no risk of malformed output |
| E2E test automation | Shell script to drive `/plugin install` | Manual verification steps | `/plugin install` is an interactive Claude Code command, not scriptable from outside |
| README comparison | Diff tool to check compliance | Visual audit by planner | README is 98 lines; a simple read confirms compliance |

## Common Pitfalls

### Pitfall 1: Bumping version in wrong files
**What goes wrong:** Editing files in `.claude/worktrees/` or planning docs instead of the source files.
**Why it happens:** The grep for "1.4.0" returns many hits across `.planning/` and `.claude/worktrees/` directories.
**How to avoid:** Only edit `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. All other "1.4.0" references are in historical planning artifacts or worktree copies.
**Warning signs:** If the edit touches more than 2 files, something is wrong.

### Pitfall 2: Assuming DOC-01 needs work
**What goes wrong:** Spending time rewriting README sections that are already correct.
**Why it happens:** The requirement says "README添加...作为首要安装方式" which sounds like new work.
**How to avoid:** Read README first. The "Plugin Installation (Recommended)" section is already the primary method. Treat DOC-01 as verify-only unless a specific deficiency is found.

### Pitfall 3: Forgetting the marketplace.json nested path
**What goes wrong:** Changing version in plugin.json but forgetting marketplace.json has the version nested under `plugins[0].version`.
**Why it happens:** Different JSON structures -- plugin.json has a top-level `.version`, marketplace.json has `.plugins[0].version`.
**How to avoid:** Use the jq commands above which target the correct paths explicitly.

### Pitfall 4: Running `/plugin install` on already-installed plugin
**What goes wrong:** E2E test fails or behaves unexpectedly because plugin is already installed from a previous test.
**Why it happens:** The user may have already tested the marketplace during Phase 16.
**How to avoid:** Include `/plugin uninstall claude-voice-notify` as a prerequisite step in verification instructions.

## Code Examples

### Verified: Current plugin.json (before bump)
```json
{
  "name": "claude-voice-notify",
  "version": "1.4.0",
  "description": "Chinese voice notifications for Claude Code task events...",
  "author": { "name": "hlwqds" },
  "license": "MIT",
  "homepage": "https://github.com/hlwqds/notify-research",
  "repository": "https://github.com/hlwqds/notify-research",
  "keywords": ["notification", "audio", "voice", "chinese", "tts"],
  "userConfig": {
    "voice": { "type": "string", "default": "gentle", "description": "...", "title": "Voice" }
  }
}
```

### Verified: Current marketplace.json (before bump)
```json
{
  "name": "hlwqds",
  "owner": { "name": "hlwqds", "email": "hlwqds@users.noreply.github.com" },
  "metadata": { "description": "Cross-platform voice notifications for Claude Code" },
  "plugins": [{
    "name": "claude-voice-notify",
    "source": "./",
    "description": "Chinese voice notifications for Claude Code task events...",
    "version": "1.4.0",
    "author": { "name": "hlwqds" },
    "keywords": ["notification", "audio", "voice", "chinese", "tts"],
    "category": "productivity"
  }]
}
```

### Verified: README already satisfies DOC-01
```markdown
## Plugin Installation (Recommended)     <- Line 7: FIRST install section

The easiest way to install...

/plugin marketplace add hlwqds/notify-research    <- Line 13
/plugin install claude-voice-notify@hlwqds       <- Line 16

## One-Liner Installation (Alternative)   <- Line 19: clearly secondary
```

### E2E Verification Steps (VAL-02, VAL-03)
```
# Step 1: Clean slate (if previously installed)
/plugin uninstall claude-voice-notify

# Step 2: Add marketplace
/plugin marketplace add hlwqds/notify-research

# Step 3: Install plugin
/plugin install claude-voice-notify@hlwqds

# Step 4: Verify installation
/plugin
# -> Should show "claude-voice-notify" in Installed tab
# -> Should show version "1.5.0"
# -> Should list 4 hook events: Stop, Notification, StopFailure, SubagentStop

# Step 5: Verify hooks work (optional smoke test)
# Trigger a task completion and confirm audio plays
```

## State of the Art

Not applicable for this phase -- no technology changes.

## Open Questions

None. All four requirements are fully understood with clear implementation paths.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified -- this phase only edits existing JSON files and audits existing documentation).

## Sources

### Primary (HIGH confidence)
- [Claude Code Plugin Marketplace Docs](https://code.claude.com/docs/en/plugin-marketplaces) -- Full marketplace schema, install flow, troubleshooting, validation commands. Confirmed `/plugin install <name>@<marketplace>` syntax, `source: "./"` relative path resolution, and hooks registration behavior.
- `.claude-plugin/plugin.json` -- Read directly, confirmed version "1.4.0" at line 3
- `.claude-plugin/marketplace.json` -- Read directly, confirmed version "1.4.0" at line 15
- `README.md` -- Read directly, confirmed DOC-01 compliance (marketplace install is primary)
- `hooks/hooks.json` -- Read directly, confirmed 4 event types with ${CLAUDE_PLUGIN_ROOT} paths
- `.planning/config.json` -- Confirmed `nyquist_validation: false`

### Secondary (MEDIUM confidence)
- Repository grep for `"1.4.0"` -- Confirmed only 2 source files need version bump (plugin.json, marketplace.json). All other references are in planning docs or worktree copies.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new stack; only existing JSON files
- Architecture: HIGH - Simple version bump pattern, well-understood
- Pitfalls: HIGH - Identified from direct file inspection and official docs

**Research date:** 2026-03-31
**Valid until:** Indefinite (no external dependencies that could change)
