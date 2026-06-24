# pmo-cross-process v2 改进方案

> 基于 2026-06-24 实战矫正总结

---

## 问题清单与修复方案

### 🚨 P0 — 阻断性问题

| # | 问题 | 现象 | 根因 | 修复 |
|---|------|------|------|------|
| 1 | **文档创建为空** | 用户打开飞书文档显示"Untitled"/空内容 | `docs +create --content ./file.md` 传的是**文件名文本**而非文件内容 | 必须用 `--content @./file.md`（`@` 前缀读取文件） |
| 2 | **文档未直接在知识库内创建** | 需先创建再 `wiki +move`，导致标题丢失、产生"Untitled"节点 | 先用 `docs +create` 再 `wiki +move` 两步 | 用 `docs +create --parent-token <wiki_node>` 直接在知识库内创建 |
| 3 | **同源文件重复记录** | QIOA 项目已有同一会议索引记录（NO.002），但未检测到 | 未检查该项目的会议索引表是否已有同 `来源文件` 的记录 | Step 5 前先 `record-search` 检查同源记录，存在则更新而非创建 |

### ⚠️ P1 — 数据正确性问题

| # | 问题 | 现象 | 根因 | 修复 |
|---|------|------|------|------|
| 4 | **负责人字段写入多用户报错** | `[{"id":"ou_A"},{"id":"ou_B"}]` 被 API 拒绝 | Base 负责人（user 类型）字段只接受**单用户** | 主负责人写入负责人字段，协作者写入备注（格式：`协作：{姓名}`） |
| 5 | **待办跨项目人员归属错误** | XRay 待办的负责人是李玥霖、陈鹏，但他们在 XRay 项目中不存在 | AI 提取时未按项目成员表校验负责人 | 提取后校验：若负责人不在该项目成员表，降级写备注 + 标注 ⚠️ |

### 📝 P2 — 效率与流程问题

| # | 问题 | 现象 | 根因 | 修复 |
|---|------|------|------|------|
| 6 | **待办逐条写入** | 9 条待办用了 9 次 `+record-upsert` | 未使用批量接口 | 用 `+record-batch-create` 一次写入 |
| 7 | **术语发现无反馈闭环** | 用户单独提出"清洁盆→清洁棚"需手动更新 ASR 校正表 | 提取中发现的术语问题未自动进入 ASR 校正反馈流程 | 术语修正应作为候选 ASR 校正项在确认界面展示并自动追加 |
| 8 | **无标准回滚流程** | 用户要求撤销时只能手动逐条 `+record-delete` | 未提供批量回滚能力 | 提供 `--rollback` 参数，传入之前的 meeting_record_id 列表即可批量删除 |
| 9 | **群通知无规范模板** | 通知内容和格式每人不一致 | 缺乏标准消息模板 | 定义标准飞书消息模板（见下文） |

---

## 修正后的 Step 5 流程

### Step 5①：创建纪要文档（修正版）

```bash
# ✅ 正确方式：直接在知识库内创建
# 准备内容文件
cat > /tmp/doc_content.md << 'EOF'
# {YYYYMMDD}-软硬一体周会-{project_alias}专题

> 📌 本文档提取自多项目会议，完整会议涉及：{all_projects}

{项目纪要内容}
EOF

# 创建文档（--parent-token 直接指定知识库节点，@ 前缀读取文件）
lark-cli docs +create \
  --parent-token <wiki_01_会议纪要_node_token> \
  --doc-format markdown \
  --content @/tmp/doc_content.md
# 注意：--content 传文件路径时必须加 @ 前缀
# ❌ --content ./file.md  → 写入的是文件名文本
# ✅ --content @./file.md → 读取文件内容写入
```

### Step 5③：同源检查（新增）

```bash
# 写入会议索引前，先检查是否已有同来源文件的记录
lark-cli base +record-list \
  --base-token <base_token> \
  --table-id <meetingIndex_table_id> \
  --filter-json '{"field_id":"来源文件","operator":"is","value":["<source_file_path>"]}'

# 已有记录 → +record-upsert --record-id <existing_id>
# 无记录   → +record-upsert（不传 --record-id 创建新记录）
```

### Step 5④：批量写入待办（修正版）

```bash
# ✅ 用 batch-create 一次写入多条待办
# ❌ 避免逐条 record-upsert
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
```

### Step 5⑤：写入里程碑（同批次原则）

```bash
# 同一批次写入，避免逐条
lark-cli base +record-batch-create \
  --base-token <base_token> \
  --table-id <milestones_table_id> \
  --json '{
    "fields":["里程碑名称","描述","负责人","状态","计划日期"],
    "rows":[
      ["里程碑1","描述1",[{"id":"ou_xxx"}],"未开始","2026-06-29"],
      ["里程碑2","描述2",null,"未开始","2026-07-01"]
    ]
  }'
```

### Step 5⑥：回填产出待办（新增报错信息）

```bash
# 收集 batch-create 返回的 record_id_list
# 统一回填到会议索引的产出待办字段
lark-cli base +record-upsert \
  --base-token <base_token> \
  --table-id <meetingIndex_table_id> \
  --record-id <meeting_record_id> \
  --json '{"产出待办":[{"id":"rec_todo1"},{"id":"rec_todo2"},...]}'
```

---

## 群消息通知模板

```markdown
📋 **{会议主题} · {项目名} 专题纪要**
📅 {会议日期}

📄 纪要文档：{doc_url}

**关键决策**
• {决策1}
• {决策2}

**待办事项（{N}条）**
🟥 P0-紧急
• {待办内容}（{负责人} · {截止日期}）
🟧 P1-重要
• {待办内容}（{负责人} · {截止日期}）
🟨 P2-一般
• {待办内容}（{负责人}）

**里程碑**
• 🎯 {里程碑名称}（{目标日期}）
```

---

## 回滚流程（新增 `--rollback` 模式）

```bash
# 撤销某个会议的写入（基于 meeting_record_id）
# 1. 查询会议索引获取产出待办列表
# 2. 删除所有待办
# 3. 删除所有里程碑
# 4. 删除或还原会议索引

# 提供 --rollback 参数简化操作
claude pmo-cross-process --rollback <meeting_record_id>
```

---

## SKILL.md 待修改章节清单

| 章节 | 修改类型 | 修改内容 |
|------|---------|---------|
| Step 5① | **重写** | 创建文档改为 `--parent-token` 直接创建 + `--content @file` 读取内容 |
| Step 5② | **删除** | 不再需要单独的 `wiki +move` 步骤 |
| Step 5③ | **增强** | 新增"同源检查"前置逻辑 |
| Step 5④ | **重写** | 逐条 `record-upsert` → `record-batch-create` |
| Step 5⑤ | **重写** | 同上，批量创建 |
| Step 5⑥ | **保留** | 逻辑不变，补充 record_id 收集方式 |
| Step 6 | **增强** | 补充群通知模板和回滚说明 |
| 新增 | **新增** | `--rollback` 参数说明 |
| 新增 | **新增** | 负责人字段单用户限制说明 |

---

## 版本号建议

当前版本 v1.8.0，建议本次改进作为 **v1.9.0** 发布，因为涉及 Step 5 的全流程重写（Breaking change in procedure）。
