# Roadmap: Claude Code 语音通知

## Milestones

- ✅ **v1.0 语音通知** — Phases 1-3 (shipped 2026-03-30)
- ✅ **v1.1 跨平台兼容** — Phases 4-5 (shipped 2026-03-30)
- ✅ **v1.2 跨平台测试** — Phases 6-8 (shipped 2026-03-30)
- 🔄 **v1.3 GitHub Actions CI** — Phases 9-11 (in progress)

## Phases

<details>
<summary>✅ v1.0 语音通知 (Phases 1-3) — SHIPPED 2026-03-30</summary>

- [x] Phase 1: Docker TTS 环境 (2/2 plans) — completed 2026-03-30
- [x] Phase 2: 生成脚本 (1/1 plans) — completed 2026-03-30
- [x] Phase 3: Hooks 集成 (1/1 plans) — completed 2026-03-30

</details>

<details>
<summary>✅ v1.1 跨平台兼容 (Phases 4-5) — SHIPPED 2026-03-30</summary>

- [x] Phase 4: macOS 兼容 (1/1 plans) — completed 2026-03-30
- [x] Phase 5: Windows 兼容 (1/1 plans) — completed 2026-03-30

</details>

<details>
<summary>✅ v1.2 跨平台测试 (Phases 6-8) — SHIPPED 2026-03-30</summary>

- [x] Phase 6: 测试基础设施 + 静态分析 (2/2 plans) — completed 2026-03-30
- [x] Phase 7: Bash 单元测试 (3/3 plans) — completed 2026-03-30
- [x] Phase 8: PowerShell 单元测试 (2/2 plans) — completed 2026-03-30

</details>

<details>
<summary>🔄 v1.3 GitHub Actions CI (Phases 9-11) — IN PROGRESS</summary>

- [x] Phase 9: 测试路径适配 (1/1 plans) — completed 2026-03-31
- [ ] Phase 10: GitHub Actions workflow (1/1 plans) — pending
- [ ] Phase 11: README + documentation (1/1 plans) — pending

</details>

## Phase Detail

### Phase 9: 测试路径适配

**Goal:** Make all test files work without Docker by replacing hardcoded `/app/` paths with CI-compatible variable/relative paths.

**Requirement mapping:** CI-09 (test files use CI-compatible paths)

**Plans:** 1 plan

Plans:
- [x] 09-01-PLAN.md — Adapt bats/Pester test paths from /app/ to $REPO_ROOT/$RepoRoot, convert stubs to PATH-prepend, fix notify-play.sh bare commands

**Success criteria:**
1. `./test.sh --bash` and `./test.sh --powershell` pass locally (Docker still works, backward compatible)
2. No hardcoded `/app/` absolute path remains in any `.bats` or `.Tests.ps1` file
3. Bats stubs install via `PATH="$REPO_ROOT/tests/stubs:$PATH"` instead of writing to `/usr/bin/`

**Approach:** Introduce `$REPO_ROOT` variable (derived from `BATS_TEST_DIRNAME` in bats, `$PSScriptRoot` in Pester) and replace all `/app/` references. Keep Docker compatibility by setting `REPO_ROOT=/app` in the Docker test.sh invocation.

---

### Phase 10: CI workflow

**Goal:** Create `.github/workflows/ci.yml` with 3-platform matrix, push/PR triggers, lint + test steps.

**Requirement mapping:** CI-01, CI-02, CI-03, CI-04, CI-05, CI-06, CI-07, CI-08, CI-10

**Plans:** 1/1 plans complete

Plans:
- [x] 10-01-PLAN.md — Fix BASH-02 macOS date incompatibility, create ci.yml with lint + 3-platform test matrix

**Success criteria:**
1. Push to main triggers CI run across all 3 platforms (ubuntu, macos, windows)
2. Pull request to main triggers CI run with concurrency cancellation of in-progress PR runs
3. ShellCheck passes on Ubuntu for all 3 bash scripts
4. PSScriptAnalyzer passes on all 3 platforms for all 3 PowerShell scripts
5. All 10 bats tests pass on ubuntu-latest and macos-latest
6. All 12 Pester tests pass on ubuntu-latest, macos-latest, and windows-latest

**Approach:** Single `ci.yml` workflow file. Separate lint job (Ubuntu only) + test job (3-platform matrix). Install bats via `bats-core/bats-action@v3.0.1`. Run Pester directly via preinstalled 5.7.1. Independent from test.sh -- CI runs commands directly on runners.

---

### Phase 11: README + CI badge

**Goal:** Create README.md with project description and CI status badge.

**Requirement mapping:** CI-11

**Plans:** 1/1 plans complete

Plans:
- [x] 11-01-PLAN.md — Create README.md with CI badge, tri-platform install instructions, hook config example, and links

**Success criteria:**
1. README.md exists at repo root with project description and usage instructions
2. CI status badge renders correctly pointing to the `ci.yml` workflow
3. Badge reflects actual CI status (passing green after Phase 10 verification)

**Approach:** Create README.md following the project description from PROJECT.md. Badge URL format: `![CI](https://github.com/hlwqds/notify-research/actions/workflows/ci.yml/badge.svg)`. Concise format: one-liner + CI badge + install + hook config + links. English language, under 80 lines.

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Docker TTS 环境 | v1.0 | 2/2 | Complete | 2026-03-30 |
| 2. 生成脚本 | v1.0 | 1/1 | Complete | 2026-03-30 |
| 3. Hooks 集成 | v1.0 | 1/1 | Complete | 2026-03-30 |
| 4. macOS 兼容 | v1.1 | 1/1 | Complete | 2026-03-30 |
| 5. Windows 兼容 | v1.1 | 1/1 | Complete | 2026-03-30 |
| 6. 测试基础设施 + 静态分析 | v1.2 | 2/2 | Complete | 2026-03-30 |
| 7. Bash 单元测试 | v1.2 | 3/3 | Complete | 2026-03-30 |
| 8. PowerShell 单元测试 | v1.2 | 2/2 | Complete | 2026-03-30 |
| 9. 测试路径适配 | v1.3 | 1/1 | Complete | 2026-03-31 |
| 10. GitHub Actions workflow | v1.3 | 1/1 | Complete    | 2026-03-31 |
| 11. README + documentation | v1.3 | 1/1 | Complete    | 2026-03-31 |

---
*Roadmap created: 2026-03-30*
*Last updated: 2026-03-31 after phase 11 planning*
