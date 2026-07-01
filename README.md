# Smart-PMO

> 基于 Claude Code + 飞书 CLI 的项目管理工具集
> 版本：见 [VERSION](./VERSION) 文件

---

## 概述

Smart-PMO 是一套项目管理的 Skill 集合，通过一系列可复用的 Claude Code Skill 覆盖会议纪要提取、待办追踪、群聊消息提取待办、文档归档、里程碑跟进、周报生成等场景。

**核心特点：**
- 🔄 **多项目支持** — 集中注册表管理，`pmo-use` 热切换
- 📊 **统一数据源** — 多维表格 Base 是唯一 truth
- 📁 **文档知识库** — 每个项目独立知识空间
- 👥 **团队协作** — 安装 Claude Code 者用 CLI，其他人直接使用 Base

## Skill 列表

| Skill | 功能 | 状态 |
|-------|------|------|
| `pmo-init` | 项目初始化（创建 Base/知识库/配置）| ✅ |
| `pmo-use` | 切换当前项目 / 成员管理 | ✅ |
| `pmo-list` | 列出所有项目 | ✅ |
| `pmo-meeting-process` | 会议处理（妙记/外部转写/文本）| ✅ |
| `pmo-todo-from-chat` | 群聊消息提取待办 | ✅ |
| `pmo-todo-followup` | 待办跟进 | ✅ |
| `pmo-archive` | 文档归档 | ✅ |
| `pmo-milestone` | 里程碑管理 | ✅ |
| `pmo-weekly-report` | 周报生成（完整文档 + 归档）| ✅ |
| `pmo-weekly-digest` | 轻量周报推送（消息卡片，不创建文档）| ✅ |
| `pmo-pin` / `pmo-unpin` | 项目关注管理 | ✅ |
| `pmo-dashboard` | 多项目概览（风险视角）| ✅ |
| `pmo-search` | 跨表跨项目搜索 | ✅ |
| `pmo-export` | Base 数据导出 | ✅ |
| `pmo-import` | 批量导入待办/里程碑 | ✅ |
| `pmo-info` | 项目详细信息 + 诊断 | ✅ |
| `pmo-today` | 今日概览 | ✅ |
| `pmo-standup` | 每日站会速报（个人视角，可推送）| ✅ |
| `pmo-risk-scan` | 项目风险扫描 | ✅ |
| `pmo-notify` | 主动提醒推送 | ✅ |
| `pmo-stats` | 统计趋势分析 | ✅ |
| `pmo-meeting-prep` | 会前议程准备 | ✅ |
| `pmo-changelog` | 变更日志（AI 语义分类）| ✅ |
| `pmo-burn-down` | 燃尽图（ASCII 终端渲染）| ✅ |
| `pmo-retro` | 项目复盘（AI 辅助生成报告）| ✅ |
| `pmo-health` | 项目健康检查（配置/连通性/队列诊断）| ✅ |
| `pmo-cross-process` | 跨项目会议处理（一次提取多项目分发）| ✅ |

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
# 1. 今日概览
claude pmo-today

# 2. 处理会议纪要
claude pmo-meeting-process --minutes <妙记链接>

# 3. 从群聊提取待办
claude pmo-todo-from-chat

# 4. 跟进待办
claude pmo-todo-followup

# 5. 周报生成
claude pmo-weekly-report --send

# 6. 多项目概览
claude pmo-dashboard

# 7. 切换项目
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
- [使用手册](使用手册.md) — 完整使用指南
- [测试 Checklist](tests/skill-checklist.md) — Skill 手动回归测试
- [Skill 验证脚本](scripts/validate-skills.sh) — Frontmatter + depends_on 自动验证

## 实施路线

| 阶段 | 内容 | 状态 |
|------|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list | ✅ 已完成 |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard + pmo-pin/pmo-unpin | ✅ 已完成 |
| **阶段三（P2）** | pmo-search + pmo-export + pmo-today + pmo-info + 持续完善 | ✅ 已完成 |
| **阶段四（v1.5.0）** | pmo-risk-scan + pmo-notify + pmo-stats + pmo-import + pmo-meeting-prep 新增；共享模块提取；文档一致性修复 | ✅ 已完成 |
| **v1.5.1 优化** | 全面审查与优化：消除重复、统一共享模块、修复 depends_on、补齐公共模式引用、文档/测试同步 | ✅ 已完成 |
| **阶段五（P3，v1.6.0）** | pmo-burn-down + pmo-changelog + pmo-retro 完整实现；新增 pmo-health + pmo-standup + pmo-weekly-digest | ✅ 已完成 |
| **v1.6.1 优化** | 全面审查与优化（P0-P2）：补齐交互确认、消除内联重复、统一共享模块引用、补全重试策略、收紧权限、版本号对齐、模板增强、新增验证脚本 | ✅ 已完成 |
| **阶段六（P4，v1.7.0）** | pmo-cross-process（跨项目会议处理：一次 AI 提取多项目分发） | ✅ 已完成 |
| **v1.7.1 优化** | pmo-meeting-process 新增里程碑提取，pmo-cross-process 提取深度对齐 | ✅ 已完成 |
| **v1.8.0 重构** | pmo-archive 重构（AI 智能分类归档）+ pmo-cross-process 提质升级 | ✅ 已完成 |
| **v1.9.0 重构** | pmo-cross-process Step 5 全流程重写：直接创建文档、批量写入、同源检查、回滚支持 | ✅ 已完成 |
| **v1.9.1 优化** | 全面审查与优化（P0-P2）：用户字段格式修复、共享模块引用统一、验证脚本增强 | ✅ 已完成 |
| **v1.9.2 优化** | 规范优化：临时文件清理、4 个 Skill 硬编码目录名修复、12 个 Skill 版本号对齐 | ✅ 已完成 |
| **v1.9.3 优化** | 安装规范修复：Skill 从用户级迁移至项目级；6 个缺失 symlink 补齐；2 个冗余目录清理；全部 symlink 转为相对路径并纳入 git 跟踪；setup.sh 适配项目级安装 | ✅ 已完成 |
