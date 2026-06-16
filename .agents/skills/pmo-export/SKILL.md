---
name: pmo-export
version: 1.6.0
description: "导出项目 Base 数据为 CSV 或 JSON 文件。支持指定导出表、格式、输出路径。CSV 采用 UTF-8 BOM 编码以兼容 Excel 直接打开。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
---

# pmo-export — 数据导出

## 执行方式

```bash
# 导出当前项目全部三张表（默认 CSV 格式）
claude pmo-export

# 指定格式
claude pmo-export --format csv
claude pmo-export --format json

# 仅导出指定表
claude pmo-export --table todos
claude pmo-export --table milestones
claude pmo-export --table meetings
claude pmo-export --table todos,milestones

# 指定输出路径（默认输出到当前目录 ./{project_id}_{date}/）
claude pmo-export --output ~/Desktop/pmo-export
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

**所有 Base 读操作在网络超时或 5xx 错误时自动重试（1s/3s/5s 退避）。**

## 执行流程

### 公共：待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)。执行开始时检查 `~/.smart-pmo/` 下的四个待处理目录。

### 配置加载

1. 按 CLAUDE.md「读取当前项目配置」规则加载项目配置
2. 检查 `schemaVersion`，执行必要的版本迁移
3. 执行配置完整性校验（必填字段：`project.name`、`larkResources.baseAppToken`、`larkResources.baseTableIds.*`）

### 第1步：解析参数

```
format  = --format 参数（默认 csv）
tables  = --table 参数解析为列表（默认 todos, milestones, meetings 全部）
output  = --output 参数（默认 ./{project_id}_{YYYYMMDD}/）
```

**输出目录处理：**
- 若目录已存在 → 提示 `输出目录 {path} 已存在，是否覆盖？[y/N]`
- 用户选择 N → 在目录名后追加 `-2`（如 `export_20260611-2`），若 `-2` 也存在则递增

### 第2步：分页拉取 Base 数据

对每个目标表，通过 `lark-base` 分页查询（每页 500 条，自动翻页直至读完）：

| 表 | 对应 config 字段 | 输出文件名 |
|----|----------------|-----------|
| 待办事项 | `baseTableIds.todos` | `todos.csv / todos.json` |
| 里程碑 | `baseTableIds.milestones` | `milestones.csv / milestones.json` |
| 会议记录索引 | `baseTableIds.meetingIndex` | `meetings.csv / meetings.json` |

**引用字段展开（避免导出原始 ID）：**
- 人员字段（负责人、参会人）→ 导出 `姓名` 字符串（多人时逗号分隔）
- 关联字段（所属会议、关联待办、产出待办）→ 导出关联记录的自动编号 ID（如 `MEET-001`，多值逗号分隔）
- 日期字段 → 格式 `YYYY-MM-DD`
- 日期时间字段 → 格式 `YYYY-MM-DD HH:MM`

### 第3步：写入文件

**CSV 格式：**
- 编码：UTF-8 BOM（`﻿` 前缀），确保 Excel 直接打开不乱码
- 首行为字段名（中文）
- 每行一条记录

**JSON 格式：**
- 整体结构：
  ```json
  {
    "exportedAt": "2026-06-11T10:00:00",
    "project": "项目名",
    "table": "待办事项",
    "totalCount": 42,
    "records": [...]
  }
  ```
- 每条记录保留原始字段名（中文），引用字段已展开

同时输出一个 `export_meta.json` 汇总文件：

```json
{
  "exportedAt": "2026-06-11T10:00:00",
  "project": "项目名（项目代号）",
  "tables": {
    "todos": {"count": 42, "file": "todos.csv"},
    "milestones": {"count": 8, "file": "milestones.csv"},
    "meetings": {"count": 15, "file": "meetings.csv"}
  }
}
```

### 第4步：完成确认

```
✅ 导出完成 — {项目名}
   📁 输出目录: {path}
   ├── todos.csv        (42 条)
   ├── milestones.csv   (8 条)
   ├── meetings.csv     (15 条)
   └── export_meta.json

提示：使用 Excel 打开 CSV 时，选择「数据 → 从文本/CSV 导入」，文件编码选择 UTF-8
```

## 快速操作

```
pmo-search "关键词"                      搜索导出的内容
pmo-stats --export stats.md              导出统计分析报告
pmo-info                                 查看项目概况
pmo-archive --file <导出文件>            归档导出文件到知识库
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 无当前项目 | 提示运行 pmo-use |
| 某表查询失败 | 跳过该表，提示 ⚠️ 并继续导出其他表 |
| 某表无记录 | 仍创建文件（CSV 只有表头行，JSON records 为空数组） |
| 输出目录无写权限 | 提示权限错误，建议换路径 |
| 数据量超大（>5000条）| 分批拉取，展示进度条（每 500 条 1 批） |
| 所有表均查询失败 | 提示排查建议（Base 连接、权限） |
| Base 查询超时 | 重试 3 次后跳过该表 |

## 边缘情况

| 场景 | 处理方式 |
|------|---------|
| 输出目录已存在 | 询问覆盖或自动追加 `-N` 后缀 |
| 某表无记录 | 创建空文件（CSV 仅表头 / JSON 空数组） |
| 目录无写权限 | 提示权限错误，建议换路径 |
| 数据量 >5000 条 | 分批拉取 + 进度条展示 |
| CSV 中文乱码 | 已用 UTF-8 BOM 编码，建议 Excel 导入方式 |
