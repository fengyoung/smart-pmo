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
  "$schema": "https://github.com/fengyoung/smart-pmo/schemas/project-config-v1.json",
  "schemaVersion": "1.1",

  "project": {
    "name": "string (必填) — 项目名称",
    "alias": "string (可选) — 项目代号 / 缩写",
    "createdDate": "string (必填) — 格式 YYYY-MM-DD，初始化日期",
    "lastModified": "string (可选) — 格式 ISO 8601，最后修改时间",
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
    "wikiNodeTokens": {
      "01-会议纪要": "string (必填) — 目录节点 token",
      "02-周报": "string (必填) — 目录节点 token",
      "03-需求文档": "string (必填) — 目录节点 token",
      "04-设计文档": "string (必填) — 目录节点 token",
      "05-项目资料": "string (必填) — 目录节点 token",
      "99-归档": "string (必填) — 目录节点 token"
    },
    "baseAppToken": "string (必填) — 多维表格 App Token",
    "baseUrl": "string (可选) — 多维表格访问链接",
    "wikiUrl": "string (可选) — 知识空间访问链接",
    "baseTableIds": {
      "todos": "string (必填) — 待办事项 表 ID",
      "milestones": "string (必填) — 里程碑 表 ID",
      "meetingIndex": "string (必填) — 会议记录索引 表 ID"
    },
    "chatIds": ["string — 项目群 ID，至少填1个"]
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
  "schemaVersion": "1.1",
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
    "chatIds": ["oc_chat_001"]
  },
  "chat": {
    "lastReadMessageId": "",
    "lastReadTime": ""
  }
}
```

---

## 项目标识符规则（alias vs 全称）

**registry 文件名**：统一使用 `alias`（如有），否则使用项目全称。文件名即项目标识符（project_id）。

```
~/.smart-pmo/registry/
├── XRay.json          ← alias 为 XRay
├── ICS.json           ← alias 为 ICS
└── 数据平台V2.json    ← 无 alias，用全称
```

**`current` 和 `pinned` 文件**：存储 project_id（即文件名不含后缀），与文件名保持一致。

**`pmo-use` 输入匹配规则**：
- 支持输入 alias 或全称，任意一种都能找到对应项目
- 匹配逻辑：先按文件名（alias）精确匹配，找不到再遍历所有 registry JSON 按 `project.name` 全称匹配

**`pmo-init` 创建规则**：
- 如果用户提供了 alias → 文件名用 alias
- 没有提供 alias → 文件名用项目全称

---

## 配置项：当前项目 `current`

纯文本文件，内容为 project_id（registry 文件名不含后缀），即 alias 或全称。

```
XRay
```

---

## 配置项：关注项目列表 `pinned`

纯文本文件，每行一个 project_id（与 `current` 格式相同）。

```
XRay
ICS
```

---

## Skill 读取配置的规则

```
function getCurrentProjectConfig():
    1. 读取 ~/.smart-pmo/current 文件，获取项目名
    2. 从 ~/.smart-pmo/registry/<项目名>.json 读取完整配置
    3. 如果文件不存在或为空 → 提示用户 "请先执行 pmo-use <项目名> 设置当前项目"
```

### pmo-use 命令对配置的修改

`pmo-use <项目名>`：写入 `~/.smart-pmo/current` 文件（全局持久化，所有终端生效）

`pmo-use <项目名> --archive`：将 registry JSON 中 `project.status` 改为 `archived`

`pmo-use <项目名> --activate`：将 registry JSON 中 `project.status` 改为 `active`

---

## 当前操作者 openId 的获取规则

所有需要"当前用户"身份的操作（如 `--mine`、`--add-member` 中的自己、里程碑负责人默认值等），通过以下方式获取当前登录用户的 openId：

```
function getCurrentUserOpenId():
    1. 通过 lark-contact 调用"获取当前用户信息"接口
       lark-cli contact +me
    2. 返回当前飞书登录用户的 openId
    3. 如调用失败 → 提示"无法获取当前用户信息，请检查飞书 CLI 登录状态"
```

**依赖声明**：所有使用 `--mine` 或涉及"当前用户"的 Skill，必须在 frontmatter `depends_on` 中声明 `lark-contact`。

涉及的 Skill：`pmo-todo-followup`、`pmo-milestone`、`pmo-use`（--add-member 时搜索成员）
