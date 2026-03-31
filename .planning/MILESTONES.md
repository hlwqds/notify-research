# Milestones

## v1.3 GitHub Actions CI (Shipped: 2026-03-31)

**Phases completed:** 3 phases, 3 plans, 6 tasks

**Key accomplishments:**

- Converted 8 test files from hardcoded Docker /app/ paths to CI-compatible variable paths ($REPO_ROOT for bats, $RepoRoot for Pester) with root-free PATH-prepend stub pattern
- GitHub Actions CI with 3-platform matrix (Ubuntu/macOS/Windows), lint gating (ShellCheck + PSSA), bats-core tests on Linux+macOS, and Pester 5.6.1 tests on all platforms
- README.md with CI status badge, tri-platform install commands, and hook configuration reference

---

## v1.2 跨平台测试 (Shipped: 2026-03-30)

**Phases completed:** 3 phases, 7 plans, 14 tasks

**Key accomplishments:**

- Test directory scaffold (bash/powershell/fixtures) with shared settings.json fixture and NOTIFY_LOCK_DIR env var override for lock file path testability
- test.sh unified test runner with ShellCheck + PSScriptAnalyzer lint pipeline and Docker-based bats-core/Pester test matrix
- 10 bats-core tests for 3 bash scripts: notify-play.sh cooldown/platform/exit-0, install.sh injection/idempotency/prerequisites, uninstall.sh removal/deletion/idempotency
- 12 Pester tests for 3 PowerShell scripts: notify-play.ps1 cooldown/MediaPlayer-mock/exit-0, install.ps1 injection/paths/BOM-free/idempotency, uninstall.ps1 removal/empty-hooks-cleanup/deletion/idempotency
- Invoke-MediaPlayer wrapper extraction enabling Pester Mock without real .NET audio dependencies
- Gap closure: test.sh Docker ENTRYPOINT fix, Alpine PATH fix, notify-play.ps1 dot-source safety

---

## v1.1 跨平台兼容 (Shipped: 2026-03-30)

**Phases completed:** 2 phases, 2 plans, 6 tasks

**Key accomplishments:**

- OS-conditional stat/afplay branches in notify-play.sh, portable version_gte() and grep -oE in install.sh, uninstall.sh verified already portable
- 3 PowerShell 5.1 scripts (notify-play.ps1, install.ps1, uninstall.ps1) with MediaPlayer headless playback, 5-second cooldown, settings.json BOM-free hook injection, and forward-slash path workaround for Windows

---

## v1.0 Claude Code 语音通知 (Shipped: 2026-03-29)

**Phases completed:** 3 phases, 4 plans, 11 tasks

**Key accomplishments:**

- Docker build environment with Spark-TTS 0.5B: pinned deps, single-stage image, and batch TTS script with voice creation mode
- Docker image built and verified; 4 Chinese notification mp3 files generated via Spark-TTS CPU inference with voice creation mode
- 4 pre-generated mp3 notification sounds committed to repo, generate.py with selective --type generation, generate.sh orchestration for rebuild pipeline
- Three shell scripts providing Claude Code async notification hooks with 5-second cooldown, idempotent install/uninstall via jq

---
