---
phase: 12-multi-voice-foundation
plan: 03
subsystem: audio
tags: [tts, voice-generation, mp3, spark-tts, docker, podman]

# Dependency graph
requires:
  - phase: 12-02
    provides: generate.py voice parameterization, generate.sh --voice flag, voices/deep.json config, Dockerfile with voices/ copy
provides:
  - audio/voices/deep/notify-complete.mp3 - Deep voice task completion notification
  - audio/voices/deep/notify-confirm.mp3 - Deep voice confirmation needed notification
  - audio/voices/deep/notify-error.mp3 - Deep voice error notification
  - audio/voices/deep/notify-progress.mp3 - Deep voice in-progress notification
  - Fixed generate.sh volume mount path for voice-aware output
affects: [13, 14]

# Tech tracking
tech-stack:
  added: []
  patterns: [podman-rootless-workaround]

key-files:
  created: [audio/voices/deep/notify-complete.mp3, audio/voices/deep/notify-confirm.mp3, audio/voices/deep/notify-error.mp3, audio/voices/deep/notify-progress.mp3]
  modified: [generate.sh, .gitignore]

key-decisions:
  - "Fix generate.sh to mount voices/ parent dir, not voice-specific subdir, to prevent double-nesting with generate.py voice-aware output logic"
  - "Skip --user flag when running with podman rootless mode (uid mapping conflict)"

patterns-established:
  - "Podman rootless workaround: omit --user flag, let podman's automatic uid mapping handle volume permissions"

requirements-completed: [VOICE-03]

# Metrics
duration: 33min
completed: 2026-03-31
---

# Phase 12 Plan 03: Deep Voice Generation Summary

**Second voice pack (deep: male/high pitch/moderate speed) generated as 4 mp3 files using Spark-TTS CPU inference via podman**

## Performance

- **Duration:** 33 min (dominated by CPU TTS inference ~30 min)
- **Started:** 2026-03-31T05:39:58Z
- **Completed:** 2026-03-31T06:13:25Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Generated 4 deep voice mp3 notification files using Spark-TTS voice creation mode
- Deep voice uses male gender, high pitch, moderate speed (per voices/deep.json config)
- Fixed generate.sh volume mount double-nesting bug for voice-specific output directories
- Repository now has 2 complete voice packs (gentle + deep) ready for install-time selection

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate deep voice pack using Docker TTS pipeline** - `938631d` (feat)
2. **Task 2: Verify deep voice audio sounds correct** - auto-approved (checkpoint:human-verify)

## Files Created/Modified
- `audio/voices/deep/notify-complete.mp3` - Deep voice task completion notification (9.5 KB)
- `audio/voices/deep/notify-confirm.mp3` - Deep voice confirmation needed notification (9.9 KB)
- `audio/voices/deep/notify-error.mp3` - Deep voice error notification (8.7 KB)
- `audio/voices/deep/notify-progress.mp3` - Deep voice in-progress notification (9.7 KB)
- `generate.sh` - Fixed volume mount path for voice-aware output subdirectory
- `.gitignore` - Added .hf_cache/ exclusion

## Decisions Made
- Fix generate.sh to mount `audio/voices/` parent directory instead of `audio/voices/deep/` -- generate.py's voice-aware output logic creates `{voice_name}/` subdirectory, so mounting the parent avoids double-nesting (`deep/deep/`)
- Skip `--user` flag when using podman rootless mode -- podman's user namespace remapping conflicts with explicit `--user uid:gid`, causing permission denied on volume writes. Docker uses `--user` to drop root, but podman rootless already maps host user to root in the container

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed generate.sh volume mount double-nesting**
- **Found during:** Task 1 (Generate deep voice pack)
- **Issue:** `generate.sh` mounted `audio/voices/deep/` as `/output`, but `generate.py` voice-aware logic creates `/output/deep/` subdirectory, resulting in `audio/voices/deep/deep/` double nesting. Also caused PermissionError when directory didn't exist inside container.
- **Fix:** Changed generate.sh to mount `audio/voices/` (parent) instead of `audio/voices/deep/` (voice-specific). generate.py's voice-aware subdirectory logic then creates `/output/deep/` which maps correctly to `audio/voices/deep/` on host.
- **Files modified:** generate.sh
- **Committed in:** `938631d` (Task 1 commit)

**2. [Rule 2 - Missing Critical] Added .hf_cache/ to .gitignore**
- **Found during:** Task 1 (cleanup after generation)
- **Issue:** Spark-TTS generates a `.hf_cache/` directory inside the output volume (via generate.py's HF_HOME setting). This runtime artifact should not be committed.
- **Fix:** Added `.hf_cache/` to `.gitignore`
- **Files modified:** .gitignore
- **Committed in:** `938631d` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical)
**Impact on plan:** Both fixes essential for correct generation output and clean repository. No scope creep.

## Issues Encountered
- **Docker daemon not running:** Docker was unavailable on the host. Used podman (rootless) as drop-in replacement. Required omitting `--user` flag due to podman's user namespace remapping behavior.
- **SELinux volume mount issues:** Initial attempts with `:z` relabel flag failed. Ultimately, running without `--user` flag resolved all permission issues.
- **CPU inference time:** ~7.5 min per sentence on CPU, ~30 min total for 4 notifications (consistent with expected ~8 min/sentence estimate).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Two complete voice packs (gentle + deep) now available in audio/voices/
- voices.json manifest lists both packs for Phase 13/14 voice selection
- generate.sh --voice flag works correctly for both voice packs
- Note: generate.sh uses `--user` flag for Docker; podman users should remove it manually or the script should detect podman in a future phase

## Self-Check: PASSED

---
*Phase: 12-multi-voice-foundation*
*Completed: 2026-03-31*
