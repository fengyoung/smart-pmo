---
name: pmo-cross-process
version: 1.7.1
description: "跨项目会议处理——一次提取多项目分发，从含多项目讨论的转写文件中提取纪要/待办/里程碑并分发到各项目"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-doc
    - lark-wiki
    - lark-base
    - lark-contact
    - lark-im
---

# pmo-cross-process — 跨项目会议处理

> 与 `pmo-meeting-process` 的分工：
> - `pmo-meeting-process` — **单项目**，用 `--sub-project` 处理主项目周会中的单个子项目专题
> - `pmo-cross-process` — **多项目**，一次分析多个目标项目，独立分发到各自 Base 和知识空间

## 执行方式

```bash
# 标准用法
claude pmo-cross-process --file <转写文件路径> --projects <项目1>,<项目2>,...

# 指定会议主题/日期（可选，覆盖文件名解析和AI识别）
claude pmo-cross-process --file <路径> --projects A,B --topic "多项目周会" --date 2026-06-17

# 模式选择（可选，组合使用）
claude pmo-cross-process --file <路径> --projects A,B --doc-only       # 仅生成纪要归档（不写Base）
claude pmo-cross-process --file <路径> --projects A,B --todos-only     # 仅提取待办+里程碑
claude pmo-cross-process --file <路径> --projects A,B --no-confirm     # 跳过确认
claude pmo-cross-process --file <路径> --projects A,B --local          # 生成本地 .md
claude pmo-cross-process --file <路径> --projects A,B --local --output ./out  # 指定输出目录
claude pmo-cross-process --file <路径> --projects A,B --asr-correction ./ASR校正表.md
```

**参数规则：**
- `--file` 必填，仅支持外部转写文件（.txt / .docx / .md）
- `--projects` 必填，逗号分隔的项目 ID（registry 文件名），最少 2 个
- `--doc-only` 和 `--todos-only` 互斥
- 若 `--projects` 仅 1 个项目 → 提示"单个项目请使用 pmo-meeting-process --file <路径> --sub-project <项目名>"，中断

## 前置条件

1. 所有目标项目已通过 `pmo-init` 注册（`~/.smart-pmo/registry/{project_id}.json` 存在且配置完整）
2. 转写文件存在且 ≤ 10MB

**所有 Base 查询操作遵循公共超时配置（单次 20s，并发 30s）。写操作失败时遵循公共错误重试策略：3 次指数退避重试（1s/3s/5s）。**

## 执行流程

### Step 0：待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)。对 `--projects` 中每个项目执行待处理队列检查。

### Step 1：加载所有项目配置

对 `--projects` 中的每个 project_id：

```
1. 加载 ~/.smart-pmo/registry/{project_id}.json
2. 文件不存在 → 收集到缺失列表
3. 检查 schemaVersion，按 CLAUDE.md 版本迁移规则处理
4. 校验配置完整性：
   ✅ project.name 不为空
   ✅ larkResources.baseAppToken 不为空
   ✅ larkResources.baseTableIds.todos/milestones/meetingIndex 不为空
   ✅ larkResources.wikiSpaceId 不为空
5. status == "archived" → ⚠️ 警告"项目已归档"，但仍允许写入
```

若任一项目加载失败 → 汇总所有失败项目，提示用户检查后中断。

构建 `projectConfigs = { project_id: config, ... }` 映射。

**关键区别：** 不依赖 `~/.smart-pmo/current`，纯粹基于 `--projects` 列表。

### Step 2：读取转写文件

- 读取本地文件，自动检测编码（UTF-8 / GBK），≤ 10MB
- 文件名自动解析：`YYYYMMDD-{类型}-{主题}.txt` 或 `YYYYMMDD-{主题}.txt` → 提取日期和主题作为默认值
- 若 `--date` 或 `--topic` 参数已指定，以参数为准

### Step 2.5：加载多项目上下文

**① ASR 校正表：**
- 优先：`--asr-correction <文件>` → 读取本地文件
- 否则：从 `--projects` 中第一个项目的 wiki `05-项目资料/ASR校正表.md` 加载
- 未找到 → 跳过

**② 成员映射（所有项目）：**
- 汇总所有项目的 `team.members`，附加 `project_id` 标签
- 输出：`aggregatedMemberList = [{name, openId, role, project_id}, ...]`

**③ 历史会议参考（每个项目）：**
- 对每个项目查询 Base 会议记录索引表，取最近 2 条记录
- 失败静默跳过（非阻塞）

**状态输出：**
```
📖 已加载 ASR校正表（{N}条）、成员映射（{M}人，跨{N}个项目）、历史会议参考（{N}条）
```

### Step 3：AI 一次提取（核心）

调用 LLM 一次，注入多项目上下文。Prompt 模板详见 [`references/cross-prompt-template.md`](references/cross-prompt-template.md)。

**提取深度：** 与 `pmo-meeting-process` 一致，按**议题级×4维度**进行深度提取（概述/进展/决策/风险）。每个项目区块内，先识别讨论议题，再对每个议题进行结构化分解。详见 Prompt 模板的"任务三"和"输出格式"。

**注入变量：**

| 变量 | 来源 |
|------|------|
| `{currentDate}` | 系统日期 |
| `{projectContexts}` | 每个项目：name, alias, PM, members |
| `{asrCorrectionTable}` | Step 2.5 |
| `{recentMeetingContext}` | 每个项目的历史会议摘要 |
| `{aggregatedMemberList}` | 所有项目的成员映射 |
| `{rawTranscript}` | 转写文件内容 |

**LLM 输出格式（议题级深度提取）：**
```
[ProjectAlias] ProjectFullName
### 1. 议题标题
**概述：** 核心内容和背景
**关键数据/进展：** 数据指标、进度状态
**决策/结论：** 达成的结论或方向性决策
**风险/问题：** 阻碍、未解决的问题

### 2. 议题标题
**概述：** ...
**关键数据/进展：** ...
**决策/结论：** ...
**风险/问题：** ...

关键决策:
• ...

待办:
- 内容 | @负责人 | YYYY-MM-DD | 优先级
里程碑:
- 名称 | YYYY-MM-DD | @负责人

[General/跨项目]
### 1. 跨项目议题
**概述：** ...
**关键数据/进展：** ...
**决策/结论：** ...
**风险/问题：** ...

待办:
- 内容 | @负责人 | YYYY-MM-DD | 优先级
```

**输出解析：** 按 `[ProjectTag]` 分组，映射到对应项目。

**待办提取规则：** 与 `pmo-meeting-process` 一致，> 📅 截止时间计算参阅 [`_shared/date-calc-rules.md`](_shared/date-calc-rules.md)。未提及截止时间则留空，未识别优先级默认 P2-一般。

**成员解析（跨项目）：**
```
对于归属项目 P 的待办：
  1. 在 P.team.members 中精确匹配 name → 获得 openId
  2. 模糊匹配（去姓/名前缀）
  3. 未匹配 → 在其他项目的 member list 中查找（openId 跨项目通用）
  4. 仍未匹配 → lark-contact 搜索通讯录
  5. 搜索无结果 → 负责人留空，标注 ⚠️ @{姓名} 未匹配
```

**特殊分类：`[General/跨项目]`** — 无法归属到单个项目的内容，在确认界面标记为「需手动分配」。

### Step 4：确认界面

按项目分组展示提取结果：

```
📋 跨项目会议处理结果 · 请确认
═══════════════════════════════
会议主题: 多项目周会
会议日期: 2026-06-17
涉及项目: XRay, RCA, PAuth

──────────────────────────────
📁 XRay (XRay拆修检测2026) — 2 议题, 3 待办, 1 里程碑
──────────────────────────────
── 议题 1: 拆修流程优化 ──
📌 概述: xxxxxxxxxx
📊 进展: xxxxxxxxxx
✅ 决策: xxxxxxxxxx
⚠️ 风险: xxxxxxxxxx
── 议题 2: 配件供应链 ──
📌 概述: xxxxxxxxxx
📊 进展: xxxxxxxxxx
✅ 决策: xxxxxxxxxx
⚠️ 风险: xxxxxxxxxx
── 关键决策 ──
• ...
── 待办事项 ──
□ [X1] 内容 | @负责人 | 截止: 日期 | P1
□ [X2] 内容 | @??? ⚠️ 负责人未匹配
── 里程碑 ──
◇ [XM1] 名称 | 计划: 日期 | @负责人

──────────────────────────────
📁 PAuth (拍图验真) — 2 议题, 2 待办
──────────────────────────────
── 议题 1: SDK联调与测试环境 ──
📌 概述: xxxxxxxxxx
📊 进展: xxxxxxxxxx
✅ 决策: xxxxxxxxxx
⚠️ 风险: xxxxxxxxxx
── 议题 2: 鉴定标准数据集 ──
📌 概述: xxxxxxxxxx
📊 进展: xxxxxxxxxx
✅ 决策: xxxxxxxxxx
⚠️ 风险: xxxxxxxxxx
── 关键决策 ──
• ...
── 待办事项 ──
□ [P1] 内容 | @负责人 | 截止: 日期 | P1
□ [P2] 内容 | @??? ⚠️ 负责人未匹配

──────────────────────────────
🌐 跨项目内容（需手动分配）— 1 待办
──────────────────────────────
□ [G1] 协调各部门评审时间 | @某某 | 截止: 日期
   ↳ 请选择目标项目: [XRay] [PAuth] [RCA] [跳过]

──────────────────────────────
[全部写入] [按项目选择] [选择写入] [仅写待办] [仅写纪要] [修改] [取消]
```

**确认选项：**

| 选项 | 行为 |
|------|------|
| **全部写入** | 为所有有内容的项目执行完整流程 |
| **按项目选择** | 用户输入项目 ID（如 `XRay,PAuth`），只写入选中项目 |
| **选择写入** | 用户输入待办编号（如 `X1,P2`），只写入选中待办+对应会议索引 |
| **仅写待办** | 跳过纪要文档生成，仅写会议索引+待办+里程碑 |
| **仅写纪要** | 仅生成纪要文档+归档，不写 Base |
| **修改** | 用户输入修改内容，重新展示确认界面 |
| **取消** | 放弃本次操作，缓存解析结果 |

`--no-confirm` 指定时等同「全部写入」。「跨项目内容」在用户手动分配目标项目前阻止写入。

### Step 5：按项目分发写入

对每个有提取内容的项目**串行**执行（项目间 Base/wiki 独立，但串行执行便于进度展示和错误隔离）：

```
For each project_id with extracted content:
  TRY:
    ① 创建纪要文档（lark-doc）
       - 标题格式: {YYYYMMDD}-多项目周会-{project_alias}专题
       - 内容仅含该项目相关节段
       - 文档头部标注: "本文档提取自多项目会议，完整会议涉及: {all_projects}"
    
    ② 归档到项目 wiki（lark-wiki +move）
       - 目标: 01-会议纪要/{YYYYMMDD}-{title}
       - 命名冲突追加序号 -2, -3
    
    ③ 写入会议索引（lark-base）
       - 会议主题前置: [{project_alias}] 
       - 记录方式: "外部转写"
       - 来源文件: 转写文件路径
       - 纪要文档链接: 步骤①的 doc_url
       - 产出待办: 暂留空（步骤⑤回填）
       → 获取 meeting_record_id
    
    ④ 写入待办（lark-base）
       - 状态=待处理，优先级=提取值或 P2-一般
       - 来源 = "会议:多项目周会"
       - 所属会议 = meeting_record_id
       - 去重: 在该项目 Base 内按 来源+待办内容 匹配
       → 收集 todo_record_ids
    
    ⑤ 写入里程碑（lark-base）
       - 状态=未开始
    
    ⑥ 回填会议索引产出待办（lark-base）
       - 更新 产出待办 = todo_record_ids
       - 失败 → 保存到 .pending_backfill/{project_id}.json
    
    记录: ✅ 成功
  CATCH:
    记录: ❌ 失败原因
    若 ②③ 成功但 ④ 全部失败 → 保存到 .pending_orphan_meeting/{project_id}.json
    CONTINUE（不中断其他项目）
```

**进度输出：**
```
⏳ XRay...  ✅ 纪要+3待办+1里程碑
⏳ PAuth... ✅ 纪要+2待办
⏳ RCA...   ⏭️ 无内容，跳过
```

### Step 6：汇总报告

```
═══════════════════════════════
📊 跨项目会议处理完成
═══════════════════════════════
会议: 多项目周会 (2026-06-17)

✅ XRay  — 纪要+3待办+1里程碑
   📄 https://feishu.cn/docx/...

✅ PAuth — 纪要+2待办
   📄 https://feishu.cn/docx/...

⏭️ RCA  — 未提取到相关内容

──────────────────────────────
⚠️ 1 条待办负责人未匹配（已在 Base 备注列标注）
```

## 排重设计

每个项目的 Base 和知识空间完全隔离：

| 排重点 | 机制 |
|--------|------|
| 会议索引 | 按该项目的 `来源文件` 字段独立检查 |
| 待办 | 按该项目的 `来源 + 待办内容` 独立匹配 |
| 跨项目 | 不跨项目去重——各项目 Base 独立 |

**场景：** 新建 PAuth 项目后，从历史综合性会议补录 PAuth 内容 → 不影响 XRay/RCA 已提取的数据。

## 异常处理

| 场景 | 处理方式 |
|------|---------|
| `--projects` 仅 1 个 | 提示改用 `pmo-meeting-process --sub-project` |
| 某项目未注册 | 汇总所有失败，统一中断 |
| 某项目配置不完整 | ⚠️ 警告并跳过，其余继续 |
| 某项目已归档 | ⚠️ 警告但仍允许写入 |
| AI 未提取到某项目内容 | 确认界面标注「无提取内容」，跳过写入 |
| `[General/跨项目]` 未手动分配 | 阻止写入，要求用户在确认界面选择目标项目 |
| 某项目 Base 全部写入失败 | 保存到 `.pending_orphan_meeting/`，继续其他项目 |
| 某项目部分待办写入失败 | 记录失败项，成功项继续，回填只关联成功的 |
| 所有项目 Base 写入失败 | 汇总错误，建议手动补录 |
| 待办负责人写入失败 | 降级写备注字段，记录到 `.pending_assignee/` |
| 回填产出待办失败 | 记录到 `.pending_backfill/`，不影响待办数据完整性 |

## `--local` 模式

跳过所有飞书 API 操作：

- 每个有内容的项目生成独立 `.md` 文件
- 文件名：`{YYYYMMDD}-{topic}-{project_alias}.md`
- 若 `--output` 指定目录 → 写入该目录；否则写入 `--file` 同目录
- 仅包含该项目相关节段；文件头标注「提取自多项目会议」

## 草稿缓存

同 `pmo-meeting-process`，但基于转写文件维度（非单项目）：

```
~/.smart-pmo/.draft/cross_{project_list_hash}_{date}.json
{
  "source_file": "/path/to/transcript.txt",
  "projects": ["XRay", "RCA", "PAuth"],
  "topic": "...",
  "date": "2026-06-17",
  "results": {
    "XRay": { "todos": [...], "milestones": [...], "discussion_points": [...] },
    "PAuth": { ... },
    "RCA": null
  },
  "cached_at": "2026-06-17T10:30:00"
}
```

- 下次同 `--file` + 同 `--projects` 执行时检测到草稿 → 提示恢复
- 写入成功后自动清理
- 超过 7 天未使用 → 提示建议删除
