---
phase: 12-multi-voice-foundation
plan: 02
subsystem: infra
tags: [tts, voice-config, docker, parameterization]

# Dependency graph
requires:
  - phase: 12-01
    provides: generate.py with voice creation mode, generate.sh Docker orchestration, Dockerfile build context
provides:
  - voices/gentle.json and voices/deep.json voice configuration files
  - voices.json manifest for voice pack discovery
  - Parameterized generate.py with --voice flag and load_voice_config()
  - Parameterized generate.sh with --voice flag and GENERATE_VOICE Docker env var
  - Dockerfile with COPY voices/ for in-container config access
affects: [12-03, 13, 14]

# Tech tracking
tech-stack:
  added: []
  patterns: [voice-config-json, env-var-docker-bridge, voice-aware-output-subdir]

key-files:
  created: [voices/gentle.json, voices/deep.json, voices.json]
  modified: [generate.py, generate.sh, Dockerfile]

key-decisions:
  - "JSON voice configs in voices/{name}.json with gender/pitch/speed fields"
  - "load_voice_config() validates required fields, exits with error on missing"
  - "GENERATE_VOICE env var bridges --voice flag through Docker boundary"
  - "Voice-aware output subdirectory: OUTPUT_DIR/{voice_name}/ when --voice specified"
  - "Backward compatible: defaults to VOICE_PARAMS when --voice omitted (D-10)"

patterns-established:
  - "Voice config pattern: voices/{name}.json with {gender, pitch, speed} fields"
  - "Docker env bridge: shell flag -> env var -> Python argparse default"

requirements-completed: [VOICE-02]

# Metrics
duration: 1min
completed: 2026-03-31
---

# Phase 12 Plan 02: Voice Parameterization Summary

**Parameterized TTS generation with per-voice JSON configs, --voice flag on generate.py/generate.sh, and Docker integration via GENERATE_VOICE env var**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-31T05:37:00Z
- **Completed:** 2026-03-31T05:38:53Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Voice config files (gentle.json, deep.json) with validated JSON schemas
- voices.json manifest for voice pack discovery (enables Phase 14 voice selection)
- generate.py parameterized with load_voice_config(), --voice flag, and voice-aware output dirs
- generate.sh --voice flag with OUTPUT_DIR override and GENERATE_VOICE Docker env passthrough
- Dockerfile includes COPY voices/ for in-container config file access

## Task Commits

Each task was committed atomically:

1. **Task 1: Create voice config files and parameterize generate.py** - `5b0effb` (feat)
2. **Task 2: Add --voice to generate.sh and update Dockerfile** - `56c1d0c` (feat)

## Files Created/Modified
- `voices/gentle.json` - Gentle voice config (female, low pitch, low speed)
- `voices/deep.json` - Deep voice config (male, high pitch, moderate speed)
- `voices.json` - Voice manifest listing available voice packs
- `generate.py` - Added load_voice_config(), --voice flag, voice_params parameter, voice-aware output subdir
- `generate.sh` - Added --voice/-v flag, OUTPUT_DIR override, GENERATE_VOICE env var for Docker
- `Dockerfile` - Added COPY voices/ voices/ for in-container config access

## Decisions Made
- JSON voice configs in `voices/{name}.json` with required fields (gender, pitch, speed) -- simple, human-readable, machine-parseable
- `load_voice_config()` validates required fields and exits with clear error messages -- fail-fast on misconfiguration
- GENERATE_VOICE env var bridges shell --voice flag through Docker boundary -- Docker can't pass CLI args, env var is the standard bridge
- Voice-aware output subdirectory (`OUTPUT_DIR/{voice_name}/`) keeps generated audio organized by voice -- avoids file collisions
- Backward compatibility preserved: without --voice, uses built-in VOICE_PARAMS and original OUTPUT_DIR (D-10)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Voice parameterization infrastructure ready for Plan 03 (generate deep voice audio)
- voices.json manifest ready for Phase 14 voice selection UX
- generate.sh --voice deep will output to audio/voices/deep/ as expected

## Self-Check: PASSED

---
*Phase: 12-multi-voice-foundation*
*Completed: 2026-03-31*
