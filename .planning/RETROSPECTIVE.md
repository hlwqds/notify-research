# Retrospective: Claude Code 语音通知

## Milestone: v1.0 — Claude Code 语音通知

**Shipped:** 2026-03-30
**Phases:** 3 | **Plans:** 4 | **Tasks:** 11

### What Was Built

- Docker containerized Spark-TTS 0.5B environment with pinned CPU-only PyTorch dependencies
- 4 pre-generated Chinese notification audio files (complete, confirm, error, progress)
- `generate.sh` orchestration script with `--type` selective regeneration support
- `install.sh` / `uninstall.sh` for idempotent hooks + audio deployment via jq
- `notify-play.sh` cooldown wrapper (5-second dedup, always exits 0)
- 4 Claude Code async hooks (Stop, Notification, StopFailure, SubagentStop)

### What Worked

- Pre-generated audio committed to repo — users can install without Docker
- Research phase caught `async: true` native mechanism before planning, avoiding shell `&` approach
- Plan checker caught stale REQUIREMENTS.md (3 events vs 4), preventing verification debt
- jq-based idempotent install/uninstall — safe to re-run, safe to remove

### What Was Inefficient

- Phase 1+2 overlap — Docker environment and audio generation could have been a single phase
- No git tagging until milestone completion — intermediate releases not versioned
- Plan checker revision cycle added overhead for documentation-only fixes

### Patterns Established

- `jq` for all JSON config manipulation (settings.json) — never sed/awk
- Absolute paths in Claude Code hooks (`/usr/bin/paplay`, full script paths)
- `async: true` for non-blocking hooks — native Claude Code mechanism
- Temp file-based cooldown (`/tmp/claude-notify-{type}.lock`) — lightweight, no daemon
- Idempotent install scripts (jq `=` assignment, not `+=` append)

### Key Lessons

- Research before planning pays off — `async: true` discovery saved a worse implementation
- Commit pre-generated assets to repo — removes Docker dependency for end users
- Plan checker catches documentation drift early — cheaper to fix during planning than execution

### Cost Observations

- Timeline: ~3 hours (single session)
- Commits: 32 total
- Model mix: opus (planning, verification), sonnet (research, execution, checking)
- Notable: Small project completed efficiently in one session with GSD workflow

## Cross-Milestone Trends

| Metric | v1.0 |
|--------|------|
| Phases | 3 |
| Plans | 4 |
| Tasks | 11 |
| Timeline | ~3 hours |
| Commits | 32 |
| Issues found in verification | 0 (passed first time after 1 revision cycle) |

---
*Retrospective started: 2026-03-30*
