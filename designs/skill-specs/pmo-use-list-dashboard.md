> 本文档与 .agents/skills/*/SKILL.md 保持同步，以 SKILL.md 为准

# pmo-use / pmo-list / pmo-pin / pmo-dashboard — 项目上下文管理 Skill 设计

> P0 优先级 | 多项目切换与管理

---

## pmo-use — 切换当前项目

### 调用方式

```bash
# 切换当前项目（写入 ~/.smart-pmo/current，全局持久化）
claude pmo-use <项目名>

# 归档项目（将项目状态改为 archived）
claude pmo-use <项目名> --archive

# 重新激活已归档项目
claude pmo-use <项目名> --activate

# 新增成员
claude pmo-use --add-member --name 张三 --role 开发

# 移除成员
claude pmo-use --remove-member --name 张三

# 查看成员列表
claude pmo-use --list-members
```

### 执行流程

#### 切换项目（默认）

```
① 检查 ~/.smart-pmo/registry/<项目名>.json 是否存在
   └→ 不存在 → 提示"项目 '<项目名>' 未注册，请先运行 pmo-init"
② 如果存在，写入 ~/.smart-pmo/current（覆盖写入，内容为项目名）
③ 展示摘要：

   ✅ 已切换至: {项目名} ({代号})

   项目经理: {姓名}
   状态: active

   使用 pmo-list 查看所有项目
```

#### 归档项目（--archive）

```
① 检查 registry JSON 是否存在
② 如果项目已是 archived → 提示"项目已归档，无需操作"
③ 更新 registry JSON 中 project.status = "archived" 和 project.lastModified
④ 如果当前项目（~/.smart-pmo/current）就是该项目，清空 current 文件
⑤ 输出："✅ 项目 {项目名} 已归档"
```

#### 激活项目（--activate）

```
① 检查 registry JSON 是否存在
② 如果项目已是 active → 提示"项目已是激活状态"
③ 更新 registry JSON 中 project.status = "active" 和 project.lastModified
④ 输出："✅ 项目 {项目名} 已重新激活"
```

#### 新增成员（--add-member）

```
① 通过 lark-contact 搜索 --name 指定的姓名，确认 openId
② 如果找到多个候选人，展示列表让用户选择
③ 将成员信息（name / openId / role）追加到 registry JSON team.members
④ 输出："✅ 已添加成员 {姓名}（{角色}）"
```

#### 移除成员（--remove-member）

```
① 在 registry JSON team.members 中查找 --name 指定的姓名
② 如果找不到 → 提示"成员 {姓名} 不在当前项目中"
③ 从列表中移除，更新 project.lastModified
④ 输出："✅ 已移除成员 {姓名}"
```

#### 查看成员（--list-members）

展示当前项目 registry JSON 中的 `team.pm` 和 `team.members`。

### 后续 Skill 读取上下文规则

```
1. 读取 ~/.smart-pmo/current 文件（内容为项目名）
2. 从 ~/.smart-pmo/registry/<项目名>.json 加载完整配置
3. 文件不存在或为空 → 提示"请先执行 pmo-use <项目名>"
```

---

## pmo-list — 列出所有项目

### 调用方式

```bash
claude pmo-list
```

### 执行流程

```
① 遍历 ~/.smart-pmo/registry/*.json
② 读取每个项目的：name、alias、status、pm.name
③ 读取 ~/.smart-pmo/current 标记当前项目
④ 读取 ~/.smart-pmo/pinned 标记关注项目
⑤ 展示表格：

   所有项目：

     当前项目 → {项目名} ({代号}) ※ 关注

     ┌──────────────┬────────┬──────────┬──────────┐
     │ 项目名称      │ 代号   │ 状态     │ 项目经理 │
     ├──────────────┼────────┼──────────┼──────────┤
     │ {项目名}     │ {代号} │ active   │ {姓名}   │
     │ {项目名}     │ {代号} │ active   │ {姓名}   │
     │ {项目名}     │ {代号} │ archived │ {姓名}   │
     └──────────────┴────────┴──────────┴──────────┘

     使用 pmo-use <项目名> 切换项目
     使用 pmo-pin <项目名>  关注项目
```

> 注意：pmo-list 仅读取本地 registry 文件，不发起任何飞书 API 调用。

---

## pmo-pin / pmo-unpin — 关注项目管理

### 调用方式

```bash
# 关注一个或多个项目
claude pmo-pin <项目名> [<项目名>...]

# 取消关注
claude pmo-unpin <项目名> [<项目名>...]
```

### 存储格式

`~/.smart-pmo/pinned` 为纯文本，每行一个项目名：

```
project-a
project-b
```

### 执行流程

**pmo-pin：**
```
① 读取 ~/.smart-pmo/pinned 文件
② 将要关注的项目名加入列表（去重）
③ 写回 pinned 文件
④ 输出确认
```

**pmo-unpin：**
```
① 从 pinned 列表中移除指定项目
② 写回文件
③ 输出确认
```

---

## pmo-dashboard — 多项目概览

### 调用方式

```bash
claude pmo-dashboard
```

### 前置条件

至少有关注项目（已用 `pmo-pin` 关注）或 active 项目。

### 执行流程

```
① 读取 ~/.smart-pmo/pinned 获取关注项目列表
   └→ 如果 pinned 为空，使用所有 status=active 的项目
② 遍历每个项目，通过 lark-base 查询：
   ├→ 待处理数（状态=待处理）
   ├→ 进行中数（状态=进行中）
   ├→ 已过期数（截止日期<今天 且 状态≠已完成/已取消）
   ├→ 今日截止数（截止日期=今天 且 状态≠已完成/已取消）
   ├→ 里程碑进行中数
   ├→ 里程碑即将到期数（计划日期7天内 且 状态≠已完成）
   └→ 里程碑已过期数（计划日期<今天 且 状态≠已完成）
③ 展示概览：

   📊 项目概览 · {today}
   ═══════════════════════════════
   重点关注（{N} 个项目）：

   ◆ {项目名} ({代号})
     待办：待处理 {N} | 进行中 {N} | ⚠️ 过期 {N}
     里程碑：已完成 {N}/{总} | ⚠️ 即将到期 {N}

   ◆ {项目名} ({代号})
     待办：待处理 {N} | 进行中 {N} | ⚠️ 过期 {N}
     里程碑：已完成 {N}/{总} | ⚠️ 即将到期 {N}

   使用 pmo-use <项目名> 查看详情
   使用 pmo-pin <项目名>  关注更多项目
```

---

## 数据来源说明

| Skill | 数据来源 | 飞书调用 |
|-------|---------|---------|
| pmo-list | 本地 registry 文件 | 无（全部本地）|
| pmo-use | 本地 registry 文件 | lark-contact（--add-member 时）|
| pmo-pin | 本地 pinned 文件 | 无 |
| pmo-dashboard | registry + lark-base 查询 | `lark-base list_record`（每个项目 1 次）|
