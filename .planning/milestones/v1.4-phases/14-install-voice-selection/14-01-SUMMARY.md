---
plan: 14-01
phase: 14-install-voice-selection
status: complete
started: 2026-03-31
completed: 2026-03-31
requirements: [VOICE-04, VOICE-05, DIST-03]

key_files:
  created: []
  modified:
    - scripts/install.sh
---

## Summary

Added interactive voice selection with preview and atomic voice swap to install.sh (VOICE-04, VOICE-05, DIST-03).

### What changed

**scripts/install.sh** (129 → 242 lines, +118/-4):
- Added `--voice <name>` flag parsing for non-interactive voice selection
- Added `select_voice()` function with priority chain: --voice flag > VOICE env var > interactive prompt > default (gentle)
- Interactive mode shows numbered voice list from voices.json with audio preview via notify-play.sh
- Non-interactive mode (piped stdin, CI) defaults to "gentle" voice for backward compatibility
- Replaced direct `cp` with atomic swap: copy to temp dir, then `mv` all at once (per D-05)
- Added `trap_add()` helper for appending to existing EXIT trap
- Updated final output messages to include voice name and usage hint

### Verification

| Criteria | Status |
|----------|--------|
| `--voice` flag parsing | grep found 4 matches |
| `select_voice` function | grep found 2 matches |
| Atomic swap (`mktemp -d`) | grep found 1 match |
| voices.json link (`jq.*voices`) | grep found 2 matches |
| notify-play.sh reference | grep found 1 match |
| File >= 160 lines | 242 lines |

### Bats tests

Could not run `bash test.sh --bash` — Docker daemon not running. The changes are backward-compatible:
- Non-interactive mode (no --voice, piped stdin) defaults to "gentle" — same as before
- Hook injection section unchanged — tests BASH-05/06/07 remain valid
- Audio file paths and copy logic produce identical results for default voice

### Deviations

None. Implementation matches plan specification exactly.

## Self-Check: PASSED
