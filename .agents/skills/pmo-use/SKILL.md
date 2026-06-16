---
name: pmo-use
version: 1.6.2
description: "切换当前项目上下文。根据项目名从 ~/.smart-pmo/registry/ 加载配置，后续所有 pmo-* 命令操作目标项目。支持 --archive / --activate 修改项目状态。"
metadata:
  requires:
    bins: []
  depends_on:
    - lark-contact
---

# pmo-use — 切换当前项目

## 执行方式

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

# 查看成员列表（通过 pmo-info 也可查看）
claude pmo-use --list-members
```

## 执行流程

### 切换项目（默认）

1. 解析输入的 `<项目名>`：
   - 先按文件名（alias）精确匹配 `~/.smart-pmo/registry/<输入>.json`
   - 找不到 → 遍历所有 registry JSON，按 `project.name` 全称匹配
   - 仍找不到 → 提示：`项目 "<输入>" 未注册，请先运行 pmo-init`
2. 找到配置后，执行配置完整性校验：

```
校验规则：
  ✅ config.project.name 不为空
  ✅ config.larkResources.baseAppToken 不为空
  ✅ config.larkResources.baseTableIds.todos 不为空
  ✅ config.larkResources.baseTableIds.milestones 不为空
  ✅ config.larkResources.baseTableIds.meetingIndex 不为空
  ✅ config.larkResources.wikiSpaceId 不为空
  ✅ config.larkResources.chatIds[0] 不为空（如有）

若任一必填字段缺失 → 输出警告并列出缺失字段，继续执行切换但不保证后续 Skill 正常工作
```

3. 尝试 Base 连通性检查：
   - 通过 `lark-base` 查询待办表（limit=1），验证 token 有效
   - 成功 → 记录待办总数用于摘要
   - 失败 → 摘要中标注 `⚠️ Base 连接失败，请检查权限或 token 有效性`

4. 写入 `~/.smart-pmo/current`（写入 project_id，即文件名不含后缀）
5. 展示摘要：

```
✅ 已切换至: {项目名} ({代号})

项目经理: {姓名}
状态: active | ⚠️ 配置不完整: {缺失字段}
Base 状态: 正常 ({N} 条待办) | ⚠️ 连接失败
配置版本: v{schemaVersion}（当前最新 v1.1）| ⚠️ 版本过旧，建议运行迁移

使用 pmo-list 查看所有项目
```

### 归档项目（--archive）

1. 检查 registry JSON 是否存在
2. 如果项目已是 `archived` → 提示"项目已归档，无需操作"
3. 更新 registry JSON 中 `project.status = "archived"` 和 `project.lastModified`
4. 如果当前项目（`~/.smart-pmo/current`）就是该项目，清空 current 文件
5. 输出："✅ 项目 {项目名} 已归档"

### 激活项目（--activate）

1. 检查 registry JSON 是否存在
2. 如果项目已是 `active` → 提示"项目已是激活状态"
3. 更新 registry JSON 中 `project.status = "active"` 和 `project.lastModified`
4. 输出："✅ 项目 {项目名} 已重新激活"

### 新增成员（--add-member）

1. 通过 `lark-contact` 搜索 `--name` 指定的姓名，确认 openId
2. 如果找到多个候选人，展示列表让用户选择
3. 将成员信息（name / openId / role）追加到 registry JSON `team.members`
4. 输出："✅ 已添加成员 {姓名}（{角色}）"

### 移除成员（--remove-member）

1. 在 registry JSON `team.members` 中查找 `--name` 指定的姓名
2. 如果找不到 → 提示"成员 {姓名} 不在当前项目中"
3. 从列表中移除，更新 `project.lastModified`
4. 输出："✅ 已移除成员 {姓名}"

### 查看成员（--list-members）

展示当前项目 registry JSON 中的 `team.pm` 和 `team.members`。

## 后续 Skill 读取上下文规则

```
1. 读取 ~/.smart-pmo/current 文件（内容为项目名）
2. 从 ~/.smart-pmo/registry/<项目名>.json 加载完整配置
3. 文件不存在或为空 → 提示"请先执行 pmo-use <项目名>"
```
