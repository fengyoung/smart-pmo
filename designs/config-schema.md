# 配置 Schema 设计

> 定义 `~/.smart-pmo/` 下所有配置文件的 JSON 结构

---

## 文件结构

```
~/.smart-pmo/
├── registry/
│   ├── <project-name>.json        # 项目配置
│   └── ...
├── current                        # 当前项目（纯文本，仅含项目名）
└── pinned                         # 关注项目列表（纯文本，每行一个项目名）
```

---

## 配置项：项目配置 `registry/<project>.json`

```json
{
  "$schema": "smart-pmo/project-config-v1",

  "project": {
    "name": "string (必填) — 项目名称",
    "alias": "string (可选) — 项目代号 / 缩写",
    "createdDate": "string (必填) — 格式 YYYY-MM-DD，初始化日期",
    "status": "string (必填) — 可选值: active | archived"
  },

  "team": {
    "pm": {
      "name": "string (必填) — 项目经理姓名",
      "openId": "string (必填) — 飞书 Open ID"
    },
    "members": [
      {
        "name": "string (必填) — 成员姓名",
        "openId": "string (必填) — 飞书 Open ID",
        "role": "string (必填) — 角色，如 开发 / 产品 / 设计 / 测试 / 运维"
      }
    ]
  },

  "larkResources": {
    "wikiSpaceId": "string (必填) — 飞书知识空间 ID",
    "baseAppToken": "string (必填) — 多维表格 App Token",
    "baseTableIds": {
      "todos": "string (必填) — 待办事项 表 ID",
      "milestones": "string (必填) — 里程碑 表 ID",
      "meetingIndex": "string (必填) — 会议记录索引 表 ID"
    },
    "chatIds": ["string — 项目群 ID，至少填1个"],
    "bot": {
      "appId": "string (必填) — 飞书自建应用 App ID",
      "appSecret": "string (必填) — 飞书自建应用 App Secret",
      "name": "string (可选) — Bot 名称"
    }
  },

  "archive": {
    "directoryStructure": [
      "01-会议纪要",
      "02-周报",
      "03-需求文档",
      "04-设计文档",
      "05-项目资料",
      "99-归档"
    ]
  },

  "chat": {
    "lastReadMessageId": "string (可选) — 上次群消息读取位置，初始为空",
    "lastReadTime": "string (可选) — 格式 YYYY-MM-DDTHH:mm:ss，初始为空"
  }
}
```

### 示例文件

```json
{
  "project": {
    "name": "智能客服平台",
    "alias": "ICS",
    "createdDate": "2026-06-09",
    "status": "active"
  },
  "team": {
    "pm": {
      "name": "张三",
      "openId": "ou_abc123"
    },
    "members": [
      { "name": "李四", "openId": "ou_def456", "role": "开发" },
      { "name": "王五", "openId": "ou_ghi789", "role": "产品" },
      { "name": "赵六", "openId": "ou_jkl012", "role": "设计" }
    ]
  },
  "larkResources": {
    "wikiSpaceId": "ss_abc123",
    "baseAppToken": "bas_abc123",
    "baseTableIds": {
      "todos": "tbl_todo_001",
      "milestones": "tbl_mile_001",
      "meetingIndex": "tbl_meet_001"
    },
    "chatIds": ["oc_chat_001"],
    "bot": {
      "appId": "cli_abc123",
      "appSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxx",
      "name": "ICS-PMO-Bot"
    }
  },
  "archive": {
    "directoryStructure": [
      "01-会议纪要",
      "02-周报",
      "03-需求文档",
      "04-设计文档",
      "05-项目资料",
      "99-归档"
    ]
  },
  "chat": {
    "lastReadMessageId": "",
    "lastReadTime": ""
  }
}
```

---

## 配置项：当前项目 `current`

纯文本文件，内容仅为当前选中的项目名称，与 `registry/<name>.json` 的文件名（不含后缀）对应。

```
smart-customer-platform
```

---

## 配置项：关注项目列表 `pinned`

纯文本文件，每行一个项目名。为空时表示暂未关注任何项目。

```
smart-customer-platform
data-platform-v2
```

---

## Skill 读取配置的规则

所有 Skill 在启动时通过以下逻辑获取当前项目配置：

```
function getCurrentProjectConfig():
    1. 检查环境变量 $SMART_PMO_CURRENT
       - 如果存在且非空 → 使用该值作为当前项目名
    2. 回退到文件 ~/.smart-pmo/current
       - 读取文件内容作为项目名
    3. 从 ~/.smart-pmo/registry/<项目名>.json 读取完整配置
    4. 如果以上步骤失败 → 提示用户 "请先执行 pmo-use <项目名> 设置当前项目"
```

### 环境变量优先级

环境变量 > 文件（用于多终端隔离场景）：

```
# 终端 1
export SMART_PMO_CURRENT=project-a
claude
> pmo-todo-followup          # → 操作 project-a

# 终端 2
export SMART_PMO_CURRENT=project-b
claude
> pmo-todo-followup          # → 操作 project-b
```

### pmo-use 命令对配置的修改

`pmo-use <项目名> [-g]`：
- 默认行为：仅设置 `$SMART_PMO_CURRENT` 环境变量（当前会话有效）
- `-g` 标志：同时写入 `~/.smart-pmo/current` 文件（全局持久化）
- 使用前会校验 `<项目名>.json` 是否存在，不存在则提示
