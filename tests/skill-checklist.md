# Smart-PMO Skill 测试 Checklist

> 用于每次修改 Skill 后进行回归测试
> 最后更新：2026-06-14

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
- [ ] `claude pmo-info` — 显示完整信息：诊断、成员、统计、链接、快速操作
- [ ] Base 统计正确（待办/里程碑/会议数目）
- [ ] 配置诊断正确（schemaVersion、必填字段、Base连接、Wiki连接）
- [ ] 资源链接正确拼接（Base URL / Wiki URL）
- [ ] active 项目 vs archived 项目状态展示正确

### Edge Cases
- [ ] 无当前项目 → 提示运行 pmo-use
- [ ] Base 连接失败 → 优雅降级，统计显示 "-"
- [ ] 资源 token 为空 → 显示"资源尚未初始化，请运行 pmo-init"
- [ ] schemaVersion 不存在 → 视为 1.0，提示建议迁移
- [ ] schemaVersion 过新 → 提示升级 Smart-PMO，中断执行
- [ ] 配置不完整（缺必填字段）→ 显示警告，不阻塞展示
- [ ] 成员列表为空 → 显示"未配置团队成员"
- [ ] 项目状态为 archived → 标注 ⚠️ 已归档

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
- [ ] `claude pmo-milestone` — 显示所有里程碑（含行序号），已完成分组默认折叠
- [ ] `claude pmo-milestone --all` — 显示全部里程碑（含所有已完成）
- [ ] `claude pmo-milestone --check` — 显示到期检查结果（过期 + 即将到期）
- [ ] `claude pmo-milestone --add "test" --due 2026-12-31 --owner @张三` — 新增
- [ ] `claude pmo-milestone --add "test" --due 2026-12-31 --owner @张三 --progress 30 --status 进行中 --desc "说明"` — 新增（完整参数）
- [ ] `claude pmo-milestone --complete MILE-001` — 用 MILE-ID 标记完成，自动填写实际日期+补齐进度
- [ ] `claude pmo-milestone --complete 2` — 用行序号标记完成
- [ ] `claude pmo-milestone --modify 1 --progress 75` — 用行序号修改进度
- [ ] `claude pmo-milestone --modify MILE-001 --status 已延期` — 修改状态
- [ ] `claude pmo-milestone --modify 1 --desc "更新描述"` — 修改描述

### Edge Cases
- [ ] 无里程碑 → 显示空列表 + 新增提示
- [ ] 新增时负责人未匹配 → 留空并提示
- [ ] 用序号但未先查看 → 自动查看后再操作
- [ ] 无效序号 → 提示超出范围
- [ ] MILE-ID 不存在 → 提示并中断
- [ ] 无效状态值 → 提示可选值并中断
- [ ] 无效进度值 → 提示需为 0~100
- [ ] Base 写入失败（重试耗尽）→ 提示手动处理

---

## pmo-weekly-report

### Happy Path
- [ ] `claude pmo-weekly-report` — 生成本周周报
- [ ] `claude pmo-weekly-report --week YYYY-MM-DD` — 生成指定周周报
- [ ] `claude pmo-weekly-report --dry-run` — 预览模式，不写入
- [ ] `claude pmo-weekly-report --no-compare` — 不对比上周
- [ ] `claude pmo-weekly-report --send` — 生成后推送摘要卡片到项目群
- [ ] `claude pmo-weekly-report --send --chat-id <id>` — 推送到指定群
- [ ] 逾期趋势等估算数据附注 `*估算` 标记
- [ ] 确认界面支持「修改」反馈循环

### Edge Cases
- [ ] 本周无会议 → 正常生成，会议部分显示「本周无会议记录」
- [ ] 本周无新增/完成待办 → 显示 0，不影响生成
- [ ] 无上周数据 → 显示「首次生成，暂无上周数据」
- [ ] 已生成过本周周报 → 检测重复，询问是否继续
- [ ] `--send` 推送失败 → 提示 ⚠️ 但周报已归档
- [ ] Base 查询超时 → 对应指标显示 `-`，不阻塞
- [ ] Wiki 归档失败（重试耗尽）→ 提示手动归档
- [ ] wikiNodeTokens 缺少 02-周报 → 提示配置问题

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

## pmo-pin / pmo-unpin

### Happy Path
- [ ] `claude pmo-pin <项目名>` — 关注单个项目
- [ ] `claude pmo-pin <项目1> <项目2>` — 批量关注
- [ ] `claude pmo-unpin <项目名>` — 取消关注
- [ ] `claude pmo-unpin <项目1> <项目2>` — 批量取消关注
- [ ] 无参数 `pmo-pin` — 显示当前关注列表 + 使用提示
- [ ] 无参数 `pmo-unpin` — 显示当前关注列表 + 使用提示

### Edge Cases
- [ ] 项目名未注册 → ⚠️ 提示未注册，跳过，其余正常
- [ ] 重复关注 → 静默跳过，标注「已在关注列表中」
- [ ] 取消关注未关注的项目 → 静默跳过
- [ ] pinned 文件不存在 → 视为空列表，正常创建
- [ ] 全部移除后为空 → 提示「pmo-dashboard 将展示所有 active 项目」

---

## pmo-dashboard

### Happy Path
- [ ] `claude pmo-dashboard` — 显示所有关注项目概览
- [ ] 告警项正确检测并提示下钻
- [ ] 非关注但有告警项目正确展示
- [ ] 无告警时显示「所有项目状态正常」
- [ ] 定时巡检提示 `/loop 30m pmo-dashboard`

### Edge Cases
- [ ] pinned 为空 → 回退到所有 active 项目
- [ ] 无任何项目（无 pinned 且无 active）→ 提示创建项目
- [ ] 无告警项 → 静默结束
- [ ] 单个项目 Base 查询失败 → 标注 ⚠️ 查询失败，其余正常
- [ ] 所有项目 Base 查询失败 → 展示失败汇总 + 排查建议
- [ ] 下钻选项 1 → 执行 pmo-todo-followup --all --overdue
- [ ] 下钻选项 2 → 切换到最严重项目 + pmo-todo-followup --overdue

---

## pmo-today

### Happy Path
- [ ] `claude pmo-today` — 显示今日截止、过期待办、里程碑、今日会议
- [ ] `claude pmo-today --all` — 跨项目今日概览，按项目分组展示
- [ ] 里程碑即将到期且进度 <30% → 额外标注 ⚠️ 进度
- [ ] 今日有会议已有纪要 → 标注「已有纪要: [查看]」

### Edge Cases
- [ ] 今日无任何关注项 → 显示"今天没有需要特别关注的事项"+ 待处理总数
- [ ] Base 连接失败 → 对应项目显示 ⚠️，其他正常
- [ ] --all 时 pinned 为空 → 回退到所有 active 项目
- [ ] 所有项目 Base 查询失败 → 展示失败汇总 + 排查建议

---

## pmo-search

### Happy Path
- [ ] `claude pmo-search 接口` — 在当前项目搜索，显示来源字段
- [ ] `claude pmo-search 接口 --in todos` — 限定表范围
- [ ] `claude pmo-search 接口 --all` — 跨项目搜索
- [ ] `claude pmo-search 接口 --limit 50` — 每表最多返回 50 条
- [ ] `claude pmo-search 接口 --since 2026-05-01 --until 2026-06-01` — 时间范围过滤
- [ ] `claude pmo-search 接口 --owner @张三` — 按负责人过滤
- [ ] 结果达到 limit 上限时显示"共 {total} 条"提示

### Edge Cases
- [ ] 无结果 → 显示搜索建议（更短关键词 / --all / 检查时间范围）
- [ ] 无当前项目且未加 --all → 提示运行 pmo-use 或加 --all
- [ ] 关键词为空 → 提示"请输入搜索关键词"
- [ ] --limit 超过 100 → 自动截断为 100
- [ ] 某表查询失败 → 跳过该表，展示其他成功结果
- [ ] --all 时 pinned 为空 → 回退到所有 active 项目
- [ ] 所有项目所有表均失败 → 提示排查建议
- [ ] --owner 姓名未匹配 → 提示 ⚠️ 未找到，按关键词搜索全部

---

## pmo-export

### Happy Path
- [ ] `claude pmo-export` — 导出当前项目全部表（CSV UTF-8 BOM）
- [ ] `claude pmo-export --format json` — JSON 格式导出
- [ ] `claude pmo-export --table todos` — 仅导出指定表
- [ ] `claude pmo-export --table todos,milestones` — 导出多张表
- [ ] `claude pmo-export --output ~/Desktop/export` — 指定输出路径
- [ ] 引用字段正确展开（人员→姓名，关联→编号ID）
- [ ] `export_meta.json` 汇总文件正确生成

### Edge Cases
- [ ] 某表无记录 → 空文件（CSV仅表头 / JSON空数组）
- [ ] 输出目录已存在 → 询问覆盖，N 则自动追加 `-N` 后缀
- [ ] 输出目录无写权限 → 提示权限错误
- [ ] 数据量 >5000 条 → 分批拉取 + 进度条
- [ ] 某表查询失败 → 跳过该表，继续导出其他表
- [ ] 所有表均查询失败 → 提示排查建议

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

## pmo-risk-scan

### Happy Path
- [ ] `claude pmo-risk-scan` — 扫描所有关注项目，显示风险等级
- [ ] `claude pmo-risk-scan --project XRay` — 扫描指定项目
- [ ] `claude pmo-risk-scan --high-only` — 仅显示高风险项目
- [ ] `claude pmo-risk-scan --send` — 推送风险报告到项目群
- [ ] 6 项指标正确计算并评级（🟢/🟡/🔴）

### Edge Cases
- [ ] 无关注项目且无 active 项目 → 提示空列表
- [ ] 新项目（<7天）→ 使用宽松阈值
- [ ] 单个项目 Base 查询失败 → 跳过该项目，标注 ⚠️
- [ ] 所有项目 Base 查询失败 → 展示失败汇总 + 排查建议
- [ ] 缺少会议记录 → 会议断层指标默认为 🟡
- [ ] 已归档项目 → 默认排除，--all 时包含

---

## pmo-notify

### Happy Path
- [ ] `claude pmo-notify` — 向当前项目群推送提醒
- [ ] `claude pmo-notify --dry-run` — 预览模式，不实际推送
- [ ] `claude pmo-notify --project XRay` — 向指定项目推送
- [ ] `claude pmo-notify --all` — 向所有关注项目推送
- [ ] `claude pmo-notify --overdue-only` — 仅过期待办提醒
- [ ] `claude pmo-notify --milestone-only` — 仅里程碑提醒
- [ ] 推送间隔 >= 30 分钟 → 正常推送
- [ ] 推送间隔 < 30 分钟 → 提示跳过

### Edge Cases
- [ ] 无需要提醒项 → 静默结束，不推送空消息
- [ ] 项目无 chatIds → 降级为终端输出 + 提示配置群聊
- [ ] IM 推送失败 → 提示 ⚠️ 但继续
- [ ] Base 查询失败 → 对应项目 ⚠️，其余正常
- [ ] pinned 为空 → 回退到所有 active 项目

---

## pmo-stats

### Happy Path
- [ ] `claude pmo-stats` — 当前项目近 4 周统计
- [ ] `claude pmo-stats --weeks 8` — 指定周期数
- [ ] `claude pmo-stats --monthly --months 3` — 按月统计
- [ ] `claude pmo-stats --project XRay` — 指定项目
- [ ] `claude pmo-stats --all` — 跨所有关注项目汇总
- [ ] `claude pmo-stats --export stats-report.md` — 导出报告
- [ ] ASCII 趋势图正确显示
- [ ] 负责人贡献分布正确

### Edge Cases
- [ ] 数据不足 2 周 → 提示数据不足，建议等待
- [ ] 新项目（<7天）→ 友好提示等待 2 周
- [ ] 缺少完成时间字段 → 标注 `*估算`
- [ ] 负责人字段为空 → 归类为「未分配」
- [ ] 零积压 → 显示庆祝信息
- [ ] --all 模式单项目失败 → 跳过，其余正常

---

## pmo-import

### Happy Path
- [ ] `claude pmo-import --file test.csv --table todos` — 交互式字段映射导入
- [ ] `claude pmo-import --file test.xlsx --table todos --auto-map` — 自动映射
- [ ] `claude pmo-import --file test.csv --table todos --dry-run` — 预览不写入
- [ ] `claude pmo-import --file test.csv --table todos --force` — 跳过重复检查
- [ ] CSV/UTF-8 正确解析
- [ ] XLSX 正确解析
- [ ] Markdown 表格正确解析
- [ ] 去重检查正确（85% 语义相似度）

### Edge Cases
- [ ] 文件不存在 → 提示检查路径
- [ ] 文件 >10MB → 提示过大
- [ ] 编码检测（UTF-8/GBK fallback）
- [ ] 空行/无效行 → 跳过并报告
- [ ] 日期格式自动检测（多种格式）
- [ ] 字段映射：中文/英文模糊匹配
- [ ] 单批 >200 条 → 自动降级（200→100→50）
- [ ] Base 错误码 1254104 → 自动减半批次重试
- [ ] 负责人未匹配 → 留空 + 警告
- [ ] 预览后 4 选项：全部写入/跳过重复/逐条确认/取消

---

## pmo-meeting-prep

### Happy Path
- [ ] `claude pmo-meeting-prep` — 生成会前议程文档
- [ ] `claude pmo-meeting-prep --date 2026-06-16` — 指定会议日期
- [ ] `claude pmo-meeting-prep --dry-run` — 预览不归档
- [ ] `claude pmo-meeting-prep --send` — 生成并推送
- [ ] `claude pmo-meeting-prep --topic "Sprint评审"` — 自定义主题
- [ ] 议程包含上次会议未完成待办列表
- [ ] 议程包含临近到期里程碑
- [ ] 议程包含长期无进展待办

### Edge Cases
- [ ] 无历史会议 → 首次会议模式，基于当前数据生成
- [ ] 上次会议无未完成待办 → 正常，该项显示无
- [ ] 无临近到期里程碑 → 跳过里程碑部分
- [ ] 距上次会议 >30 天 → 警告间隔过长
- [ ] Base 查询失败 → 生成框架文档，标注 `*无法获取`
- [ ] IM 推送失败 → 文档已归档，仅推送失败
- [ ] Wiki 归档失败（重试耗尽）→ 提示手动归档

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
