---
name: pmo-search
version: 1.3.0
description: "跨表跨项目搜索。支持在待办事项、里程碑、会议记录三张表中按关键词检索，返回匹配条目并附 Base 记录直达链接。已集成到 pmo-todo-followup、pmo-dashboard、pmo-info 的操作提示中。支持 --limit 控制结果数量。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-doc
    - lark-wiki
---

# pmo-search — 跨表搜索

## 执行方式

```bash
# 在当前项目搜索
claude pmo-search <关键词>

# 指定搜索范围（表）
claude pmo-search <关键词> --in todos
claude pmo-search <关键词> --in milestones
claude pmo-search <关键词> --in meetings
claude pmo-search <关键词> --in todos,meetings

# 跨所有关注项目搜索
claude pmo-search <关键词> --all

# 搜索知识库文档正文（会议纪要、周报等）
claude pmo-search <关键词> --in docs

# 限定时间范围
claude pmo-search <关键词> --since 2026-05-01
claude pmo-search <关键词> --since 2026-05-01 --until 2026-06-01

# 限定负责人
claude pmo-search <关键词> --owner @张三

# 限制每表返回条数（默认 20，可调整至 50/100）
claude pmo-search <关键词> --limit 50
```

## 前置条件

已通过 `pmo-use` 设置当前项目（`--all` 模式不需要）。

## 执行流程

### 公共：待处理队列检查

执行前先检查以下目录（按 CLAUDE.md 公共约定）：

| 目录 | 用途 | 处理方式 |
|------|------|---------|
| `~/.smart-pmo/.pending_backfill/` | 会议索引产出待办回填失败 | 自动重试回填，成功删文件；重试耗尽见 CLAUDE.md 人工介入出口 |
| `~/.smart-pmo/.pending_orphan_meeting/` | 孤立会议记录（步骤②成功+步骤③全部失败）| 提示用户执行 `--index-only` 补录 |
| `~/.smart-pmo/.pending_assignee/` | 负责人 API 写入失败 | 提示用户存在待分配记录 |
| `~/.smart-pmo/.draft/` | 用户取消的解析草稿 | 提示用户存在缓存草稿 |

过期清理规则见 CLAUDE.md「待处理队列过期清理规则」。

### 配置加载（非 --all 模式）

1. 按 CLAUDE.md「读取当前项目配置」规则加载项目配置
2. 检查 `schemaVersion`，执行必要的版本迁移
3. `--all` 模式：遍历 pinned 项目（或所有 active 项目），对每个项目加载并校验配置

### 第1步：解析搜索参数

```
keyword   = 用户输入的关键词（支持中文）
scope     = --in 参数（默认：todos,milestones,meetings 全部）
projects  = --all 时遍历所有 active 项目；否则仅当前项目
time_from = --since（可选）
time_to   = --until（可选）
owner     = --owner 解析后的 openId（可选）
```

### 第2步：并行查询各表

对每个目标项目的每个目标表，通过 `lark-base` 执行关键词过滤查询：

**待办事项表（todos）：**
- 匹配字段：待办内容、来源、备注
- 附加过滤：--owner → 负责人字段；--since/--until → 截止日期或创建时间

**里程碑表（milestones）：**
- 匹配字段：里程碑名称、描述、备注
- 附加过滤：--owner → 负责人字段；--since/--until → 计划日期

**会议记录索引表（meetings）：**
- 匹配字段：会议主题、讨论要点摘要、关键决策
- 附加过滤：--since/--until → 会议日期

**知识库文档（docs，仅当 --in docs 时）：**
- 通过 `lark-wiki` 遍历项目知识库中 `01-会议纪要/` 和 `02-周报/` 目录下的文档
- 对每个文档通过 `lark-doc` 读取正文内容，关键词匹配
- 返回格式：文档标题 + 匹配摘要 + Wiki 链接
- 单目录最多搜索 20 个文档，合并结果按匹配度排序
- 超过 3 个文档时并行读取正文（提高效率）

每张表最多返回 `--limit` 指定的条数（默认 20，最大 100，按相关性/时间倒序）。

**超限提示：** 查询结果达到 `--limit` 上限时，在结果底部显示：
```
  ── 仅显示前 {limit} 条，共 {total} 条匹配 ──
  使用 --limit 50 查看更多，或缩小关键词 / 时间范围
```

### 第3步：语义相关性排序

对每条结果计算与关键词的相关度（关键词在哪个字段出现、出现次数），按相关度从高到低排序。跨表结果合并后统一排序。

### 第4步：构造 Base 记录直达链接

每条搜索结果，根据 CLAUDE.md「Base 记录 URL 构造规则」生成可点击跳转链接：

```
记录链接 = https://bytedance.larkoffice.com/base/{baseAppToken}/table/{tableId}/record/{record_id}
```

- 待办结果：链接指向待办事项表对应记录
- 里程碑结果：链接指向里程碑表对应记录
- 会议结果：若有纪要文档链接（doc_url）则展示文档链接；同时展示会议索引表记录链接

### 第5步：展示结果

```
🔍 搜索 "{keyword}" — {总结果数} 条
══════════════════════════════════════
项目：{项目名}（--all 模式下按项目分组）

── 待办事项（{N} 条）──
#1 [TODO-012] 接口设计方案评审
   负责人：张三 | 截止：2026-06-15 | 状态：待处理
   匹配："设计方案" 出现在「待办内容」
   来源：会议 Sprint评审 · 2026-06-09
   🔗 [在 Base 中查看](https://bytedance.larkoffice.com/base/{baseAppToken}/table/{todosTableId}/record/{record_id})

#2 [TODO-007] 完成 API 接口文档
   负责人：李四 | 截止：2026-06-10 ‼️ | 状态：进行中
   匹配："接口" 出现在「待办内容」
   🔗 [在 Base 中查看](...)

── 会议记录（{N} 条）──
#3 [MEET-003] 接口设计讨论会
   会议日期：2026-06-05
   匹配："接口设计" 出现在「会议主题」
   📎 [查看会议纪要](doc_url)  🔗 [会议索引记录](base_record_url)

── 里程碑（{N} 条）──
（无匹配）

─────────────────────────────────
未找到满意的结果？试试：
  pmo-search "{keyword}" --all         跨所有项目搜索
  pmo-search "{keyword}" --in meetings 仅搜会议记录
```

**无结果时：**
```
🔍 搜索 "{keyword}" — 未找到匹配结果

建议：
  · 尝试更短的关键词（如"接口"替代"接口设计方案"）
  · 添加 --all 跨所有项目搜索
  · 检查时间范围限制是否过窄
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 无当前项目且未加 --all | 提示运行 pmo-use 或加 --all |
| 关键词为空 | 提示"请输入搜索关键词" |
| --limit 超过 100 | 自动截断为 100，提示"已限制为最多 100 条" |
| 某表查询失败 | 跳过该表，展示其他成功结果，底部标注 ⚠️ |
| 单个项目 Base 连接失败 | 提示某项目查询失败，展示其他成功结果 |
| --all 时 pinned 为空 | 回退到所有 active 项目 |
| 所有项目所有表均失败 | 提示排查建议（登录状态、Base 权限、网络连接） |
| --owner 姓名未匹配 | 提示 ⚠️ @{姓名} 未找到，按关键词搜索全部结果 |
