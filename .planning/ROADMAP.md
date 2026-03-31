# Roadmap: Claude Code 语音通知

## Milestones

- ✅ **v1.0 Claude Code 语音通知** - Phases 1-3 (shipped 2026-03-29)
- ✅ **v1.1 跨平台兼容** - Phases 4-5 (shipped 2026-03-30)
- ✅ **v1.2 跨平台测试** - Phases 6-8 (shipped 2026-03-30)
- ✅ **v1.3 GitHub Actions CI** - Phases 9-11 (shipped 2026-03-31)
- ✅ **v1.4 Hooks 生态分发** - Phases 12-15 (shipped 2026-03-31)
- 🚧 **v1.5 插件市场分发** - Phases 16-17 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-3) - SHIPPED 2026-03-29</summary>

### Phase 1: Docker TTS 环境
**Goal**: Containerized Spark-TTS environment for generating Chinese notification audio
**Plans**: 1 plan

Plans:
- [x] 01-01: Docker build environment with Spark-TTS 0.5B

### Phase 2: 音频生成
**Goal**: 4 Chinese notification mp3 files generated and committed to repo
**Plans**: 2 plans

Plans:
- [x] 02-01: Generate 4 notification audio files via Spark-TTS
- [x] 02-02: Audio file cleanup, normalization, and repo commit

### Phase 3: Claude Code Hooks 集成
**Goal**: Claude Code hooks play notification sounds on task completion, errors, and prompts
**Plans**: 1 plan

Plans:
- [x] 03-01: Three shell scripts for hooks integration (install/uninstall/notify-play)

</details>

<details>
<summary>✅ v1.1 跨平台兼容 (Phases 4-5) - SHIPPED 2026-03-30</summary>

### Phase 4: macOS 兼容
**Goal**: Notification system works on macOS (afplay, BSD stat)
**Plans**: 1 plan

Plans:
- [x] 04-01: macOS platform support in notify-play.sh and install.sh

### Phase 5: Windows PowerShell
**Goal**: Full Windows support via PowerShell scripts
**Plans**: 1 plan

Plans:
- [x] 05-01: Three PowerShell scripts for Windows (notify-play, install, uninstall)

</details>

<details>
<summary>✅ v1.2 跨平台测试 (Phases 6-8) - SHIPPED 2026-03-30</summary>

### Phase 6: 测试基础设施
**Goal**: Test directory structure and mock stubs for cross-platform testing
**Plans**: 3 plans

Plans:
- [x] 06-01: Test directory scaffold (bash/powershell/fixtures)
- [x] 06-02: test.sh unified test runner
- [x] 06-03: bats-core tests for 3 bash scripts (10 tests)

### Phase 7: PowerShell 测试
**Goal**: 12 Pester tests covering all PowerShell script logic
**Plans**: 3 plans

Plans:
- [x] 07-01: Pester tests for notify-play.ps1
- [x] 07-02: Pester tests for install.ps1
- [x] 07-03: Pester tests for uninstall.ps1

### Phase 8: Docker 测试矩阵
**Goal**: Docker-based test matrix running lint + bats + Pester
**Plans**: 1 plan

Plans:
- [x] 08-01: Docker test matrix integration

</details>

<details>
<summary>✅ v1.3 GitHub Actions CI (Phases 9-11) - SHIPPED 2026-03-31</summary>

### Phase 9: CI-Compatible Test Paths
**Goal**: Tests pass in CI without hardcoded Docker paths
**Plans**: 1 plan

Plans:
- [x] 09-01: Convert tests to variable-based paths ($REPO_ROOT/$RepoRoot)

### Phase 10: GitHub Actions CI Workflow
**Goal**: CI runs lint + test on 3 platforms automatically
**Plans**: 1 plan

Plans:
- [x] 10-01: GitHub Actions CI workflow with 3-platform matrix

### Phase 11: README with CI Badge
**Goal**: README documents the project with CI status
**Plans**: 1 plan

Plans:
- [x] 11-01: README with CI badge and project documentation

</details>

<details>
<summary>✅ v1.4 Hooks 生态分发 (Phases 12-15) - SHIPPED 2026-03-31</summary>

### Phase 12: Multi-Voice Foundation
**Goal**: Per-voice directory structure with parameterized voice generation
**Plans**: 3 plans

Plans:
- [x] 12-01: Migrate audio to per-voice directory layout (audio/voices/{name}/)
- [x] 12-02: Parameterized voice generation (--voice flag, voices/*.json)
- [x] 12-03: Generate second voice pack (deep: male/high pitch)

### Phase 13: Plugin Packaging
**Goal**: Claude Code plugin manifest with hooks.json for native /plugin install
**Plans**: 2 plans

Plans:
- [x] 13-01: .claude-plugin/plugin.json manifest
- [x] 13-02: hooks/hooks.json with ${CLAUDE_PLUGIN_ROOT} portable paths

### Phase 14: Install Voice Selection
**Goal**: Interactive voice selection at install time with one-liner installers
**Plans**: 3 plans

Plans:
- [x] 14-01: Interactive voice selection with preview (--voice flag)
- [x] 14-02: Atomic voice swap (temp dir + mv)
- [x] 14-03: One-liner installers (curl|bash, irm|iex) via GitHub Release

### Phase 15: Community Docs
**Goal**: MIT License, plugin-first README, GitHub discovery metadata
**Plans**: 2 plans

Plans:
- [x] 15-01: MIT License + plugin-first README overhaul
- [x] 15-02: GitHub discovery metadata (topics, description, community submission)

</details>

### 🚧 v1.5 插件市场分发 (In Progress)

**Milestone Goal:** 搭建 Claude Code 自建插件市场，让用户通过 `/plugin` 原生发现和安装语音通知插件

- [x] **Phase 16: Marketplace 构建** - Create marketplace.json and update plugin manifest for plugin marketplace distribution (completed 2026-03-31)
- [x] **Phase 17: 验证与发布** - End-to-end validation of /plugin install flow and documentation update (completed 2026-03-31)

## Phase Details

### Phase 16: Marketplace 构建
**Goal**: Plugin marketplace artifacts created and validated, ready for /plugin native discovery
**Depends on**: Phase 15 (plugin packaging from v1.4)
**Requirements**: MKT-01, MKT-02, MKT-03, MKT-04, VAL-01
**Success Criteria** (what must be TRUE):
  1. `.claude-plugin/marketplace.json` exists with market name, owner, and plugin entry metadata (source, description, version, author)
  2. `plugin.json` includes all optional marketplace fields (author, license, homepage, repository, keywords)
  3. `hooks/hooks.json` uses `${CLAUDE_PLUGIN_ROOT}` for all script paths (no regression from v1.4)
  4. `claude plugin validate .` passes with zero errors
**Plans**: 1 plan

Plans:
- [x] 16-01: Create marketplace.json and enrich plugin.json, then validate with claude plugin validate

### Phase 17: 验证与发布
**Goal**: Users can discover and install the plugin via /plugin, and README reflects marketplace as primary installation method
**Depends on**: Phase 16
**Requirements**: VAL-02, VAL-03, DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. User can install the plugin via `/plugin install claude-voice-notify@marketplace-name`
  2. After install, plugin appears in `/plugin` Installed tab with hooks correctly registered
  3. README shows `/plugin marketplace add` as the primary installation method (above one-liner and git-clone methods)
  4. plugin.json version is 1.5.0
**Plans**: 1 plan

Plans:
- [x] 17-01: Bump version to 1.5.0, audit README, E2E verification of /plugin install flow

## Progress

**Execution Order:**
Phases execute in numeric order: 16 → 17

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 16. Marketplace 构建 | v1.5 | 1/1 | Complete    | 2026-03-31 |
| 17. 验证与发布 | v1.5 | 1/1 | Complete   | 2026-03-31 |
