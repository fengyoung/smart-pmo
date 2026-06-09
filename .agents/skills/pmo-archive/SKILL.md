---
name: pmo-archive
version: 1.0.0
description: "文档归档：将本地文件上传到项目知识库指定目录。支持 docx/pdf/xlsx/pptx/png/jpg/md/txt，≤50MB。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-wiki
    - lark-base
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

通过 `lark-wiki` 上传文件到指定目录节点。

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
