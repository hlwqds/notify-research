# GSD-2 + GLM Coding Plan 配置指南

## 前提条件

- GSD-2 已安装（`npm install -g gsd-pi`）
- GLM Coding Plan 订阅（获取 API Key）
- Fish Shell

## 1. 配置 GLM API Key

编辑 `~/.gsd/agent/auth.json`，添加 `zai` 条目：

```json
{
  "zai": {
    "type": "api_key",
    "key": "<你的GLM_API_KEY>"
  }
}
```

> GLM Coding Plan 的 API Key 在 [open.bigmodel.cn](https://open.bigmodel.cn) 获取。

## 2. 配置模型路由

编辑 `~/.gsd/prefs.md`（全局配置，所有项目生效）：

```yaml
---
version: 1
models:
  default: zai/glm-5-turbo
  research: zai/glm-5.1
  planning: zai/glm-5.1
  execution: zai/glm-5-turbo
  execution_simple: zai/glm-4.5-air
---
```

### 模型等级对应关系

| GSD 等级 | GLM 模型 | 对标 Claude | 用途 |
|----------|----------|-------------|------|
| heavy | glm-5.1 | Opus | 研究、复杂规划 |
| standard | glm-5-turbo | Sonnet | 普通代码执行 |
| light | glm-4.5-air | Haiku | 简单任务（重命名、小修改） |

## 3. 配置 Google Search 扩展

Google Search 扩展读环境变量 `GEMINI_API_KEY`：

```fish
set -Ux GEMINI_API_KEY "<你的Gemini_API_KEY>"
```

`-U` 是 fish 的 universal 变量，设一次永久生效。

## 4. 启动 GSD

```bash
gsd
```

无需指定 `--provider` 或 `--model`，prefs.md 已配置默认模型。

### 会话中切换模型

- `Ctrl+L` — 打开模型选择器，搜索 `glm`
- `/model` — 查看当前模型

## 5. 可选：配置 fallback 链

当主模型不可用时自动切换到备用模型：

```yaml
---
version: 1
models:
  default: zai/glm-5-turbo
  planning:
    model: zai/glm-5.1
    fallbacks:
      - zai/glm-5-turbo
  execution: zai/glm-5-turbo
  execution_simple: zai/glm-4.5-air
---
```

## 6. 可选：自定义模型（非内置模型）

如果 GSD 版本没有内置 GLM 模型，可通过 `~/.gsd/agent/models.json` 手动添加：

```json
{
  "providers": {
    "zai": {
      "baseUrl": "https://open.bigmodel.cn/api/paas/v4",
      "api": "openai-completions",
      "apiKey": "<你的GLM_API_KEY>",
      "models": [
        {
          "id": "glm-5.1",
          "name": "GLM-5.1",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 16384
        },
        {
          "id": "glm-5-turbo",
          "name": "GLM-5-Turbo",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 16384
        },
        {
          "id": "glm-4.5-air",
          "name": "GLM-4.5-Air",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 16384
        }
      ]
    }
  }
}
```

## 7. 配置智谱官方 MCP Server

编辑 `~/.gsd/mcp.json`（全局生效，所有项目可用）：

```json
{
  "mcpServers": {
    "zai-mcp-server": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@z_ai/mcp-server"
      ],
      "env": {
        "Z_AI_API_KEY": "<你的GLM_API_KEY>",
        "Z_AI_MODE": "ZHIPU"
      }
    },
    "web-search-prime": {
      "type": "http",
      "url": "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
      "headers": {
        "Authorization": "Bearer <你的GLM_API_KEY>"
      }
    },
    "web-reader": {
      "type": "http",
      "url": "https://open.bigmodel.cn/api/mcp/web_reader/mcp",
      "headers": {
        "Authorization": "Bearer <你的GLM_API_KEY>"
      }
    },
    "zread": {
      "type": "http",
      "url": "https://open.bigmodel.cn/api/mcp/zread/mcp",
      "headers": {
        "Authorization": "Bearer <你的GLM_API_KEY>"
      }
    }
  }
}
```

### MCP Server 说明

| MCP | 类型 | 功能 | 文档 |
|-----|------|------|------|
| **zai-mcp-server** | stdio（本地） | 视觉理解（GLM-4.6V），图片/视频分析 | [文档](https://docs.bigmodel.cn/cn/coding-plan/mcp/vision-mcp-server) |
| **web-search-prime** | http（远程） | 联网搜索，替代 Claude Code 原生搜索 | [文档](https://docs.bigmodel.cn/cn/coding-plan/mcp/search-mcp-server) |
| **web-reader** | http（远程） | 网页内容抓取与解析 | [文档](https://docs.bigmodel.cn/cn/coding-plan/mcp/reader-mcp-server) |
| **zread** | http（远程） | GitHub 开源仓库代码/文档读取 | [文档](https://docs.bigmodel.cn/cn/coding-plan/mcp/zread-mcp-server) |

> 所有 MCP Server 使用 GLM Coding Plan 的同一个 API Key。

## 8. 可选：配置其他工具扩展

通过 `/gsd config` 或 auth.json 配置：

| 工具 | 环境变量 | 用途 |
|------|---------|------|
| Brave Search | `BRAVE_API_KEY` | 网页搜索（免费 2000 次/月） |
| Tavily Search | `TAVILY_API_KEY` | 网页搜索 |
| Context7 Docs | `CONTEXT7_API_KEY` | 库文档查询（免费 1000 次/月） |
| Jina Page Extract | `JINA_API_KEY` | 网页内容提取 |

## GLM Coding Plan 高峰时段

- **高峰时段**：14:00-18:00（UTC+8）
- **高峰消耗**：按 3 倍计算
- **非高峰**：GLM-5-Turbo 仅 1 倍抵扣（至 2026 年 4 月底）
- **限额刷新**：每 5 小时动态刷新，每周 7 天周期刷新

## 文件位置汇总

| 文件 | 用途 |
|------|------|
| `~/.gsd/agent/auth.json` | API Key 存储 |
| `~/.gsd/prefs.md` | 全局偏好（模型路由等） |
| `~/.gsd/agent/models.json` | 自定义模型（可选） |
| `~/.gsd/mcp.json` | 全局 MCP Server 配置 |
| `.gsd/prefs.md` | 项目级配置（优先于全局） |
| `.gsd/mcp.json` | 项目级 MCP 配置（优先于全局） |

## 参考

- [GSD-2 GitHub](https://github.com/gsd-build/gsd-2)
- [Pi SDK](https://github.com/badlogic/pi-mono)
- [GLM Coding Plan 文档](https://docs.bigmodel.cn/cn/coding-plan/usage-notes)
- [GSD-2 自定义模型文档](https://github.com/gsd-build/gsd-2/blob/master/docs/custom-models.md)
