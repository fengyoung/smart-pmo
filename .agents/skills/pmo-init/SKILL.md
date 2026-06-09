---
name: pmo-init
version: 1.0.0
description: "交互式初始化新项目：创建飞书知识空间、多维表格 Base（待办/里程碑/会议索引 3 张表）、注册项目配置。按提示收集项目信息后自动完成全部基础设施搭建。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-wiki
    - lark-base
    - lark-im
---

# pmo-init — 项目初始化

## 执行方式

```bash
# 交互式初始化新项目
claude pmo-init
```

## 前置条件

1. 用户已手动在飞书开放平台创建智能体 Bot 应用，获取到 `appId` 和 `appSecret`
2. 用户已确认要初始化的项目群聊

## 执行流程

### 第1步：交互收集项目信息

逐一提问以下信息：

| 问题 | 变量 | 说明 |
|------|------|------|
| 项目名称？ | `project_name` | 如"智能客服平台" |
| 项目代号（可选）？ | `project_alias` | 如 "ICS"；有 alias 时 registry 文件名用 alias，否则用全称 |
| 项目经理姓名和飞书账号？ | `pm_name`, `pm_open_id` | 搜索确认 open_id |
| 核心成员？ | `members` | 可添加多个，每人姓名+角色+open_id |
| 项目群？ | `chat_id` | 搜索群名确认 |
| Bot 的 appId？ | `bot_app_id` | 用户手动创建的智能体（详见 designs/bot-setup-guide.md）|
| Bot 的 appSecret？ | `bot_app_secret` | 用户手动创建的智能体 |

**文件名规则**：`project_id = alias ?: project_name`，注册文件路径为 `~/.smart-pmo/registry/{project_id}.json`

### 第2步：创建知识空间

通过 `lark-wiki` 创建独立知识空间：

```bash
# 创建空间，解析返回的 space_id
lark-cli wiki spaces create --data '{"name":"{project_name} 知识空间","description":"{project_name} 的项目文档归档空间"}' --yes
# → 记录返回值中的 space_id
```

创建 6 个子目录节点，**逐条执行并记录每个节点返回的 node_token**：

```bash
# 每条命令执行后解析输出中的 node_token 字段
lark-cli wiki +node-create --space-id {space_id} --title "01-会议纪要" --obj-type wiki
# → 记录 node_token_1

lark-cli wiki +node-create --space-id {space_id} --title "02-周报" --obj-type wiki
# → 记录 node_token_2

lark-cli wiki +node-create --space-id {space_id} --title "03-需求文档" --obj-type wiki
# → 记录 node_token_3

lark-cli wiki +node-create --space-id {space_id} --title "04-设计文档" --obj-type wiki
# → 记录 node_token_4

lark-cli wiki +node-create --space-id {space_id} --title "05-项目资料" --obj-type wiki
# → 记录 node_token_5

lark-cli wiki +node-create --space-id {space_id} --title "99-归档" --obj-type wiki
# → 记录 node_token_6

# 若 +node-create 不支持 obj-type wiki，改用原生 API：
# lark-cli api POST "/open-apis/wiki/v2/spaces/{space_id}/nodes" \
#   --data '{"obj_type":"wiki","title":"01-会议纪要"}'
# → 从返回 JSON 的 data.node.node_token 字段读取
```

**注意**：每条命令的返回 JSON 中包含 `node_token` 字段，需逐一提取保存，用于第4步写入 `wikiNodeTokens`。如果命令返回为空，则通过 `lark-cli wiki +node-list --space-id {space_id}` 查询已创建节点列表获取 token。

### 第3步：创建多维表格 Base

通过 `lark-base` 创建 Base：

```bash
# 创建 Base（自带一张默认"数据表"）
lark-cli base +base-create --name "{project_name}-PMO-管理台" --time-zone "Asia/Shanghai"
```

**在 Base 中创建 3 张表：**
```bash
lark-cli base +table-create --base-token {token} --name "待办事项"
lark-cli base +table-create --base-token {token} --name "里程碑"
lark-cli base +table-create --base-token {token} --name "会议记录索引"
```

**删除默认"数据表"：**（最后一张表不可删，先建新表再删默认表）
```bash
lark-cli base +table-delete --base-token {token} --table-id {default_table_id} --yes
```

**逐表添加字段：**
- text/datetime/number → 用快捷方式 `+field-create --json`
- select → 必须用原生 API（快捷方式不支持 `property` 嵌套）
- link → 必须用原生 API（需指定 `property.table_id`）
- user → 原生 API 创建（API 默认 `multiple=true`，需在 Base UI 手动改为单选）

实际创建时的字段：

**表1：待办事项**

| 字段名 | 类型 | 配置 |
|--------|------|------|
| 待办ID | 自动编号 | 格式 TODO-001 |
| 待办内容 | 文本 | 必填 |
| 负责人 | 人员 | 必填，单选 |
| 截止日期 | 日期 | 必填，格式 YYYY-MM-DD |
| 状态 | 单选 | 选项：待处理/进行中/已完成/已取消，默认待处理 |
| 优先级 | 单选 | 选项：P0-紧急/P1-重要/P2-一般/P3-低优，默认 P2-一般 |
| 所属会议 | 关联 | 关联会议记录索引表 |
| 来源 | 文本 | |
| 来源消息ID | 文本 | |
| 完成日期 | 日期 | |
| 备注 | 文本 | |

**表2：里程碑**

| 字段名 | 类型 | 配置 |
|--------|------|------|
| 里程碑ID | 自动编号 | 格式 MILE-001 |
| 里程碑名称 | 文本 | 必填 |
| 计划日期 | 日期 | 必填 |
| 实际日期 | 日期 | |
| 负责人 | 人员 | 必填，单选 |
| 状态 | 单选 | 选项：未开始/进行中/已完成/已延期/已取消，默认未开始 |
| 进度 | 数字 | 0~100 |
| 关联待办 | 关联 | 关联待办事项表 |
| 描述 | 文本 | |
| 备注 | 文本 | |

**表3：会议记录索引**

| 字段名 | 类型 | 配置 |
|--------|------|------|
| 会议ID | 自动编号 | 格式 MEET-001 |
| 会议主题 | 文本 | 必填 |
| 会议日期 | 日期 | 必填 |
| 开始时间 | 日期时间 | |
| 结束时间 | 日期时间 | |
| 参会人 | 人员（多选）| |
| 记录方式 | 单选 | 选项：飞书妙记/外部转写/手动记录 |
| 来源文件 | 文本 | |
| 纪要文档链接 | 链接 | 必填 |
| 讨论要点摘要 | 文本 | |
| 关键决策 | 文本 | |
| 产出待办 | 关联 | 关联待办事项表 |
| 备注 | 文本 | |

创建完成后建立表间关联：
- 待办事项.所属会议 → 会议记录索引
- 里程碑.关联待办 → 待办事项
- 会议记录索引.产出待办 → 待办事项

### 第4步：注册项目配置

**① 将 appSecret 写入 macOS Keychain：**

```bash
security add-generic-password -s "smart-pmo-{project_alias}-bot" -a smart-pmo -w "{bot_app_secret}" -U
```

**② 写入 `~/.smart-pmo/registry/{project_name}.json`：**

```json
{
  "project": {
    "name": "{project_name}",
    "alias": "{project_alias}",
    "createdDate": "{today}",
    "status": "active"
  },
  "team": {
    "pm": { "name": "{pm_name}", "openId": "{pm_open_id}" },
    "members": [...]
  },
  "larkResources": {
    "wikiSpaceId": "{space_id}",
    "wikiNodeTokens": {
      "01-会议纪要": "{node_token_1}",
      "02-周报": "{node_token_2}",
      "03-需求文档": "{node_token_3}",
      "04-设计文档": "{node_token_4}",
      "05-项目资料": "{node_token_5}",
      "99-归档": "{node_token_6}"
    },
    "baseAppToken": "{base_token}",
    "baseTableIds": {
      "todos": "{todo_table_id}",
      "milestones": "{milestone_table_id}",
      "meetingIndex": "{meeting_table_id}"
    },
    "chatIds": ["{chat_id}"],
    "bot": {
      "appId": "{bot_app_id}",
      "appSecret": "@keychain:smart-pmo-{project_alias}-bot",
      "name": "{project_name}-PMO-Bot"
    }
  },
  "chat": {
    "lastReadMessageId": "",
    "lastReadTime": ""
  }
}
```

### 第5步：设置当前项目

```bash
# 写入 ~/.smart-pmo/current（写入 project_id，即 alias 或全称）
echo "{project_id}" > ~/.smart-pmo/current
```

### 第6步：初始化群消息读取位置

通过 `lark-im` 获取项目群当前最新消息 ID，写入配置：

```
lark-cli im +latest-message-id --chat-id {chat_id}
→ 更新 registry JSON 中:
  chat.lastReadMessageId = <最新消息ID>
  chat.lastReadTime      = <当前时间 ISO 8601>
```

**目的**：让 `pmo-todo-from-chat` 首次执行时只处理此刻之后的新消息，避免翻取历史群聊。
如果获取失败，`lastReadMessageId` 保持为空（首次执行时读最近 7 天）。

### 第7步：推送到项目群

通过 `lark-im` 发送卡片消息到项目群，通知初始化完成，包含：
- 项目名称和成员
- PMO 管理台 Base 链接
- 知识空间链接
- 快速上手指引

### 第8步：提示手动调整清单（API 限制）

由于飞书 bitable API 的部分限制，以下 4 个字段需要在 Base UI 中手动调整：

```
⚠️ 请在 Base UI 中手动调整以下字段：

┌─────────────────────┬──────────────┬───────────────────┐
│ 表       │ 字段          │ 调整操作             │
├─────────────────────┼──────────────┼───────────────────┤
│ 待办事项  │ 负责人        │ 取消"允许多选"        │
│ 里程碑    │ 负责人        │ 取消"允许多选"        │
│ 里程碑    │ 进度          │ 显示格式改为"进度条"    │
│ 会议索引  │ 纪要文档链接   │ 字段类型改为"链接"     │
│ 全部关联字段│ 关联待办/产出待办 │ 开启"允许多选"      │
└─────────────────────┴──────────────┴───────────────────┘

Base 链接：https://zhuanspirit.feishu.cn/base/{base_token}
```

## 异常处理

| 场景 | 处理方式 |
|------|---------|
| 项目名已注册 | 询问是否覆盖，如否则中断 |
| 知识空间创建失败 | 提示手动创建，提供指引 |
| Base 创建失败 | 提示手动创建 |
| 用户中途退出 | 已创建资源不清理，提示可重试 |
