# Smart-PMO

> 基于 Claude Code + 飞书 CLI + 飞书智能体 Bot 的项目管理工具集

---

## 概述

Smart-PMO 是一套项目管理的 Skill 集合，通过一系列可复用的 Claude Code Skill 覆盖会议纪要提取、待办追踪、群聊消息提取待办、文档归档、里程碑跟进、周报生成等场景。

**核心特点：**
- 🔄 **多项目支持** — 集中注册表管理，`pmo-use` 热切换
- 🤖 **飞书智能体 Bot** — 定时推送 + 群聊交互，无需自建服务
- 📊 **统一数据源** — 多维表格 Base 是唯一 truth
- 📁 **文档知识库** — 每个项目独立知识空间

## Skill 列表

| Skill | 功能 | 优先级 |
|-------|------|--------|
| `pmo-init` | 项目初始化（创建 Base/知识库/配置）| P0 |
| `pmo-use` | 切换当前项目 | P0 |
| `pmo-list` | 列出所有项目 | P0 |
| `pmo-meeting-process` | 会议处理（妙记/外部转写）| P0 |
| `pmo-todo-from-chat` | 群聊消息提取待办 | P0 |
| `pmo-todo-followup` | 待办跟进 | P0 |
| `pmo-archive` | 文档归档 | P0 |
| `pmo-milestone` | 里程碑管理 | P1 |
| `pmo-weekly-report` | 周报生成 | P1 |
| `pmo-pin` / `pmo-dashboard` | 多项目管理 | P1 |

## 架构概览

```
Claude Code (本地)          飞书智能体 Bot (平台)
    │                            │
    │ AI 密集型操作                │ 定时推送 + @Bot 交互
    │ 会议处理/待办提取/归档       │ 查/写 Base
    └──────────┬─────────────────┘
               │
     ┌─────────▼─────────┐
     │  飞书数据层         │
     │  Base + 知识库 + IM │
     └───────────────────┘
```

## 快速开始

```bash
# 1. 初始化新项目
claude pmo-init

# 2. 处理会议纪要
claude pmo-meeting-process --minutes <妙记链接>

# 3. 从群聊提取待办
claude pmo-todo-from-chat

# 4. 跟进待办
claude pmo-todo-followup

# 5. 切换项目
claude pmo-use <项目名>
```

## 文档索引

- [需求清单](REQUIREMENTS.md) — 完整需求定义
- [Base 表设计](designs/base-tables.md) — 多维表格字段定义
- [配置 Schema](designs/config-schema.md) — 配置文件结构
- [Bot 配置指南](designs/bot-setup-guide.md) — 飞书智能体配置步骤
- [Skill 详细规格](designs/skill-specs/) — 各 Skill 执行流程

## 实施路线

| 阶段 | 内容 |
|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list + Bot 配置 |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard/pmo-pin |
| **阶段三（P2）** | 飞书智能体 Bot 深度增强 |
