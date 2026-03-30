# Requirements: Claude Code 语音通知 — v1.3 GitHub Actions CI

**Defined:** 2026-03-30
**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## v1.3 Requirements (GitHub Actions CI)

### CI Workflow

- [ ] **CI-01**: GitHub Actions workflow triggered on push to main and pull_request
- [ ] **CI-02**: 3-platform matrix (ubuntu-latest, macos-latest, windows-latest)
- [ ] **CI-03**: Minimal permissions (`permissions: contents: read`)
- [ ] **CI-04**: fail-fast: false (don't cancel other platforms on single failure)
- [ ] **CI-05**: Concurrency control (cancel in-progress PR runs, queue main pushes)

### Static Analysis in CI

- [ ] **CI-06**: ShellCheck runs on all 3 bash scripts (Ubuntu only, lint results platform-independent)
- [ ] **CI-07**: PSScriptAnalyzer runs on all 3 PowerShell scripts (all platforms)

### bats Tests in CI

- [ ] **CI-08**: bats-core tests run on Ubuntu and macOS runners (10 tests)
- [ ] **CI-09**: Test files use CI-compatible paths (no hardcoded `/app/` Docker paths)

### Pester Tests in CI

- [ ] **CI-10**: Pester tests run on all 3 platform runners (12 tests)

### README

- [ ] **CI-11**: README with CI status badge and project documentation

## Out of Scope

| Feature | Reason |
|---------|--------|
| Docker 构建测试 | CI 使用原生 runner 工具，无需 Docker |
| Release workflow | 仅 CI，不做 CD |
| 代码覆盖率报告 | bats 无成熟覆盖率工具，Pester 覆盖率对短脚本价值低 |
| Windows Server Core 容器 | 3-11 GB 镜像，原生 runner 更合适 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CI-01 | Phase 10 | Planned |
| CI-02 | Phase 10 | Planned |
| CI-03 | Phase 10 | Planned |
| CI-04 | Phase 10 | Planned |
| CI-05 | Phase 10 | Planned |
| CI-06 | Phase 10 | Planned |
| CI-07 | Phase 10 | Planned |
| CI-08 | Phase 10 | Planned |
| CI-09 | Phase 9 | Planned |
| CI-10 | Phase 10 | Planned |
| CI-11 | Phase 11 | Planned |

**Coverage:**
- v1.3 requirements: 11 total
- Mapped to phases: 11 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
