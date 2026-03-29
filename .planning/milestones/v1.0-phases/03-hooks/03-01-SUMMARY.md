---
phase: 03-hooks
plan: 01
subsystem: hooks
tags: [bash, jq, paplay, claude-code-hooks, async-hooks]

# Dependency graph
requires:
  - phase: 01-docker-tts
    provides: "Docker container for Spark-TTS inference"
  - phase: 02-generate-script
    provides: "Pre-generated mp3 notification audio files in audio/"
provides:
  - "scripts/notify-play.sh — cooldown wrapper for paplay (5s dedup)"
  - "scripts/install.sh — idempotent hooks + audio installation via jq"
  - "scripts/uninstall.sh — clean removal of hooks and audio files"
  - "4 async hook events in ~/.claude/settings.json (Stop, Notification, StopFailure, SubagentStop)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "jq assignment (=) for idempotent settings.json modification"
    - "temp file + non-empty check before JSON overwrite (Pitfall 2 prevention)"
    - "Cooldown wrapper pattern: lock file timestamp for per-type dedup"
    - "Claude Code async: true for non-blocking notification hooks"

key-files:
  created:
    - "scripts/notify-play.sh"
    - "scripts/install.sh"
    - "scripts/uninstall.sh"
  modified: []

key-decisions:
  - "async: true used instead of shell & for native Claude Code non-blocking"
  - "timeout: 10 on all hooks (audio files play in <1s)"
  - "Lock files left in /tmp/ (benign, cleaned on reboot per Pitfall 5)"

patterns-established:
  - "Pattern: Cooldown wrapper script with /tmp lock file timestamps"
  - "Pattern: Idempotent jq settings.json modification with temp file safety"

requirements-completed: [HOOKS-01]

# Metrics
duration: 1min
completed: 2026-03-30
---

# Phase 3 Plan 1: Hooks Integration Summary

**Three shell scripts providing Claude Code async notification hooks with 5-second cooldown, idempotent install/uninstall via jq**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-29T19:29:54Z
- **Completed:** 2026-03-29T19:30:57Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Cooldown wrapper script (notify-play.sh) that always exits 0 and deduplicates within 5s per type
- Idempotent install.sh using jq to inject 4 async hook events into settings.json without destroying existing GSD hooks
- Clean uninstall.sh that removes only the 4 notify hooks and audio files, preserving all other hooks
- Full end-to-end verification: install, verify, uninstall, re-install cycle all passed

## Task Commits

Each task was committed atomically:

1. **Task 1: Create notify-play.sh cooldown wrapper** - `bcd0232` (feat)
2. **Task 2: Create install.sh and uninstall.sh** - `e131325` (feat)
3. **Task 3: Verify hooks installation works end-to-end** - auto-approved (auto_advance), no separate commit

## Files Created/Modified
- `scripts/notify-play.sh` - Cooldown wrapper: plays audio with 5s per-type dedup, always exits 0
- `scripts/install.sh` - Copies mp3 to ~/.claude/, injects 4 async hook events via jq
- `scripts/uninstall.sh` - Removes 4 hook events from settings.json, deletes mp3 files

## Decisions Made
- **async: true instead of shell &** - Claude Code native async mechanism; async hooks cannot block Claude's behavior, eliminating Pitfall 1 risk
- **timeout: 10 seconds** - Audio files are under 15KB and play in under 1 second; 10s timeout is generous safety margin
- **Lock files left in /tmp/** - Benign per Pitfall 5; cleaned on reboot; age-based comparison handles stale files

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all scripts passed syntax checks, all verification steps succeeded on first attempt.

## User Setup Required

None - no external service configuration required. Hooks are now active in ~/.claude/settings.json.

## Next Phase Readiness

- All 3 phase plans (01-docker-tts, 02-generate-script, 03-hooks) are complete
- The v1.0 milestone "语音通知可用" is achieved: users hear audio notifications on Stop, Notification, StopFailure, and SubagentStop events
- Hooks are installed and active; uninstall.sh available for clean removal

## Self-Check: PASSED

All files and commits verified present.

---
*Phase: 03-hooks*
*Completed: 2026-03-30*
