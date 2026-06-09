---
name: pmo-pin
version: 1.0.0
description: "关注/取消关注项目。被关注的项目在 pmo-dashboard 中集中展示概览。"
metadata:
  requires:
    bins: []
  depends_on: []
---

# pmo-pin / pmo-unpin — 项目关注管理

## 执行方式

```bash
# 关注一个或多个项目
claude pmo-pin <项目名> [<项目名>...]

# 取消关注
claude pmo-unpin <项目名> [<项目名>...]
```

## 执行流程

**pmo-pin：**
1. 读取 `~/.smart-pmo/pinned` 文件
2. 将要关注的项目名加入列表（去重）
3. 写回 pinned 文件
4. 输出确认

**pmo-unpin：**
1. 从 pinned 列表中移除指定项目
2. 写回文件
3. 输出确认

## 存储格式

`~/.smart-pmo/pinned` 为纯文本，每行一个项目名：

```
project-a
project-b
```
