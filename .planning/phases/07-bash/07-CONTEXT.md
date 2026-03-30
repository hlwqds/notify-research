# Phase 7: Bash 单元测试 - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

bats-core 测试覆盖 3 个 bash 脚本全部核心逻辑：notify-play.sh（冷却/平台分支）、install.sh（hook 注入/幂等/前置检查）、uninstall.sh（hook 移除/文件删除/幂等）。共 10 个测试用例（BASH-01~10）。

不涉及 PowerShell 测试（Phase 8），不涉及新功能开发。

</domain>

<decisions>
## Implementation Decisions

### Test Structure & Isolation
- **D-01:** 每个测试文件独立设置 LOCK_DIR、settings.json fixture 拷贝等。不在文件间共享可变状态。每个 test function 使用临时目录，teardown 清理。
- **D-02:** 不使用 bats-file/bats-support 等插件，纯 bats-core + bash。减少外部依赖。

### Mocking Strategy
- **D-03:** 使用 PATH stub 脚本模拟 paplay/afplay。在 tests/stubs/ 目录创建 paplay 和 afplay 脚本（exit 0）。测试前将 tests/stubs/ prepend 到 PATH。
- **D-04:** stub 脚本记录调用日志到临时文件（`$CALLED_LOG`），以便测试验证哪个 player 被调用（BASH-03 平台分支）。日志写入 `$(mktemp)` 或指定文件。
- **D-05:** 不用 bats run() override 或 Docker 音频隔离来 mock。

### Install/Uninstall Test Data
- **D-06:** 测试从 audio/ 目录复制真实 MP3 文件到临时 CLAUDE_DIR。安装脚本检查文件存在性，真实文件模拟实际安装流程。
- **D-07:** settings.json 使用 tests/fixtures/settings.json 的拷贝作为测试目标。fixture 含已有 PreToolUse hook，确保 install.sh 不覆盖非通知类 hooks。

### Test Naming & Grouping
- **D-08:** 按被测脚本分文件：tests/bash/notify-play.bats（4 tests）、install.bats（3 tests）、uninstall.bats（3 tests）。与脚本 1:1 对应。
- **D-09:** 测试名使用描述性句子风格：`@test "cooldown skip when lock file is younger than 5 seconds"`。标准 bats 约定。

### Claude's Discretion
- 临时目录的具体路径策略（mktemp / bats TMPDIR）
- setup/teardown helper 的具体实现（inline 或 extracted function）
- stub 脚本的日志格式（一行一条或 JSON）
- install.sh 前置检查测试中如何跳过 claude version 检查（可能需要 mock `claude` 命令）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 7 Requirements
- `.planning/REQUIREMENTS.md` — BASH-01~10 详细定义和验收标准

### Scripts Under Test
- `scripts/notify-play.sh` — 39 行，冷却逻辑 + 平台分支（Darwin/Linux）
- `scripts/install.sh` — 127 行，前置检查 + jq hook 注入 + 音频复制
- `scripts/uninstall.sh` — 37 行，jq hook 删除 + 音频删除

### Test Infrastructure (Phase 6)
- `test.sh` — 统一测试入口，`--bash` flag 运行 Docker bats
- `tests/fixtures/settings.json` — 含 PreToolUse hook 的假配置
- `tests/fixtures/dummy.mp3` — 最小有效 MP3

### Phase 6 Context (Carried Forward)
- `.planning/phases/06-test-infra-static-analysis/06-CONTEXT.md` — Docker 镜像 pin、volume mount 路径、NOTIFY_LOCK_DIR 机制
- `.planning/STATE.md` — v1.2 decisions: 冷却测试用时间戳操纵、Docker Linux-only

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/fixtures/settings.json` — 已含 PreToolUse hook，可直接拷贝作为 install.sh 测试目标
- `audio/notify-*.mp3` — 4 个真实 MP3 文件，install.sh 测试需要这些文件存在
- `test.sh` line 73 — `docker run --rm -v "$REPO_ROOT:/app" "$BATS_IMAGE" /app/tests/bash`

### Established Patterns
- 所有 bash 脚本使用 `set -euo pipefail`
- notify-play.sh 使用 `${NOTIFY_LOCK_DIR:-/tmp}` 覆盖 lock 路径（Phase 6 D-09）
- notify-play.sh 使用绝对路径调用 player：`/usr/bin/afplay` 和 `/usr/bin/paplay`
- install.sh 使用 jq 注入 hooks 到 settings.json，通过 TMPFILE + mv 原子替换
- install.sh 有 5 个前置检查（claude version、jq、player、settings.json、notify-play.sh 可执行）
- uninstall.sh 使用 `jq 'del(.hooks.Stop, ...)'` 删除 4 个 hook key

### Integration Points
- test.sh `--bash` 通过 Docker 运行 bats：容器内 /app = 仓库根目录
- stub 脚本需要能被容器内的 notify-play.sh 发现（通过 PATH）
- install.sh 使用 `$REPO_ROOT/scripts/notify-play.sh` 构造 hook command 路径 — 在 Docker 容器内此路径为 `/app/scripts/notify-play.sh`

</code_context>

<specifics>
## Specific Ideas

- stub 脚本写入调用日志到 `$CALLED_LOG` 环境变量指定的文件，测试 setup 设置 `export CALLED_LOG=$(mktemp)`
- 冷却测试用 `touch -d` 直接设置 lock file 时间戳，不用 sleep
- install.sh 幂等测试：先运行一次 install，验证 hooks 存在；再运行一次，验证 hooks 未重复
- uninstall.sh 幂等测试：先 uninstall 清除 hooks，再 uninstall 一次，验证不报错

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 07-bash*
*Context gathered: 2026-03-30*
