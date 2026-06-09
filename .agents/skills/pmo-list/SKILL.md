---
name: pmo-list
version: 1.0.0
description: "列出所有已注册的项目，显示状态、项目经理和待办数量。支持查看所有 active 和 archived 项目。"
metadata:
  requires:
    bins: []
  depends_on: []
---

# pmo-list — 列出所有项目

## 执行方式

```bash
claude pmo-list
```

## 执行流程

1. 遍历 `~/.smart-pmo/registry/*.json`
2. 读取每个项目的：`name`、`alias`、`status`、`pm.name`
3. 读取 `~/.smart-pmo/current` 标记当前项目
4. 读取 `~/.smart-pmo/pinned` 标记关注项目
5. 展示表格：

```
所有项目：

  当前项目 → {项目名} ({代号}) ※ 关注

  ┌──────────────┬────────┬────────┬──────────┐
  │ 项目名称      │ 代号   │ 状态   │ 项目经理 │
  ├──────────────┼────────┼────────┼──────────┤
  │ {项目名}     │ {代号} │ active │ {姓名}   │
  │ {项目名}     │ {代号} │ active │ {姓名}   │
  │ {项目名}     │ {代号} │ archived │ {姓名} │
  └──────────────┴────────┴────────┴──────────┘

  使用 pmo-use <项目名> 切换项目
  使用 pmo-pin <项目名>  关注项目
```
