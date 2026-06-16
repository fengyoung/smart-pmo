---
name: pmo-todo-from-chat
version: 1.6.0
description: "从项目群聊消息中自动提取待办事项。支持多群并发读取，AI 分析提取待办，经用户确认后写入 Base 待办表。内置3层去重机制避免重复录入。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-im
    - lark-base
    - lark-contact
---

# pmo-todo-from-chat — 群聊消息提取待办

## 执行方式

```bash
# 手动从群聊提取待办
claude pmo-todo-from-chat
```

## 前置条件

1. 已通过 `pmo-use` 设置当前项目
2. 项目配置中有 `larkResources.chatIds`（至少一个群 ID）
3. `chat.readPositions[<chat_id>]` 为首次执行时自动初始化（读最近 7 天）

## 公共模式引用

### 配置加载

按 CLAUDE.md「读取当前项目配置」规则加载项目配置：

1. 优先读取环境变量 `$SMART_PMO_CURRENT`
2. 若无环境变量，读取文件 `~/.smart-pmo/current`
3. 用 project_id 加载 `~/.smart-pmo/registry/{project_id}.json`
4. 文件不存在或为空 → 提示「请先执行 pmo-use <项目名>」，中断执行
5. 检查 `schemaVersion`，执行必要的版本迁移（见 CLAUDE.md 版本迁移表）
6. 执行配置完整性校验

### 配置完整性校验

1. 必填字段检查：`project.name`、`larkResources.baseAppToken`、`larkResources.baseTableIds.todos`、`larkResources.chatIds` 不为空
2. 若任一必填字段缺失 → 提示「配置不完整，缺少: {字段列表}。建议重新运行 pmo-init 修复」

### 错误重试策略

所有 Base 写操作遵循公共错误重试策略（见 CLAUDE.md）：3 次指数退避重试（1s/3s/5s）。

### 待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)。执行开始时检查 `~/.smart-pmo/` 下的四个待处理目录。

### 日期计算

> 📅 详见 [`_shared/date-calc-rules.md`](../_shared/date-calc-rules.md)。模糊时间表达（如「尽快」「下周X」「月底」）按共享模块规则计算。

## 执行流程

### 第1步：获取项目配置和读取位置

```python
config = get_current_project_config()
chat_ids = config["larkResources"]["chatIds"]  # 支持多群，遍历全部
read_positions = config["chat"].get("readPositions", {})
```

对每个 `chat_id`，获取其读取位置（兼容旧版 schemaVersion < 1.1 的单值字段）：

```python
last_msg_id = {}
for chat_id in chat_ids:
    if chat_id in read_positions:
        pos = read_positions[chat_id]
    else:
        # 旧配置兼容：单值字段迁移到第一个 chat_id
        pos = {
            "lastReadMessageId": config.get("chat", {}).get("lastReadMessageId", ""),
            "lastReadTime":       config.get("chat", {}).get("lastReadTime", "")
        }
    last_msg_id[chat_id] = pos.get("lastReadMessageId", "")
```

### 第2步：并行读取所有群聊消息

对 `chatIds` 中的每个群**并行**调用 `lark-im` 的 `list_message`：
- 若该群 `last_msg_id` 为空 → 读取最近 7 天消息（最多 100 条）
- 若不为空 → 从 `last_msg_id` 的下一条开始增量读取

**消息过滤规则：**
- 排除系统消息（type=system）
- 排除纯表情/图片消息

保留每条消息的 `message_id` 和 `chat_id`（多群时用于结果归因和按群更新读取位置）。

### 第3步：AI 分析提取待办

分析消息内容，识别潜在待办事项：

```
语义识别模式：
1. 主动承诺型："我来处理"、"我会负责"、"这个交给我"
2. 分配任务型："XX处理一下"、"XX负责"、"交给XX"
3. 需求表达型："需要做"、"要准备"、"得安排"
4. 明确标记型：含 "TODO"、"待办"、"to-do"
```

提取要素：
| 要素 | 来源 |
|------|------|
| 待办内容 | 任务描述语句 |
| 负责人 | @提及 或 姓名识别 |
| 截止时间 | 如"这周五""下周一""尽快" |
| 优先级 | 从消息语气和关键词推断（见下方优先级推断规则） |

**优先级推断规则（从群聊消息语义推断）：** 详见 [`_shared/date-calc-rules.md`](../_shared/date-calc-rules.md) 中的优先级推断规则。

**截止时间动态计算：** 详见 [`_shared/date-calc-rules.md`](../_shared/date-calc-rules.md)，基于 `currentDate` 计算，未提及则留空并在确认界面标注 ⚠️ 截止时间未指定。

**成员名称解析（负责人字段）— 写入前必须完成验证：**

识别到姓名/@ 后，按以下顺序解析为 openId：
1. 在项目配置 `team.members` 列表中按 `name` 精确匹配 → 获得 openId 和姓名
2. 精确匹配失败 → 尝试模糊匹配（去姓/名前缀）
3. 仍匹配不到 → 通过 `lark-contact` 搜索飞书通讯录（按姓名关键词）→ 获取 `open_id` 和 `localized_name`
4. 搜索返回多个候选 → 确认界面列出候选让用户选择
5. 无结果 → 负责人字段留空，标注 `⚠️ @{姓名} 未匹配到飞书账号，请确认`

**负责人字段写入格式（⚠️ 关键）：**
写入 Base 时必须同时传 `id` 和 `name`，仅传 `id` 会触发 `1254066 UserFieldConvFail`：
```json
{"负责人": [{"id": "ou_xxx", "name": "姓名"}]}
```

**负责人写入失败降级（P1-5）：**
- 写入后验证负责人字段是否成功；若失败 → 自动将负责人姓名写入备注字段
- 记录到 `~/.smart-pmo/.pending_assignee/{project_id}.json`
- 终端提示：`⚠️ @{姓名} 写入负责人失败，已写入备注列，请在 Base 中手动分配`

### 第4步：3层去重

**L1 — 消息 ID 去重：**
- `last_msg_id` 之后的第一次读取，每条消息都是新消息
- 后续读取时，已处理的消息 ID 在 Base 中有记录 → 跳过

**L2 — 内容语义去重：**
- 新提取的待办与 Base 中已有待办做语义相似度对比
- 相似度 > 80% → 标记为"已在Base中"
- **阈值说明**：群聊消息提取使用 80%（语义不确定性更高，偏宽松避免漏提），文件批量导入使用 85%（结构化数据，偏严格去重）。这是有意设计的差异，分别适配各自的场景特征。

**L3 — 用户确认兜底：**
- 展示结果给用户，提供 3 个选项：[全部写入] [选择写入] [取消]

展示格式（多群时在来源中标注群名）：

```
📋 从群消息发现以下潜在待办
──────────────────────────
分析范围: {earliest_last_read_time} ~ {now}
分析消息: {N} 条（{群A名} {n1} 条，{群B名} {n2} 条）
提取待办: {N} 条（{N} 条已在 Base 中）

1. □ [新] {待办内容} | @{负责人} | 截止: {日期}
   → 来源: {群名} · {发言人} {时间}

2. □ [新] {待办内容} | @??? | 截止: {日期}
   ⚠️ 负责人 "李四" 未匹配到飞书账号，请确认
   → 来源: {群名} · {发言人} {时间}

3. □ [新] {待办内容} | @{负责人}
   ⚠️ 截止时间未指定

-  ⚠️ [已存在] {待办内容} | @{负责人}（不可选）

[全部写入] [选择写入] [取消]
```

**选择"选择写入"后的交互：**

```
请输入要写入的序号（逗号分隔，如 1,3 或 1-3，输入 all 全选）：
> _
```

- 输入 `1,3`：写入第1和第3条
- 输入 `1-3`：写入第1到第3条
- 输入 `all`：全部可选项写入
- "已存在"条目不占用序号、不可选
- 确认后再次展示选中列表，用户确认后执行写入

### 第5步：写入 Base

用户确认后，按以下顺序执行（保证 readPosition 的原子性）：

1. 通过 `lark-base` 将选中的待办写入「待办事项」表：
   - 来源 = "群聊:{群名}"（多群时区分来源）
   - 来源消息ID = 原始消息ID
   - 状态 = "待处理"
   - 优先级 = 根据消息语义推断（默认 P2-一般，见上方优先级推断规则）

2. **写入结果后，按群独立更新 readPosition**：

   每个群独立处理，互不影响：
   - 该群有待办写入且**全部写入成功** → 更新 `readPositions[chat_id]`：
     - `lastReadMessageId` = 该群本批消息中最后一条的 ID
     - `lastReadTime` = 当前时间 ISO 8601
   - 该群有待办写入但**部分失败** → **不更新该群 readPosition**；将失败条目的内容+来源消息ID记录到 `~/.smart-pmo/.pending_assignee/{project_id}.json`（复用现有队列），在终端标注 `⚠️ {群名} 有 {N} 条写入失败，已记录，下次自动重试`
   - 该群**全部待办写入失败** → 不更新该群 readPosition（下次执行时重读该批消息重试）
   - 该群**无选中的待办**（用户未选该群消息）→ 不更新该群 readPosition（该批消息下次继续可见）

   > **设计原则：** readPosition 只在对应群的全部选中待办均写入成功时才推进。部分失败时保留消息可见窗口，保证失败条目下次可以重试，不依赖语义去重兜底。

## 异常处理

| 场景 | 处理 |
|------|------|
| 无新消息 | 提示"自 {earliest_lastReadTime} 以来，{N} 个群均无新消息" |
| 未提取到待办 | 提示"未识别到新待办" |
| 连接失败 | 提示稍后重试 |
| 某群部分写入失败 | 不推进该群 readPosition；失败条目记录到 pending 队列，下次执行时重读重试 |
| 某群 readPosition 更新失败 | 警告提示，不影响其他群；下次执行时该群重读重试 |

## 分批读取说明

每次执行最多读取 100 条消息。消息积压时的处理：

- 每次执行从 `lastReadMessageId` 开始增量读取下一批 100 条
- 写入成功后 `lastReadMessageId` 推进到本批最后一条
- 再次执行时自动读取下一批，直到无新消息为止
- 判断是否读完：当本次读取条数 < 100 时，表示已追上最新消息
