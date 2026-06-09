---
name: pmo-dashboard
version: 1.0.0
description: "多项目概览仪表盘。展示所有关注项目的待办和里程碑状态汇总。从 Base 实时拉取数据。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
---

# pmo-dashboard — 多项目概览

## 执行方式

```bash
claude pmo-dashboard
```

## 前置条件

至少有关注项目（已用 `pmo-pin` 关注）或 active 项目。

## 执行流程

1. 读取 `~/.smart-pmo/pinned` 获取关注项目列表
   - 如果 pinned 为空，使用所有 status=active 的项目
2. 遍历每个项目，通过 `lark-base` 查询：
   - 待处理数（状态=待处理）
   - 进行中数（状态=进行中）
   - 已过期数（截止日期<今天 且 状态≠已完成/已取消）
   - 里程碑进行中数
   - 里程碑即将到期数
3. 展示概览：

```
📊 项目概览 · {today}
═══════════════════════════════
重点关注（{N} 个项目）：

◆ {项目名} ({代号})
  待办：待处理 {N} | 进行中 {N} | ⚠️ 过期 {N}
  里程碑：已完成 {N}/{总} | ⚠️ 即将到期 {N}

◆ {项目名} ({代号})
  待办：待处理 {N} | 进行中 {N} | ⚠️ 过期 {N}
  里程碑：已完成 {N}/{总} | ⚠️ 即将到期 {N}

使用 pmo-use <项目名> 查看详情
使用 pmo-pin <项目名>  关注更多项目
```
