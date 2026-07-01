---
name: batch-meeting-process
version: 2.0.0
description: "批量会议纪要提取——匹配多个语音转写文件(.txt)，循环调用 pmo-meeting-process --no-confirm --local 为每个文件生成本地 .md 会议纪要。提取质量与单文件模式完全一致。"
metadata:
  requires:
    bins: []
  depends_on: []
---

# batch-meeting-process — 批量会议纪要提取

## 设计原则

本技能**不包含独立的提取逻辑**，而是对每个文件委托 `pmo-meeting-process --file <path> --no-confirm --local` 执行提取。

因此：
- 提取质量（ASR 校正、历史上下文、Prompt 模板）与单文件模式 **完全一致**
- `pmo-meeting-process` 的改进自动惠及批量模式
- 本技能只负责：**文件发现 → 用户确认 → 循环调用 → 进度反馈**

## 使用方式

```bash
# 处理 output 目录下所有转写文件
claude batch-meeting-process ./output/*.txt

# 处理指定日期的文件
claude batch-meeting-process ./output/20260615-*.txt
```

**参数说明：** 传入一个或多个文件路径（支持 glob 通配符展开），必须为 `.txt` 格式的语音转写文件。

## 执行流程

### 第 1 步：展开文件列表

- 使用 glob 展开输入参数匹配的所有文件路径
- 过滤出 `.txt` 后缀且实际存在的文件
- 过滤 `-笔记.txt`、`-备忘.txt` 等非会议转写文件（根据文件名前缀判断，只要是 `YYYYMMDD-*.txt` 格式的文件均可处理）
- 按文件名排序
- 输出文件清单让用户确认：
  ```
  📋 共匹配到 {N} 个文件，即将批量提取：
    1. ./output/会议A.txt
    2. ./output/会议B.txt
    ...
  [开始提取] [选择文件] [取消]
  ```
- 用户确认后进入提取阶段

### 第 2 步：循环调用 pmo-meeting-process

对用户确认的每个文件，执行：

```
pmo-meeting-process --file <path> --no-confirm --local
```

**调用说明：**
- `--no-confirm`：跳过交互确认，全自动处理
- `--local`：生成本地 `.md` 文件，同目录同名

**上下文增强（自动生效）：**
每个文件提取时，`pmo-meeting-process` 会自动：
1. 从 `~/.smart-pmo/asr-correction.json` 加载统一 ASR 校正表（全局本地资源）
2. 注入结构化 Prompt 模板
3. 加载项目成员信息（若有项目配置）

> 如需禁用上下文增强（纯文本提取），可改用：
> `pmo-meeting-process --file <path> --no-confirm --local`

### 第 3 步：进度反馈

处理过程中实时输出进度：

```
━━━ 处理进度 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ [1/5] 20260615-内部讨论-拍照3.0硬件部署与清洁棚进展.md
   → 提取到 6 项待办，3 项决策
   → 输出: ./output/20260615-内部讨论-拍照3.0硬件部署与清洁棚进展.md
⏳ [2/5] 部门周会-重质检核心周会...

…

━━━ 处理完成 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 成功提取 {N} 个文件
❌ 失败 {N} 个文件
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 文件不存在 | 跳过并提示 |
| 文件 >10MB | 跳过，提示文件过大 |
| 编码解析失败 | 尝试 GBK，失败则跳过 |
| 内容为空 | 跳过并提示 |
| 某文件提取失败 | 跳过该文件，继续处理其余，最终汇总失败列表 |
| pmo-meeting-process 未找到项目配置 | 降级为纯文本提取，继续处理（见 --local 模式说明） |
