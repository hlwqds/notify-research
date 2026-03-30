# Phase 6: 测试基础设施 + 静态分析 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

建立测试基础设施：统一测试入口脚本 (test.sh)、Docker 测试矩阵（bats-core + Pester）、共享 fixture、ShellCheck + PSScriptAnalyzer 静态分析配置、notify-play.sh/ps1 可测试性改造（环境变量覆盖 lock file 路径）。

不写具体测试用例（Phase 7/8 的职责），只搭脚手架和工具链。

</domain>

<decisions>
## Implementation Decisions

### test.sh 入口设计
- **D-01:** test.sh 使用子命令 flag 风格：`--lint`（ShellCheck + PSSA）、`--bash`（bats-core in Docker）、`--powershell`（Pester in Docker）、`--all`（全部依次执行）
- **D-02:** lint 失败返回非零退出码，`--all` 模式下 lint 失败阻断后续 bash/powershell 测试

### Docker 测试矩阵
- **D-03:** test.sh 内置 Docker 调用（自动 docker build/run），用户无需手动管理容器
- **D-04:** 使用官方预构建镜像 + volume mount，不写自定义 Dockerfile：
  - bats: `bats/bats-core:latest`（或 pinned 版本）
  - Pester: `mcr.microsoft.com/powershell:latest`（或 pinned 版本）
- **D-05:** 测试脚本和 fixture 通过 volume mount 注入容器，不烘焙进镜像

### ShellCheck / PSScriptAnalyzer 配置
- **D-06:** 静态分析使用 warning 级别（ShellCheck `--severity warning`，PSSA `-Severity Warning`）
- **D-07:** ShellCheck 对 scripts/*.sh（3 个）、PSSA 对 scripts/*.ps1（3 个）运行

### Fixture 和 notify-play.sh/ps1 改造
- **D-08:** 共享 fixture 目录 `tests/fixtures/` 包含：
  - `settings.json`：模拟真实用户配置（包含已有 hooks 如 PreToolUse + 普通配置项）
  - `dummy.mp3`：小文件，仅用于路径存在性检查
- **D-09:** notify-play.sh 第 14 行改为 `LOCK_DIR="${NOTIFY_LOCK_DIR:-/tmp}"`，lock file 路径变为 `$LOCK_DIR/claude-notify-${TYPE}.lock`，默认行为不变
- **D-10:** notify-play.ps1 同步加 `$env:NOTIFY_LOCK_DIR` 覆盖，保持两个脚本的可测试性机制对称
- **D-11:** 测试目录结构：`tests/bash/`、`tests/powershell/`、`tests/fixtures/`

### Claude's Discretion
- ShellCheck/PSScriptAnalyzer 的具体排除规则（如需排除特定 warning，在规划时决定）
- bats-core 和 PowerShell 镜像的具体版本 pin（规划时选 stable 版本）
- dummy.mp3 的大小和格式（最小有效 MP3 即可）
- test.sh 的输出格式（彩色/简洁）和详细程度

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Requirements
- `.planning/REQUIREMENTS.md` — INFRA-01~04, LINT-01~02 详细定义
- `.planning/ROADMAP.md` — Phase 6 goal, success criteria, requirements mapping

### Scripts Under Test
- `scripts/notify-play.sh` — 第 14 行 LOCK_FILE 硬编码需改造（D-09）
- `scripts/notify-play.ps1` — 第 18 行 $env:TEMP 需加 $env:NOTIFY_LOCK_DIR 覆盖（D-10）
- `scripts/install.sh` — ShellCheck 分析目标
- `scripts/uninstall.sh` — ShellCheck 分析目标
- `scripts/install.ps1` — PSSA 分析目标
- `scripts/uninstall.ps1` — PSSA 分析目标

### Project Decisions
- `.planning/STATE.md` — v1.2 decisions: Docker Linux-only, 冷却测试用时间戳操纵

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Dockerfile`（Spark-TTS）— 现有 Docker 构建模式参考，但测试矩阵用官方镜像不复用此 Dockerfile
- `scripts/*.sh` / `scripts/*.ps1` — 6 个被测脚本，所有 bash 脚本使用 `set -euo pipefail`

### Established Patterns
- bash 脚本使用 `$SCRIPT_DIR` / `$REPO_ROOT` 模式定位文件（install.sh 第 8-9 行）
- PowerShell 使用 `param()` + `$ErrorActionPreference = "Stop"` 模式
- jq 用于 settings.json 操作（bash 侧），ConvertFrom-Json/ConvertTo-Json 用于 PowerShell 侧
- lock file 路径硬编码在 notify-play.sh 第 14 行：`/tmp/claude-notify-${TYPE}.lock`

### Integration Points
- `audio/` 目录有 4 个真实 MP3 文件，但测试不应使用真实音频（用 fixture dummy.mp3）
- `$HOME/.claude/settings.json` 是 install/uninstall 操作的目标，测试需隔离（用 fixture）
- 无现有 `tests/` 目录，需从零创建

</code_context>

<specifics>
## Specific Ideas

- fake settings.json 应包含已有 hooks（如 PreToolUse），模拟真实用户配置，确保 install.sh 不覆盖非通知类的 hooks
- Docker volume mount 路径：容器内 `/app` 挂载仓库根目录，测试脚本通过相对路径找到 scripts/ 和 tests/fixtures/

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 06-test-infra-static-analysis*
*Context gathered: 2026-03-30*
