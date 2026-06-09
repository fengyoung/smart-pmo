---
name: pmo-todo-followup
version: 1.0.0
description: "待办事项跟进：查看、筛选、标记完成、修改负责人/截止日期。支持 --mine/--overdue/--status/--all/--complete/--modify 参数。"
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

# 标记完成（单个）
claude pmo-todo-followup --complete TODO-003

# 批量标记完成（多个 ID）
claude pmo-todo-followup --complete TODO-003 TODO-005 TODO-008

# 批量完成我的全部待处理待办（需确认）
claude pmo-todo-followup --complete --all-mine

# 修改待办
claude pmo-todo-followup --modify TODO-003 --assign @李四
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

**`--all` 模式的展示格式（按项目分组）：**

```
📋 全部项目待办 ({N} 个项目)
══════════════════════════════════

◆ {项目名} ({代号}) — 过期 {N} | 待处理 {N}
┌──────┬─────────────────┬──────────┬──────────┬────────┐
│ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──────┼─────────────────┼──────────┼──────────┼────────┤
│ 003  │ 确定UI方案       │ 李四     │ 06-06 ‼️ │ P1     │
└──────┴─────────────────┴──────────┴──────────┴────────┘

◆ {项目名2} ({代号2}) — 过期 {N} | 待处理 {N}
...
```

**`--all` 模式下使用 `--complete`**：
- 需同时指定项目，格式：`pmo-todo-followup --complete {project_id}/TODO-003`
- 或直接切换到该项目后执行：`pmo-use XRay && pmo-todo-followup --complete TODO-003`
3. 按截止日期排序，分组展示：

```
📋 待办列表 — {项目名} ({N} 项)
═══════════════════════════════
⚠️ 已过期（{N} 项）:
┌──────┬─────────────────┬──────────┬──────────┐
│ ID   │ 内容             │ 负责人   │ 截止日期  │
├──────┼─────────────────┼──────────┼──────────┤
│ 003  │ 确定UI方案       │ 李四     │ 06-06 ‼️ │
└──────┴─────────────────┴──────────┴──────────┘

待处理（{N} 项）:
┌──────┬─────────────────┬──────────┬──────────┬────────┐
│ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──────┼─────────────────┼──────────┼──────────┼────────┤
│ 001  │ Sprint评审准备  │ 张三     │ 06-12    │ P0     │
└──────┴─────────────────┴──────────┴──────────┴────────┘

操作: pmo-todo-followup --complete <ID>  标记完成
      pmo-todo-followup --modify <ID>... 修改
```

### 标记完成 (--complete)

**单个或多个 ID：**
1. 通过 `lark-base update_record` 逐条更新：
   - 状态 = "已完成"
   - 完成日期 = 当天
2. 输出确认："✅ TODO-{ID} 已标记为完成"（每条一行）

**批量完成我的全部待处理（--complete --all-mine）：**
1. 查询负责人=当前用户、状态=待处理 的所有待办
2. 展示待完成列表，要求用户确认："以上 {N} 条全部标记为完成？[y/N]"
3. 确认后批量更新，输出汇总结果

### 修改待办 (--modify)

1. 通过 `lark-base update_record` 更新指定字段
2. 输出确认
