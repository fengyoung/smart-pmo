# Smart-PMO

> 基于 Claude Code + 飞书 CLI 的项目管理工具集

---

## 概述

Smart-PMO 是一套项目管理的 Skill 集合，通过一系列可复用的 Claude Code Skill 覆盖会议纪要提取、待办追踪、群聊消息提取待办、文档归档、里程碑跟进、周报生成等场景。

**核心特点：**
- 🔄 **多项目支持** — 集中注册表管理，`pmo-use` 热切换
- 📊 **统一数据源** — 多维表格 Base 是唯一 truth
- 📁 **文档知识库** — 每个项目独立知识空间
- 👥 **团队协作** — 安装 Claude Code 者用 CLI，其他人直接使用 Base

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
Claude Code (本地)
    │
    │ AI 密集型操作
    │ 会议处理/待办提取/归档/周报
    │
    └──────────┬─────────────────┘
               │
     ┌─────────▼─────────┐
     │  飞书数据层         │
     │  Base + 知识库 + IM │
     └───────────────────┘
```

## 快速开始

### 新用户安装

```bash
# 1. 克隆仓库
git clone <仓库地址> ~/MyProjects/smart-pmo

# 2. 运行初始化脚本（创建配置目录 + 注册 Skills）
cd ~/MyProjects/smart-pmo && bash setup.sh
```

**前置依赖：**
- `@larksuite/cli` 已安装并完成认证（`npm install -g @larksuite/cli && lark-cli auth login`）
- Claude Code 已安装

### 初始化第一个项目

```bash
# 交互式创建
claude pmo-init
```

### 日常使用

```bash
# 1. 处理会议纪要
claude pmo-meeting-process --minutes <妙记链接>

# 2. 从群聊提取待办
claude pmo-todo-from-chat

# 3. 跟进待办
claude pmo-todo-followup

# 4. 切换项目
claude pmo-use <项目名>
```

### 迁移到新机器

```
迁移步骤                  │ 移什么               │ 移什么
──────────────────────────┼──────────────────────┼─────────────────────
1. clone 仓库             │ Skill 定义 + 模板     │ Git 管理 ✅
2. bash setup.sh          │ 创建 symlink + 配置目录│ 自动完成
3. 手动复制 ~/.smart-pmo/registry/*.json │ 项目配置│ 敏感信息 ⚠️
4. claude pmo-list        │ 验证一切正常           │
```

> ⚠️ `~/.smart-pmo/registry/` 包含成员 open_id，**不要放入 Git**。迁移时手动复制或用加密方式传输。

## 文档索引

- [需求清单](REQUIREMENTS.md) — 完整需求定义
- [Base 表设计](designs/base-tables.md) — 多维表格字段定义
- [配置 Schema](designs/config-schema.md) — 配置文件结构
- [Bot 配置指南](designs/bot-setup-guide.md) — 飞书智能体配置步骤（已归档）
- [Skill 详细规格](designs/skill-specs/) — 各 Skill 执行流程

## 实施路线

| 阶段 | 内容 |
|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard/pmo-pin |
| **阶段三（P2）** | pmo-search + 持续完善 |
