# Roadmap: Claude Code 语音通知

## Milestones

- **v1.0 语音通知** -- Phases 1-3 (shipped 2026-03-30)
- **v1.1 跨平台兼容** -- Phases 4-5 (shipped 2026-03-30)
- **v1.2 跨平台测试** -- Phases 6-8 (shipped 2026-03-30)
- **v1.3 GitHub Actions CI** -- Phases 9-11 (shipped 2026-03-31)
- **v1.4 Hooks 生态分发** -- Phases 12-15 (in progress)

## Phases

<details>
<summary>v1.0 语音通知 (Phases 1-3) -- SHIPPED 2026-03-30</summary>

- [x] Phase 1: Docker TTS 环境 (2/2 plans) -- completed 2026-03-30
- [x] Phase 2: 生成脚本 (1/1 plans) -- completed 2026-03-30
- [x] Phase 3: Hooks 集成 (1/1 plans) -- completed 2026-03-30

</details>

<details>
<summary>v1.1 跨平台兼容 (Phases 4-5) -- SHIPPED 2026-03-30</summary>

- [x] Phase 4: macOS 兼容 (1/1 plans) -- completed 2026-03-30
- [x] Phase 5: Windows 兼容 (1/1 plans) -- completed 2026-03-30

</details>

<details>
<summary>v1.2 跨平台测试 (Phases 6-8) -- SHIPPED 2026-03-30</summary>

- [x] Phase 6: 测试基础设施 + 静态分析 (2/2 plans) -- completed 2026-03-30
- [x] Phase 7: Bash 单元测试 (3/3 plans) -- completed 2026-03-30
- [x] Phase 8: PowerShell 单元测试 (2/2 plans) -- completed 2026-03-30

</details>

<details>
<summary>v1.3 GitHub Actions CI (Phases 9-11) -- SHIPPED 2026-03-31</summary>

- [x] Phase 9: 测试路径适配 (1/1 plans) -- completed 2026-03-31
- [x] Phase 10: GitHub Actions workflow (1/1 plans) -- completed 2026-03-31
- [x] Phase 11: README + documentation (1/1 plans) -- completed 2026-03-31

</details>

### v1.4 Hooks 生态分发 (In Progress)

**Milestone Goal:** 将通知系统打包为 Claude Code hooks 扩展包，通过 GitHub 社区生态分发给其他用户一键安装使用

- [x] **Phase 12: Multi-Voice Foundation** - Per-voice directory structure with parameterized generation and 2 shipped voice packs (completed 2026-03-31)
- [x] **Phase 13: Plugin Packaging** - Claude Code plugin manifest and hooks with portable path resolution (completed 2026-03-31)
- [ ] **Phase 14: Install & Voice Selection** - curl|bash fallback, voice selection at install time, legacy backward compatibility
- [ ] **Phase 15: Community & Docs** - MIT LICENSE, plugin-primary README, GitHub topic tags for discoverability

## Phase Details

### Phase 12: Multi-Voice Foundation
**Goal**: Audio files organized in per-voice directory structure with parameterized voice generation, shipping at least 2 voice styles
**Depends on**: Phase 11 (v1.3 shipped)
**Requirements**: VOICE-01, VOICE-02, VOICE-03
**Success Criteria** (what must be TRUE):
  1. `audio/voices/{voice-name}/` directory structure exists with one subdirectory per voice style, each containing 4 notification mp3 files
  2. `generate.py --voice <name>` loads voice settings from `voices/<name>.json` and produces audio in the correct subdirectory
  3. At least 2 voice packs (default + 1 alternative) are pre-generated, committed, and playable
**Plans**: 3 plans

Plans:
- [x] 12-01-PLAN.md -- Migrate audio/ to voices/gentle/ directory layout and update all path references
- [x] 12-02-PLAN.md -- Parameterize generate.py/generate.sh with --voice flag and create voice config JSON files
- [x] 12-03-PLAN.md -- Generate and verify deep voice pack

### Phase 13: Plugin Packaging
**Goal**: Notification system installable as a Claude Code plugin via one command, with portable path resolution
**Depends on**: Phase 12
**Requirements**: DIST-01, DIST-04
**Success Criteria** (what must be TRUE):
  1. User can install the notification system with a single Claude Code plugin install command and immediately hear voice notifications on task completion
  2. All audio and script paths in hooks resolve correctly via `${CLAUDE_PLUGIN_ROOT}` with no hardcoded absolute paths
  3. Plugin structure validates successfully (plugin.json + hooks/hooks.json)
**Plans**: 2 plans

Plans:
- [x] 13-01-PLAN.md -- Create .claude-plugin/plugin.json manifest with userConfig for voice selection
- [x] 13-02-PLAN.md -- Create hooks/hooks.json with ${CLAUDE_PLUGIN_ROOT} path resolution and validate plugin structure

### Phase 14: Install & Voice Selection
**Goal**: Users can install via curl|bash fallback, choose a voice at install time, and legacy install scripts still work
**Depends on**: Phase 13
**Requirements**: DIST-02, DIST-03, VOICE-04, VOICE-05
**Success Criteria** (what must be TRUE):
  1. User can install the notification system on a fresh machine with a single `curl | bash` command and hear notifications immediately
  2. User can select a voice style during installation and all 4 notification sounds reflect the chosen voice
  3. Existing install.sh/install.ps1 scripts continue to work as before (backward compatibility)
  4. Switching voice at install time swaps all 4 audio files atomically (no partial state)
**Plans**: TBD

Plans:
- [ ] 14-01: Add voice selection to install.sh/install.ps1 with interactive prompt and --voice flag
- [ ] 14-02: Create install-online.sh curl|bash entry point with tagged-release URL pinning
- [ ] 14-03: Verify legacy install/uninstall scripts still work with new audio directory structure

### Phase 15: Community & Docs
**Goal**: Project is discoverable and installable by Claude Code users searching GitHub or community lists
**Depends on**: Phase 14
**Requirements**: DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. README shows plugin-based install as the primary installation method with curl|bash as fallback
  2. Project has a LICENSE file (MIT) making it eligible for community listing
  3. GitHub repository has topic tags (claude-code, hooks, notifications, tts) that appear in search results
**Plans**: TBD

Plans:
- [ ] 15-01: Add MIT LICENSE file and update README with plugin install as primary method
- [ ] 15-02: Add GitHub topic tags and repository description for discoverability

## Progress

**Execution Order:**
Phases execute in numeric order: 12 -> 13 -> 14 -> 15

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
| 10. GitHub Actions workflow | v1.3 | 1/1 | Complete | 2026-03-31 |
| 11. README + documentation | v1.3 | 1/1 | Complete | 2026-03-31 |
| 12. Multi-Voice Foundation | v1.4 | 3/3 | Complete    | 2026-03-31 |
| 13. Plugin Packaging | v1.4 | 2/2 | Complete   | 2026-03-31 |
| 14. Install & Voice Selection | v1.4 | 0/3 | Not started | - |
| 15. Community & Docs | v1.4 | 0/2 | Not started | - |

---
*Roadmap created: 2026-03-30*
*Last updated: 2026-03-31 after Phase 13 planning*
