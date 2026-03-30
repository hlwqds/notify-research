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

## Milestone: v1.1 — 跨平台兼容

**Shipped:** 2026-03-30
**Phases:** 2 | **Plans:** 2 | **Tasks:** 6

### What Was Built

- macOS afplay playback + BSD stat compatibility in notify-play.sh and install.sh
- Windows notify-play.ps1 with .NET MediaPlayer headless playback + 5-second cooldown
- Windows install.ps1 with `shell: powershell` hook injection, forward-slash paths, BOM-free JSON
- Windows uninstall.ps1 with idempotent hook removal and mp3 cleanup
- Portable `version_gte()` and `grep -oE` replacing GNU-only `sort -V` and `grep -oP`

### What Worked

- Deep research phase (05-RESEARCH.md) caught PowerShell pitfalls before coding — BOM issue, Depth default, forward-slash requirement
- Key-links in plan frontmatter ensured cross-file wiring (install.ps1 → notify-play.ps1 path references)
- Existing portable shell patterns (no `stat -c`, no `grep -P`) made macOS work mostly free
- Cloned bash scripts (PowerShell equivalents) made Windows implementation predictable

### What Was Inefficient

- Worktree merge conflicts in planning files after executor agent — needed manual resolution
- v1.0 phases 1-3 directories already cleaned up before v1.1 — no cross-phase regression tests possible

### Patterns Established

- PowerShell `WriteAllText` + `UTF8Encoding($false)` for BOM-free JSON (never `Set-Content`)
- `ConvertTo-Json -Depth 100` for settings.json (default depth 2 truncates)
- Forward-slash paths in hook commands on Windows (Claude Code bug #26759 workaround)
- `$env:TEMP` lock files for cooldown on Windows, `[System.IO.Path]::GetTempPath()` fallback
- `PSObject.Properties.Remove()` for idempotent JSON property deletion

### Key Lessons

- PowerShell JSON manipulation has several gotchas (BOM, depth, property removal) — document in RESEARCH.md
- Clone pattern works well for cross-platform scripts — same logic, platform idioms
- Worktree isolation is worth the merge complexity for parallel execution safety

### Cost Observations

- Timeline: ~1 day (same day as v1.0)
- Commits: ~20 (v1.1 scope only)
- Model mix: opus (orchestration), sonnet (execution, verification)
- Notable: Small milestone completed quickly — research quality directly correlated with zero-revision execution

## Cross-Milestone Trends

| Metric | v1.0 | v1.1 | Total |
|--------|------|------|-------|
| Phases | 3 | 2 | 5 |
| Plans | 4 | 2 | 6 |
| Tasks | 11 | 6 | 17 |
| Timeline | ~3 hours | ~1 day | ~1 day |
| Commits | 32 | ~20 | ~52 |
| Issues found in verification | 0 | 0 | 0 |
| Verification first-pass rate | 100% | 100% | 100% |

---
*Retrospective updated: 2026-03-30 after v1.1 milestone*
