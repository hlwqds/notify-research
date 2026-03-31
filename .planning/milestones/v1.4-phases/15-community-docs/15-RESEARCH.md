# Phase 15: Community & Docs - Research

**Researched:** 2026-03-31
**Domain:** Documentation, Licensing, Community Discovery
**Confidence:** HIGH

## Summary

This phase focuses on finalizing the project for public discovery and community adoption. The project will transition to the **MIT License**, overhaul its **README.md** to prioritize the **Claude Code Plugin** installation method, and establish discoverability via **GitHub Topic Tags** and community list submissions.

**Primary recommendation:** Use the `/plugin` command as the primary installation method in documentation, while maintaining the `curl | bash` one-liners as a seamless alternative for users without plugin support.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **License**: Must be MIT License (replacing any mention of Apache 2.0).
- **GitHub Tags**: Must include `claude-code`, `hooks`, `notifications`, `tts`.
- **README**: Primary installation method must be "plugin-based".

### the agent's Discretion
- **README Structure**: Organize for maximum "Time to First Notification".
- **Community Lists**: Recommend specific lists for submission (e.g., awesome-claude-code).
- **Topic Tags**: Recommend additional relevant tags beyond the required ones.

### Deferred Ideas (OUT OF SCOPE)
- **Official Marketplace Submission**: Deferred until Anthropic opens a public submission process.
- **npm/PyPI Distribution**: Not required as `/plugin` and `curl | bash` are sufficient.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-01 | Project has a LICENSE file (MIT) | Standard MIT License text verified; 2026/hlwqds as placeholders. |
| DOCS-02 | README documents plugin-based install primary | Verified Claude Code `/plugin marketplace add` and `/plugin install` flow. |
| DOCS-03 | GitHub repository has topic tags | Identified recommended tags and "Awesome" lists for discovery. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Claude Code | >= 2.1.88 | CLI Platform | Latest stable version as of March 2026. |
| MIT License | 2026 | Licensing | Industry standard for open-source permissiveness. |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| curl | Online install | Linux/macOS one-liner installation. |
| jq | JSON processing | Required for legacy/standalone installation scripts. |
| powershell | Windows install | One-liner installation for Windows users. |

## Architecture Patterns

### Recommended README Structure
1.  **Header**: Project Name + High-signal description + CI Badge.
2.  **Plugin Installation (Primary)**: The "Zero-config" way.
3.  **One-Liner Installation (Alternative)**: For users preferring shell scripts.
4.  **Configuration**: How to change voices using `/claude-voice-notify:configure`.
5.  **Hooks Detail**: Table explaining the 4 notification events.
6.  **Compatibility**: OS and Claude Code version requirements.
7.  **Legacy/Uninstallation**: `git clone` and `uninstall.sh`.
8.  **License**: MIT.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Plugin Management | Custom updater | `/plugin update` | Native Claude Code mechanism handles versioning and safety. |
| Configuration UI | Custom CLI prompts | `/plugin configure` | Native UI/Command is more consistent for Claude users. |

## Common Pitfalls

### Pitfall 1: Confusing Marketplace vs. Plugin
**What goes wrong:** Users try to `/plugin install` without adding the marketplace first.
**How to avoid:** Explicitly document the 2-step process in the README.

### Pitfall 2: Environment Variable Scope
**What goes wrong:** `${CLAUDE_PLUGIN_ROOT}` only works inside the plugin system; legacy scripts need `REPO_ROOT` detection.
**How to avoid:** Keep legacy scripts separate and self-contained (already implemented in Phase 14).

## Code Examples

### Plugin Installation (Verified Pattern)
```bash
# 1. Add this repository as a marketplace
/plugin marketplace add hlwqds/notify-research

# 2. Install the notification plugin
/plugin install claude-voice-notify@hlwqds
```

### One-Liner Installation (Alternative)
```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.ps1 | iex
```

### Configuration Command
```bash
# Interactive configuration (voice selection)
/claude-voice-notify:configure

# Direct voice selection
/claude-voice-notify:configure voice deep
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `git clone` + manual script | `/plugin install` | Safer, portable, auto-updating, no repo clutter. |
| Manual `settings.json` edit | `${user_config}` | Configuration is managed by Claude Code, not fragile shell scripts. |

## Open Questions

1. **Official Marketplace?**
   - What we know: Anthropic has an internal official marketplace.
   - What's unclear: Public submission process and timeline.
   - Recommendation: Use `hlwqds/notify-research` as a custom marketplace until official path opens.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Claude Code | Plugin Platform | ✓ | 2.1.88 | Legacy scripts |
| curl | Online Install | ✓ | — | git clone |
| jq | Legacy Install | ✓ | — | Manual config |

## Sources

### Primary (HIGH confidence)
- Official Claude Code CLI Help Docs - `/plugin` and `/hooks` command behavior.
- NPM Registry - `@anthropic-ai/claude-code` latest version (2.1.88).
- Open Source Initiative - MIT License standard text.

### Secondary (MEDIUM confidence)
- Community Reddit/GitHub - `hesreallyhim/awesome-claude-code` submission guidelines.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH
- Architecture: HIGH
- Pitfalls: MEDIUM

**Research date:** 2026-03-31
**Valid until:** 2026-04-30
