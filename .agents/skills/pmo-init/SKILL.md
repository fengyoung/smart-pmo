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
| 项目代号（可选）？ | `project_alias` | 如 "ICS" |
| 项目经理姓名和飞书账号？ | `pm_name`, `pm_open_id` | 搜索确认 open_id |
| 核心成员？ | `members` | 可添加多个，每人姓名+角色+open_id |
| 项目群？ | `chat_id` | 搜索群名确认 |
| Bot 的 appId？ | `bot_app_id` | 用户手动创建的智能体 |
| Bot 的 appSecret？ | `bot_app_secret` | 用户手动创建的智能体 |

收集完毕后展示摘要，请求用户确认。

### 第2步：创建知识空间

通过 `lark-wiki` 创建独立知识空间：

```
空间名称：{project_name} 知识空间
```

创建后在空间中建立 6 个目录：
- `01-会议纪要/`
- `02-周报/`
- `03-需求文档/`
- `04-设计文档/`
- `05-项目资料/`
- `99-归档/`

### 第3步：创建多维表格 Base

通过 `lark-base` 创建 Base：

```
Base 名称：{project_name}-PMO-管理台
```

在 Base 中创建 3 张表：

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

写入 `~/.smart-pmo/registry/{project_name}.json`，包含所有收集到的信息和飞书资源 ID。

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
    "baseAppToken": "{base_token}",
    "baseTableIds": {
      "todos": "{todo_table_id}",
      "milestones": "{milestone_table_id}",
      "meetingIndex": "{meeting_table_id}"
    },
    "chatIds": ["{chat_id}"],
    "bot": {
      "appId": "{bot_app_id}",
      "appSecret": "{bot_app_secret}",
      "name": "{project_name}-PMO-Bot"
    }
  },
  "archive": {
    "directoryStructure": [
      "01-会议纪要", "02-周报", "03-需求文档",
      "04-设计文档", "05-项目资料", "99-归档"
    ]
  },
  "chat": {
    "lastReadMessageId": "",
    "lastReadTime": ""
  }
}
```

### 第5步：设置当前项目

```bash
# 写入 ~/.smart-pmo/current
echo "{project_name}" > ~/.smart-pmo/current
```

### 第6步：推送到项目群

通过 `lark-im` 发送卡片消息到项目群，通知初始化完成，包含：
- 项目名称和成员
- PMO 管理台 Base 链接
- 知识空间链接
- 快速上手指引

## 异常处理

| 场景 | 处理方式 |
|------|---------|
| 项目名已注册 | 询问是否覆盖，如否则中断 |
| 知识空间创建失败 | 提示手动创建，提供指引 |
| Base 创建失败 | 提示手动创建 |
| 用户中途退出 | 已创建资源不清理，提示可重试 |
