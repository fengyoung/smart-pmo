---
name: pmo-info
version: 1.0.0
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
2. 通过 `lark-base` 查询 Base 统计数据：
   - 待办总数 / 待处理数 / 进行中数 / 已过期数
   - 里程碑总数 / 已完成数 / 进行中数
   - 会议记录总数
3. 展示信息：

```
📋 项目详情 — {项目名} ({代号})
═══════════════════════════════════

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
📊 Base：https://zhuanspirit.feishu.cn/base/{token}
📁 知识空间：飞书 Wiki #{space_id}
💬 项目群：{chat_id}

操作：
  pmo-todo-followup    查看/跟进待办
  pmo-milestone        查看里程碑
  pmo-meeting-process  处理会议纪要
```

## 异常处理

| 场景 | 处理 |
|------|------|
| 无当前项目 | 提示运行 pmo-use |
| Base 连接失败 | 仅显示配置中的基础信息 |
