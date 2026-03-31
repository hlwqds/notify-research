# Requirements: Claude Code 语音通知

**Defined:** 2026-03-31
**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## v1.5 Requirements

### Marketplace 构建

- [ ] **MKT-01**: 用户可通过 `/plugin marketplace add owner/repo` 添加语音通知插件市场
- [ ] **MKT-02**: `.claude-plugin/marketplace.json` 包含市场 name、owner 信息、plugin 入口（source/description/version/author）
- [ ] **MKT-03**: `plugin.json` 补全 marketplace 可选字段（author, license, homepage, repository, keywords）
- [ ] **MKT-04**: `hooks/hooks.json` 所有路径使用 `${CLAUDE_PLUGIN_ROOT}` 可移植变量（v1.4 已实现，需确认无回归）

### 验证与测试

- [ ] **VAL-01**: `claude plugin validate .` 验证 plugin.json 通过（无 error）
- [ ] **VAL-02**: 用户可通过 `/plugin install claude-voice-notify@marketplace-name` 安装插件
- [ ] **VAL-03**: 安装后 hooks 正确注册（通过 `/plugin` → Installed tab 可见）

### 文档与版本

- [ ] **DOC-01**: README 添加 `/plugin marketplace add` 作为首要安装方式
- [ ] **DOC-02**: 版本号升级到 1.5.0（plugin.json）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 提交到 Anthropic 官方市场 | 需要 Anthropic 审核，不在控制范围内 |
| npm 包分发 | hooks + 音频文件适合 git 分发，npm 不合适 |
| 私有市场 (GITHUB_TOKEN auth) | 公开仓库无需私有认证 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MKT-01 | Phase 16 | Pending |
| MKT-02 | Phase 16 | Pending |
| MKT-03 | Phase 16 | Pending |
| MKT-04 | Phase 16 | Pending |
| VAL-01 | Phase 16 | Pending |
| VAL-02 | Phase 17 | Pending |
| VAL-03 | Phase 17 | Pending |
| DOC-01 | Phase 17 | Pending |
| DOC-02 | Phase 17 | Pending |

**Coverage:**
- v1.5 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 after v1.5 roadmap creation*
