# Smart-PMO 项目手册

> 基于 Claude Code + 飞书 CLI + 飞书智能体 Bot 的项目管理工具集

---

## 项目定位

Smart-PMO 是一套项目管理的 Skill 集合，覆盖会议纪要提取、待办追踪、群聊消息提取待办、文档归档、里程碑跟进、周报生成等场景。

**关键设计原则：**
- **所有 Skill 全局共用**，通过 `~/.smart-pmo/registry/` 集中注册表切换项目上下文
- **飞书智能体 Bot 独立完成定时推送**（每日待办概览 + 里程碑检查），无需自建服务
- **统一数据源**为飞书多维表格 Base（待办/里程碑/会议索引三张表），Bot 和 Claude Code 共享
- **不自建任何服务**，全线依赖飞书平台 + Claude Code 本地能力

---

## 目录结构

```
_smart-pmo/
├── CLAUDE.md                           # 本文件 — 项目手册
├── REQUIREMENTS.md                     # 完整需求清单
├── README.md                           # 项目概述与快速开始

├── designs/                            # 详细设计文档
│   ├── base-tables.md                  # 多维表格 Base 3 张表的字段设计
│   ├── config-schema.md                # 配置项 schema 定义
│   ├── bot-setup-guide.md              # 飞书智能体 Bot 配置指南
│   └── skill-specs/                    # 各 Skill 详细规格
│       ├── pmo-init.md
│       ├── pmo-meeting-process.md
│       ├── pmo-todo-from-chat.md
│       ├── pmo-todo-followup.md
│       ├── pmo-archive.md
│       ├── pmo-milestone.md
│       ├── pmo-weekly-report.md
│       └── pmo-use-list-dashboard.md

├── templates/                          # 文档模板
│   ├── meeting-notes-template.md       # 会议纪要文档模板
│   └── weekly-report-template.md       # 周报文档模板

└── bot/                                # 飞书智能体 Bot 配置
    ├── card-templates/                  # 推送卡片模板
    │   ├── overdue-card.json            # P0 过期待办告警卡片
    │   ├── meeting-summary-card.json    # P1 会议纪要卡片
    │   └── daily-overview-card.json     # P2 每日概览卡片
    └── scheduled-tasks.md               # 定时任务配置说明
```

---

## Skill 命名规范

| 格式 | 示例 |
|------|------|
| `pmo-<动词>-<名词>` | `pmo-init`, `pmo-use` |
| `pmo-<领域>-<动作>` | `pmo-meeting-process`, `pmo-todo-followup` |

所有 Skill 在 Claude Code 中通过 `claude pmo-<skill>` 调用。

---

## 技术栈与依赖

| 依赖 | 角色 | 说明 |
|------|------|------|
| 飞书 CLI | 底层能力 | 通过 `lark-*` skill 访问飞书各 API |
| `lark-base` | 操作多维表格 | 读/写待办、里程碑、会议索引 3 张表 |
| `lark-wiki` | 操作知识库 | 创建知识空间、上传文档 |
| `lark-doc` | 创建文档 | 生成会议纪要、周报等飞书文档 |
| `lark-im` | 操作群聊 | 发消息/卡片、读历史消息 |
| `lark-minutes` | 飞书妙记 | 读取会议转写内容 |
| 飞书智能体 Bot | 定时+交互 | 平台托管，不自建服务 |
| Claude Code Skill | 执行入口 | 所有 `pmo-*` skill |

---

## 配置管理

所有项目配置集中存储在 `~/.smart-pmo/`：

```
~/.smart-pmo/
├── registry/
│   ├── <project-name>.json          # 每个项目的完整配置
│   └── ...
├── current                           # 当前项目（文本文件，内容为项目名）
└── pinned                            # 关注项目列表（每行一个项目名）
```

**当前项目确定规则：** `$SMART_PMO_CURRENT` 环境变量 > `~/.smart-pmo/current` 文件

---

## 核心数据模型

### 飞书多维表格 Base — 3 张表

**表1：待办事项** — 所有待办统一管理
**表2：里程碑** — 项目里程碑规划+跟踪  
**表3：会议记录索引** — 会议归档 + 关联待办

每张表的详细字段定义见 `designs/base-tables.md`。

### 飞书知识库（每项目独立知识空间）

```
[项目名] 知识空间
├── 01-会议纪要/
├── 02-周报/
├── 03-需求文档/
├── 04-设计文档/
├── 05-项目资料/
└── 99-归档/
```

---

## Claude Code Skill 开发规范

1. **每个 Skill 是一个 `.md` 文件**，按 Claude Code Skill 的标准格式定义
2. **交互优先** — 关键操作需用户确认后再执行
3. **幂等设计** — 重复执行不产生重复数据（基于去重逻辑）
4. **配置驱动** — 所有项目参数字段通过配置读取，不硬编码
5. **信息反馈** — 执行完成后通过 `lark-im` 推送到项目群

---

## 飞书智能体 Bot

每个项目独立一个飞书智能体 Bot，负责：
- **定时推送**：每日 10:00 待办概览、09:30 里程碑检查
- **群聊交互**：@Bot 自然语言查询/操作 Base 数据

Bot 的配置由用户在飞书开放平台手动完成，`pmo-init` 时录入 appId/appSecret。
详细配置步骤见 `designs/bot-setup-guide.md`。

---

## 实施路线

| 阶段 | 内容 |
|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list + Bot 配置指南 |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard/pmo-pin |
| **阶段三（P2）** | 飞书智能体 Bot 深度增强（更多 Base 操作能力） |
