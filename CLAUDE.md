# Smart-PMO 项目手册

> 基于 Claude Code + 飞书 CLI 的项目管理工具集

---

## 项目定位

Smart-PMO 是一套项目管理的 Skill 集合，覆盖会议纪要提取、待办追踪、群聊消息提取待办、文档归档、里程碑跟进、周报生成等场景。

**关键设计原则：**
- **所有 Skill 全局共用**，通过 `~/.smart-pmo/registry/` 集中注册表切换项目上下文
- **统一数据源**为飞书多维表格 Base（待办/里程碑/会议索引三张表）
- **不自建任何服务**，全线依赖飞书 CLI + Claude Code 本地能力
- **团队协作**：安装 Claude Code 的成员用 CLI 操作，其他成员直接使用 Base

---

## 目录结构

```
smart-pmo/
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

└── bot/                                # 飞书智能体 Bot 配置（已归档参考）
    ├── card-templates/                  # 推送卡片模板
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
5. **信息反馈** — 执行完成后在终端输出结果

### 公共：读取当前项目配置（所有 Skill 统一遵循）

所有 `pmo-*` Skill 在需要项目上下文时，**必须按以下顺序**确定当前项目：

```
1. 优先读取环境变量 $SMART_PMO_CURRENT
2. 若无环境变量，读取文件 ~/.smart-pmo/current（内容为 project_id）
3. 用 project_id 加载 ~/.smart-pmo/registry/{project_id}.json
4. 文件不存在或为空 → 提示"请先执行 pmo-use <项目名>"，中断执行
```

**配置对象结构（所有 Skill 通过以下路径访问字段）：**

```
config.project.name              项目全称
config.project.alias             项目代号（可选）
config.project.status            active / archived
config.team.pm.name              项目经理姓名
config.team.pm.openId            项目经理 openId
config.team.members[]            成员列表 [{name, openId, role}]
config.larkResources.wikiSpaceId         知识空间 ID
config.larkResources.wikiNodeTokens      各目录节点 token（键为目录名）
config.larkResources.baseAppToken        Base token
config.larkResources.baseTableIds.todos          待办表 ID
config.larkResources.baseTableIds.milestones     里程碑表 ID
config.larkResources.baseTableIds.meetingIndex   会议索引表 ID
config.larkResources.chatIds[0]          项目群 chat_id
config.chat.lastReadMessageId            群消息读取位置
config.chat.lastReadTime                 上次读取时间
```

### 公共：成员名称解析（所有 Skill 统一遵循）

识别到姓名或 @提及 时，**写入 Base 前必须按以下顺序解析为 openId**：

```
1. 在 config.team.members 中精确匹配 name 字段
2. 精确匹配失败 → 尝试模糊匹配（去掉姓前缀或名后缀）
3. 仍匹配不到 → 通过 lark-contact 搜索飞书通讯录（按姓名关键词）
4. 搜索返回多个候选 → 在确认界面列出，让用户选择
5. 无结果 → 负责人字段留空，标注 ⚠️ @{姓名} 未匹配，请手动指定
```

未匹配的负责人不阻塞写入流程，但在用户确认界面必须明确标注。

### 公共：日期计算（所有 Skill 统一遵循）

模糊时间表达基于当前日期（`currentDate` = 系统上下文中注入的今日日期）动态计算：

| 表达 | 计算规则 |
|------|---------|
| 今天 | currentDate |
| 明天 | currentDate + 1天 |
| 尽快 / ASAP | currentDate + 3天 |
| 这周五 | 本周五；若今日已是周五则取下周五 |
| 下周X | 下一周的星期X |
| 月底 | 当月最后一天 |
| 下个月底 | 下月最后一天 |
| 未提及 | 留空，确认界面标注 ⚠️ 截止时间未指定 |

---

<!-- 飞书智能体 Bot 已废弃（飞书计费策略调整），不再使用 -->

---

## 实施路线

| 阶段 | 内容 |
|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard/pmo-pin |
| **阶段三（P2）** | pmo-search + 持续完善 |
