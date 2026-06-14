---
name: pmo-info
version: 1.2.0
description: "查看当前项目详细信息：成员、待办统计、里程碑进度、资源链接。从配置和 Base 实时拉取数据。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
---

# pmo-info — 查看当前项目详细信息

## 执行方式

```bash
claude pmo-info
```

## 前置条件

已通过 `pmo-use` 设置当前项目。

**所有 Base 读操作在网络超时或 5xx 错误时自动重试（1s/3s/5s 退避）。**

## 执行流程

### 公共：待处理队列检查

执行前先检查以下目录（按 CLAUDE.md 公共约定）：

| 目录 | 用途 | 处理方式 |
|------|------|---------|
| `~/.smart-pmo/.pending_backfill/` | 会议索引回填失败 | 自动重试回填，成功删文件 |
| `~/.smart-pmo/.pending_assignee/` | 负责人 API 写入失败 | 提示用户存在待分配记录 |
| `~/.smart-pmo/.draft/` | 用户取消的解析草稿 | 提示用户存在缓存草稿 |

过期清理规则见 CLAUDE.md「待处理队列过期清理规则」。

### 配置加载

1. 按 CLAUDE.md「读取当前项目配置」规则加载项目配置
2. 检查 `schemaVersion`，执行必要的版本迁移
3. 执行配置完整性校验（必填字段：`project.name`、`larkResources.baseAppToken`、`larkResources.baseTableIds.*`、`larkResources.wikiSpaceId`）

### 第1步：配置诊断

```
── 配置诊断 ──
schemaVersion: 1.1 ✅ | ⚠️ 版本过旧（当前 1.1，配置 1.0），建议迁移
必填字段: 全部通过 ✅ | ⚠️ 缺少: {字段列表}
Base 连接: 正常 ✅ | ⚠️ 连接失败
Wiki 连接: 正常 ✅ | ⚠️ 未验证
```

- Base 连接检查：通过 `lark-base` 查询待办表（limit=1）验证 token 有效
- 校验不通过不阻塞操作，但在终端明确展示警告

### 第2步：查询 Base 统计数据

通过 `lark-base` 查询 Base 统计数据（可并行查询）：
- 待办总数 / 待处理数 / 进行中数 / 已过期数（截止日期 < currentDate）
- 里程碑总数 / 已完成数 / 进行中数
- 会议记录总数

**查询容错：** Base 连接失败时统计数据展示 `-`，仅显示配置中的基础信息。

### 第3步：展示信息

```
📋 项目详情 — {项目名} ({代号})
═══════════════════════════════════

── 配置诊断 ──
版本: v1.1 ✅ | ⚠️ 版本过旧
字段检查: 全部通过 ✅ | ⚠️ 缺少 baseTableIds.todos
Base 连接: 正常 ✅ | ⚠️ 失败

── 基本信息 ──
项目名称：XRay拆修检测2026
代号：XRay
状态：active
创建日期：2026-06-09
最后修改：2026-06-09T15:20:00

── 团队 ──
项目经理：邹晨风
核心成员：8 人
  郭煜彬（产品决策者）
  冯扬（技术决策者）
  ...

── 待办统计 ──
总数：0 | 待处理：0 | 进行中：0 | 已过期：0

── 里程碑 ──
总数：0 | 已完成：0 | 进行中：0

── 会议 ──
总记录：0

── 资源链接 ──
📊 Base：https://feishu.cn/base/{baseAppToken}
📁 知识空间：https://feishu.cn/wiki/{wikiSpaceId}
💬 项目群 chat_id：{chatIds[0]}

── 快速操作 ──
pmo-todo-followup              查看/跟进待办
pmo-todo-followup --overdue    查看过期待办
pmo-search <关键词>             搜索待办/里程碑/会议
pmo-milestone                  查看里程碑
pmo-milestone --check          检查到期情况
pmo-milestone --add "名称" --due YYYY-MM-DD --owner @姓名  创建里程碑
pmo-meeting-process --minutes  处理飞书妙记
pmo-meeting-process --text     手动输入会议记录
pmo-todo-from-chat             从群消息提取待办
pmo-weekly-report              生成本周周报
pmo-archive --file <路径>      归档文件到知识库
pmo-use --archive              归档本项目
```

**资源链接拼接规则：**
- Base URL = `https://feishu.cn/base/{config.larkResources.baseAppToken}`
- Wiki URL = `https://feishu.cn/wiki/{config.larkResources.wikiSpaceId}`
- 如果这两个 token 都为空（初始化未完成），显示"资源尚未初始化，请运行 pmo-init"

## 异常处理

| 场景 | 处理 |
|------|------|
| 无当前项目 | 提示运行 pmo-use |
| Base 连接失败 | 仅显示配置中的基础信息，统计数据显示 "-" |
| 资源 token 为空 | 提示"资源尚未初始化，请运行 pmo-init" |
| schemaVersion 过新 | 提示"配置版本过新，请升级 Smart-PMO"，中断执行 |
| 成员列表为空 | 显示"未配置团队成员" |

## 边缘情况

| 场景 | 处理方式 |
|------|---------|
| 配置不完整（缺必填字段）| 显示缺少字段警告，不阻塞展示 |
| Base 连接失败 | 统计数据全部显示 `-`，仅展示配置信息 |
| 资源链接 token 为空 | 显示"资源尚未初始化" |
| schemaVersion 不存在 | 视为 1.0，提示建议迁移 |
| schemaVersion > 当前 | 提示升级 Smart-PMO，中断执行 |
| 项目状态为 archived | 标注 ⚠️ 已归档，提示可 pmo-use --activate 重新激活 |
