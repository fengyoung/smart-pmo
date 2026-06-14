---
name: pmo-changelog
version: 0.1.0
description: "变更日志：汇总指定周期内已完成待办和里程碑为自然语言 Changelog，适合对外发布或团队同步。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-doc
---

# pmo-changelog — 变更日志（P3 规划中）

> ⚠️ **状态：规划中**。本 Skill 为 P3 优先级，等待实施资源。

## 规划功能

- 按周期（周/月/里程碑）汇总已完成的待办
- AI 自然语言生成格式化的 Changelog（参考 Keep a Changelog 规范）
- 分类：新增功能 / 修复 / 改进 / 其他
- 可选归档到知识库 `05-项目资料/`

## 实现要点

1. 从 Base 待办表拉取已完成记录（状态=已完成，按完成日期筛选）
2. AI 按内容语义分类到标准的 Changelog 类别
3. 生成飞书文档 + 可选 Markdown 导出
4. 与 pmo-stats 互补：stats 负责数字趋势，changelog 负责内容摘要

## 预计实现复杂度

低（约 100 行 SKILL.md）
