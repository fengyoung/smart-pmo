---
name: pmo-use
version: 1.0.0
description: "切换当前项目上下文。根据项目名从 ~/.smart-pmo/registry/ 加载配置，后续所有 pmo-* 命令操作目标项目。支持 -g 全局写入持久化。"
metadata:
  requires:
    bins: []
  depends_on: []
---

# pmo-use — 切换当前项目

## 执行方式

```bash
# 切换当前项目（默认当前会话有效）
claude pmo-use <项目名>

# 全局持久化写入（其他终端也生效）
claude pmo-use <项目名> -g
```

## 执行流程

1. 检查 `~/.smart-pmo/registry/<项目名>.json` 是否存在
2. 如果不存在 → 提示：`项目 "<项目名>" 未注册，请先运行 pmo-init`
3. 如果存在，读取配置并展示摘要：

```
✅ 已切换至: {项目名} ({代号})

项目经理: {姓名}
待办: {N} | 里程碑: {N}

使用 pmo-list 查看所有项目
```

4. 设置上下文：
   - 无 `-g`：设置 `SMART_PMO_CURRENT` 环境变量
   - 有 `-g`：写入 `~/.smart-pmo/current` 文件

## 后续 Skill 读取上下文规则

```
优先级：
1. $SMART_PMO_CURRENT 环境变量（最高）
2. ~/.smart-pmo/current 文件（兜底）
3. 以上都没有 → 提示"请先执行 pmo-use"
```
