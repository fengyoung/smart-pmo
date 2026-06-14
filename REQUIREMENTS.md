# Smart-PMO 项目需求清单

> 最后更新：2026-06-12

---

## 一、项目定位

Smart-PMO 是一套基于 **Claude Code Skill 系统 + 飞书 CLI** 的项目管理工具集，以半自动化的方式辅助项目管理的日常运作。核心依赖飞书平台的多维表格 Base 和知识库作为统一数据源，**不自建任何服务**。

### 核心理念

- **多项目支持**：通过集中注册表管理多个项目，`pmo-use` 热切换上下文
- **配置驱动**：所有项目参数集中存储在 `~/.smart-pmo/registry/`，技能不硬编码
- **统一数据源**：多维表格 Base 是待办/里程碑/会议索引的唯一 truth
- **团队协作**：安装 Claude Code + pmo-* skill 的成员用 CLI 操作，其他成员直接使用 Base

---

## 二、整体架构

### 2.1 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    Claude Code (安装者各自使用)                 │
│                                                              │
│  pmo-init            → 初始化项目+创建Base+知识库+注册         │
│  pmo-meeting-process → 读取妙记/文件 → 提取纪要→归档→写Base   │
│  pmo-todo-from-chat  → lark-im 读群消息 → 提取待办 → 写Base  │
│  pmo-todo-followup   → 查Base → 待办跟进                      │
│  pmo-archive         → 上传文件到知识库                        │
│  pmo-milestone       → 查Base里程碑 → 到期检查                 │
│  pmo-weekly-report   → 汇总Base → 生成周报 → 归档              │
│                                                              │
│  项目上下文管理：                                              │
│  pmo-list / pmo-use / pmo-pin / pmo-dashboard                │
│                                                              │
│  依赖：lark-* 系列 skill + ~/.smart-pmo/registry/             │
└───────────────┬──────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────┐
│                    飞书 CLI 层                                │
│  lark-base / lark-doc / lark-wiki / lark-im / lark-minutes   │
└───────────────┬──────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────┐
│                     飞书数据层                                 │
│                                                              │
│  知识库(Wiki)        ← 会议纪要 + 周报 + 归档文档             │
│  多维表格(Base)      ← 待办 + 里程碑 + 会议索引（统一数据源）  │
│  群聊(IM)           ← 待办消息提取源                          │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 数据流

```
项目群聊 → pmo-todo-from-chat → AI提取 → 用户确认 → 写Base
飞书妙记 → pmo-meeting-process → AI提取 → 归档知识库 + 写Base
外部转写文件 → pmo-meeting-process → AI提取 → 归档知识库 + 写Base
定时推送 → （非刚需，按需在群内使用飞书定时应用）
```

---

## 三、配置与项目上下文管理

### 3.1 目录结构

```
~/.smart-pmo/                            ← 中央配置中心
├── registry/
│   ├── project-a.json                   ← project-a 的完整项目配置
│   ├── project-b.json                   ← project-b 的完整项目配置
│   └── ...                              ← 新项目由 pmo-init 自动注册
├── current                              ← 当前项目（文本文件，内容为项目名）
└── pinned                               ← 关注项目列表（每行一个项目名）
```

### 3.2 项目配置 JSON (`~/.smart-pmo/registry/<project>.json`)

```json
{
  "project": {
    "name": "项目名称",
    "alias": "项目代号",
    "createdDate": "2026-06-09",
    "status": "active"
  },
  "team": {
    "pm": { "name": "项目经理", "openId": "ou_xxxx" },
    "members": [
      { "name": "成员A", "openId": "ou_xxxx", "role": "开发" },
      { "name": "成员B", "openId": "ou_xxxx", "role": "产品" }
    ]
  },
  "larkResources": {
    "wikiSpaceId": "ss_xxxxx",
    "baseAppToken": "bas_xxxxx",
    "baseTableIds": {
      "todos": "tbl_xxxxx",
      "milestones": "tbl_xxxxx",
      "meetingIndex": "tbl_xxxxx"
    },
    "chatIds": [
      "oc_xxxxxxxxxxxxxxxxxxxxxxxx"
    ]
  },
  "chat": {
    "readPositions": {
      "oc_xxxxxxxxxxxxxxxxxxxxxxxx": {
        "lastReadMessageId": "om_xxxxx",
        "lastReadTime": "2026-06-08T18:00:00"
      }
    }
  }
}
```

### 3.3 当前项目确定规则

```
优先级：环境变量 > ~/.smart-pmo/current 文件
   1. 如果设了 `SMART_PMO_CURRENT=project-a` → 使用 project-a
   2. 否则读 `~/.smart-pmo/current` 文件内容
   
多终端互不干扰：终端1 export project-a, 终端2 export project-b
```

### 3.4 项目上下文管理 Skill

| Skill | 功能 |
|-------|------|
| `pmo-use <项目名> [-g]` | 切换当前项目（-g 全局写入 current，默认只设环境变量）|
| `pmo-list` | 列出所有已注册项目及其状态概览 |
| `pmo-pin <项目名...>` | 关注 1-N 个项目，用于 dashboard 聚合展示 |
| `pmo-unpin <项目名>` | 取消关注项目 |
| `pmo-dashboard` | 一次性展示所有关注项目的待办/里程碑概览 |

---

## 四、数据存储方案

### 4.1 项目文档 → 飞书知识库（Wiki）

每个项目独立的知识空间，目录结构：

```
[项目名] 知识空间
├── 📁 01-会议纪要/         ← pmo-meeting-process 自动归档
├── 📁 02-周报/             ← pmo-weekly-report 生成
├── 📁 03-需求文档/
├── 📁 04-设计文档/
├── 📁 05-项目资料/
└── 📁 99-归档/
```

### 4.2 待办 + 里程碑 + 会议索引 → 飞书多维表格（Base）

每个项目一个 Base，包含 3 张数据表：

#### 📋 表1：待办事项（Todo Items）

| 字段名 | 字段类型 | 必填 | 说明 |
|--------|---------|------|------|
| `待办ID` | 自动编号 | — | 格式 TODO-001 |
| `待办内容` | 文本 | ✅ | 具体的待办事项描述 |
| `负责人` | 人员（单选） | ✅ | 唯一负责人 |
| `截止日期` | 日期 | ✅ | 格式 YYYY-MM-DD |
| `状态` | 单选 | ✅ | `待处理` / `进行中` / `已完成` / `已取消` |
| `优先级` | 单选 | ✅ | `P0-紧急` / `P1-重要` / `P2-一般` / `P3-低优` |
| `所属会议` | 关联记录 | | 关联到「会议记录索引」表 |
| `来源` | 文本 | | 标记来源：会议/群聊/手动 |
| `来源消息ID` | 文本 | | 群聊来源时记录消息 ID（去重用）|
| `完成日期` | 日期 | | 标记完成时自动填入 |
| `备注` | 文本 | | |
| `创建时间` | 创建时间（自动） | — | |
| `创建人` | 创建人（自动） | — | |

**可选视图：**
- 📌 我的待办（负责人=当前用户，状态≠已完成/已取消）
- ⚠️ 已过期（截止日期<今天，状态≠已完成/已取消）
- 📊 完成统计（按状态分组+计数）

#### 🏁 表2：里程碑（Milestones）

| 字段名 | 字段类型 | 必填 | 说明 |
|--------|---------|------|------|
| `里程碑ID` | 自动编号 | — | 格式 MILE-001 |
| `里程碑名称` | 文本 | ✅ | 如：需求评审完成、Beta 版发布 |
| `计划日期` | 日期 | ✅ | |
| `实际日期` | 日期 | | |
| `负责人` | 人员（单选） | ✅ | |
| `状态` | 单选 | ✅ | `未开始` / `进行中` / `已完成` / `已延期` / `已取消` |
| `进度` | 百分比 | | 0%~100% |
| `关联待办` | 关联记录 | | 关联到「待办事项」表 |
| `描述` | 文本 | | 详细说明/验收标准 |
| `备注` | 文本 | | |
| `创建时间` | 创建时间（自动） | — | |

**可选视图：**
- 📅 时间线（按计划日期排序，按状态分组）
- ⚠️ 即将到期（计划日期7天内，状态≠已完成）

#### 📝 表3：会议记录索引（Meeting Index）

| 字段名 | 字段类型 | 必填 | 说明 |
|--------|---------|------|------|
| `会议ID` | 自动编号 | — | 格式 MEET-001 |
| `会议日期` | 日期 | ✅ | |
| `会议主题` | 文本 | ✅ | |
| `开始时间` | 日期时间 | | |
| `结束时间` | 日期时间 | | |
| `参会人` | 人员（多选） | | |
| `记录方式` | 单选 | ✅ | `飞书妙记` / `外部转写` / `手动记录` |
| `来源文件` | 文本 | | 妙记链接或本地转写文件路径 |
| `纪要文档链接` | 链接 | ✅ | 归档后的文档链接 |
| `产出待办` | 关联记录 | | 关联到「待办事项」表，1 → N |
| `讨论要点摘要` | 文本 | | AI 自动提取 |
| `关键决策` | 文本 | | AI 自动提取 |
| `备注` | 文本 | | |
| `创建时间` | 创建时间（自动） | — | |

#### 表间关联

```
会议记录索引 ──(产出待办)──→ 待办事项 ←──(关联待办)── 里程碑
     ↑                        ↑
     └──(所属会议)─────────────┘
```

---

## 五、功能模块详情

### M1 — `pmo-init` 项目初始化（P0）

交互式创建新项目，自动完成全部基础设施搭建。

| # | 需求 |
|---|------|
| 1 | 交互式收集：项目名称、项目经理、核心成员、项目群 |
| 2 | 自动创建**飞书知识空间**（独立），按模板建立目录结构（6 个目录） |
| 3 | 自动创建**多维表格 Base**（3 张表：待办/里程碑/会议索引），按 4.2 定义字段 |
| 4 | 生成配置写入 `~/.smart-pmo/registry/<项目名>.json` |
| 5 | 设定 `~/.smart-pmo/current` 指向新项目 |

### M2 — `pmo-meeting-process` 会议处理（P0）

| # | 需求 |
|---|------|
| 1 | **输入源A（飞书妙记）**：通过妙记链接或 session ID 自动获取转写内容（调 `lark-minutes`） |
| 2 | **输入源B（外部转写文件）**：传入本地转写文件路径（.txt / .docx / .md），Claude 解析 |
| 3 | 自动识别并提取：会议主题、日期时间、参会人 |
| 4 | 自动提取：讨论要点、关键决策、争议点 |
| 5 | 自动提取：待办事项（内容、负责人、截止时间） |
| 6 | 生成结构化会议纪要文档，归档到知识库 `01-会议纪要/` |
| 7 | 将提取的待办写入 Base「待办事项」表，关联对应的会议记录 |
| 8 | 将会议记录写入 Base「会议记录索引」表 |
| 9 | 支持追加补充纪要内容 |

### M3 — `pmo-todo-from-chat` 群消息提取待办（P0）

| # | 需求 |
|---|------|
| 1 | 通过 `lark-im` 从项目群读取未处理的历史消息（从 `lastReadMessageId` 开始）|
| 2 | 最多读取 100 条消息，过滤系统消息 |
| 3 | AI 分析消息内容，识别潜在待办（基于语义模式：提及责任人、任务表述等）|
| 4 | 提取待办要素：内容、负责人、隐式截止时间 |
| 5 | 与 Base 已有待办排重（基于来源消息 ID + 内容相似度）|
| 6 | 展示给用户确认后写入 Base「待办事项」表 |
| 7 | 更新 `lastReadMessageId` 和 `lastReadTime`，避免重复处理 |

### M4 — `pmo-todo-followup` 待办跟进（P0）

| # | 需求 |
|---|------|
| 1 | 从 Base 读取当前有效待办（状态为"待处理"/"进行中"），支持按负责人或截止日期分组 |
| 2 | 检查已过期待办并生成提醒列表 |
| 3 | 标记待办为"已完成"，自动填入完成日期 |
| 4 | 修改待办负责人或截止日期 |

### M5 — `pmo-archive` 文档归档（P0）

| # | 需求 |
|---|------|
| 1 | 上传本地文件到知识库指定目录（Word/PDF/图片/代码文档等）|
| 2 | 归档时自动添加元数据：归档日期、类型 |

### M6 — `pmo-milestone` 里程碑管理（P1）

| # | 需求 |
|---|------|
| 1 | 从 Base 读取所有里程碑及当前状态 |
| 2 | 新增/修改里程碑（写入 Base）|
| 3 | 检查即将到期（7天内）和已过期的里程碑 |
| 4 | 标记里程碑完成，记录实际完成日期 |

### M7 — `pmo-weekly-report` 周报生成（P1）

| # | 需求 |
|---|------|
| 1 | 统计本周会议次数和主要议题 |
| 2 | 统计待办完成率（本周新增 / 本周完成 / 逾期未完成）|
| 3 | 统计里程碑状态 |
| 4 | 生成格式化周报文档，归档到知识库 `02-周报/` |

---

## 六、群聊消息提取待办

### 6.1 `pmo-todo-from-chat` 执行流程

```
用户执行 `pmo-todo-from-chat`
         │
         ▼
① 从配置中读 lastReadMessageId
   └→ 调 lark-im list_message 获取后续消息（上限 100 条）
   └→ 过滤：排除系统消息
         │
         ▼
② AI 分析消息内容，提取潜在待办
   └→ 识别模式："我来负责" "x总处理一下" "需要做" "明天前要完成" 等
   └→ 提取：待办内容、负责人（@提及/姓名）、隐式截止时间（"这周五"）
         │
         ▼
③ 与 Base 已有待办排重
   └→ 来源消息 ID 去重：同一消息不重复提取
   └→ 内容去重：语义相似度 >80% 跳过
         │
         ▼
④ 展示给用户确认
   └→ "从群消息中发现以下 N 条潜在待办，是否写入 Base？"
   └→ [全部写入] [选择写入] [忽略全部]
         │
         ▼
⑤ 确认后 → 通过 lark-base 写入「待办事项」表
   更新配置中的 lastReadMessageId
```

### 6.2 排重机制

| 场景 | 排重策略 |
|------|---------|
| 同一消息多次读取 | 通过 `lastReadMessageId` 增量读取，不重复 |
| 同一待办在群聊中反复讨论 | 基于待办内容的语义相似度去重 |
| 已录入 Base 的待办又被识别 | 比对 Base 已有记录标题 -> 跳过 |
| 误提取（非待办的日常对话）| 用户确认环节兜底，不强制写入 |

---

## 七、非功能需求

| # | 需求 | 说明 |
|---|------|------|
| NF1 | **多项目支持** | 集中注册表管理，`pmo-use` 热切换，互不干扰 |
| NF2 | **配置驱动** | 所有项目参数集中在 `~/.smart-pmo/registry/` |
| NF3 | **交互友好** | 关键操作前确认；输出格式化表格 |
| NF4 | **可扩展** | 新增 Skill 统一命名和接口风格 |
| NF5 | **飞书 CLI 依赖** | 飞书操作通过 `lark-*` skill 完成 |
| NF6 | **幂等安全** | 重复执行同一次会议/消息处理不产生重复数据 |

---

## 八、Skill 命名总览

| Skill | 功能 | 优先级 | 指令示例 |
|-------|------|--------|---------|
| `pmo-init` | 项目初始化 | P0 | `claude pmo-init` |
| `pmo-use` | 切换当前项目 | P0 | `claude pmo-use project-a` |
| `pmo-list` | 列出所有项目 | P0 | `claude pmo-list` |
| `pmo-pin` / `pmo-unpin` | 关注项目管理 | P1 | `claude pmo-pin project-a project-b` |
| `pmo-dashboard` | 多项目概览 | P1 | `claude pmo-dashboard` |
| `pmo-meeting-process` | 会议处理 | P0 | `claude pmo-meeting-process --minutes <url>` |
| `pmo-todo-from-chat` | 群消息提取待办 | P0 | `claude pmo-todo-from-chat` |
| `pmo-todo-followup` | 待办跟进 | P0 | `claude pmo-todo-followup` |
| `pmo-archive` | 文档归档 | P0 | `claude pmo-archive --file <path> --dir <dir>` |
| `pmo-milestone` | 里程碑管理 | P1 | `claude pmo-milestone --check` |
| `pmo-weekly-report` | 周报生成 | P1 | `claude pmo-weekly-report` |
| `pmo-search` | 跨表跨项目搜索 | P2 | `claude pmo-search <关键词>` |
| `pmo-export` | 数据导出 CSV/JSON | P2 | `claude pmo-export` |
| `pmo-today` | 今日概览 | P2 | `claude pmo-today` |
| `pmo-info` | 项目详情与诊断 | P2 | `claude pmo-info` |
| `pmo-risk-scan` | 项目风险扫描 | P2 | `claude pmo-risk-scan` |
| `pmo-notify` | 待办/里程碑提醒推送 | P2 | `claude pmo-notify --all` |
| `pmo-stats` | 项目统计分析 | P2 | `claude pmo-stats` |
| `pmo-import` | 文件批量导入待办 | P2 | `claude pmo-import --file <path>` |
| `pmo-meeting-prep` | 会前准备议程生成 | P2 | `claude pmo-meeting-prep` |

---

## 九、实施路线

| 阶段 | 内容 | 目标 | 状态 |
|------|------|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list | 核心闭环可用 | ✅ 已完成 |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard/pmo-pin/pmo-unpin | 管理维度完整 | ✅ 已完成 |
| **阶段三（P2）** | pmo-search + pmo-export + pmo-today + pmo-info 全面升级 + 持续完善 | 检索增强 + 工具链完整 | ✅ 已完成 |
| **阶段四（v1.5.0）** | pmo-risk-scan + pmo-notify + pmo-stats + pmo-import + pmo-meeting-prep 新增；共享模块提取；文档一致性修复 | 风险管理 + 主动通知 + 数据导入 | ✅ 已完成 |
| **v1.5.1 优化** | 全面审查与优化（P0-P3）：消除三重重复、统一共享模块引用、补齐公共模式引用、修复 depends_on、文档/测试同步 | 维护性优化 | ✅ 已完成 |
| **阶段五（P3规划）** | pmo-burn-down + pmo-changelog + pmo-retro（SKILL.md stub 已就绪） | 燃尽图 + 变更日志 + 回顾 | 📋 规划中 |

---

## 十、待办事项（当前）

以下是在已经完成全面审阅优化的基础上，仍待解决的问题：

1. 已有 `pmo-search` skill（P2），已集成到 `pmo-todo-followup`、`pmo-dashboard` 等 Skill 的操作提示中
2. Bot 相关内容已彻底清理（`bot/` 目录已删除，`bot-setup-guide.md` 保留作为历史存档）
3. `setup.sh` 已增强：Node.js 前置检查、lark-cli 安装引导
4. 配置版本管理已上线（schemaVersion 1.1），支持自动迁移
5. 测试 checklist 已编写（`tests/skill-checklist.md`），需在实际使用中持续更新
