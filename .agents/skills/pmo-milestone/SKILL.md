---
name: pmo-milestone
version: 1.0.0
description: "里程碑管理：查看里程碑列表、新增里程碑、标记完成、到期检查。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-im
---

# pmo-milestone — 里程碑管理

## 执行方式

```bash
# 查看所有里程碑
claude pmo-milestone

# 检查到期情况（7天内到期 + 已过期）
claude pmo-milestone --check

# 新增里程碑
claude pmo-milestone --add "里程碑名称" --due YYYY-MM-DD --owner @姓名

# 标记完成
claude pmo-milestone --complete MILE-001
```

## 执行流程

### 查看所有

从 Base「里程碑」表读取所有记录，按状态分组展示。

### 到期检查 --check

1. 读取所有状态≠已完成的里程碑
2. 筛选即将到期（7天内）和已过期
3. 推送到项目群

### 新增 --add

1. 通过 `lark-base` 写入里程碑表
2. 输出确认

### 标记完成 --complete

1. `lark-base` 更新：状态=已完成，实际日期=今天
2. 输出确认
