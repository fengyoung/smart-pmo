---
name: pmo-export
version: 1.0.0
description: "数据导出：将项目 Base 表的待办/里程碑/会议索引数据导出为 CSV 或 JSON 文件，方便离线分析和数据迁移。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
---

# pmo-export — 数据导出

## 执行方式

```bash
# 导出当前项目的所有表数据（CSV 格式）
claude pmo-export

# 指定导出格式
claude pmo-export --format csv
claude pmo-export --format json

# 仅导出指定表
claude pmo-export --table todos
claude pmo-export --table milestones
claude pmo-export --table meetings

# 指定输出目录
claude pmo-export --output ~/Desktop/pmo-export/
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

## 执行流程

### 第1步：读取数据

从 Base 各表读取全部记录（自动分页，每页最多 500 条）：

- **待办事项表**：所有记录
- **里程碑表**：所有记录
- **会议记录索引表**：所有记录

### 第2步：格式转换

**CSV 格式（默认）：**
- 第一行为表头（字段中文名）
- 人员字段转换为姓名展示
- 关联字段转换为关联记录 ID 列表
- 日期字段格式化为 YYYY-MM-DD
- 编码为 UTF-8 BOM（兼容 Excel 打开）

**JSON 格式：**
- 输出为 JSON 数组，每个记录一个对象
- 保留原始字段名和值
- 关联字段保留原始 record_id

### 第3步：写入文件

```
输出目录结构（默认 ~/Desktop/pmo-export/）：

{项目名}_{导出日期}/
├── todos.csv          (或 todos.json)
├── milestones.csv     (或 milestones.json)
├── meeting_index.csv  (或 meeting_index.json)
└── export_info.txt    (导出元信息)
```

`export_info.txt` 内容：
```
项目: {项目名} ({代号})
导出时间: 2026-06-11T15:30:00
配置版本: v1.1
表统计:
  - 待办事项: {N} 条
  - 里程碑: {N} 条
  - 会议记录: {N} 条
导出格式: CSV
```

### 第4步：完成确认

```
✅ 数据导出完成

导出位置: ~/Desktop/pmo-export/{项目名}_2026-06-11/
  📄 todos.csv          — {N} 条待办
  📄 milestones.csv     — {N} 条里程碑
  📄 meeting_index.csv  — {N} 条会议记录
  📄 export_info.txt    — 导出元信息

总记录数: {N} 条
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 无当前项目 | 提示运行 pmo-use |
| Base 连接失败 | 提示某表读取失败，继续导出成功的表 |
| 某表无记录 | 该表文件内容为空（仅表头），输出标注"无数据" |
| 输出目录已存在 | 询问是否覆盖 |
| 磁盘空间不足 | 提示释放空间 |
