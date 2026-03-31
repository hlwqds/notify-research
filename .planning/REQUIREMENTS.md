# Requirements: Claude Code 语音通知

**Defined:** 2026-03-31
**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## v1.4 Requirements

### Distribution & Install (DIST)

- [ ] **DIST-01**: User can install the notification system as a Claude Code plugin via one command
- [ ] **DIST-02**: User can install the notification system via `curl | bash` one-liner without plugin support
- [ ] **DIST-03**: Existing install.sh/install.ps1 scripts continue to work as legacy fallback
- [ ] **DIST-04**: Plugin uses `${CLAUDE_PLUGIN_ROOT}` for portable path resolution (no hardcoded repo paths)

### Multi-Voice Audio (VOICE)

- [x] **VOICE-01**: Audio files are organized in `audio/{voice-name}/` directory structure with one subdirectory per voice style
- [x] **VOICE-02**: `generate.py` accepts `--voice` parameter to load voice settings from `voices/*.json` config files
- [x] **VOICE-03**: At least 2 voice styles are pre-generated and shipped (default + 1 alternative, e.g. female voice)
- [ ] **VOICE-04**: User can select a voice style during installation
- [ ] **VOICE-05**: Switching voice style at install time swaps all 4 notification audio files atomically

### Community & Docs (DOCS)

- [ ] **DOCS-01**: Project has a LICENSE file (MIT) required for community listing eligibility
- [ ] **DOCS-02**: README documents plugin-based install as the primary installation method
- [ ] **DOCS-03**: GitHub repository has topic tags for discoverability (claude-code, hooks, notifications, tts)

## v2 Requirements

### Marketplace & Promotion

- **MKT-01**: Project is listed in Claude Code official marketplace (when submission process is available)
- **MKT-02**: Project is included in awesome-claude-code / awesome-claude-plugins community lists
- **MKT-03**: Project is promoted on Chinese developer communities (V2EX, SegmentFault, Juejin)

### Advanced Voice

- **VOICE-06**: User can create custom voice packs by providing a speaker reference audio file
- **VOICE-07**: Voice preview (play sample before selecting during install)

## Out of Scope

| Feature | Reason |
|---------|--------|
| 实时语音合成 | CPU 推理 8 分钟/句，性能不可接受 |
| 动态文案通知 | 需要实时 TTS，超出预生成架构 |
| GUI 设置界面 | CLI install + 手动编辑即可，保持简单 |
| npm/PyPI 分发 | Claude Code plugin 系统和 curl|bash 已足够 |
| 音频文件 Git LFS | 单文件 ~10-15 KB，总大小 ~200 KB，不需要 LFS |
| 官方 marketplace 提交 | Anthropic 未公开提交标准和时间线，需等待 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DIST-01 | Phase 13 | Pending |
| DIST-02 | Phase 14 | Pending |
| DIST-03 | Phase 14 | Pending |
| DIST-04 | Phase 13 | Pending |
| VOICE-01 | Phase 12 | Complete |
| VOICE-02 | Phase 12 | Complete |
| VOICE-03 | Phase 12 | Complete |
| VOICE-04 | Phase 14 | Pending |
| VOICE-05 | Phase 14 | Pending |
| DOCS-01 | Phase 15 | Pending |
| DOCS-02 | Phase 15 | Pending |
| DOCS-03 | Phase 15 | Pending |

**Coverage:**
- v1.4 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 after v1.4 roadmap creation*
