# Phase 14: Install & Voice Selection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 14-install-voice-selection
**Areas discussed:** Voice selection UX, curl|bash installer, voice swap, Windows support

---

## Voice Selection UX

| Option | Description | Selected |
|--------|-------------|----------|
| Numbered list | List available voices (1. gentle 2. deep), user enters number | |
| Numbered list + preview | List voices, user can press 'p' to hear sample before confirming | ✓ |
| --voice flag only | No interactive prompt, user specifies via --voice flag | |

**User's choice:** Numbered list + preview playback
**Notes:** User wants audio preview before confirming voice selection

## Preview Playback

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed: complete | Always preview notify-complete.mp3 | |
| Rotate all 4 | Play all 4 notification sounds in sequence | |
| User selects type | User chooses which notification type to preview | ✓ |

**User's choice:** User selects which notification type to preview
**Notes:** Maximum flexibility — user can preview any of the 4 notification sounds

## curl|bash Download Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Release tarball | Download tagged release tar.gz, extract, run install.sh | ✓ |
| git clone --depth 1 | Shallow clone repo, run install.sh | |
| Minimal package | Only scripts + audio in release, no Docker/tests | |

**User's choice:** GitHub Release tarball

## Version Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Latest release tag | Query GitHub API for latest release tag | ✓ |
| Pinned version | Hardcoded version in script | |
| Default latest + override | Latest by default, env var override | |

**User's choice:** Always install latest published release tag

## Voice Swap Post-Install

| Option | Description | Selected |
|--------|-------------|----------|
| Re-run install script | Switch voice by running install.sh --voice deep | ✓ |
| Separate switch-voice script | Dedicated script to swap audio without reconfiguring hooks | |
| You decide | Leave to implementation judgment | |

**User's choice:** Re-run install script (idempotent, covers both audio swap and hook reconfig)

## Windows curl|bash Support

| Option | Description | Selected |
|--------|-------------|----------|
| Linux/macOS only | curl|bash is Unix convention, Windows uses plugin or git clone | |
| Also support iex + curl | Provide PowerShell one-liner: iex (irm ...) | ✓ |

**User's choice:** Also provide Windows iex + curl equivalent

## Windows iex Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Download tarball + extract + install.ps1 | Mirrors bash flow completely | ✓ |
| Individual file downloads | Download each mp3 + script separately | |

**User's choice:** Download tarball + extract + run install.ps1 (symmetric with bash flow)

## Claude's Discretion

No areas explicitly delegated to Claude's judgment.

## Deferred Ideas

None — discussion stayed within phase scope.
