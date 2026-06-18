# Smart-PMO 项目手册

> 基于 Claude Code + 飞书 CLI 的项目管理工具集
> 项目版本：见根目录 `VERSION` 文件（当前 v1.8.0）

---

## 版本管理约定

- **`VERSION`** 文件为项目唯一版本源，所有版本号需与此文件保持一致
- `使用手册.md` 的版本标注、`designs/config-schema.md` 的 `schemaVersion` 跟随 VERSION 同步更新
- 各 Skill 独立维护自身版本号（在各自 SKILL.md frontmatter 中），但依赖的公共约定（如配置结构）应与 VERSION 兼容
- **Skill 版本号约定**：新 Skill 首次交付时版本号与项目 VERSION 对齐（如 v1.5.0 交付的 Skill 初始版本为 1.5.0）；后续根据自身实际变更频次独立演进（如 1.5.0 → 1.5.1 → 1.6.0）

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
├── VERSION                             # 项目唯一版本源

├── .agents/                             # Claude Code Skill 定义
│   └── skills/
│       ├── _shared/                      # 公共模块（日期计算、待处理队列检查、卡片模板等）
│       ├── pmo-cross-process/             # 跨项目会议处理（一次提取多项目分发）
│       └── ...

├── designs/                            # 架构级设计文档
│   ├── base-tables.md                  # 多维表格 Base 3 张表的字段设计
│   ├── config-schema.md                # 配置项 schema 定义
│   └── bot-setup-guide.md              # 飞书智能体 Bot 配置指南（已归档）

├── templates/                          # 文档模板
│   ├── meeting-notes-template.md       # 会议纪要文档模板
│   ├── weekly-report-template.md       # 周报文档模板
│   └── asr-correction-table-template.md # ASR 校正表模板

├── tests/                              # 测试
│   └── skill-checklist.md              # Skill 手动回归测试清单

├── scripts/                            # 工具脚本
│   └── validate-skills.sh              # Skill frontmatter + depends_on 验证

├── output/                             # 外部转写文件存放（.gitignore 排除）
│   └── README.md                       # 目录用途说明
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
| 飞书 CLI | 底层能力 | 通过 `lark-*` skill 访问飞书各 API；所有操作通过 CLI 完成 |
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

**并发写保护：** 多个终端同时运行 `pmo-use` 切换项目会导致竞态，约定如下：
- 写入 `current` 前使用**原子创建**（exclusive create，O_EXCL 语义）尝试创建 `current.lock` 临时文件（内容为当前进程 PID + 时间戳）
  - 原子创建：若文件已存在则失败，若不存在则创建并写入，整个操作不可分割（避免 TOCTOU）
  - 实现示例：`open(path, 'wx')` in Python / `O_CREAT|O_EXCL` in POSIX / `--no-clobber` in shell
- 原子创建失败（锁已存在）且距创建时间 < 15s → 等待 2s 后重试，最多重试 5 次（总等待 ≤ 10s）
- 锁存在且超过 15s（残留锁）→ 直接覆盖，不等待
- 写入完成后立即删除 `current.lock`

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

### 公共：配置版本管理（所有 Skill 统一遵循）

所有 registry JSON 文件包含 `schemaVersion` 字段，当前最新版本为 `1.1`。

**版本兼容检查规则：**
```
1. 读取 registry JSON 后，检查 schemaVersion 字段
2. 若 schemaVersion 不存在 → 视为 1.0，按迁移规则升级
3. 若 schemaVersion < 当前版本 → 自动执行增量迁移（见下方迁移表）
4. 若 schemaVersion > 当前版本 → 提示"配置版本过新，请升级 Smart-PMO"，中断执行
```

**版本迁移表：**

| 版本 | 变更内容 | 迁移规则 |
|------|---------|---------|
| 1.0 → 1.1 | `chat.lastReadMessageId` 改为 `chat.readPositions["<chat_id>"]` map | 将原单值迁移为 `{ "<chatIds[0]>": { "lastReadMessageId": "<原值>", "lastReadTime": "<原值>" } }` |

### 公共：读取当前项目配置（所有 Skill 统一遵循）

所有 `pmo-*` Skill 在需要项目上下文时，**必须按以下顺序**确定当前项目：

```
1. 优先读取环境变量 $SMART_PMO_CURRENT
2. 若无环境变量，读取文件 ~/.smart-pmo/current（内容为 project_id）
3. 用 project_id 加载 ~/.smart-pmo/registry/{project_id}.json
4. 文件不存在或为空 → 提示"请先执行 pmo-use <项目名>"，中断执行
5. 检查 schemaVersion，执行必要的版本迁移（见上方版本管理）
6. 执行配置完整性校验（见下方配置校验）
```

**配置对象结构（所有 Skill 通过以下路径访问字段）：**

```
config.schemaVersion               配置版本号（当前 1.1）
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
config.larkResources.chatIds[]          项目群 chat_id 列表
config.chat.readPositions["<chat_id>"].lastReadMessageId   各群消息读取位置
config.chat.readPositions["<chat_id>"].lastReadTime        各群上次读取时间
```

### 公共：配置完整性校验（所有 Skill 统一遵循）

加载配置后，执行以下基本校验：

```
1. 必填字段检查：
   - config.project.name 不为空
   - config.larkResources.baseAppToken 不为空
   - config.larkResources.baseTableIds.todos/milestones/meetingIndex 不为空
   - config.larkResources.wikiSpaceId 不为空
2. 若任一必填字段缺失 → 提示"配置不完整，缺少: {字段列表}。建议重新运行 pmo-init 修复"
3. Base 连通性检查（可选，pmo-use 和 pmo-info 执行）：
   - 通过 lark-base 查询待办表（limit=1）验证 Base token 有效
   - 失败时提示"⚠️ Base 连接失败，请检查 Base 权限和 token 有效性"
4. 校验不通过不阻塞操作，但在终端明确展示警告
```

### 公共：超时配置（所有 Skill 统一遵循）

所有 Base 查询操作统一使用以下超时阈值，**不在各 Skill 中硬编码**：

| 场景 | 超时值 | 说明 |
|------|-------|------|
| 单次 Base 查询 | 20s | 单张表查询（列表、搜索） |
| 并发多项目查询 | 30s | dashboard / today / list 等跨项目并发查询等待上限 |
| 飞书 API 写操作 | 15s | create_record / update_record / wiki 归档等 |

超时即视为失败，触发重试逻辑。

### 公共：错误重试策略（所有 Skill 统一遵循）

所有飞书 API 写操作（Base 写入/更新、Wiki 创建、文档创建）遵循以下重试策略：

```
1. 首次失败 → 等待 1s 后重试
2. 再次失败 → 等待 3s 后重试
3. 第三次失败 → 等待 5s 后重试
4. 三次均失败 → 记录错误详情，按下方"重试耗尽人工介入"规则处理
5. 可重试错误类型：网络超时、API 限流(429)、5xx 服务端错误
6. 不可重试错误类型：权限不足(403)、资源不存在(404)、参数错误(400)
```

**重试耗尽后的人工介入出口（所有 Skill 统一遵循）：**

不同失败场景提供不同的具体操作引导，而不是仅提示"请手动处理"：

| 失败场景 | 终端提示 | 具体操作引导 |
|---------|---------|------------|
| Base 会议索引写入失败 | `❌ 会议索引写入失败（{错误码}）` | `→ 请在 Base 中手动新增会议记录：{baseUrl}/table/{meetingIndex表ID}` |
| Base 待办写入失败 | `❌ 待办写入失败（{错误码}）` | `→ 请在 Base 中手动新增待办：{baseUrl}/table/{todos表ID}` |
| 会议索引回填失败（步骤④）| `❌ 产出待办关联回填失败，已保存到待处理队列` | `→ 下次执行任意 pmo-* 命令时自动重试；或执行 pmo-todo-followup 手动触发` |
| Wiki 归档失败 | `❌ 知识库归档失败（{错误码}）` | `→ 请在 pmo-archive 手动归档：claude pmo-archive <文件路径>` |
| 负责人字段写入失败 | `⚠️ 负责人字段写入失败，已写入备注列` | `→ 请在 Base 中手动分配：{record_url}` |

**Base 记录 URL 构造规则（供上述提示使用）：**
```
baseUrl = https://bytedance.larkoffice.com/base/{config.larkResources.baseAppToken}
记录 URL = {baseUrl}/table/{tableId}/record/{record_id}
表 URL   = {baseUrl}/table/{tableId}
```

### 公共：知识库标准目录（所有 Skill 统一遵循）

知识库的 6 个标准目录定义在项目配置 `config.larkResources.wikiNodeTokens` 的 keys 中，所有 Skill **从配置动态读取**，不硬编码目录名：

```
标准目录（按序号排列）：
  01-会议纪要  ← pmo-meeting-process 自动归档会议纪要
  02-周报      ← pmo-weekly-report 生成归档
  03-需求文档  ← pmo-archive 可归档需求文档
  04-设计文档  ← pmo-archive 可归档设计文档
  05-项目资料  ← pmo-archive 可归档项目资料
  99-归档      ← pmo-archive 默认归档目录
```

任何需要展示目录列表的 Skill，从 `Object.keys(config.larkResources.wikiNodeTokens)` 获取并排序。
```

### 公共：成员名称解析（所有 Skill 统一遵循）

识别到姓名或 @提及 时，**写入 Base 前必须按以下顺序解析为 openId**：

```
1. 在 config.team.members 中精确匹配 name 字段 → 获得 openId 和姓名
2. 精确匹配失败 → 尝试模糊匹配（去掉姓前缀或名后缀）
3. 仍匹配不到 → 通过 lark-contact 搜索飞书通讯录（按姓名关键词）→ 获取 open_id 和 localized_name
4. 搜索返回多个候选 → 在确认界面列出，让用户选择
5. 无结果 → 负责人字段留空，标注 ⚠️ @{姓名} 未匹配，请手动指定
```

**负责人字段写入格式（⚠️ 关键）：**
写入 Base 时必须同时传 `id` 和 `name`，仅传 `id` 会触发 `1254066 UserFieldConvFail`：
```json
{"负责人": [{"id": "ou_xxx", "name": "姓名"}]}
```

**负责人写入失败降级：**
- API 写入失败时自动将负责人姓名写入备注字段（格式：`负责人: {姓名列表}`）
- 记录到 `~/.smart-pmo/.pending_assignee/{project_id}.json`
- `pmo-todo-followup` 执行时检查并提示

未匹配的负责人不阻塞写入流程，但在用户确认界面必须明确标注。

### 公共：待处理队列（所有 Skill 统一遵循）

> 📋 详见 [`_shared/pending-queue-check.md`](.agents/skills/_shared/pending-queue-check.md)。包含四个待处理目录的定义、过期清理规则、以及引用方式。

**所有 Skill 执行时先检查以下四个目录**（详见共享模块）：

| 目录 | 用途 | 处理方式 |
|------|------|---------|
| `.pending_backfill/` | 会议索引"产出待办"回填失败 | 自动重试回填，成功删文件 |
| `.pending_orphan_meeting/` | 会议索引已写入但待办写入失败（孤立会议记录）| 提示用户，建议 `--index-only` 补录待办 |
| `.pending_assignee/` | 负责人 API 写入失败 | pmo-todo-followup 执行时提示用户手动分配 |
| `.draft/` | 用户取消的解析草稿 | pmo-meeting-process 执行同文件时提示恢复 |

### 公共：Base 写入负责人字段格式（所有 Skill 统一遵循）

写入 Base 负责人字段（user类型）时，**必须使用以下格式**，缺一不可：

```json
{"负责人": [{"id": "ou_xxx", "name": "飞书通讯录中的姓名"}]}
```

> ⚠️ 仅传 `{"id": "ou_xxx"}` 会触发 `1254066 UserFieldConvFail`。多负责人时数组中追加对象。

### 公共：日期计算（所有 Skill 统一遵循）

> 📅 详见 [`_shared/date-calc-rules.md`](.agents/skills/_shared/date-calc-rules.md)。包含模糊时间表达计算规则和优先级推断规则。

### 公共：卡片消息模板（所有 Skill 统一遵循）

> 📋 详见 [`_shared/feishu-card-template.md`](.agents/skills/_shared/feishu-card-template.md)。包含飞书卡片消息（interactive）的构造模板、色谱选择、以及 Python 构造示例。

---

<!-- 飞书智能体 Bot 已废弃（飞书计费策略调整），不再使用 -->

---

## 实施路线

| 阶段 | 内容 | 状态 |
|------|------|------|
| **阶段一（P0）** | pmo-init + pmo-meeting-process + pmo-todo-from-chat + pmo-todo-followup + pmo-archive + pmo-use/pmo-list | ✅ 已完成 |
| **阶段二（P1）** | pmo-milestone + pmo-weekly-report + pmo-dashboard/pmo-pin/pmo-unpin | ✅ 已完成 |
| **阶段三（P2）** | pmo-search + pmo-export + pmo-today + pmo-info 全面升级 | ✅ 已完成 |
| **阶段四（v1.5.0）** | pmo-risk-scan + pmo-notify + pmo-stats + pmo-import + pmo-meeting-prep 新增；共享模块提取；文档一致性修复 | ✅ 已完成 |
| **v1.5.1 优化** | 全面审查与优化（P0-P3）：消除三重重复、统一共享模块引用、补齐 5 个 P2 Skill 公共模式引用、修复 depends_on 声明、文档同步、测试 checklist 全覆盖 | ✅ 已完成 |
| **阶段五（P3，v1.6.0）** | pmo-burn-down + pmo-changelog + pmo-retro 完整实现；新增 pmo-health + pmo-standup + pmo-weekly-digest | ✅ 已完成 |
| **v1.6.1 优化** | 全面审查与优化（P0-P2）：补齐交互确认、消除内联重复、统一共享模块引用、补全重试策略、收紧权限、版本号对齐、模板增强、新增验证脚本 | ✅ 已完成 |
| **v1.6.2 优化** | 新增飞书卡片消息模板共享模块（feishu-card-template），支持 interactive 类型通知，含 Python 构造器、色谱对照、Skill 引用规范 | ✅ 已完成 |
| **v1.7.0（P4）** | pmo-cross-process（跨项目会议处理：一次 AI 提取多项目分发） | ✅ 已完成 |
| **v1.7.1 优化** | pmo-meeting-process 新增里程碑提取，pmo-cross-process 提取深度对齐 | ✅ 已完成 |
| **v1.8.0 重构** | pmo-archive 重构：新增飞书链接输入、AI 内容理解自动分类、格式转换；从手动目录指定升级为全自动智能归档 | ✅ 已完成 |
