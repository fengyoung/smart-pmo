---
name: pmo-archive
version: 1.1.0
description: "文档归档：将本地文件上传到项目知识库指定目录。支持 docx/pdf/xlsx/pptx/png/jpg/md/txt，≤50MB。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-wiki
    - lark-drive
---

# pmo-archive — 文档归档

## 执行方式

```bash
# 归档到指定目录
claude pmo-archive --file <路径> --dir <目录名>

# 不指定目录则交互选择
claude pmo-archive --file <路径>

# 自定义文件名
claude pmo-archive --file <路径> --dir 03-需求文档 --rename "需求文档-v2.docx"
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

## 执行流程

### 第1步：读取文件和选择目录

目录列表从项目配置的 `larkResources.wikiNodeTokens` keys 获取（不依赖 archive.directoryStructure）。

如果未指定 `--dir`，展示目录列表供选择：

```
请选择归档目录：
1. 01-会议纪要
2. 02-周报
3. 03-需求文档  ← 推荐（基于文件名匹配）
4. 04-设计文档
5. 05-项目资料
6. 99-归档
```

### 第2步：上传到知识库

飞书 wiki API 对不同文件格式的支持方式不同：

**方式A — 可直接创建为 wiki 节点（Markdown/文档类）：**
- `.md` / `.txt`：通过 `lark-wiki +node-create` 创建文档节点，再写入内容
- `.docx`：通过 `lark-doc` 上传导入，再关联到对应 wiki 节点

**方式B — 需先上传云文档再创建快捷方式（二进制文件）：**
- `.pdf` / `.xlsx` / `.pptx` / `.png` / `.jpg`：
  1. 通过 `lark-drive` 上传到云文档空间，获取 `file_token`
  2. 在目标 wiki 节点下通过 `lark-wiki +node-create` 创建快捷方式节点（`obj_type=shortcut`，指向 `file_token`）

执行时自动判断格式并选择对应方式，无需用户感知。

**文件命名规则：**
- 未指定 `--rename`：文件名自动添加 `YYYYMMDD-` 日期前缀（如 `20260609-需求文档v2.docx`）
- 指定 `--rename "自定义名称"`：以指定名称为准，不再添加日期前缀（用户自己决定命名）

### 第3步：完成确认

```
✅ 已归档: {文件名}
   📎 [查看文件]
   目录: {目录名}
   日期: {日期}
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 文件不存在 | 提示检查路径 |
| 类型不支持 | 提示支持格式 |
| >50MB | 建议压缩后上传 |
| 云文档上传失败 | 提示检查飞书云文档权限 |
