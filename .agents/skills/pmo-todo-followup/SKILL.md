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

# 标记完成
claude pmo-todo-followup --complete TODO-003

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

1. 通过 `lark-base update_record` 更新：
   - 状态 = "已完成"
   - 完成日期 = 当天
2. 输出确认："✅ TODO-{ID} 已标记为完成"
3. 可选推送群消息

### 修改待办 (--modify)

1. 通过 `lark-base update_record` 更新指定字段
2. 输出确认

## 设计文档

完整规格见：`../../designs/skill-specs/pmo-todo-followup.md`
