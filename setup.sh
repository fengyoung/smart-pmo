#!/bin/bash
# Smart-PMO 环境初始化脚本
# 用法: bash setup.sh

set -e

SKILLS_DIR="$HOME/.claude/skills"
PMO_SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)/.agents/skills"
REGISTRY_DIR="$HOME/.smart-pmo/registry"

echo "┌─────────────────────────────────────┐"
echo "│  Smart-PMO 环境初始化               │"
echo "└─────────────────────────────────────┘"
echo ""

# 1. 检查 lark-cli
echo "▶ 检查 lark-cli..."
if ! command -v lark-cli &> /dev/null; then
    echo "  ❌ lark-cli 未安装"
    echo "  请先安装: npm install -g @anthropic/lark-cli"
    echo "  然后完成认证: lark-cli auth"
    exit 1
fi
echo "  ✅ lark-cli 已安装"

# 2. 创建配置目录
echo "▶ 创建配置目录..."
mkdir -p "$REGISTRY_DIR"
mkdir -p "$HOME/.smart-pmo"
touch "$HOME/.smart-pmo/current" 2>/dev/null || true
touch "$HOME/.smart-pmo/pinned" 2>/dev/null || true
echo "  ✅ ~/.smart-pmo/ 目录已创建"

# 3. 注册 Skill 符号链接
echo "▶ 注册 Claude Code Skills..."
mkdir -p "$SKILLS_DIR"

count=0
for skill_dir in "$PMO_SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    target="$SKILLS_DIR/$skill_name"

    if [ -L "$target" ]; then
        rm "$target"
    fi

    ln -sf "$skill_dir" "$target"
    echo "  ✅ $skill_name"
    ((count++))
done

echo ""
echo "┌─────────────────────────────────────┐"
echo "│  ✅ 初始化完成！已注册 $count 个 Skills    │"
echo "└─────────────────────────────────────┘"
echo ""
echo "下一步："
echo "  1. claude pmo-init    ← 初始化你的第一个项目"
echo "  2. claude pmo-list    ← 查看已注册的项目"
echo ""
echo "使用前请确保："
echo "  • 已在飞书开放平台创建智能体 Bot 应用"
echo "  • 已准备好项目群聊"
