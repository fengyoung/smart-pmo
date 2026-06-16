# 公共：飞书卡片消息模板

> **适用范围**：所有需要发送飞书群通知的 `pmo-*` Skill（pmo-notify、pmo-todo-followup、pmo-weekly-report、pmo-meeting-process 等）
> **唯一权威源**：本文件为飞书卡片消息（interactive 类型）的唯一定义处。所有 Skill 统一引用此处，不再内联重复。

---

## 卡片结构

飞书卡片消息使用 `--msg-type interactive` + `--content JSON` 发送。标准结构如下：

```json
{
  "config": { "wide_screen_mode": true },
  "header": {
    "title": { "tag": "plain_text", "content": "标题" },
    "template": "blue"          // blue | wathet | green | yellow | orange | red | purple | turquoise
  },
  "elements": [ ... ]
}
```

## 推荐组合模板

### 模板 A：会议归档 & 待办同步（通用通知）

适用于：会议纪要归档、批量待办导入等场景。

```python
import json, subprocess

def build_notification_card(title, sections, footer="Smart-PMO 自动归档"):
    """
    title: str - 卡片标题
    sections: list of dict -
        [{"heading": "📚 标题", "items": ["项目1", "项目2"]}, ...]
        或 [{"divider": True}] 插入分隔线
    footer: str - 底部备注文字
    """
    elements = []

    for sec in sections:
        if sec.get("divider"):
            elements.append({"tag": "hr"})
            continue

        elements.append({
            "tag": "div",
            "text": {
                "tag": "lark_md",
                "content": f"**{sec['heading']}**"
            }
        })

        for item in sec.get("items", []):
            elements.append({
                "tag": "div",
                "text": {
                    "tag": "lark_md",
                    "content": item
                }
            })

    elements.append({
        "tag": "note",
        "elements": [
            {"tag": "plain_text", "content": f"📎 {footer}"}
        ]
    })

    card = {
        "config": {"wide_screen_mode": True},
        "header": {
            "title": {"tag": "plain_text", "content": title},
            "template": "blue"
        },
        "elements": elements
    }

    return card

# 使用示例
card = build_notification_card(
    title="📋 XRay · 今日待办同步",
    sections=[
        {"heading": "📚 新增内容", "items": [
            "① **某次会议纪要**　📅 06-16\n[查看详情](https://xxx.feishu.cn/wiki/xxx)",
            "② **某次会议纪要**　📅 06-15\n[查看详情](https://xxx.feishu.cn/wiki/xxx)"
        ]},
        {"divider": True},
        {"heading": "⏳ 待处理待办（N项）", "items": [
            "🎨 **待办标题** · 负责人 · 06-30",
            "🚀 **待办标题** · 负责人 · 06-30"
        ]}
    ],
    footer="Smart-PMO · XRay 项目"
)

cmd = [
    "lark-cli", "im", "+messages-send",
    "--chat-id", chat_id,
    "--msg-type", "interactive",
    "--content", json.dumps(card, ensure_ascii=False),
    "--as", "user"
]
subprocess.run(cmd, capture_output=True, text=True, timeout=15)
```

### 模板 B：纯文本 Markdown（简单通知）

适用于：简短提示、无需卡片样式的场景。

```bash
lark-cli im +messages-send \\
  --chat-id <chat_id> \\
  --markdown "**标题**\n\n内容" \\
  --as user
```

---

## 卡片模板色谱

| template 值 | 适用场景 |
|-------------|---------|
| `blue`      | 常规通知、会议纪要归档 |
| `green`     | 完成、上线、成功 |
| `yellow`    | 待办提醒、即将到期 |
| `orange`    | 延迟、风险提示 |
| `red`       | 阻断性风险、失败 |
| `purple`    | 里程碑、版本发布 |
| `turquoise` | 周报、统计数据 |

## 注意事项

1. **JSON 必须用 Python/脚本构造**，避免 shell 中转义问题（特别是 `&`、`"`、`\n` 等字符）
2. 卡片消息中的链接用 markdown 格式：`[显示文字](https://...)`
3. `lark_md` 中支持：**加粗**、`[链接](url)`、\n 换行
4. 不要使用 HTML 标签或表格，飞书卡片不支持
5. `chat_id` 从项目配置 `config.larkResources.chatIds[0]` 获取
6. 发送失败遵循公共错误重试策略（1s/3s/5s 三次重试）

## 引用方式

在 Skill 文件中引用：

```markdown
> 📋 卡片消息构造详见 [`_shared/feishu-card-template.md`](../_shared/feishu-card-template.md)
```
