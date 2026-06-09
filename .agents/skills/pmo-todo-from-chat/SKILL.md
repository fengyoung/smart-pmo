---
name: pmo-todo-from-chat
version: 1.0.0
description: "从项目群聊消息中自动提取待办事项。读取群聊未处理消息，AI 分析提取待办，经用户确认后写入 Base 待办表。内置3层去重机制避免重复录入。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-im
    - lark-base
---

# pmo-todo-from-chat — 群聊消息提取待办

## 执行方式

```bash
# 手动从群聊提取待办
claude pmo-todo-from-chat
```

## 前置条件

1. 已通过 `pmo-use` 设置当前项目
2. 项目配置中已有 `chat.lastReadMessageId`（首次执行为空）

## 执行流程

### 第1步：获取项目配置和读取位置

```python
config = get_current_project_config()
chat_id = config["larkResources"]["chatIds"][0]
last_msg_id = config["chat"]["lastReadMessageId"]  # 可能为空
last_read_time = config["chat"]["lastReadTime"]     # 可能为空
```

### 第2步：读取群聊消息

通过 `lark-im` 调用 `list_message`:
- 如果 `last_msg_id` 为空 → 读取最近 7 天的消息（最多 100 条）
- 如果不为空 → 从 `last_msg_id` 的下一条开始增量读取

**消息过滤规则：**
- 排除系统消息（type=system）
- 排除 Bot 自己发出的消息
- 排除 @Bot 的指令类消息（如 /todo, /overdue 等）
- 排除纯表情/图片消息

保留每条消息的 `message_id` 用于排重。

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

### 第4步：3层去重

**L1 — 消息 ID 去重：**
- `last_msg_id` 之后的第一次读取，每条消息都是新消息
- 后续读取时，已处理的消息 ID 在 Base 中有记录 → 跳过

**L2 — 内容语义去重：**
- 新提取的待办与 Base 中已有待办做语义相似度对比
- 相似度 > 80% → 标记为"已在Base中"

**L3 — 用户确认兜底：**
- 展示结果给用户，提供 3 个选项：[全部写入] [选择写入] [取消]

展示格式：

```
📋 从群消息发现以下潜在待办
──────────────────────────
分析范围: {last_read_time} ~ {now}
分析消息: {N} 条
提取待办: {N} 条（{N} 条已在 Base 中）

□ [新] {待办内容} | @{负责人} | 截止: {日期}
   → 来源: {发言人} {时间}

□ [新] {待办内容} | @{负责人}
   ⚠️ 截止时间未指定

⚠️ [已存在] {待办内容} | @{负责人}
   → 已在待办列表中，跳过

[全部写入] [选择写入] [取消]
```

### 第5步：写入 Base

用户确认后：
1. 通过 `lark-base` 将选中的待办写入「待办事项」表
   - 来源 = "群聊"
   - 来源消息ID = 原始消息ID
   - 状态 = "待处理"
   - 优先级 = "P2-一般"

2. 更新配置中的 `lastReadMessageId` 和 `lastReadTime`

### 第6步：推送反馈

通过 `lark-im` 推送群消息：

```
已从群消息提取 {N} 条待办并录入 Base
```

## 设计文档

完整规格见：`../../designs/skill-specs/pmo-todo-from-chat.md`

## 异常处理

| 场景 | 处理 |
|------|------|
| 无新消息 | 提示"自 {lastReadTime} 以来无新消息" |
| 未提取到待办 | 提示"未识别到新待办" |
| 连接失败 | 提示稍后重试 |
