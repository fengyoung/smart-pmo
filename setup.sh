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

# 0. 检查 Node.js 和 npm
echo "▶ 检查 Node.js 环境..."
if ! command -v node &> /dev/null; then
    echo "  ❌ Node.js 未安装"
    echo ""
    echo "  lark-cli 依赖 Node.js 运行，请先安装 Node.js (>=16)："
    echo "    macOS:  brew install node"
    echo "    Linux:  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    echo "            sudo apt-get install -y nodejs"
    echo "    官网:   https://nodejs.org/ (下载 LTS 版本)"
    echo ""
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "  ❌ npm 未安装（通常随 Node.js 一起安装）"
    echo "  请重新安装 Node.js: https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
echo "  ✅ Node.js $(node -v) / npm $(npm -v)"

if [ "$NODE_VERSION" -lt 16 ]; then
    echo "  ⚠️  Node.js 版本过低（当前 $(node -v)），建议 >=16"
    echo "  是否继续？(y/n)"
    read -r continue_choice
    if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
        echo "  请升级 Node.js 后重新运行"
        exit 1
    fi
fi
echo ""

# 1. 检查/安装 lark-cli (@larksuite/cli)
echo "▶ 检查 lark-cli..."
if ! command -v lark-cli &> /dev/null; then
    echo "  ⚠️  lark-cli 未安装"
    echo "  是否自动安装？(y/n)"
    read -r install_choice
    if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
        echo "  正在安装 @larksuite/cli..."
        npm install -g @larksuite/cli
        echo "  ✅ lark-cli 已安装"
        echo ""
        echo "  接下来请完成认证："
        echo "    lark-cli auth login"
        echo "    （使用你的飞书个人账号扫码登录）"
        echo ""
        echo -n "  按回车键继续... "
        read -r
    else
        echo "  请手动安装: npm install -g @larksuite/cli"
        echo "  然后完成认证: lark-cli auth login"
        echo ""
        read -r -p "  按回车键继续（跳过 lark-cli 检查）... "
    fi
else
    echo "  ✅ lark-cli 已安装"
fi

# 2. 创建配置目录
echo "▶ 创建配置目录..."
mkdir -p "$REGISTRY_DIR"
mkdir -p "$HOME/.smart-pmo"
mkdir -p "$HOME/.smart-pmo/.pending_backfill"
mkdir -p "$HOME/.smart-pmo/.pending_orphan_meeting"
mkdir -p "$HOME/.smart-pmo/.pending_assignee"
mkdir -p "$HOME/.smart-pmo/.draft"
touch "$HOME/.smart-pmo/current" 2>/dev/null || true
touch "$HOME/.smart-pmo/pinned" 2>/dev/null || true
echo "  ✅ ~/.smart-pmo/ 目录已创建（含待处理队列子目录）"

# 2.5 复制示例配置（如果存在）
SAMPLE_CONFIG="$(cd "$(dirname "$0")" && pwd)/.smart-pmo-sample"
if [ -d "$SAMPLE_CONFIG" ]; then
    echo "▶ 复制示例项目配置..."
    cp -n "$SAMPLE_CONFIG"/*.json "$REGISTRY_DIR/" 2>/dev/null || true
    echo "  ✅ 示例配置已复制"
fi

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
# 4. 检查 lark-cli 认证状态
echo "▶ 检查 lark-cli 认证状态..."
if command -v lark-cli &> /dev/null; then
    if lark-cli auth status 2>/dev/null; then
        echo "  ✅ lark-cli 已认证"
    else
        echo "  ⚠️  lark-cli 未认证，请运行: lark-cli auth login"
    fi
else
    echo "  ⚠️  lark-cli 未安装，跳过认证检查"
fi
echo ""

echo "下一步："
echo "  1. claude pmo-init    ← 初始化你的第一个项目"
echo "  2. claude pmo-list    ← 查看已注册的项目"
echo ""
echo "使用前请确保："
echo "  • lark-cli 已完成认证（lark-cli auth status）"
echo "  • 已准备好项目群聊"
echo ""
echo "多人协作："
echo "  其他成员只需克隆仓库 + 执行 bash setup.sh 即可"
echo "  初始化项目后，将 ~/.smart-pmo/registry/*.json 同步给团队成员"
