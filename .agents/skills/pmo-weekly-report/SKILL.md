---
name: pmo-weekly-report
version: 1.0.0
description: "自动生成项目周报。从 Base 统计本周会议、待办完成率、里程碑进展，生成格式化周报文档并归档到知识库。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-base
    - lark-doc
    - lark-wiki
    - lark-im
---

# pmo-weekly-report — 周报生成

## 执行方式

```bash
# 生成本周周报
claude pmo-weekly-report

# 生成指定周的周报
claude pmo-weekly-report --week YYYY-MM-DD
```

## 执行流程

1. 确定周范围（本周或 --week 指定）
2. 从 Base 收集数据：
   - 本周会议记录
   - 本周新增/完成/逾期待办的统计
   - 里程碑状态
3. AI 整理周报内容
4. 展示草稿给用户确认
5. 用户确认后：
   - 通过 `lark-doc` 创建周报文档
   - 通过 `lark-wiki` 归档到 `02-周报/`
   - 通过 `lark-im` 推送摘要到项目群

## 设计文档

完整格式见：`../../designs/skill-specs/pmo-weekly-report.md` 和 `../../templates/weekly-report-template.md`
