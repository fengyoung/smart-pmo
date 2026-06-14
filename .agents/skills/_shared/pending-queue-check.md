# 公共：待处理队列检查

> **适用范围**：所有涉及 Base 写入或飞书 API 操作的 `pmo-*` Skill
> **排除范围**：纯本地文件操作 Skill（pmo-pin、pmo-unpin、pmo-list、pmo-use 等）

---

## 检查流程

执行前先检查以下四个目录（按 CLAUDE.md 公共约定）：

| 目录 | 用途 | 处理方式 |
|------|------|---------|
| `~/.smart-pmo/.pending_backfill/` | 会议索引产出待办回填失败 | 自动重试回填，成功删文件；重试耗尽见 CLAUDE.md 人工介入出口 |
| `~/.smart-pmo/.pending_orphan_meeting/` | 孤立会议记录（步骤②成功+步骤③全部失败）| 提示用户执行 `--index-only` 补录 |
| `~/.smart-pmo/.pending_assignee/` | 负责人 API 写入失败 | pmo-todo-followup 执行时提示用户手动分配 |
| `~/.smart-pmo/.draft/` | 用户取消的解析草稿 | pmo-meeting-process 执行同文件时提示恢复 |

## 过期清理规则

| 目录 | 过期阈值 | 过期处理方式 |
|------|---------|------------|
| `.pending_backfill/` | 30 天 | 提示"存在 30 天前的未完成回填记录，可能已失效，是否清除？[y/N]" |
| `.pending_orphan_meeting/` | 30 天 | 提示"存在 30 天前的孤立会议记录，是否清除？[y/N]" |
| `.pending_assignee/` | 30 天 | 提示"存在 30 天前的待分配负责人记录，可能已过期，是否清除？[y/N]" |
| `.draft/` | 7 天 | 提示"检测到过期草稿（{date}），是否删除？[y/N]" |

检查逻辑：读取文件中的 `failed_at` / `cached_at` 字段，与 `currentDate` 比较。文件缺少时间戳则按文件 mtime 计算。过期记录不自动删除，需用户确认。

## 引用方式

各 Skill 在「执行流程」章节开头加入以下一行引用：

```markdown
### 公共：待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](_shared/pending-queue-check.md)。检查 `.pending_backfill/`、`.pending_orphan_meeting/`、`.pending_assignee/`、`.draft/` 四个目录。
```
