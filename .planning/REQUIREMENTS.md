# Requirements: Claude Code 语音通知 — v1.2 跨平台测试

**Defined:** 2026-03-30
**Core Value:** 用户不在 Claude Code 窗口时，通过语音即时感知任务状态，不用反复切窗口查看。

## v1.2 Requirements (跨平台测试)

### 静态分析

- [ ] **LINT-01**: ShellCheck 对 3 个 bash 脚本运行静态分析（install.sh, uninstall.sh, notify-play.sh）
- [ ] **LINT-02**: PSScriptAnalyzer 对 3 个 PowerShell 脚本运行静态分析（install.ps1, uninstall.ps1, notify-play.ps1）

### Bash 单元测试

- [ ] **BASH-01**: bats-core 测试 notify-play.sh 冷却跳过（lock file 存在且 < 5 秒）
- [ ] **BASH-02**: bats-core 测试 notify-play.sh 冷却通过（lock file 旧于 5 秒）
- [ ] **BASH-03**: bats-core 测试 notify-play.sh 平台分支（Darwin afplay vs Linux paplay）
- [ ] **BASH-04**: bats-core 测试 notify-play.sh 始终 exit 0（即使播放器失败）
- [ ] **BASH-05**: bats-core 测试 install.sh 4 个 hook 事件注入到 settings.json
- [ ] **BASH-06**: bats-core 测试 install.sh 幂等重跑（不重复添加 hooks）
- [ ] **BASH-07**: bats-core 测试 install.sh 前置检查（缺少 jq/paplay/settings.json/mp3 报错）
- [ ] **BASH-08**: bats-core 测试 uninstall.sh 4 个 hook 事件移除
- [ ] **BASH-09**: bats-core 测试 uninstall.sh mp3 文件删除
- [ ] **BASH-10**: bats-core 测试 uninstall.sh 幂等重跑（无 hooks 不报错）

### PowerShell 单元测试

- [ ] **PS-01**: Pester 测试 notify-play.ps1 冷却跳过（lock file < 5 秒）
- [ ] **PS-02**: Pester 测试 notify-play.ps1 冷却通过（lock file 旧于 5 秒）
- [ ] **PS-03**: Pester 测试 notify-play.ps1 MediaPlayer mock（不调用真实音频）
- [ ] **PS-04**: Pester 测试 notify-play.ps1 始终 exit 0
- [ ] **PS-05**: Pester 测试 install.ps1 4 个 hook 事件注入且 shell 为 powershell
- [ ] **PS-06**: Pester 测试 install.ps1 forward-slash 路径转换
- [ ] **PS-07**: Pester 测试 install.ps1 BOM-free JSON 输出（无 UTF-8 BOM）
- [ ] **PS-08**: Pester 测试 install.ps1 幂等重跑
- [ ] **PS-09**: Pester 测试 uninstall.ps1 4 个 hook 事件移除
- [ ] **PS-10**: Pester 测试 uninstall.ps1 空 hooks 对象清理
- [ ] **PS-11**: Pester 测试 uninstall.ps1 mp3 文件删除
- [ ] **PS-12**: Pester 测试 uninstall.ps1 幂等重跑

### 测试基础设施

- [ ] **INFRA-01**: 统一测试入口脚本 test.sh（运行 ShellCheck + bats + Pester）
- [ ] **INFRA-02**: 测试目录结构（tests/bash/, tests/powershell/, tests/fixtures/）
- [ ] **INFRA-03**: Docker 测试矩阵（Linux 容器运行 bats，pwsh 容器运行 Pester）
- [ ] **INFRA-04**: notify-play.sh 可测试性改造（lock file 路径支持环境变量覆盖）

## Out of Scope

| Feature | Reason |
|---------|--------|
| macOS Docker 容器 | macOS 不可容器化，无官方 Docker 镜像 |
| Windows Server Core Docker | 3-11 GB 镜像过大，本地测试不实用 |
| GitHub Actions CI | 仅本地运行，CI 以后再说 |
| bash 代码覆盖率 | 无成熟工具（kcov 停止维护） |
| Spark-TTS 环境测试 | 仅测试通知脚本，TTS 构建独立 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| LINT-01 | TBD | Planned |
| LINT-02 | TBD | Planned |
| BASH-01 | TBD | Planned |
| BASH-02 | TBD | Planned |
| BASH-03 | TBD | Planned |
| BASH-04 | TBD | Planned |
| BASH-05 | TBD | Planned |
| BASH-06 | TBD | Planned |
| BASH-07 | TBD | Planned |
| BASH-08 | TBD | Planned |
| BASH-09 | TBD | Planned |
| BASH-10 | TBD | Planned |
| PS-01 | TBD | Planned |
| PS-02 | TBD | Planned |
| PS-03 | TBD | Planned |
| PS-04 | TBD | Planned |
| PS-05 | TBD | Planned |
| PS-06 | TBD | Planned |
| PS-07 | TBD | Planned |
| PS-08 | TBD | Planned |
| PS-09 | TBD | Planned |
| PS-10 | TBD | Planned |
| PS-11 | TBD | Planned |
| PS-12 | TBD | Planned |
| INFRA-01 | TBD | Planned |
| INFRA-02 | TBD | Planned |
| INFRA-03 | TBD | Planned |
| INFRA-04 | TBD | Planned |

**Coverage:**
- v1.2 requirements: 28 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30*
