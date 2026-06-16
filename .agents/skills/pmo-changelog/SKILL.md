---
name: pmo-changelog
version: 1.6.2
description: "变更日志：汇总指定周期内已完成待办和里程碑为自然语言 Changelog，适合对外发布或团队同步。支持按周/月/里程碑范围生成，可导出 Markdown 或归档到知识库。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-doc
    - lark-wiki
    - lark-im
---

# pmo-changelog — 变更日志

> 自动将已完成的待办和里程碑整理为 Changelog，按语义分类，适合版本发布公告、团队同步或归档。

## 执行方式

```bash
# 生成本周 Changelog（默认）
claude pmo-changelog

# 指定周期类型
claude pmo-changelog --period week         # 本周（默认）
claude pmo-changelog --period month        # 本月

# 指定起始日期（到今天）
claude pmo-changelog --since 2026-06-01

# 指定里程碑范围
claude pmo-changelog --milestone MILE-001

# 预览模式，不归档不写入
claude pmo-changelog --dry-run

# 导出为本地 Markdown 文件
claude pmo-changelog --export changelog.md

# 生成并推送摘要到项目群
claude pmo-changelog --send
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

**所有飞书 API 写操作遵循公共错误重试策略（见 CLAUDE.md）：3 次指数退避重试（1s/3s/5s）。**

## 执行流程

### 公共：待处理队列检查

执行前先检查以下目录（按 CLAUDE.md 公共约定），详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)：

| 目录 | 用途 | 处理方式 |
|------|------|------|
| `~/.smart-pmo/.pending_backfill/` | 会议索引回填失败 | 自动重试回填，成功删文件 |
| `~/.smart-pmo/.pending_orphan_meeting/` | 孤立会议记录 | 提示用户执行 `--index-only` 补录 |
| `~/.smart-pmo/.pending_assignee/` | 负责人 API 写入失败 | 提示用户存在待分配记录 |
| `~/.smart-pmo/.draft/` | 用户取消的解析草稿 | 提示用户存在缓存草稿 |

### 配置加载

1. 按 CLAUDE.md「读取当前项目配置」规则加载项目配置
2. 检查 `schemaVersion`，执行必要的版本迁移
3. 执行配置完整性校验（必填字段：`project.name`、`larkResources.baseAppToken`、`larkResources.baseTableIds.todos`、`larkResources.baseTableIds.milestones`）

### 第1步：确定时间范围

根据参数确定 Changelog 覆盖的时间范围：

| 参数 | 范围计算 |
|------|------|
| 默认 / `--period week` | 本周周一 ~ today（ISO 周，周一为第一天） |
| `--period month` | 本月 1 日 ~ today |
| `--since YYYY-MM-DD` | 指定日期 ~ today |
| `--milestone <ID>` | 该里程碑的计划开始日 ~ min(今天, 计划完成日) |

**`--milestone` 未提供 ID 时的里程碑选择交互：**

通过 `lark-base` 查询所有非取消里程碑，展示列表供选择：
```
请选择里程碑范围：
  1. [MILE-001] Beta版发布（06-01 ~ 06-15）✅ 已完成
  2. [MILE-002] UAT评审（06-08 ~ 06-20）🔄 进行中
  3. [MILE-003] 正式上线（06-21 ~ 06-30）⏳ 未开始
请输入序号：
```

> 📅 日期范围计算详见 [`_shared/date-calc-rules.md`](../_shared/date-calc-rules.md)

### 第2步：拉取已完成数据

并行从 Base 查询：

**已完成待办**（完成日期在范围内）：
- 完成日期、待办内容、负责人、优先级、来源

**已完成里程碑**（实际完成日期在范围内，或计划完成日期在范围内且状态=已完成）：
- 里程碑名称、计划日期、实际完成日期

**查询容错：** Base 查询超时（见 CLAUDE.md 超时配置，单次 20s）→ 对应数据留空，输出中标注 `⚠️ 数据获取失败，部分内容可能不完整`

### 第3步：AI 语义分类

对已完成待办，通过 AI 按内容语义自动分类：

| 类别 | 标识 | 特征关键词 |
|------|------|------|
| 新增功能 | ✨ | 新增、开发、实现、上线、发布、完成、创建 |
| 修复 | 🐛 | 修复、fix、bug、问题、异常、错误、失效 |
| 改进优化 | ⚡ | 优化、改进、提升、重构、调整、更新 |
| 文档/流程 | 📝 | 文档、方案、评审、会议、培训、规范 |
| 其他 | 🔧 | 以上均不符合 |

**分类原则：**
- 优先按内容判断，若内容模糊则参考来源（来自哪次会议）
- 一条待办只属于一个类别
- 某分类无内容时该分类不出现在输出中（不输出空标题）

### 第4步：生成 Changelog 草稿

按以下格式生成：

```markdown
# Changelog · {项目名}

## [{版本/周期标识}] — {startDate} ~ {endDate}

### ✨ 新增功能
- {待办内容}（@{负责人}，{完成日期}）

### ⚡ 改进优化
- {待办内容}（@{负责人}，{完成日期}）

### 🐛 修复
- {待办内容}（@{负责人}，{完成日期}）

### 📝 文档/流程
- {待办内容}（@{负责人}，{完成日期}）

### 🏁 里程碑完成
- {里程碑名称}（计划 {planDate}，实际完成 {actualDate}）

---
> 📊 本周期完成待办 {N} 项，里程碑 {N} 个
> 由 Smart-PMO 自动生成 · {today}
```

**版本/周期标识规则：**
- `--period week`：`第{N}周`（如 `第25周`）
- `--period month`：`{YYYY}年{M}月`
- `--milestone <ID>`：`{里程碑名称}`
- `--since <date>`：`{since} 以来`

### 第5步：展示确认

在终端展示完整草稿，用户可选择：

```
📋 Changelog 草稿 · 请确认
────────────────────────────────
[草稿内容]
────────────────────────────────
共 {N} 条待办 · {N} 个里程碑

[确认归档] [预览调整] [仅导出 Markdown] [取消]
```

| 选项 | 行为 |
|------|------|
| **确认归档** | 创建飞书文档 + 归档到知识库 `05-项目资料/` |
| **预览调整** | 用户输入修改意见，AI 调整后重新展示 |
| **仅导出 Markdown** | 写入本地文件，不归档知识库 |
| **取消** | 丢弃草稿 |

### 第6步：归档/导出

**归档到知识库（选「确认归档」时）：**
1. 通过 `lark-doc` 创建飞书文档
2. 通过 `lark-wiki` 归档到 `05-项目资料/`
   - 文档标题格式：`{YYYYMMDD}-Changelog-{周期标识}`（如 `20260615-Changelog-第25周`）
   - 命名冲突时追加序号：`-2`、`-3`

**本地导出（`--export` 参数或选「仅导出 Markdown」时）：**
- 写入指定路径（默认：`./changelog-{YYYYMMDD}.md`）
- 文件使用 UTF-8 编码

**推送摘要（`--send` 时）：**
- 向项目群推送一条消息卡片：
  ```
  📝 {项目名} Changelog · {周期标识}

  ✨ 新增 {N} 项  ⚡ 改进 {N} 项  🐛 修复 {N} 项
  🏁 里程碑完成 {N} 个

  本周亮点：
  · {完成的最高优先级待办 1-2 条}

  📎 查看完整 Changelog → {wiki文档链接}
  ```
- 推送到 `config.larkResources.chatIds` 的第一个群
- 推送失败不阻塞归档流程，提示 `⚠️ 推送失败，Changelog 已归档`

**输出确认：**
```
✅ Changelog 已生成
══════════════════════════════
  周期：{周期标识}（{N} 项待办，{N} 个里程碑）
  文档：{YYYYMMDD}-Changelog-{周期标识}
  归档：05-项目资料/
  链接：{wiki文档链接}
```

### --dry-run 预览模式

只执行步骤 1-4，展示完整草稿后结束，**不创建文档、不归档、不推送**。

底部显示：
```
── 预览模式，未写入 ──
使用 pmo-changelog 正式生成并归档
使用 pmo-changelog --export <文件名> 导出到本地
```

## 异常处理

| 场景 | 处理方式 |
|------|------|
| 无当前项目 | 提示「请先执行 pmo-use <项目名>」 |
| 指定范围内无完成数据 | 展示空 Changelog，提示「本周期无已完成待办/里程碑」 |
| Base 查询失败 | 显示警告，询问是否使用空数据继续 |
| 里程碑 ID 不存在 | 提示「找不到里程碑 {ID}，请通过 pmo-milestone 查看可用 ID」 |
| Wiki 归档失败（重试耗尽） | 提示 `❌ 归档失败` + `→ 请执行 pmo-archive <导出文件路径> 手动归档`（见 CLAUDE.md 人工介入出口） |
| --send 推送失败 | 提示 ⚠️，不影响归档结果 |
| wikiNodeTokens 缺少 05-项目资料 | 提示「⚠️ 缺少 05-项目资料 目录节点，改为归档到 99-归档/」 |
| --since 日期晚于今天 | 提示「起始日期不能晚于今天」 |

## 边缘情况

| 场景 | 处理方式 |
|------|------|
| 同一内容被重复完成 | 按完成日期最新的一条展示，其余忽略 |
| 负责人字段为空 | 显示 `@（未分配）` |
| 里程碑跨多个周期 | 按实际完成日期归入对应周期 |
