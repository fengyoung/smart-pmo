---
name: pmo-archive
version: 1.8.0
description: "文档智能归档：支持本地文件和飞书链接两种输入，AI 自动理解内容并分类归档到项目知识库对应目录（01-会议纪要/02-周报/03-需求文档/04-设计文档/05-项目资料/99-归档），不确定时交互推荐。本地文件自动转换为飞书兼容格式。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-wiki
    - lark-drive
    - lark-doc
    - lark-base
---

# pmo-archive — 文档智能归档

> v1.8.0 重构：新增飞书链接输入、AI 内容理解自动分类、格式转换；在保持原有本地文件归档能力基础上，改为全自动路由，AI 不确定时才交互确认。

## 执行方式

```bash
# ===== 本地文件归档 =====
# 标准用法（AI 自动分类，无需指定目录）
claude pmo-archive --file <本地文件路径>

# 手动指定目录（跳过 AI 分类）
claude pmo-archive --file <路径> --dir <目录名>

# 自定义文件名
claude pmo-archive --file <路径> --dir 03-需求文档 --rename "需求文档-v2.docx"

# 批量归档目录下所有文件（每个文件 AI 自动分类）
claude pmo-archive --dir <本地目录路径>
claude pmo-archive --dir <本地目录路径> --target <目标目录名>  # 跳过 AI 分类，统一归档到指定目录

# ===== 飞书链接归档（v1.8.0 新增）=====
# 归档飞书文档到知识库（AI 自动理解内容并分类）
claude pmo-archive --url <飞书文档链接>

# 手动指定目录（跳过 AI 分类）
claude pmo-archive --url <飞书文档链接> --dir 04-设计文档

# 批量归档多个飞书链接
claude pmo-archive --url <链接1> --url <链接2> --url <链接3>
```

## 前置条件

1. 已通过 `pmo-use` 设置当前项目
2. 本地文件存在且 ≤50MB，类型支持 `.md / .txt / .docx / .pdf / .xlsx / .pptx / .png / .jpg`
3. 飞书链接可访问（用户有权限），支持 `/docx/`、`/wiki/`、`/docs/` 等路径

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

所有飞书 API 写操作（Wiki 创建、Drive 上传、Doc 读取）遵循公共错误重试策略（见 CLAUDE.md）：3 次指数退避重试（1s/3s/5s）。

**重试耗尽后的人工介入：**

| 失败场景 | 终端提示 | 具体操作引导 |
|---------|---------|------------|
| Wiki 归档失败 | `❌ 知识库归档失败（{错误码}）` | `→ 请在 Base 中手动操作：{wikiSpaceUrl}` |
| Drive 上传失败 | `❌ 云盘上传失败（{错误码}）` | `→ 请手动上传文件到云盘后，在 Wiki 中创建快捷方式` |
| 格式转换失败 | `❌ 格式转换失败（{错误码}）` | `→ 请手动将文件转为飞书文档后上传` |

### 待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)。执行开始时检查 `~/.smart-pmo/` 下的四个待处理目录。

---

## 执行流程

### 统一处理管道

无论输入源是什么（本地文件或飞书链接），都走统一管道：

```
输入 → 读取内容 → AI 分类 → 目录确定 → 格式转换（如需要）→ 归档写入
```

### Step 1：解析输入 & 读取内容

**输入源 A — 本地文件（`--file`）：**
1. 检查文件存在、大小 ≤50MB、扩展名在支持列表中
2. 根据格式提取文本内容（截断到 ≤3000 字符用于 AI 分类）：
   - `.md` / `.txt`：直接读取前 3000 字符
   - `.docx`：用 Python `python-docx` 提取文本
   - `.pdf`：用 `pdftotext` 或 Python `PyPDF2` 提取前 5 页文本作为分类依据
   - `.xlsx`：用 Python `openpyxl` 提取前 3 个 sheet 的前 100 行
   - `.pptx`：用 Python `python-pptx` 提取所有幻灯片文本
   - `.png` / `.jpg`：仅用文件名作为分类依据（图像无文本可提取）
3. 输出：`{ content, filename, file_size, file_ext }`

**输入源 B — 飞书链接（`--url`）：**
1. 解析 URL，提取 token 和资源类型：
   - `/docx/<token>` → 文档
   - `/wiki/<token>` → Wiki 节点，通过 `lark-cli drive +inspect` 解包到底层类型
2. 根据资源类型读取内容：
   - `docx` 类型：通过 `lark-cli docs +fetch --api-version v2 --doc <token> --doc-format markdown` 读取全文
   - 其他文本类型（sheet）：提取文本摘要
3. 获取元信息：`{ title, doc_url, doc_token, resource_type }`
4. 输出：`{ content, title, doc_url, doc_token, resource_type }`

### Step 2：AI 内容分类

> Prompt 模板详见 [`references/classify-prompt-template.md`](references/classify-prompt-template.md)

将 Step 1 提取的内容 + 元信息注入 LLM，输出分类结果。

**Prompt 变量构造规则：**

| 变量 | 构造方式 |
|------|---------|
| `{wikiDirectories}` | `Object.keys(config.larkResources.wikiNodeTokens).sort().join(", ")` |
| `{wikiDirectoryDescriptions}` | 固定映射表（见 prompt 模板「目录用途描述」），仅列出 6 个标准目录 |
| `{contentSnippet}` | Step 1 提取的文本内容，取前 3000 字符 |
| `{extraMeta}` | 飞书文档时为 `文档标题: {title}\n飞书链接: {url}`；本地文件时为空 |
| `{sourceType}` | `本地文件` 或 `飞书文档` |
| `{sourceDetail}` | 本地绝对路径 或 飞书文档 URL |

**分类目标（6 个标准目录，从项目配置动态读取）：**

| 目录 | 适用文档类型 |
|------|-------------|
| `01-会议纪要` | 会议记录、妙记转写、讨论纪要 |
| `02-周报` | 周报、双周报、月报 |
| `03-需求文档` | PRD、需求说明、用户故事、功能规格 |
| `04-设计文档` | 技术方案、架构设计、接口文档、流程图 |
| `05-项目资料` | 项目计划、排期、人员、参考材料、ASR 校正表 |
| `99-归档` | 历史文档、已废弃、无法归类的通用文档 |

**LLM 输出格式（严格）：**
```
DIR: <目录名>
CONFIDENCE: high | medium | low
REASON: <一句话归类理由>
RENAME: <建议的新文件名，可选，不填则保留原名>
```

**分类规则：**
- `CONFIDENCE: high` → 直接使用 AI 结果，不交互
- `CONFIDENCE: medium` → 交互推荐（展示推荐目录 + 备选，用户确认）
- `CONFIDENCE: low` → 交互选择（列出全部 6 个目录，用户手动选择）

**交互推荐界面（medium 置信度）：**
```
🤖 AI 推荐归档目录
──────────────────────────────
  文件: {文件名}
  推荐: {目录名} — {理由}
  备选: {第二候选目录}

  [采用推荐] [选择备选] [手动指定] [跳过]
```

**交互选择界面（low 置信度或手动模式）：**
```
📁 请选择归档目录
──────────────────────────────
  文件: {文件名}
  内容摘要: {前100字}

  1. 01-会议纪要
  2. 02-周报
  3. 03-需求文档  ← 推荐
  4. 04-设计文档
  5. 05-项目资料
  6. 99-归档

  输入序号（1-6）或 [s]跳过:
```

### Step 3：格式转换 & 归档写入

统一目标：确保最终归档产物是飞书知识库中的可访问文档或快捷方式。

**归档矩阵（按输入源 × 类型 × 格式选择路由）：**

| 输入源 | 原始格式 | 飞书目标格式 | 归档方式 |
|--------|---------|-------------|---------|
| 本地 | `.md / .txt` | docx | ① `docs +create` 创建飞书文档 → ② `wiki +node-create --node-type shortcut --origin-node-token <doc_token>` 创建快捷方式 |
| 本地 | `.docx` | docx | ① `drive +import --type docx` 导入为飞书文档 → ② `wiki +node-create --node-type shortcut --origin-node-token <file_token>` 创建快捷方式 |
| 本地 | `.pdf` | file | ① `drive +upload` 上传到云盘 → ② `wiki +node-create --node-type shortcut --origin-node-token <file_token>` 创建快捷方式 |
| 本地 | `.xlsx` | sheet | ① `drive +import --type sheet` 导入为飞书电子表格 → ② `wiki +node-create --node-type shortcut --origin-node-token <file_token>` 创建快捷方式 |
| 本地 | `.pptx` | slides | ① `drive +import --type slides` 导入为飞书幻灯片 → ② `wiki +node-create --node-type shortcut --origin-node-token <file_token>` 创建快捷方式 |
| 本地 | `.png / .jpg` | file | ① `drive +upload` 上传原始文件 → ② `wiki +node-create --node-type shortcut --origin-node-token <file_token>` 创建快捷方式 |
| 飞书链接 | `docx` | 保持原格式 | ① `wiki +node-create --node-type shortcut --origin-node-token <doc_token>` 直接在目标目录创建快捷方式 |
| 飞书链接 | `sheet / slides / bitable / mindnote` | 保持原格式 | 同上：直接创建快捷方式到目标目录 |

**归档执行步骤（串行）：**
1. **格式转换**（本地文件需要，飞书链接跳过）：
   - 文本类（md/txt）→ `docs +create --doc-format markdown` 创建飞书文档。文档标题取自文件第一个 `# 标题`，无标题时取文件名（不含扩展名）。`--content` 参数有长度限制（建议 ≤500KB），超大文件应先用 `drive +import --type docx` 代替 `docs +create`
   - Office 类（docx/xlsx/pptx）→ `drive +import` 导入为在线文档
   - 二进制类（pdf/png/jpg）→ `drive +upload` 原始上传
2. **Wiki 归档**：在目标目录节点下创建快捷方式，指向步骤 1 得到的飞书文档/文件
3. **文件命名**（优先级从高到低）：
   - `--rename` 参数指定的名称最高优先级，不加日期前缀（用户已自行决定命名）
   - 其次使用 AI 建议的 RENAME（不含日期前缀，自动添加 `YYYYMMDD-`）
   - 默认使用原始文件名，自动添加 `YYYYMMDD-` 日期前缀
   - 若文件名已以 `YYYYMMDD-` 开头，不再重复添加日期前缀

**归档完成确认：**
```
✅ 已归档
──────────────────────────────
  文件: {文件名}
  目标: {目录名}
  理由: AI — {分类理由}
  📎 查看: {飞书文档/文件链接}
```

### Step 4：批量处理

**本地批量（`--dir <本地目录>`）：**
1. 扫描目录下所有支持格式文件
2. 对每个文件串行执行 Step 1-3
3. 进度展示：

```
📦 批量归档 · {本地目录}
  发现 {N} 个文件

  [1/{N}] ✅ requirements.docx → 03-需求文档
  [2/{N}] ✅ design-spec.pdf → 04-设计文档
  [3/{N}] ⚠️ large-file.zip（格式不支持，已跳过）
  ...

✅ 归档完成：{成功数}/{总数} 成功，{跳过数} 跳过
```

**飞书批量（多个 `--url`）：**
```
📦 批量归档 · {M} 个飞书链接

  [1/{M}] ✅ {doc_title} → 03-需求文档
  [2/{M}] ✅ {doc_title} → 04-设计文档
  ...

✅ 归档完成：{成功数}/{总数} 成功
```

### Step 5：去重保护

归档前检查目标目录下是否已有同名文件：
- 同名存在 → 文件名追加序号（如 `20260618-需求文档v2-2.docx`）
- 同名且内容相同的飞书链接 → 提示「该文档已归档至 {目录}，跳过」，不重复创建快捷方式

---

## 特殊场景

### 图像文件处理（.png / .jpg）

图像文件无法提取文本内容，**跳过 AI 分类**，分类**仅基于文件名关键词规则**：
1. 文件名包含「架构」「流程」「设计」等关键词 → 推荐 `04-设计文档`
2. 文件名包含「原型」「UI」「界面」→ 推荐 `03-需求文档`
3. 文件名包含「照片」「截图」→ 推荐 `05-项目资料`
4. 无法判断 → 直接进入交互选择界面（无 AI 推荐）

### 同名冲突

| 场景 | 处理 |
|------|------|
| 同目录下已有同名快捷方式，指向同一飞书文档 | 跳过，提示「已归档」 |
| 同目录下已有同名快捷方式，指向不同飞书文档 | 追加序号 -2, -3 |
| 同目录下已有同名原始节点 | 追加序号 |

---

## 异常处理

| 场景 | 处理 |
|------|------|
| 文件不存在 | 提示检查路径 |
| 类型不支持 | 提示支持格式列表 |
| 文件 > 50MB | 建议压缩后上传 |
| 飞书链接无权限 | 提示检查文档权限 |
| 飞书链接资源类型不支持 | 提示支持的资源类型（docx/sheet/slides/bitable/mindnote） |
| 格式转换失败 | 降级：原始文件上传到云盘 + 创建快捷方式 |
| AI 分类失败（LLM 不可用） | 降级：跳过 AI 分类，进入交互选择目录 |
| Wiki 目录不存在 | 检查 wikiNodeTokens 配置，缺失则提示运行 pmo-init 修复 |
| Drive 上传失败（重试耗尽）| 提示手动上传引导 |
| 批量模式某文件失败 | 记录失败并继续处理其余文件 |
