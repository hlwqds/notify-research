# Phase 11: README + CI badge - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Create README.md at repo root with project description, CI status badge, tri-platform installation instructions (tabbed format), hook configuration example, and links to source code. English language, concise format suitable for a small utility project.

Requirement mapping: CI-11 (README with CI status badge and project documentation).

</domain>

<decisions>
## Implementation Decisions

### Language & Tone
- **D-01:** README written in English — GitHub standard, international audience
- **D-02:** Concise format — one-liner description + CI badge + install + hook config + links. Not a full architecture doc or developer guide.

### Badges
- **D-03:** CI badge only — single workflow status badge pointing to `ci.yml`. No license or platform badges.
- **D-04:** Badge URL format: `![CI](https://github.com/hlwqds/notify-research/actions/workflows/ci.yml/badge.svg)`

### Installation Section
- **D-05:** Tabbed format — separate code blocks for Linux/macOS (curl bash install.sh) and Windows (iwr + PowerShell install.ps1). Use emoji or section headers to separate platforms.

### Content Structure
- **D-06:** Sections: one-liner description → CI badge → installation (tabbed) → hook configuration example → links (Spark-TTS source, license)

### Claude's Discretion
- Exact section ordering beyond D-06
- Tab rendering approach (emoji headers vs HTML details vs markdown code blocks with comments)
- Whether to include uninstall commands
- Whether to mention Docker/generate.sh (TTS regeneration is a dev concern, not user-facing)
- Hook configuration example format (full settings.json vs minimal snippet)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project description, core value, constraints, shipped features
- `.planning/REQUIREMENTS.md` — CI-11 definition

### Install Scripts (for accurate README commands)
- `scripts/install.sh` — Linux/macOS install command reference
- `scripts/install.ps1` — Windows install command reference

### CI Workflow (for badge URL)
- `.github/workflows/ci.yml` — CI workflow file the badge points to

### Hooks Configuration
- `tests/fixtures/settings.json` — Example hook configuration in Claude Code settings.json format

### Prior Phase Context
- `.planning/phases/10-ci-workflow/10-CONTEXT.md` — CI workflow decisions, repo owner (hlwqds/notify-research)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/fixtures/settings.json` — Working hook config example to reference in README
- `scripts/install.sh` / `scripts/install.ps1` — Install commands to document

### Established Patterns
- No README exists yet — creating from scratch
- Project uses `hlwqds/notify-research` repo on GitHub

### Integration Points
- README.md goes at repo root — no existing file conflicts
- CI badge URL depends on workflow file name `ci.yml` (already created in Phase 10)

</code_context>

<specifics>
## Specific Ideas

- Concise format: this is a small utility, not a framework — README should be scannable in under 30 seconds
- CI badge at the top right (standard placement)
- Install commands should be copy-paste ready
- Hook configuration example shows the minimal setup needed

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 11-readme-ci-badge*
*Context gathered: 2026-03-31*
