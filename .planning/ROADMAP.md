# Roadmap: Claude Code 语音通知

## Milestones

- ✅ **v1.0 语音通知** — Phases 1-3 (shipped 2026-03-30)
- ✅ **v1.1 跨平台兼容** — Phases 4-5 (shipped 2026-03-30)
- 🚧 **v1.2 跨平台测试** — Phases 6-8 (in progress)

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

### 🚧 v1.2 跨平台测试 (In Progress)

**Milestone Goal:** 为通知脚本建立跨平台测试体系，Docker 测试矩阵覆盖 Linux/macOS/Windows，静态分析 + 单元测试。

- [x] **Phase 6: 测试基础设施 + 静态分析** - 目录结构、共享 fixture、Docker 测试矩阵、notify-play.sh 可测试性改造、ShellCheck 和 PSScriptAnalyzer 配置
- [ ] **Phase 7: Bash 单元测试** - bats-core 测试 3 个 bash 脚本核心逻辑（冷却防抖、平台分支、hook 注入/移除、幂等性）
- [ ] **Phase 8: PowerShell 单元测试** - Pester 测试 3 个 PowerShell 脚本核心逻辑（冷却防抖、MediaPlayer mock、BOM-free JSON、幂等性）

## Phase Details

<details>
<summary>✅ v1.0 语音通知 (Phases 1-3) — SHIPPED 2026-03-30</summary>

### Phase 1: Docker TTS 环境
**Goal**: Docker 化 Spark-TTS 推理环境，可生成中文通知音频
**Plans**: 2 plans

Plans:
- [x] 01-01: [Completed]
- [x] 01-02: [Completed]

### Phase 2: 生成脚本
**Goal**: 批量生成 4 种中文通知音频文件
**Plans**: 1 plan

Plans:
- [x] 02-01: [Completed]

### Phase 3: Hooks 集成
**Goal**: Claude Code 4 种事件触发语音通知
**Plans**: 1 plan

Plans:
- [x] 03-01: [Completed]

</details>

<details>
<summary>✅ v1.1 跨平台兼容 (Phases 4-5) — SHIPPED 2026-03-30</summary>

### Phase 4: macOS 兼容
**Goal**: macOS afplay 音频播放 + BSD stat 兼容
**Plans**: 1 plan

Plans:
- [x] 04-01: [Completed]

### Phase 5: Windows 兼容
**Goal**: Windows PowerShell 通知播放 + 安装/卸载脚本
**Plans**: 1 plan

Plans:
- [x] 05-01: [Completed]

</details>

### Phase 6: 测试基础设施 + 静态分析
**Goal**: 建立测试目录结构、Docker 测试矩阵、共享 fixture，配置 ShellCheck 和 PSScriptAnalyzer 静态分析，改造 notify-play.sh 支持环境变量覆盖 lock file 路径
**Depends on**: Phase 5 (v1.1 shipped)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, LINT-01, LINT-02
**Success Criteria** (what must be TRUE):
  1. Running `./test.sh --lint` executes ShellCheck on all 3 bash scripts and PSScriptAnalyzer on all 3 PowerShell scripts without errors
  2. `tests/bash/`, `tests/powershell/`, `tests/fixtures/` directories exist with shared fixture files (fake settings.json, fake MP3)
  3. Docker containers for bash testing (bats-core) and PowerShell testing (Pester) build and run successfully
  4. notify-play.sh supports `NOTIFY_LOCK_DIR` environment variable to override lock file path (backward-compatible, defaults to /tmp)
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md — Test directory structure, fixtures, notify-play.sh/ps1 testability refactor
- [x] 06-02-PLAN.md — test.sh entry point with ShellCheck + PSScriptAnalyzer + Docker test matrix

### Phase 7: Bash 单元测试
**Goal**: bats-core 测试覆盖 3 个 bash 脚本全部核心逻辑（notify-play.sh 冷却/平台分支、install.sh hook 注入/幂等/前置检查、uninstall.sh hook 移除/文件删除/幂等）
**Depends on**: Phase 6
**Requirements**: BASH-01, BASH-02, BASH-03, BASH-04, BASH-05, BASH-06, BASH-07, BASH-08, BASH-09, BASH-10
**Success Criteria** (what must be TRUE):
  1. Running `./test.sh --bash` executes all bats-core tests and all pass
  2. Cooldown tests use timestamp manipulation (not sleep) and pass reliably without flakiness
  3. install.sh tests verify correct hook injection into settings.json and idempotent re-runs
  4. uninstall.sh tests verify hook removal and mp3 deletion, with idempotent re-runs producing no errors
  5. Audio player commands (paplay, afplay) are fully mocked -- no real audio hardware required
**Plans**: 2 plans

Plans:
- [x] 07-01-PLAN.md — Stub scripts, test.sh jq fix, notify-play.bats (4 tests: cooldown skip/pass, platform branch, always-exit-0)
- [ ] 07-02-PLAN.md — install.bats (3 tests: hook injection, idempotent, prerequisites) + uninstall.bats (3 tests: hook removal, mp3 deletion, idempotent)

### Phase 8: PowerShell 单元测试
**Goal**: Pester 测试覆盖 3 个 PowerShell 脚本全部核心逻辑（notify-play.ps1 冷却/MediaPlayer mock、install.ps1 hook 注入/路径转换/BOM-free/幂等、uninstall.ps1 hook 移除/空 hooks 清理/文件删除/幂等）
**Depends on**: Phase 6
**Requirements**: PS-01, PS-02, PS-03, PS-04, PS-05, PS-06, PS-07, PS-08, PS-09, PS-10, PS-11, PS-12
**Success Criteria** (what must be TRUE):
  1. Running `./test.sh --powershell` executes all Pester tests and all pass
  2. MediaPlayer is fully mocked via wrapper function -- no real audio hardware or .NET MediaPlayer required
  3. install.ps1 tests verify forward-slash path conversion and BOM-free JSON output
  4. uninstall.ps1 tests verify hook removal, empty hooks object cleanup, and mp3 deletion
  5. Cooldown tests use timestamp manipulation (not Start-Sleep) and pass reliably
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Docker TTS 环境 | v1.0 | 2/2 | Complete | 2026-03-30 |
| 2. 生成脚本 | v1.0 | 1/1 | Complete | 2026-03-30 |
| 3. Hooks 集成 | v1.0 | 1/1 | Complete | 2026-03-30 |
| 4. macOS 兼容 | v1.1 | 1/1 | Complete | 2026-03-30 |
| 5. Windows 兼容 | v1.1 | 1/1 | Complete | 2026-03-30 |
| 6. 测试基础设施 + 静态分析 | v1.2 | 2/2 | Complete | 2026-03-30 |
| 7. Bash 单元测试 | v1.2 | 0/2 | Not started | - |
| 8. PowerShell 单元测试 | v1.2 | 0/? | Not started | - |

---
*Roadmap created: 2026-03-30*
*Last updated: 2026-03-30 after planning phase 07*
