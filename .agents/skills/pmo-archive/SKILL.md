---
name: pmo-archive
version: 1.6.0
description: "文档归档：将本地文件上传到项目知识库指定目录。支持 docx/pdf/xlsx/pptx/png/jpg/md/txt，≤50MB。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-wiki
    - lark-drive
    - lark-base
---

# pmo-archive — 文档归档

## 执行方式

```bash
# 归档单个文件到指定目录
claude pmo-archive --file <路径> --dir <目录名>

# 不指定目录则交互选择
claude pmo-archive --file <路径>

# 自定义文件名
claude pmo-archive --file <路径> --dir 03-需求文档 --rename "需求文档-v2.docx"

# 批量归档目录下所有文件
claude pmo-archive --dir <本地目录路径> --target <目标目录名>

# 批量归档 + 指定目标目录（不指定 --target 则交互选择）
claude pmo-archive --dir <本地目录路径>
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

## 公共模式引用

### 配置加载

按 CLAUDE.md「读取当前项目配置」规则加载项目配置：

1. 优先读取环境变量 `$SMART_PMO_CURRENT`
2. 若无环境变量，读取文件 `~/.smart-pmo/current`
3. 用 project_id 加载 `~/.smart-pmo/registry/{project_id}.json`
4. 文件不存在或为空 → 提示「请先执行 pmo-use <项目名>」，中断执行
5. 检查 `schemaVersion`，执行必要的版本迁移
6. 执行配置完整性校验

### 配置完整性校验

1. 必填字段检查：`project.name`、`larkResources.baseAppToken`、`larkResources.wikiSpaceId`、`larkResources.wikiNodeTokens` 不为空
2. 若任一必填字段缺失 → 提示「配置不完整，缺少: {字段列表}。建议重新运行 pmo-init 修复」

### 错误重试策略

所有飞书 API 写操作（Wiki 创建、Drive 上传）遵循公共错误重试策略（见 CLAUDE.md）：3 次指数退避重试（1s/3s/5s）。

**重试耗尽后的人工介入：**

| 失败场景 | 终端提示 | 具体操作引导 |
|---------|---------|------------|
| Wiki 归档失败 | `❌ 知识库归档失败（{错误码}）` | `→ 请在 pmo-archive 手动归档：claude pmo-archive <文件路径>` |

### 待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)。执行开始时检查 `~/.smart-pmo/` 下的四个待处理目录。

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

### 第2步：用户确认

上传前展示确认信息，等待用户确认后再执行：

```
📋 归档确认
──────────────────────────────
  文件: {文件名}（{文件大小}）
  目标目录: {目录名}
  上传方式: {方式A 直接创建 | 方式B 云文档+快捷方式}
──────────────────────────────

是否确认归档？[Y/n]
```

- 用户选择 `Y` 或回车 → 继续执行上传
- 用户选择 `n` → 取消归档，终端输出 `⏸️ 已取消归档`

**批量模式（`--dir`）**：确认界面展示文件总数和汇总大小，获得确认后开始串行上传。

### 第3步：上传到知识库

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
- **去重保护**：若文件名已以 `YYYYMMDD-` 开头（如 `20260609-会议纪要.docx`），不再重复添加前缀
- 指定 `--rename "自定义名称"`：以指定名称为准，不再添加日期前缀（用户自己决定命名）

### 第4步：完成确认

```
✅ 已归档: {文件名}
   📎 [查看文件]
   目录: {目录名}
   日期: {日期}
```

### 批量归档（--dir 模式）

当指定 `--dir <本地目录路径>` 时：

1. 扫描目录下所有支持的文件（按扩展名过滤：docx/pdf/xlsx/pptx/png/jpg/md/txt）
2. 跳过子目录，仅处理顶层文件
3. 单文件上限 50MB，超过则跳过并标注 ⚠️
4. 串行上传（避免飞书限流），每个文件完成后再处理下一个
5. 进度展示：

```
📦 批量归档 · {本地目录路径}
  发现 {N} 个文件 → 目标目录：{dir}

  [1/{N}] ✅ requirements.docx
  [2/{N}] ✅ design-spec.pdf
  [3/{N}] ⚠️ large-file.zip（格式不支持，已跳过）
  ...

✅ 归档完成：{成功数}/{总数} 成功，{跳过数} 跳过
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 文件不存在 | 提示检查路径 |
| 类型不支持 | 提示支持格式 |
| >50MB | 建议压缩后上传 |
| 云文档上传失败 | 提示检查飞书云文档权限 |
