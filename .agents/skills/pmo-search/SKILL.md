---
name: pmo-search
version: 1.1.0
description: "跨表跨项目搜索。支持在待办事项、里程碑、会议记录三张表中按关键词检索，返回匹配条目并附来源链接。已集成到 pmo-todo-followup、pmo-dashboard、pmo-info 的操作提示中。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-doc
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

# 限定时间范围
claude pmo-search <关键词> --since 2026-05-01
claude pmo-search <关键词> --since 2026-05-01 --until 2026-06-01

# 限定负责人
claude pmo-search <关键词> --owner @张三
```

## 前置条件

已通过 `pmo-use` 设置当前项目（`--all` 模式不需要）。

## 执行流程

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

每张表最多返回 20 条匹配记录（按相关性/时间倒序）。

### 第3步：语义相关性排序

对每条结果计算与关键词的相关度（关键词在哪个字段出现、出现次数），按相关度从高到低排序。跨表结果合并后统一排序。

### 第4步：展示结果

```
🔍 搜索 "{keyword}" — {总结果数} 条
══════════════════════════════════════
项目：{项目名}（--all 模式下按项目分组）

── 待办事项（{N} 条）──
#1 [TODO-012] 接口设计方案评审
   负责人：张三 | 截止：2026-06-15 | 状态：待处理
   匹配："设计方案" 出现在「待办内容」
   来源：会议 Sprint评审 · 2026-06-09

#2 [TODO-007] 完成 API 接口文档
   负责人：李四 | 截止：2026-06-10 ‼️ | 状态：进行中
   匹配："接口" 出现在「待办内容」

── 会议记录（{N} 条）──
#3 [MEET-003] 接口设计讨论会
   会议日期：2026-06-05
   匹配："接口设计" 出现在「会议主题」
   📎 [查看会议纪要]

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
| Base 连接失败 | 提示某项目查询失败，展示其他成功结果 |
