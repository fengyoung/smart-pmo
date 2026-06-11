# Smart-PMO Skill 测试 Checklist

> 用于每次修改 Skill 后进行回归测试
> 最后更新：2026-06-11

---

## 测试前提

- [ ] `lark-cli` 已安装且已认证
- [ ] 至少有一个已注册的测试项目（XRay）
- [ ] 测试项目的 Base、Wiki 空间可正常访问

---

## pmo-list

### Happy Path
- [ ] `claude pmo-list` — 列出所有项目，显示正确统计
- [ ] `claude pmo-list --active` — 仅显示 active 项目
- [ ] `claude pmo-list --config-only` — 仅显示配置信息，不查询 Base

### Edge Cases
- [ ] 无已注册项目时 — 显示空列表 + 提示 pmo-init
- [ ] Base 查询超时 — 对应项目显示 ⚠️，其他项目正常

---

## pmo-use

### Happy Path
- [ ] `claude pmo-use XRay` — 切换成功，显示摘要
- [ ] `claude pmo-use --list-members` — 正确列出成员

### Edge Cases
- [ ] 切换到不存在的项目 → 提示未注册
- [ ] 配置不完整的项目 → 显示缺少字段警告
- [ ] Base 连接失败 → 标注 ⚠️ 但仍允许切换

---

## pmo-info

### Happy Path
- [ ] `claude pmo-info` — 显示完整信息：诊断、成员、统计、链接
- [ ] Base 统计正确（待办/里程碑/会议数目）

### Edge Cases
- [ ] 无当前项目 → 提示运行 pmo-use
- [ ] Base 连接失败 → 优雅降级，统计显示 "-"

---

## pmo-meeting-process

### Happy Path
- [ ] `claude pmo-meeting-process --text` → 输入文本 → 正确提取
- [ ] 展示确认界面 → [确认写入] → 生成纪要 + 写入待办 + 写入会议索引
- [ ] 待办正确关联到会议记录（所属会议字段非空）

### Edge Cases
- [ ] 无当前项目 → 提示 pmo-use
- [ ] 无待办提取 → 询问是否仅写入纪要
- [ ] 成员名未匹配 → 正确标注 ⚠️，写入留空
- [ ] 重复执行同一会议 → 去重提示

### Failure Recovery
- [ ] 步骤④回填失败 → 写入 pending_backfill 文件
- [ ] 下次执行 pmo-* 命令时自动重试回填

---

## pmo-todo-from-chat

### Happy Path
- [ ] `claude pmo-todo-from-chat` — 增量读取所有群 → AI 提取 → 确认 → 写入
- [ ] 多群项目：两个群的消息均被读取，来源标注群名
- [ ] 优先级推断正确（紧急 → P0，尽快 → P1，默认 → P2）
- [ ] 各群 readPositions 分别正确推进

### Edge Cases
- [ ] 所有群均无新消息 → 提示无新消息
- [ ] 未提取到待办 → 提示未识别
- [ ] "已存在"条目不占用序号、不可选
- [ ] 某群写入失败 → 该群 readPosition 不推进，其他群正常

---

## pmo-todo-followup

### Happy Path
- [ ] `claude pmo-todo-followup` — 显示全部待办列表
- [ ] `claude pmo-todo-followup --mine` — 仅显示我的待办
- [ ] `claude pmo-todo-followup --overdue` — 仅显示过期
- [ ] `claude pmo-todo-followup --complete 1` — 行序号完成
- [ ] `claude pmo-todo-followup --all --complete TODO-003 --project XRay` — --all 模式下指定项目操作
- [ ] `claude pmo-todo-followup --complete TODO-003` — TODO-ID 完成
- [ ] `claude pmo-todo-followup --modify 1 --due 2026-07-01` — 修改截止日期

### Edge Cases
- [ ] 无效序号 → 提示无效
- [ ] --complete 但未先查看 → 自动查询后再完成
- [ ] --all 模式各项目序号独立

---

## pmo-milestone

### Happy Path
- [ ] `claude pmo-milestone` — 显示所有里程碑（含行序号）
- [ ] `claude pmo-milestone --check` — 显示到期检查结果
- [ ] `claude pmo-milestone --add "test" --due 2026-12-31 --owner @张三` — 新增
- [ ] `claude pmo-milestone --complete MILE-001` — 用 MILE-ID 标记完成
- [ ] `claude pmo-milestone --complete 2` — 用行序号标记完成
- [ ] `claude pmo-milestone --modify 1 --progress 75` — 用行序号修改进度

### Edge Cases
- [ ] 无里程碑 → 显示空列表
- [ ] 新增时负责人未匹配 → 留空并提示
- [ ] 用序号但未先查看 → 自动查看后再操作

---

## pmo-weekly-report

### Happy Path
- [ ] `claude pmo-weekly-report` — 生成本周周报
- [ ] `claude pmo-weekly-report --no-compare` — 不对比上周
- [ ] `claude pmo-weekly-report --send` — 生成后推送摘要卡片到项目群
- [ ] 逾期趋势等估算数据附注 `*估算` 标记

### Edge Cases
- [ ] 本周无会议 → 正常生成，会议部分显示"无"
- [ ] 已生成过本周周报 → 询问是否覆盖
- [ ] `--send` 推送失败 → 提示 ⚠️ 但周报已归档

---

## pmo-archive

### Happy Path
- [ ] `claude pmo-archive --file test.md --dir 03-需求文档` — 归档成功
- [ ] 文件自动添加日期前缀

### Edge Cases
- [ ] 文件不存在 → 提示检查路径
- [ ] 文件 >50MB → 提示压缩
- [ ] 不支持的格式 → 提示支持格式

---

## pmo-dashboard

### Happy Path
- [ ] `claude pmo-dashboard` — 显示所有关注项目概览
- [ ] 告警项正确检测并提示下钻
- [ ] 非关注但有告警项目正确展示

### Edge Cases
- [ ] pinned 为空 → 回退到所有 active 项目
- [ ] 无告警项 → 静默结束
- [ ] 单个项目 Base 查询失败 → 不影响其他项目

---

## pmo-today

### Happy Path
- [ ] `claude pmo-today` — 显示今日截止、过期待办、里程碑、今日会议
- [ ] `claude pmo-today --all` — 跨项目今日概览，按项目分组展示

### Edge Cases
- [ ] 今日无任何关注项 → 显示"今天没有需要特别关注的事项"+ 待处理总数
- [ ] Base 连接失败 → 对应项目显示 ⚠️，其他正常

---

## pmo-search

### Happy Path
- [ ] `claude pmo-search 接口` — 在当前项目搜索，显示来源字段
- [ ] `claude pmo-search 接口 --in todos` — 限定表范围
- [ ] `claude pmo-search 接口 --all` — 跨项目搜索
- [ ] `claude pmo-search 接口 --limit 50` — 每表最多返回 50 条
- [ ] 结果达到 limit 上限时显示"共 {total} 条"提示

### Edge Cases
- [ ] 无结果 → 显示搜索建议
- [ ] 无当前项目且未加 --all → 提示

---

## pmo-export

### Happy Path
- [ ] `claude pmo-export` — 导出当前项目全部表
- [ ] `claude pmo-export --format json` — JSON 格式导出
- [ ] `claude pmo-export --table todos` — 仅导出指定表

### Edge Cases
- [ ] 某表无记录 → 空文件（仅表头）
- [ ] 输出目录已存在 → 询问是否覆盖

---

## pmo-init

### Happy Path
- [ ] `claude pmo-init` → 交互式创建 → 全部成功
- [ ] 生成配置 schemaVersion 为 1.1
- [ ] `claude pmo-init --from XRay` → 模板克隆

### Edge Cases
- [ ] 项目名已注册且完整 → 提示已初始化
- [ ] 项目名已注册但不完整 → 断点恢复
- [ ] --from 源项目不存在 → 退回到交互式

---

## 集成测试场景

- [ ] 完整流程：pmo-init → pmo-use → pmo-info → 检查数据一致性
- [ ] 会议闭环：pmo-meeting-process → pmo-todo-followup 查看待办 → pmo-todo-followup --complete → 状态正确
- [ ] 群聊闭环：pmo-todo-from-chat → 写入成功 → readPositions 按群推进 → 再次执行无重复
- [ ] 多群场景：两个群都有新消息 → 均被提取 → 来源标注不同群名
- [ ] 周报闭环：多次操作后 → pmo-weekly-report --send → 统计数据正确 + 群消息发出
- [ ] 多项目切换：pmo-use A → pmo-list → pmo-use B → pmo-info → 数据隔离正确
- [ ] 断点恢复：pmo-meeting-process 模拟失败 → pending_backfill 写入 → 下次 pmo-info 自动重试
- [ ] 队列过期：手动将 pending_backfill 文件 failed_at 改为 31 天前 → 任一 pmo-* 执行时提示清理
