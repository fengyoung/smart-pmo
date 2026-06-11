# 多维表格 Base 字段设计

> 对应飞书多维表格 API (bitable)，每个项目一个 Base

---

## 总览

每个项目的 PMO 管理台 Base 包含 3 张数据表，通过关联字段互相连接。

```
📊 [项目名]-PMO-管理台
├── 📋 待办事项（Todo Items）
├── 🏁 里程碑（Milestones）
└── 📝 会议记录索引（Meeting Index）
```

### 表间关联

```
会议记录索引 ──(产出待办)──→ 待办事项 ←──(关联待办)── 里程碑
     ↑                        ↑
     └──(所属会议)─────────────┘
```

---

## 表1：📋 待办事项

### 字段定义

| 字段名 | 字段类型 | 必填 | 默认值 | 说明 |
|--------|---------|------|--------|------|
| 待办ID | 自动编号 `auto_serial` | — | 格式 `TODO-001` | 系统自动生成，不可修改 |
| 待办内容 | 文本 `text` | ✅ | — | 具体的待办事项描述 |
| 负责人 | 人员 `user` | ✅ | — | 单选，从项目成员中选择 |
| 截止日期 | 日期 `date` | — | — | 格式：YYYY-MM-DD；AI 无法识别时留空，展示时高亮"截止日期待确认" |
| 状态 | 单选 `select` | ✅ | `待处理` | 选项：`待处理` / `进行中` / `已完成` / `已取消` |
| 优先级 | 单选 `select` | ✅ | `P2-一般` | 选项：`P0-紧急` / `P1-重要` / `P2-一般` / `P3-低优` |
| 所属会议 | 关联 `lookup` | — | — | 关联到「会议记录索引」表的「产出待办」字段 |
| 来源 | 文本 `text` | — | — | 标记来源：`会议:xxx` / `群聊` / `手动` / `其他` |
| 来源消息ID | 文本 `text` | — | — | 群聊来源时记录消息 ID（内部排重用）|
| 完成日期 | 日期 `date` | — | — | 标记完成时由 Skill 自动填入 |
| 备注 | 文本 `text` | — | — | 补充说明 |

### 选项定义

**状态（单选）：**
- `待处理` — 绿色
- `进行中` — 蓝色
- `已完成` — 灰色
- `已取消` — 红色

**优先级（单选）：**
- `P0-紧急` — 红色，紧急
- `P1-重要` — 橙色
- `P2-一般` — 蓝色
- `P3-低优` — 灰色

### 建议视图

| 视图名 | 筛选条件 | 排序 | 分组 |
|--------|---------|------|------|
| 📌 全部待办 | 无 | 截止日期 升序 | 状态 |
| 👤 我的待办 | 负责人=当前用户，状态≠已完成/已取消 | 截止日期 升序 | 优先级 |
| ⚠️ 已过期 | 截止日期<今天，状态≠已完成/已取消 | 截止日期 升序 | 负责人 |
| 📊 完成统计 | 无 | — | 按状态分组+计数 |

---

## 表2：🏁 里程碑

### 字段定义

| 字段名 | 字段类型 | 必填 | 默认值 | 说明 |
|--------|---------|------|--------|------|
| 里程碑ID | 自动编号 `auto_serial` | — | 格式 `MILE-001` | 系统自动生成 |
| 里程碑名称 | 文本 `text` | ✅ | — | 如：需求评审完成、Beta 版发布 |
| 计划日期 | 日期 `date` | ✅ | — | 预期完成日期 |
| 实际日期 | 日期 `date` | — | — | 实际完成日期，标记完成时由 Skill 填入 |
| 负责人 | 人员 `user` | ✅ | — | 单选 |
| 状态 | 单选 `select` | ✅ | `未开始` | 选项：`未开始` / `进行中` / `已完成` / `已延期` / `已取消` |
| 进度 | 数字 `number` | — | 0 | 0~100，百分比。Skill 更新或手动填写 |
| 关联待办 | 关联 `lookup` | — | — | 关联到「待办事项」表，标记里程碑下的关键待办 |
| 描述 | 文本 `text` | — | — | 里程碑详细说明 / 验收标准 |
| 备注 | 文本 `text` | — | — | 补充说明 |

### 选项定义

**状态（单选）：**
- `未开始` — 灰色
- `进行中` — 蓝色
- `已完成` — 绿色
- `已延期` — 红色
- `已取消` — 灰色

### 建议视图

| 视图名 | 筛选条件 | 排序 | 分组 |
|--------|---------|------|------|
| 📅 时间线 | 无 | 计划日期 升序 | 状态 |
| ⚠️ 即将到期 | 计划日期 7天内，状态≠已完成 | 计划日期 升序 | 负责人 |
| ✅ 已完成 | 状态=已完成 | 实际日期 降序 | — |

---

## 表3：📝 会议记录索引

### 字段定义

| 字段名 | 字段类型 | 必填 | 默认值 | 说明 |
|--------|---------|------|--------|------|
| 会议ID | 自动编号 `auto_serial` | — | 格式 `MEET-001` | 系统自动生成 |
| 会议主题 | 文本 `text` | ✅ | — | |
| 会议日期 | 日期 `date` | ✅ | — | 会议召开的日期 |
| 开始时间 | 日期时间 `datetime` | — | — | 精确开始时间 |
| 结束时间 | 日期时间 `datetime` | — | — | 精确结束时间 |
| 参会人 | 人员（多选） `multi_user` | — | — | 所有参会人员 |
| 记录方式 | 单选 `select` | ✅ | — | 选项：`飞书妙记` / `外部转写` / `手动记录` |
| 来源文件 | 文本 `text` | — | — | 妙记链接 URL / 本地转写文件路径 |
| 纪要文档链接 | 链接 `url` | ✅ | — | 归档到知识库后的文档链接 |
| 讨论要点摘要 | 文本 `text` | — | — | AI 自动提取的讨论要点摘要 |
| 关键决策 | 文本 `text` | — | — | AI 自动提取的决策记录（换行分隔）|
| 产出待办 | 关联 `lookup` | — | — | 关联到「待办事项」表，标记该会议产生了哪些待办 |
| 备注 | 文本 `text` | — | — | 补充说明 |

### 选项定义

**记录方式（单选）：**
- `飞书妙记` — 紫色
- `外部转写` — 橙色
- `手动记录` — 灰色

### 建议视图

| 视图名 | 筛选条件 | 排序 | 分组 |
|--------|---------|------|------|
| 📂 全部记录 | 无 | 会议日期 降序 | 记录方式 |
| 📅 本月会议 | 会议日期 本月内 | 会议日期 降序 | — |

---

## 飞书 Base API 创建参考

pmo-init 调用飞书 API 创建 Base 时，对应的 API 参数。

### 创建 Base

```bash
# shortcut
lark-cli base +base-create --name "<项目名>-PMO-管理台" --time-zone "Asia/Shanghai"
# 新建 Base 自带一张默认表"数据表"，需删除
```

### 创建知识空间

```bash
# 创建空间
lark-cli wiki spaces create --data '{"name":"<项目名> 知识空间","description":"..."}' --yes
# 创建子目录节点（obj-type 使用 wiki，创建目录容器节点，而非 docx 文档）
lark-cli wiki +node-create --space-id <space_id> --title "01-会议纪要" --obj-type wiki
lark-cli wiki +node-create --space-id <space_id> --title "02-周报" --obj-type wiki
lark-cli wiki +node-create --space-id <space_id> --title "03-需求文档" --obj-type wiki
lark-cli wiki +node-create --space-id <space_id> --title "04-设计文档" --obj-type wiki
lark-cli wiki +node-create --space-id <space_id> --title "05-项目资料" --obj-type wiki
lark-cli wiki +node-create --space-id <space_id> --title "99-归档" --obj-type wiki
# 注意：如果 lark-cli 不支持 wiki 类型，改用原生 API：
# lark-cli api POST "/open-apis/wiki/v2/spaces/<space_id>/nodes" \
#   --data '{"obj_type":"wiki","title":"01-会议纪要"}'
```

### 创建表（+table-create）

```bash
lark-cli base +table-create --base-token <token> --name "待办事项"
# 新建表自带 ID 字段(auto_number)，无需手动创建
```

### 创建字段

**快捷方式（推荐用于 text/datetime/number）：**
```bash
lark-cli base +field-create --base-token <token> --table-id <id> --json '{"name":"待办内容","type":"text"}'
lark-cli base +field-create --base-token <token> --table-id <id> --json '{"name":"截止日期","type":"datetime"}'
```

**原生 API（必须用于 select / link / user 字段）：**
```bash
# select 字段 — 快捷方式不支持 property 嵌套，需原生 API
lark-cli api POST "/open-apis/bitable/v1/apps/<token>/tables/<id>/fields" \
  --data '{"field_name":"状态","type":3,"property":{"options":[...]}}'

# link 字段 — 需指定 table_id
lark-cli api POST "/open-apis/bitable/v1/apps/<token>/tables/<id>/fields" \
  --data '{"field_name":"所属会议","type":18,"property":{"table_id":"<target_table_id>"}}'

# user 字段
lark-cli api POST "/open-apis/bitable/v1/apps/<token>/tables/<id>/fields" \
  --data '{"field_name":"负责人","type":11,"property":{}}'
```

### 字段类型对照

| 类型 | type | 快捷方式 string | 说明 |
|------|------|----------------|------|
| 文本 | 1 | `text` | 单行文本 |
| 数字 | 2 | `number` | 数字 |
| 单选 | 3 | — | 需原生 API（快捷方式不支持 property 嵌套）|
| 多选 | 4 | — | 需原生 API |
| 日期时间 | 5 | `datetime` | 快捷方式创建后 format=yyyy/MM/dd |
| 人员 | 11 | `user` | **注意：API 默认 multiple=true（多选）**，单选需在 Base UI 手动设置 |
| 自动编号 | 13 | — | +table-create 自动创建 ID 字段 |
| 链接(URL) | 15 | — | **API 不支持创建 url 类型**，需在 Base UI 手动改为链接列 |
| 关联记录 | 18 | — | 需原生 API 指定 table_id |
| 多选人员 | 22 | — | 需原生 API |

### ⚠️ 已知 API 限制

以下字段类型无法通过 API 精确创建，需 `pmo-init` 完成后在 Base UI 中手动调整：

| 字段 | 期望 | API 实际创建 | 手动调整方式 |
|------|------|-------------|-------------|
| `负责人`（待办/里程碑） | 单选人员 | **多选人员** | Base UI → 字段设置 → 取消"允许多选" |
| `纪要文档链接` | URL 链接 | **文本** | Base UI → 字段设置 → 改为链接列 |
| `关联待办` / `产出待办` | 多值关联 | **单值关联** | Base UI → 字段设置 → 允许多选 |
| `进度` | 进度条 | **数字** | Base UI → 字段设置 → 显示为进度条 |

> **建议：** pmo-init 完成后，输出手动调整清单提醒用户在 Base UI 中修正这 4 类字段。
