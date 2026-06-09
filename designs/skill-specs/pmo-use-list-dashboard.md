# pmo-use / pmo-list / pmo-pin / pmo-dashboard — 项目上下文管理 Skill 设计

> P0 优先级 | 多项目切换与管理

---

## pmo-use — 切换当前项目

### 调用方式

```bash
claude pmo-use <项目名> [-g]
```

| 参数 | 说明 |
|------|------|
| `<项目名>` | 必填，对应 `~/.smart-pmo/registry/<项目名>.json` |
| `-g` | 可选，全局写入 `~/.smart-pmo/current`，否则仅设环境变量 |

### 执行流程

```
① 检查 ~/.smart-pmo/registry/<项目名>.json 是否存在
   └→ 不存在 → 提示"项目未注册，请先运行 pmo-init"
② 读取配置，展示项目摘要
③ 设定上下文：
   └→ 无 -g → export SMART_PMO_CURRENT=<项目名>
   └→ 有 -g → 写入 ~/.smart-pmo/current
④ 输出确认：
   ┌─────────────────────────────────────┐
   │ ✅ 已切换至: 智能客服平台 (ICS)       │
   │                                     │
   │ 项目经理: 张三   待办: 8 进行中: 3   │
   │ 里程碑: 4       已过期: 2            │
   │                                     │
   │ 使用 pmo-info 查看详细信息           │
   └─────────────────────────────────────┘
```

### pmo-use 补全

- 支持 Tab 补全项目名（基于 registry 中的文件名）

---

## pmo-list — 列出所有项目

### 调用方式

```bash
claude pmo-list
```

### 执行流程

```
① 遍历 ~/.smart-pmo/registry/*.json
② 读取每个项目的 project.name, project.status, team.pm.name
③ 显示表格：

   当前项目 → 智能客服平台 (ICS) ※ 关注

   ┌──────────────┬────────┬────────┬──────────┬───────┐
   │ 项目名称      │ 代号   │ 状态   │ 项目经理 │ 待办  │
   ├──────────────┼────────┼────────┼──────────┼───────┤
   │ 智能客服平台  │ ICS    │ active │ 张三     │ 8     │
   │ 数据平台V2   │ DP2    │ active │ 李四     │ 12    │
   │ 旧版CRM      │ CRM    │ archived │ 王五    │ 0     │
   └──────────────┴────────┴────────┴──────────┴───────┘

   使用 pmo-use <项目名> 切换项目
   使用 pmo-pin <项目名>  关注项目
```

---

## pmo-pin / pmo-unpin — 关注项目管理

### 调用方式

```bash
claude pmo-pin <项目名...>
claude pmo-unpin <项目名...>
```

### 执行流程

```
pmo-pin project-a project-b
├→ 读取 ~/.smart-pmo/pinned
├→ 将 project-a 和 project-b 加入列表（去重）
└→ 写回 pinned 文件

pmo-unpin project-b
├→ 从 pinned 列表中移除 project-b
└→ 写回 pinned 文件
```

---

## pmo-dashboard — 多项目概览

### 调用方式

```bash
claude pmo-dashboard
```

### 执行流程

```
① 读取 ~/.smart-pmo/pinned 获取关注项目列表
   如果 pinned 为空，默认读取所有 active 项目
② 遍历每个关注项目：
   ├→ 读取 registry/<项目名>.json
   ├→ 通过 lark-base 查询待办统计
   │   ├→ 待处理数（状态=待处理）
   │   ├→ 进行中数（状态=进行中）
   │   ├→ 已过期数（截止日期<今天 且 状态≠已完成/已取消）
   │   └→ 今日截止数（截止日期=今天 且 状态≠已完成/已取消）
   └→ 通过 lark-base 查询里程碑统计
       ├→ 总里程碑数
       ├→ 已完成数
       ├→ 即将到期数（计划日期7天内 且 状态≠已完成）
       └→ 已过期数（计划日期<今天 且 状态≠已完成）
③ 输出概览（支持分页）：

   📊 项目概览 · 2026-06-09
   ═══════════════════════════════════════
   重点关注（2 个项目）：

   ◆ 智能客服平台 (ICS)
     待办：待处理 5 | 进行中 3 | ⚠️ 过期 2
     里程碑：已完成 2/4 | ⚠️ 即将到期 1

   ◆ 数据平台V2 (DP2)
     待办：待处理 8 | 进行中 4 | ⚠️ 过期 1
     里程碑：已完成 1/3 | ⚠️ 即将到期 2

   使用 pmo-use <项目名> 查看详情
   使用 pmo-pin <项目名>  关注更多项目
```

---

## 数据来源说明

| Skill | 数据来源 | 飞书调用 |
|-------|---------|---------|
| pmo-list | 本地 registry 文件 | 无（全部本地）|
| pmo-use | 本地 registry 文件 | 无 |
| pmo-pin | 本地 pinned 文件 | 无 |
| pmo-dashboard | registry + lark-base 查询 | `lark-base list_record`（每个项目1次）|
