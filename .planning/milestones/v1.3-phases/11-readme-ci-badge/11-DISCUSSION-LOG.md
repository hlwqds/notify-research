# Phase 11: README + CI badge - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 11-README + CI badge
**Areas discussed:** Language, Scope, Badges, Install format

---

## Language

| Option | Description | Selected |
|--------|-------------|----------|
| English | GitHub standard, international audience | ✓ |
| Chinese | Match PROJECT.md, intuitive for Chinese users | |
| English + Chinese sections | Main English, key descriptions with Chinese translation | |

**User's choice:** English
**Notes:** Standard GitHub convention.

---

## Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Concise (recommended) | One-liner + CI badge + tri-platform install + hook config + links | ✓ |
| Detailed | Full architecture, all notification types, TTS customization, Docker build, dev guide | |
| Standard | Description + badge + install + basic usage + test running + license | |

**User's choice:** Concise
**Notes:** Small utility project — scannable README is appropriate.

---

## Badges

| Option | Description | Selected |
|--------|-------------|----------|
| CI badge only (recommended) | Single CI workflow status badge | ✓ |
| CI + License | CI badge + Apache 2.0 license badge | |
| CI + License + Platform | CI badge + License + tri-platform compatibility badges | |

**User's choice:** CI badge only
**Notes:** Keep it minimal.

---

## Install Format

| Option | Description | Selected |
|--------|-------------|----------|
| Tabbed platforms (recommended) | Separate code blocks for Linux/macOS/Windows, separated by tabs or emoji | ✓ |
| Unified + annotations | Single curl/iwr command block with comments for Windows differences | |
| Collapsible details | Default shows curl, platform details in <details> sections | |

**User's choice:** Tabbed platforms
**Notes:** Clear per-platform copy-paste experience.

---

## Claude's Discretion

- Section ordering beyond the defined structure
- Tab rendering approach
- Whether to include uninstall commands
- Whether to mention Docker/generate.sh
- Hook config example format (full vs minimal)

## Deferred Ideas

None.
