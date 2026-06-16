---
name: pmo-health
version: 1.6.0
description: "项目健康检查：诊断当前项目的配置完整性、Base/Wiki 连通性、待处理队列积压、配置版本等，输出类 brew doctor 的健康报告。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-wiki
---

# pmo-health — 项目健康检查

> 一键诊断项目配置和数据层的健康状态，快速定位潜在问题，适合排查 pmo-* 命令异常时使用，或定期作为系统自检。

## 执行方式

```bash
# 当前项目完整健康检查
claude pmo-health

# 检查所有已注册项目（active 和 archived）
claude pmo-health --all

# 仅检查配置，跳过网络连通性（快速模式）
claude pmo-health --config-only
```

## 前置条件

无强制前置条件。`--all` 模式不需要设置当前项目；默认模式需要当前项目已通过 `pmo-use` 设置。

**Base 读操作超时遵循 CLAUDE.md 公共配置（单次 20s，并发 30s）。所有飞书 API 写操作遵循公共错误重试策略：3 次指数退避重试（1s/3s/5s）。**

## 执行流程

### 第1步：确定检查目标

- 默认：读取 `~/.smart-pmo/current` 加载当前项目
- `--all`：遍历 `~/.smart-pmo/registry/` 下所有 `.json` 文件（包含 archived 项目）
- `--config-only`：跳过第3步的网络连通性检查

### 第2步：逐项检查

对每个目标项目，依次执行以下检查：

#### 检查①：配置完整性

读取 `~/.smart-pmo/registry/{project_id}.json`，验证：

| 字段 | 是否必填 | 说明 |
|------|----------|------|
| `project.name` | ✅ 必填 | 项目名称不能为空 |
| `larkResources.baseAppToken` | ✅ 必填 | Base token |
| `larkResources.baseTableIds.todos` | ✅ 必填 | 待办表 ID |
| `larkResources.baseTableIds.milestones` | ✅ 必填 | 里程碑表 ID |
| `larkResources.baseTableIds.meetingIndex` | ✅ 必填 | 会议索引表 ID |
| `larkResources.wikiSpaceId` | ✅ 必填 | 知识空间 ID |
| `larkResources.wikiNodeTokens` | 建议 | 6 个标准目录节点 |
| `larkResources.chatIds` | 建议 | 项目群（推送功能依赖） |
| `team.pm.openId` | 建议 | 项目经理 openId |

结果：
- ✅ 全部必填字段存在 → `配置完整`
- ⚠️ 缺少建议字段 → `配置完整，但缺少建议字段：{字段列表}`
- ❌ 缺少必填字段 → `配置不完整，缺少：{字段列表}`

#### 检查②：配置版本

检查 `schemaVersion` 字段：

| 情况 | 结果 |
|------|------|
| 不存在 → 视为 1.0 | ⚠️ 配置版本过旧（1.0），建议迁移至 1.1 |
| == 当前最新（1.1）| ✅ 配置版本 v1.1（最新）|
| < 当前版本 | ⚠️ 配置版本 v{旧}，建议迁移至 v{新} |
| > 当前版本 | ❌ 配置版本 v{新}，高于当前 Smart-PMO 支持版本，请升级 Smart-PMO |

#### 检查③：Base 连通性（非 --config-only 模式）

通过 `lark-base` 分别查询三张表（各 limit=1）：

- 待办表 → ✅ / ❌
- 里程碑表 → ✅ / ❌
- 会议索引表 → ✅ / ❌

输出：`✅ Base 连通（3/3 表正常，待办 {N} 条）` 或 `⚠️ Base 连通（{N}/3 表正常）` 或 `❌ Base 连接失败`

超时阈值：每张表 20s（见 CLAUDE.md 超时配置）

#### 检查④：Wiki 连通性（非 --config-only 模式）

通过 `lark-wiki` 获取知识空间基本信息（不读取内容），验证空间可达：

- ✅ Wiki 知识空间可达（{N} 个目录节点）
- ⚠️ Wiki 可达，但节点数 {N}/6（缺少部分标准目录）
- ❌ Wiki 连接失败（{错误信息}）

同时检查 `wikiNodeTokens` 中的 6 个标准目录是否都有对应节点 token。

#### 检查⑤：待处理队列积压

检查 `~/.smart-pmo/` 下四个待处理目录（详见 [`_shared/pending-queue-check.md`](../_shared/pending-queue-check.md)）：

| 目录 | 积压数 | 结果 |
|------|-------|------|
| `.pending_backfill/` | 0 | ✅ 无积压 |
| `.pending_backfill/` | >0 | ⚠️ {N} 条待回填（执行 pmo-todo-followup 自动重试）|
| `.pending_orphan_meeting/` | >0 | ⚠️ {N} 条孤立会议记录（执行 pmo-meeting-process --index-only 补录）|
| `.pending_assignee/` | >0 | ⚠️ {N} 条待分配负责人（执行 pmo-todo-followup 查看并手动分配）|
| `.draft/` | >0（含过期）| ⚠️ {N} 个草稿（含 {N} 个超过 7 天）|

同时触发过期清理规则（详见 `_shared/pending-queue-check.md`）：
- `.draft/` 超过 7 天的草稿：提示删除
- `.pending_*` 超过 30 天的文件：提示确认是否清理

#### 检查⑥：项目状态一致性

- 当前项目（`~/.smart-pmo/current`）是否存在于 registry → 不存在则 ⚠️
- archived 项目是否还在 `pinned` 列表中 → ⚠️ 建议取消关注

### 第3步：生成健康报告

**单项目格式：**

```
🏥 健康检查 — {项目名} · {today}
══════════════════════════════════

① 配置完整性    ✅ 全部必填字段正常
                ⚠️ 建议补充：larkResources.chatIds（推送功能依赖）

② 配置版本      ✅ v1.1（最新）

③ Base 连通性   ✅ 3/3 表正常（待办 12 条，里程碑 3 条，会议 5 条）

④ Wiki 连通性   ✅ 知识空间可达（6/6 目录节点）

⑤ 待处理队列   ⚠️ .pending_backfill 有 2 条积压
                   → 执行 pmo-todo-followup 自动重试
               ✅ 其余队列无积压

⑥ 状态一致性   ✅ 无问题

────────────────────────────────────
总体状态：🟡 需关注（1 项警告）

快速操作：
  pmo-todo-followup   处理待处理队列
  pmo-info            查看项目详情
```

**`--all` 模式格式（一行一个项目）：**

```
🏥 全项目健康检查 · {today}
══════════════════════════════════

项目                  配置   Base   Wiki   队列   整体
────────────────────────────────────────────────────
XRay（active）         ✅     ✅     ✅    ⚠️2    🟡
RCA（active）          ✅     ✅     ⚠️    ✅     🟡
数据平台V2（archived） ✅     -      -      ✅     🟢

注：archived 项目跳过连通性检查（显示 -）
────────────────────────────────────────────────────
汇总：🟢 {N} 个正常 · 🟡 {N} 个需关注 · 🔴 {N} 个异常
```

### 健康等级定义

| 等级 | 含义 | 条件 |
|------|------|------|
| 🟢 正常 | 所有检查通过 | 所有项均为 ✅ |
| 🟡 需关注 | 存在警告 | 有 ⚠️ 项，无 ❌ 项 |
| 🔴 异常 | 存在严重问题 | 有 ❌ 项（配置不完整或连接失败） |

## 异常处理

| 场景 | 处理方式 |
|------|------|
| 无当前项目（非 --all 模式）| 提示「请先执行 pmo-use <项目名>」 |
| registry 目录不存在 | 提示「Smart-PMO 尚未初始化，请先执行 pmo-init」 |
| 某项目 JSON 解析失败 | 标注 ❌ 配置文件损坏，跳过该项目其余检查 |
| Base 查询网络超时 | 标注 ⚠️ 连通性检查超时，建议稍后重试 |
| `--all` 中某项目检查失败 | 标注 ❌，不影响其他项目的检查 |

## 边缘情况

| 场景 | 处理方式 |
|------|------|
| `~/.smart-pmo/` 目录不存在 | 提示「Smart-PMO 配置目录不存在，请先执行 setup.sh」 |
| 全部项目健康 | 展示 `🎉 所有项目状态正常` |
| 只有一个项目 | `--all` 与默认输出相同 |
