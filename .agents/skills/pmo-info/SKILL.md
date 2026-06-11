---
name: pmo-info
version: 1.1.0
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

## 执行流程

1. 读取当前项目配置 `~/.smart-pmo/registry/{current}.json`
2. 执行配置诊断：

```
── 配置诊断 ──
schemaVersion: 1.1 ✅ | ⚠️ 版本过旧（当前 1.1，配置 1.0），建议迁移
必填字段: 全部通过 ✅ | ⚠️ 缺少: {字段列表}
Base 连接: 正常 ✅ | ⚠️ 连接失败
Wiki 连接: 正常 ✅ | ⚠️ 未验证
```

3. 通过 `lark-base` 查询 Base 统计数据：
   - 待办总数 / 待处理数 / 进行中数 / 已过期数（截止日期 < currentDate）
   - 里程碑总数 / 已完成数 / 进行中数
   - 会议记录总数
4. 展示信息：

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
