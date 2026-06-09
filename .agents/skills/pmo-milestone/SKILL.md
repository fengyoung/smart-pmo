---
name: pmo-milestone
version: 1.1.0
description: "里程碑管理：查看里程碑列表、新增里程碑、修改里程碑、标记完成、到期检查。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-im
    - lark-contact
---

# pmo-milestone — 里程碑管理

## 执行方式

```bash
# 查看所有里程碑
claude pmo-milestone

# 检查到期情况（7天内到期 + 已过期），仅终端输出
claude pmo-milestone --check

# 检查并推送到项目群
claude pmo-milestone --check --notify

# 新增里程碑
claude pmo-milestone --add "里程碑名称" --due YYYY-MM-DD --owner @姓名

# 修改里程碑
claude pmo-milestone --modify MILE-001 --due 2026-07-15
claude pmo-milestone --modify MILE-001 --owner @王五
claude pmo-milestone --modify MILE-001 --progress 75
claude pmo-milestone --modify MILE-001 --status 已延期

# 标记完成
claude pmo-milestone --complete MILE-001
```

## 执行流程

### 查看所有

从 Base「里程碑」表读取所有记录，按状态分组展示。

### 到期检查 --check

1. 读取所有状态≠已完成/已取消的里程碑
2. 筛选即将到期（7天内）和已过期，在终端输出
3. 仅在指定 `--notify` 时才推送到项目群

### 新增 --add

1. 解析 `--owner @姓名`：
   - 在项目配置 `team.members` 中按姓名精确匹配 openId
   - 找不到 → 通过 `lark-contact` 搜索飞书通讯录
   - 仍找不到 → 负责人字段留空，提示 `⚠️ @{姓名} 未匹配`
2. 通过 `lark-base` 写入里程碑表
3. 输出确认

### 修改 --modify

1. 按 ID 查找里程碑记录
2. 更新指定字段：
   - `--due YYYY-MM-DD`：修改计划日期
   - `--owner @姓名`：修改负责人（走同上的姓名解析流程）
   - `--progress 0-100`：修改进度（整数）
   - `--status <状态值>`：修改状态（未开始/进行中/已完成/已延期/已取消）
3. 通过 `lark-base update_record` 更新，输出确认

### 标记完成 --complete

1. `lark-base` 更新：状态=已完成，实际日期=今天
2. 输出确认
