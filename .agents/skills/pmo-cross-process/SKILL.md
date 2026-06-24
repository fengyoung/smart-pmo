---
name: pmo-cross-process
version: 1.9.0
description: "跨项目会议处理——一次提取多项目分发，从含多项目讨论的转写文件中提取纪要/待办/里程碑并分发到各项目（v1.9.0：Step 5 全流程重写——直接在知识库内创建文档、批量写入、同源检查、负责人单用户限制、回滚支持）"
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
claude pmo-cross-process --rollback <meeting_record_id1>,<meeting_record_id2>  # 回滚模式：撤销指定会议的写入

# v1.9.0 新增参数
claude pmo-cross-process --file <路径> --projects A,B --notify       # 写入完成后自动推送到项目群
```

**参数规则：**

| 模式 | 必填参数 | 可选参数 |
|------|---------|---------|
| 正常模式 | `--file` + `--projects`（≥2个项目） | `--topic` `--date` `--doc-only` `--todos-only` `--no-confirm` `--local` `--output` `--asr-correction` `--notify` |
| 回滚模式 | `--rollback <record_ids>` | 无 |

- `--file` 仅支持外部转写文件（.txt / .docx / .md），≤ 10MB
- `--projects` 逗号分隔的项目 ID（registry 文件名），最少 2 个；仅 1 个 → 提示改用 `pmo-meeting-process --sub-project`
- `--doc-only` 和 `--todos-only` 互斥
- `--rollback` 与其他所有参数互斥，单独使用
- `--notify` 在写入完成后自动推送群通知，可与正常模式各参数组合

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

### Step 1.5：动态项目检测（v1.8.1+）

> 🔍 当 `--projects` 指定后，额外扫描转写内容中是否涉及其他已注册项目。

```
1. 加载 ~/.smart-pmo/registry/ 下所有项目配置（仅读取 project.name / project.alias）
2. 构建已知项目名称/代号列表
3. 从转写文件内容中关键词匹配（项目名、代号、产品线名、业务领域名）
4. 若匹配到 `--projects` 之外的项目：
   - 在确认界面输出：📌 检测到转写中还涉及 {项目名}（{alias}），是否追加？
   - 用户确认后 → 补充加载该项目配置到 projectConfigs
   - 用户拒绝 → 仅提取内容标注「⚠️ 未在 --projects 中指定」，不执行写入
5. 若首次成功追加，将用户选择记录到草稿缓存，下次同 --file 执行时沿用
```

**设计意图：** 用户可能在一开始未意识到转写涉及了哪些项目。此步骤在加载配置后、读取转写后执行，提供一个修正机会，避免全部提取完成后再补跑。

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

### Step 2.5b：ASR 校正反馈（v1.8.1+，v1.9.0 扩展）

> 📝 AI 提取完成后，将提取过程中发现的 ASR 错误和术语问题反馈给用户，并更新 ASR 校正表。

**反馈范围（v1.9.0 扩展）：**

| 类型 | 触发条件 | 示例 |
|------|---------|------|
| 人名误识别 | 无法在成员表中匹配，但上下文可推断正确人名 | "会山" →（待确认） |
| 术语误识别 | 行业/业务术语被 ASR 转写为同音/近音词，且不在现有校正表 | "清洁盆" → "清洁棚" |
| 昵称/口语名称 | 转写中使用的口语称呼无法匹配到成员表 | "太哥" → "刘太路" |

**执行时机：** AI 提取完成后（Step 3 产出结果后），在展示确认界面之前。

```
1. LLM 输出中若包含「⚠️ 建议添加到 ASR 校正表」行 → 解析其中的候选修正项
2. 汇总所有候选修正项（人名 + 术语），格式：
   检测到疑似 ASR 误识别：
   📝 人名误识别：
   • "{误识别写法}" → {正确写法}（上下文：...）
   🔤 术语误识别：
   • "{误识别写法}" → {正确写法}（上下文：...）
3. 在确认界面输出，询问用户：
   是否将这些条目追加到各项目的 ASR 校正表中？
   [是] [否] [选择追加]
4. 用户确认「是」或「选择追加」后：
   a. 对于已有 ASR 校正表的项目 → 通过 lark-cli docs +update --command append 追加到末尾
   b. 对于尚无 ASR 校正表的项目 → 创建文档后通过 lark-cli wiki +move 归档到 05-项目资料/
   c. 术语追加格式：| {误识别写法} | {正确写法} |
   d. 人名追加格式：| {误识别写法} | {正确写法} |
5. 更新完成后在终端输出：✅ ASR 校正表已更新（{N}条，含术语{K}条）
```

**设计意图：** ASR 错误在校正表未覆盖时会被带入提取结果。此步骤在提取后、写入前给用户一个修正机会，避免"提取后才人工纠正"的被动局面。

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

注：
• 若有同源文件记录 → 顶部展示 🔄 提示
• 若有 ASR/术语候选 → 底部展示 📝 建议
```

**v1.9.0 新增确认元素：**

| 元素 | 触发条件 | 展示 |
|------|---------|------|
| 同源检测 | 某项目已有同来源文件 | `🔄 {项目名} 已有同源记录，本次将更新` |
| 跨项目人员 | 待办负责人不在目标项目 | `⚠️ @{姓名} 不在成员表中，将写备注` |
| 术语反馈 | 提取发现术语需校正 | `🔤 "清洁盆" → "清洁棚"` |

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

对每个有提取内容的项目**串行**执行：

```
For each project_id with extracted content:
  
  ① 同源检查（新增）
     - 查询该项目会议索引表，按"来源文件"字段匹配当前转写文件
     - 有匹配 → 记录已有 meeting_record_id，后续步骤改为"更新"模式
     - 无匹配 → 创建新记录
     - (避免同文件为同一项目创建多条会议索引)

  ② 创建纪要文档（修正：直接在知识库内创建，无需 move）
     - 准备内容文件（Markdown），头部标注:
       "本文档提取自多项目会议，完整会议涉及: {all_projects}"
     - 执行:
       lark-cli docs +create \
         --parent-token <wiki_01_会议纪要_node_token> \
         --doc-format markdown \
         --content @<content_file>
       ⚠️ 关键：--content 必须加 @ 前缀（--content @file.md 读取文件内容；
         不加 @ 会写入文件名文本导致文档为空）
     - 记录 doc_url
     
     ❌ 不再使用 docs +create + wiki +move 两步方式
     ❌ 不再使用 --content ./file.md（缺少 @ 前缀）
  
  ③ 写入/更新会议索引（lark-base）
     - 步骤①有匹配 → 更新已有记录（+record-upsert --record-id <existing_id>）
     - 无匹配 → 创建新记录
     - 会议主题前置: [{project_alias}]
     - 记录方式: "外部转写"
     - 来源文件: 转写文件路径
     - 纪要文档链接: 步骤②的 doc_url
     - 产出待办: 暂留空（步骤⑤回填）
     → 获取 meeting_record_id
  
  ④ 人员归属校验（v1.9.0 新增）
     - 对每个待办的负责人，检查是否在目标项目 team.members 中
     - 在成员表中 → 正常写入 / 不在 → ⚠️ 标注
     - 校验结果在确认界面展示

  ⑤ 批量写入待办（使用 batch-create）
     - 状态=待处理，优先级=提取值或 P2-一般
     - 来源 = "会议:多项目周会"
     - 所属会议 = meeting_record_id
     - 负责人字段只接受单用户：
       ✅ [{"id": "ou_xxx"}]（单用户）
       ❌ [{"id": "ou_A"}, {"id": "ou_B"}]（多用户会报错）
       多协作者场景：主负责人写入负责人字段，协作者写入备注"协作：{姓名}"
     - 去重: +record-batch-create 本身不执行去重；写入前先用 +record-list 检查已存在记录再决定
     - 用 +record-batch-create 一次写入多条：
       lark-cli base +record-batch-create \
         --base-token <base_token> \
         --table-id <todos_table_id> \
         --json '{
           "fields":["待办内容","来源","负责人","截止日期","状态","优先级","所属会议"],
           "rows":[
             ["待办1","会议:多项目周会",[{"id":"ou_xxx"}],"2026-06-25","待处理","P0-紧急",[{"id":"rec_meeting"}]],
             ["待办2","会议:多项目周会",[{"id":"ou_yyy"}],null,"待处理","P1-重要",[{"id":"rec_meeting"}]]
           ]
         }'
     ❌ 避免逐条 +record-upsert（效率低）
     → 收集 todo_record_ids（从 batch-create 返回值获取）
  
  ⑥ 批量写入里程碑（lark-base）
     - 状态=未开始
     - 同样使用 +record-batch-create
       lark-cli base +record-batch-create \
         --base-token <base_token> \
         --table-id <milestones_table_id> \
         --json '{
           "fields":["里程碑名称","描述","负责人","状态","计划日期"],
           "rows":[
             ["M1","描述",[{"id":"ou_xxx"}],"未开始","2026-06-29"],
             ["M2","描述",null,"未开始","2026-07-01"]
           ]
         }'
  
  ⑦ 回填会议索引产出待办（lark-base）
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
⏳ PIC-3.0... ✅ 纪要+9待办+2里程碑
⏳ PSD-3.0... ✅ 纪要+3待办+1里程碑
⏳ XRay...    ✅ 纪要+6待办+2里程碑
⏳ QIOA...    ✅ 更新纪要+4待办+2里程碑
```

### Step 5b：群通知推送

写入完成后，可选择向各项目群推送通知。

**标准消息模板：**
```
📋 {会议主题} · {项目名} 专题纪要
📅 {会议日期}

📄 纪要文档：{doc_url}

**关键决策**
• {决策1}
• {决策2}

**待办事项（{N}条）**
🟥 P0-紧急
• {待办}（{负责人} · {截止日期}）
🟧 P1-重要
• {待办}（{负责人} · {截止日期}）
🟨 P2-一般
• {待办}（{负责人}）

**里程碑**
• 🎯 {里程碑名称}（{目标日期}）
```

**推送命令：**
```bash
lark-cli im +messages-send --chat-id <chat_id> --markdown "<模板内容>"
```

### Step 5c：回滚模式（`--rollback`）

新增 `--rollback` 参数，用于撤销指定会议的写入：

```bash
claude pmo-cross-process --rollback <meeting_record_id1>,<meeting_record_id2>
```

**执行逻辑：**
```
前置条件：会前对目标项目的里程碑表做快照（记录当前全部记录 ID 列表）

1. 根据 meeting_record_id 查询会议索引，获取产出待办列表
2. 删除所有关联的待办记录（通过产出待办 link 字段反向定位）
3. 对比里程碑表现状与快照，删除新增的记录（里程碑表无"所属会议"link 字段，无法直接追溯）
4. 若会议索引是本次创建的 → 删除；若是更新的 → 还原旧值
5. 清理草稿缓存

> ⚠️ 回滚限制：
> - 里程碑依赖快照对比机制，若运行期间有其他操作插入了新里程碑，可能误删。
> - 还原会议索引旧值需要 Step 5③ 写入前自动将旧值序列化到草稿缓存（sourceRevisions）。
> - 若不满足以上条件，建议手动回滚。
```

### Step 6：汇总报告

```
═══════════════════════════════
📊 跨项目会议处理完成
═══════════════════════════════
会议: 多项目周会 (2026-06-17)

✅ PIC-3.0 — 纪要+9待办+2里程碑
   📄 https://feishu.cn/docx/...

✅ XRay — 纪要+6待办+2里程碑
   📄 https://feishu.cn/docx/...

✅ QIOA — 更新纪要+4待办+2里程碑
   📄 https://feishu.cn/docx/...

⏭️ RCA  — 未提取到相关内容

──────────────────────────────
⚠️ 1 条待办负责人未匹配（已在 Base 备注列标注）
💬 群通知已推送到 2 个项目群（--notify 模式）
```

`--notify` 模式启用时，在 Step 6 后自动执行 Step 5b（群通知推送）。

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
| 负责人字段含多用户报错 | 主负责人写入负责人字段，协作者信息写入备注（格式：`协作：{姓名}`） |
| 待办跨项目人员归属错误 | 提取后校验：若负责人不在该项目成员表中，标注 ⚠️ 并降级写备注 |
| 回填产出待办失败 | 记录到 `.pending_backfill/`，不影响待办数据完整性 |
| 文档创建后为空 | 检查是否使用了 `--content @file.md`（`@` 前缀），而非 `--content file.md` |
| 同源文件已有会议记录 | `--rollback` 模式可清空重写，或在确认界面提示用户选择「覆盖/跳过」 |

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
