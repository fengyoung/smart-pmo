---
name: pmo-todo-followup
version: 1.6.0
description: "待办事项跟进：查看、筛选、标记完成、修改负责人/截止日期。支持 --mine/--overdue/--status/--all/--complete/--modify 参数。--all 模式下支持 --project 指定目标项目，无需切换上下文。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-im
    - lark-contact
---

# pmo-todo-followup — 待办跟进

## 执行方式

```bash
# 查看全部待办（默认）
claude pmo-todo-followup

# 只看我的待办
claude pmo-todo-followup --mine

# 只看已过期
claude pmo-todo-followup --overdue

# 按状态筛选
claude pmo-todo-followup --status 待处理

# 跨所有关注项目查看
claude pmo-todo-followup --all

# 标记完成（支持 TODO-ID 或列表中的行序号）
claude pmo-todo-followup --complete 3
claude pmo-todo-followup --complete TODO-003
claude pmo-todo-followup --complete 1 3 5
claude pmo-todo-followup --complete TODO-003 TODO-005

# 批量完成我的全部待处理待办（需确认）
claude pmo-todo-followup --complete --all-mine

# 修改待办（支持 TODO-ID 或行序号）
claude pmo-todo-followup --modify 3 --assign @李四
claude pmo-todo-followup --modify TODO-003 --due 2026-06-20

# --all 模式下直接操作指定项目（无需切换上下文）
claude pmo-todo-followup --all --complete TODO-003 --project XRay
claude pmo-todo-followup --all --modify TODO-003 --due 2026-06-20 --project XRay
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

1. 必填字段检查：`project.name`、`larkResources.baseAppToken`、`larkResources.baseTableIds.todos` 不为空
2. 若任一必填字段缺失 → 提示「配置不完整，缺少: {字段列表}。建议重新运行 pmo-init 修复」

### 错误重试策略

所有 Base 写操作遵循公共错误重试策略（见 CLAUDE.md）：3 次指数退避重试（1s/3s/5s）。

### 待处理队列检查

> 📋 详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)。执行开始时检查 `~/.smart-pmo/` 下的四个待处理目录，特别关注：
> - `.pending_assignee/` — 其他 Skill 写入失败的负责人分配，提示用户手动处理
> - `.pending_backfill/` — 会议索引回填失败的待办，自动重试关联

### 日期计算

> 📅 详见 [`_shared/date-calc-rules.md`](../_shared/date-calc-rules.md)。模糊时间表达（如「尽快」「下周X」）按共享模块规则计算。

## 执行流程

### 查看待办

1. 从 Base「待办事项」表读取所有记录
2. 按参数过滤（--mine / --overdue / --status）
   - `--mine`：先通过 `lark-contact +me` 获取当前用户 openId，再筛选负责人字段
   - `--all`：遍历 `~/.smart-pmo/pinned` 项目列表（若 pinned 为空则用所有 active 项目），并行查询每个项目的 Base，按项目分组展示
3. 按截止日期排序，分组展示，**每行附带行序号**（从 1 开始，跨分组连续）

**展示格式（单项目）：**

```
📋 待办列表 — {项目名} ({N} 项)
═══════════════════════════════
⚠️ 已过期（{N} 项）:
┌──┬──────┬─────────────────┬──────────┬──────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │
├──┼──────┼─────────────────┼──────────┼──────────┤
│1 │ 003  │ 确定UI方案       │ 李四     │ 06-06 ‼️ │
│2 │ 007  │ 发送测试报告     │ 张三     │ 06-07 ‼️ │
└──┴──────┴─────────────────┴──────────┴──────────┘

待处理（{N} 项）:
┌──┬──────┬─────────────────┬──────────┬──────────┬────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──┼──────┼─────────────────┼──────────┼──────────┼────────┤
│3 │ 001  │ Sprint评审准备   │ 张三     │ 06-12    │ P0     │
│4 │ 009  │ 更新设计稿       │ 王五     │ 06-15    │ P2     │
└──┴──────┴─────────────────┴──────────┴──────────┴────────┘

操作提示（可用序号或 TODO-ID）：
  pmo-todo-followup --complete 1        标记第1条完成
  pmo-todo-followup --complete 1 2 3    批量标记完成
  pmo-todo-followup --modify 3 --due 2026-06-20
  pmo-search <关键词>                   搜索待办/里程碑/会议
```

**`--all` 模式的展示格式（按项目分组，序号跨项目独立）：**

```
📋 全部项目待办 ({N} 个项目)
══════════════════════════════════

◆ {项目名} ({代号}) — 过期 {N} | 待处理 {N}
┌──┬──────┬─────────────────┬──────────┬──────────┬────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──┼──────┼─────────────────┼──────────┼──────────┼────────┤
│1 │ 003  │ 确定UI方案       │ 李四     │ 06-06 ‼️ │ P1     │
└──┴──────┴─────────────────┴──────────┴──────────┴────────┘

◆ {项目名2} ({代号2}) — 过期 {N} | 待处理 {N}
┌──┬──────┬─────────────────┬──────────┬──────────┬────────┐
│# │ ID   │ 内容             │ 负责人   │ 截止日期  │ 优先级 │
├──┼──────┼─────────────────┼──────────┼──────────┼────────┤
│1 │ 012  │ 接口文档更新     │ 赵六     │ 06-08 ‼️ │ P1     │
└──┴──────┴─────────────────┴──────────┴──────────┴────────┘
```

**`--all` 模式下使用 `--complete` / `--modify`**：

有三种操作方式，按优先级依次：
1. **使用 `--project <项目名>`**（推荐）：直接指定目标项目，无需切换上下文
   ```
   pmo-todo-followup --all --complete TODO-003 --project XRay
   pmo-todo-followup --all --modify TODO-003 --due 2026-06-20 --project XRay
   ```
2. **使用 TODO-ID 且 ID 全局唯一**：自动从所有项目查找该 ID 所属项目，找到唯一匹配时直接操作
3. **使用行序号**：序号在 --all 模式下各项目独立（从 1 开始），需搭配 `--project` 指定目标项目；否则提示先切换上下文

### 标记完成 (--complete)

**参数解析：**
- 纯数字（如 `3`、`1 3 5`）→ 解析为展示列表中的行序号，从上次展示的列表映射到对应 TODO-ID
- `TODO-XXX` 格式 → 直接使用该 ID
- 混合使用均支持：`--complete 1 TODO-005 3`

**行序号生命周期（⚠️ 重要）：**
行序号仅在**当次展示的列表**中有效，以下情况会导致序号失效：
- 任何会修改 Base 数据的操作（写入待办、标记完成、修改字段）
- 切换项目（pmo-use）
- 新的一次 Base 查询

如果使用序号操作但本次会话中未先查看过列表（无法映射序号 → ID），**自动先重新执行一次列表查询**，再继续完成操作，并提示：
```
ℹ️ 序号映射已刷新（Base 可能已变更），以最新列表为准：
   [展示刷新后的列表]
```

**单个或多个：**
1. 通过 `lark-base update_record` 逐条更新：
   - 状态 = "已完成"
   - 完成日期 = 当天（currentDate）
2. 输出确认："✅ TODO-{ID} 已标记为完成"（每条一行）

**批量完成我的全部待处理（--complete --all-mine）：**
1. 查询负责人=当前用户、状态=待处理 的所有待办
2. 展示待完成列表，要求用户确认："以上 {N} 条全部标记为完成？[y/N]"
3. 确认后批量更新，输出汇总结果

### 修改待办 (--modify)

**参数解析**：同 `--complete`，支持行序号或 TODO-ID（行序号生命周期规则相同）。

1. 通过 `lark-base update_record` 更新指定字段：
   - `--assign @姓名`：解析姓名为 openId（走成员名称解析逻辑）
   - `--due YYYY-MM-DD`：修改截止日期
   - `--priority P0/P1/P2/P3`：修改优先级（仅接受 P0/P1/P2/P3，无效值提示并中断）
   - `--status 状态值`：修改状态（仅接受 待处理/进行中/已完成/已取消，无效值提示并中断）
2. 输出确认
