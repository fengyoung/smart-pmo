---
name: pmo-todo-followup
version: 1.1.0
description: "待办事项跟进：查看、筛选、标记完成、修改负责人/截止日期。支持 --mine/--overdue/--status/--all/--complete/--modify 参数。列表展示带行序号，支持用序号代替 TODO-ID 操作。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-im
    - lark-contact
---

# pmo-todo-followup — 待办跟进

## 执行方式

```bash
# 查看全部待办（默认）
claude pmo-todo-followup

# 只看我的待办
claude pmo-todo-followup --mine

# 只看已过期
claude pmo-todo-followup --overdue

# 按状态筛选
claude pmo-todo-followup --status 待处理

# 跨所有关注项目查看
claude pmo-todo-followup --all

# 标记完成（支持 TODO-ID 或列表中的行序号）
claude pmo-todo-followup --complete 3
claude pmo-todo-followup --complete TODO-003
claude pmo-todo-followup --complete 1 3 5
claude pmo-todo-followup --complete TODO-003 TODO-005

# 批量完成我的全部待处理待办（需确认）
claude pmo-todo-followup --complete --all-mine

# 修改待办（支持 TODO-ID 或行序号）
claude pmo-todo-followup --modify 3 --assign @李四
claude pmo-todo-followup --modify TODO-003 --due 2026-06-20
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

## 执行流程

### 查看待办

1. 从 Base「待办事项」表读取所有记录
2. 按参数过滤（--mine / --overdue / --status）
   - `--mine`：先通过 `lark-contact +me` 获取当前用户 openId，再筛选负责人字段
   - `--all`：遍历 `~/.smart-pmo/pinned` 项目列表（若 pinned 为空则用所有 active 项目），并行查询每个项目的 Base，按项目分组展示
3. 按截止日期排序，分组展示，**每行附带行序号**（从 1 开始，跨分组连续）

**展示格式（单项目）：**

```
📋 待办列表 — {项目名} ({N} 项)
═══════════════════════════════
⚠️ 已过期（{N} 项）:
┌──┬──────┬─────────────────┬──────────┬──────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │
├──┼──────┼─────────────────┼──────────┼──────────┤
│1 │ 003  │ 确定UI方案       │ 李四     │ 06-06 ‼️ │
│2 │ 007  │ 发送测试报告     │ 张三     │ 06-07 ‼️ │
└──┴──────┴─────────────────┴──────────┴──────────┘

待处理（{N} 项）:
┌──┬──────┬─────────────────┬──────────┬──────────┬────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──┼──────┼─────────────────┼──────────┼──────────┼────────┤
│3 │ 001  │ Sprint评审准备   │ 张三     │ 06-12    │ P0     │
│4 │ 009  │ 更新设计稿       │ 王五     │ 06-15    │ P2     │
└──┴──────┴─────────────────┴──────────┴──────────┴────────┘

操作提示（可用序号或 TODO-ID）：
  pmo-todo-followup --complete 1        标记第1条完成
  pmo-todo-followup --complete 1 2 3    批量标记完成
  pmo-todo-followup --modify 3 --due 2026-06-20
```

**`--all` 模式的展示格式（按项目分组，序号跨项目独立）：**

```
📋 全部项目待办 ({N} 个项目)
══════════════════════════════════

◆ {项目名} ({代号}) — 过期 {N} | 待处理 {N}
┌──┬──────┬─────────────────┬──────────┬──────────┬────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──┼──────┼─────────────────┼──────────┼──────────┼────────┤
│1 │ 003  │ 确定UI方案       │ 李四     │ 06-06 ‼️ │ P1     │
└──┴──────┴─────────────────┴──────────┴──────────┴────────┘

◆ {项目名2} ({代号2}) — 过期 {N} | 待处理 {N}
┌──┬──────┬─────────────────┬──────────┬──────────┬────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──┼──────┼─────────────────┼──────────┼──────────┼────────┤
│1 │ 012  │ 接口文档更新     │ 赵六     │ 06-08 ‼️ │ P1     │
└──┴──────┴─────────────────┴──────────┴──────────┴────────┘
```

**`--all` 模式下使用 `--complete`**：
- 每个项目的序号独立（从 1 开始），需先 `pmo-use <项目名>` 切换项目再用序号操作
- 或直接用 TODO-ID：`pmo-todo-followup --complete TODO-003`（在 --all 模式下需搭配 `--project {project_id}`）

### 标记完成 (--complete)

**参数解析：**
- 纯数字（如 `3`、`1 3 5`）→ 解析为展示列表中的行序号，从上次展示的列表映射到对应 TODO-ID
- `TODO-XXX` 格式 → 直接使用该 ID
- 混合使用均支持：`--complete 1 TODO-005 3`

**序号有效性检查：**
如果使用序号操作，但本次会话中未先查看过列表（无法映射序号 → ID），自动先执行一次列表查询再继续完成操作。

**单个或多个：**
1. 通过 `lark-base update_record` 逐条更新：
   - 状态 = "已完成"
   - 完成日期 = 当天（currentDate）
2. 输出确认："✅ TODO-{ID} 已标记为完成"（每条一行）

**批量完成我的全部待处理（--complete --all-mine）：**
1. 查询负责人=当前用户、状态=待处理 的所有待办
2. 展示待完成列表，要求用户确认："以上 {N} 条全部标记为完成？[y/N]"
3. 确认后批量更新，输出汇总结果

### 修改待办 (--modify)

**参数解析**：同 `--complete`，支持行序号或 TODO-ID。

1. 通过 `lark-base update_record` 更新指定字段：
   - `--assign @姓名`：解析姓名为 openId（走成员名称解析逻辑）
   - `--due YYYY-MM-DD`：修改截止日期
   - `--priority P0/P1/P2/P3`：修改优先级
   - `--status 状态值`：修改状态
2. 输出确认
