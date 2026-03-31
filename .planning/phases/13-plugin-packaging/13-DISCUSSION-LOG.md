# Phase 13: Plugin Packaging - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 13-plugin-packaging
**Areas discussed:** Audio delivery strategy, Platform hook handling, userConfig & voice selection, Testing approach

---

## Audio Delivery Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| 留插件目录 (Recommended) | hook 命令用 ${CLAUDE_PLUGIN_ROOT}/audio/voices/{name}/notify-*.mp3 引用，不复制文件。安装简单，但依赖插件目录存在时才能播放 | ✓ |
| 复制到 ~/.claude/ | 保持当前行为，install 时复制到 ~/.claude/。hook 命令用固定路径 ~/.claude/notify-*.mp3。更可靠但文件重复 | |
| 你决定 | Claude decides | |

**User's choice:** 留插件目录 (Recommended)
**Notes:** No copy to ~/.claude/, install only injects hooks.

---

## Platform Hook Handling

| Option | Description | Selected |
|--------|-------------|----------|
| 双 hook 条目 (Recommended) | hooks.json 里为每个事件写两条 hook：一条 bash (Linux/macOS)，一条 powershell (Windows)。Claude Code 自动按平台选择正确的 shell 执行 | ✓ |
| 单 hook + 脚本内分流 | 每个事件一条 hook，用 platform 检测逻辑 (uname -s 或 $PSVersionTable) 在脚本内部分流 | |
| 你决定 | Claude decides | |

**User's choice:** 双 hook 条目 (Recommended)
**Notes:** Rely on Claude Code's `"shell"` field for platform selection.

---

## userConfig & Voice Selection

| Option | Description | Selected |
|--------|-------------|----------|
| 最小 userConfig (Recommended) | plugin.json userConfig 只包含一个 voice 字段，默认 “gentle”。Phase 14 再做完整的安装交互式 voice selection，Phase 13 只预留接口 | ✓ |
| 完整 userConfig | userConfig 包含 voice + audioPlayer 自定义字段 (允许用户指定播放器命令如 mpv/afplay) | |
| 你决定 | Claude decides | |

**User's choice:** 最小 userConfig (Recommended)
**Notes:** Phase 14 adds full voice selection UX.

---

## Testing Approach

| Option | Description | Selected |
|--------|-------------|----------|
| 结构验证 (Recommended) | 验证 plugin.json schema 合法、hooks.json 语法正确、${CLAUDE_PLUGIN_ROOT} 路径引用存在。不依赖 Claude Code 实际运行插件 | ✓ |
| 结构 + 模拟执行 | 结构验证 + 模拟 Claude Code hook 执行 (mock 环境变量，验证路径解析和脚本调用) | |
| 你决定 | Claude decides | |

**User's choice:** 结构验证 (Recommended)
**Notes:** Plugin system immature — no functional testing against Claude Code.

---

## Claude's Discretion

- plugin.json schema details (name, description, version, etc.)
- Exact hooks.json format and field structure
- Whether to create a validation script or inline checks
- hooks.json organization (single file vs split)

## Deferred Ideas

None.
