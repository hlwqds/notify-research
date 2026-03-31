# Phase 17: 验证与发布 - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

End-to-end verification that the plugin can be installed via `/plugin` native discovery, README reflects marketplace as primary installation method, and version is bumped to 1.5.0 to mark the v1.5 milestone release.

</domain>

<decisions>
## Implementation Decisions

### Version Bump
- **D-01:** Bump version to `"1.5.0"` in exactly 2 files: `plugin.json` and `marketplace.json` plugin entry. No other files reference the version number in a way that requires updating.

### README Changes
- **D-02:** DOC-01 is largely satisfied already — README has `/plugin marketplace add` as "Plugin Installation (Recommended)" at top. Verify-only: if any sections still reference old install methods as primary, adjust. Otherwise no changes needed.

### E2E Verification
- **D-03:** VAL-02 and VAL-03 are human verification items — they require an actual Claude Code environment to run `/plugin install`. Include as manual verification steps in VERIFICATION.md, not automated tests.

### Claude's Discretion
- Whether README needs any wording improvements beyond DOC-01 compliance
- How to present VAL-02/VAL-03 verification instructions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Plugin Artifacts
- `.claude-plugin/plugin.json` — current manifest (version 1.4.0, needs bump to 1.5.0)
- `.claude-plugin/marketplace.json` — marketplace catalog (plugin entry version 1.4.0, needs bump)
- `hooks/hooks.json` — hooks configuration (verify registered correctly after install)

### Documentation
- `README.md` — project docs (verify marketplace install is primary method)
- `.planning/REQUIREMENTS.md` — v1.5 requirements (VAL-02, VAL-03, DOC-01, DOC-02 acceptance criteria)

### Project Context
- `.planning/ROADMAP.md` — Phase 17 success criteria
- `.planning/STATE.md` — project state and prior decisions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.claude-plugin/marketplace.json` — exists, needs version field update only
- `.claude-plugin/plugin.json` — exists, needs version field update only
- `README.md` — already has marketplace install as primary, verify-only

### Established Patterns
- Version is a bare string `"X.Y.Z"` in both plugin.json and marketplace.json
- README uses "Plugin Installation (Recommended)" heading for marketplace method

### Integration Points
- No code changes — this phase is verification + minor config updates

</code_context>

<specifics>
## Specific Ideas

- Version bump is mechanical: change `"1.4.0"` → `"1.5.0"` in 2 files
- E2E verification commands: `/plugin marketplace add hlwqds/notify-research` then `/plugin install claude-voice-notify@hlwqds` then check `/plugin` Installed tab

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 17-release*
*Context gathered: 2026-03-31*
