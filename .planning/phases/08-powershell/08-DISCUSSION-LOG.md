# Phase 8: PowerShell 单元测试 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 8-powershell
**Areas discussed:** Mock 策略, 测试隔离, BOM 验证

---

## Mock 策略 (MediaPlayer)

| Option | Description | Selected |
|--------|-------------|----------|
| Pester Mock 原地拦截 | Mock Add-Type（阻止程序集加载）+ Mock New-Object（返回假 MediaPlayer 对象）。不改生产代码。 | |
| 重构为可 mock 函数 | 把 MediaPlayer 播放逻辑提取为独立函数（如 Invoke-MediaPlayer），测试时 mock 该函数。改动生产代码但更干净。 | ✓ |
| You decide | 让 planner 根据研究结果选择最佳方案。 | |

**User's choice:** 重构为可 mock 函数
**Notes:** 用户偏好代码整洁性，接受小幅生产代码改动换取可测试性。与 bash 侧使用 PATH stub 的思路一致——都是将外部依赖替换为可 mock 的接口。

---

## 测试隔离 ($env:USERPROFILE)

| Option | Description | Selected |
|--------|-------------|----------|
| 直接设置 $env:USERPROFILE | 在 BeforeEach 中设置 $env:USERPROFILE = $TestTempDir，指向临时目录中的 fake ~/.claude/settings.json。 | ✓ |
| You decide | 技术细节交给 planner。 | |

**User's choice:** 直接设置 $env:USERPROFILE
**Notes:** 与 Phase 7 bash 测试中 HOME 覆盖模式一致。直接明确，无需 planner 探索。

---

## BOM 验证 (PS-07)

| Option | Description | Selected |
|--------|-------------|----------|
| 字节级检查文件头 | 读取文件前 3 字节，验证不等于 0xEF 0xBB 0xBF（UTF-8 BOM）。精确但需要处理字节。 | ✓ |
| You decide | 技术实现细节，planner 选最可靠的方式即可。 | |

**User's choice:** 字节级检查文件头
**Notes:** 用户偏好精确验证而非间接推断。

---

## Claude's Discretion

- 重构后的函数命名（Invoke-MediaPlayer 或其他）
- Pester Describe/Context/It 嵌套层级
- BeforeAll 共享 fixture vs 每个 It 独立拷贝
- 冷却时间戳操纵的具体 PowerShell API

## Deferred Ideas

None — discussion stayed within phase scope.
