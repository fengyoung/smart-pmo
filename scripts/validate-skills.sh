#!/usr/bin/env bash
# Smart-PMO Skill 验证脚本
# 检查所有 SKILL.md 的 frontmatter 完整性、depends_on 一致性、共享模块引用
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/../.agents/skills" && pwd)"
ISSUES=0
CHECKS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((ISSUES++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((ISSUES++)); }

echo "=== Smart-PMO Skill 验证 ==="
echo ""

# --- 检查 1: 所有 Skill 目录有 SKILL.md ---
echo "--- 检查 1: SKILL.md 存在性 ---"
for dir in "$SKILLS_DIR"/pmo-*/; do
    name=$(basename "$dir")
    if [[ "$name" == "_shared" ]]; then continue; fi
    ((CHECKS++))
    if [[ -f "$dir/SKILL.md" ]]; then
        log_pass "$name"
    else
        log_fail "$name: 缺少 SKILL.md"
    fi
done
echo ""

# --- 检查 2: Frontmatter 必填字段 ---
echo "--- 检查 2: Frontmatter 必填字段 ---"
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    issues=0
    grep -q "^name: " "$skill_file" || { log_fail "$name: frontmatter 缺少 name"; issues=1; }
    grep -q "^version: " "$skill_file" || { log_fail "$name: frontmatter 缺少 version"; issues=1; }
    grep -q "^description: " "$skill_file" || { log_fail "$name: frontmatter 缺少 description"; issues=1; }
    [[ $issues -eq 0 ]] && log_pass "$name"
done
echo ""

# --- 检查 3: depends_on 一致性 ---
echo "--- 检查 3: depends_on 一致性 ---"
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    issues=0

    # 提取 depends_on 列表（在 frontmatter 区块内）
    deps=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep '^\s*- ' | sed 's/^\s*- //' || echo "")

    # 特殊检查：内容中使用了 lark-contact 但 depends_on 未声明
    if grep -q "lark-contact" "$skill_file" && ! echo "$deps" | grep -q "lark-contact"; then
        log_warn "$name: 使用了 lark-contact 但未在 depends_on 中声明"
        issues=1
    fi

    [[ $issues -eq 0 ]] && log_pass "$name"
done
echo ""

# --- 检查 4: 共享模块引用 ---
echo "--- 检查 4: 共享模块引用 ---"
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))

    # 检查是否同时有共享引用和内联内容（说明重复）
    has_shared_ref=$(grep -c "pending-queue-check\|date-calc-rules" "$skill_file" || true)
    has_inline_table=$(grep -c "pending_backfill.*pending_orphan.*pending_assignee" "$skill_file" || true)

    if [[ $has_shared_ref -gt 0 ]] && [[ $has_inline_table -gt 0 ]]; then
        log_warn "$name: 同时有共享模块引用和内联待处理队列表（重复）"
    else
        log_pass "$name"
    fi
done
echo ""

# --- 检查 5: 版本号 ---
echo "--- 检查 5: 版本号 ---"
PROJECT_VERSION=$(cat "$(dirname "$0")/../VERSION")
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    skill_ver=$(grep "^version: " "$skill_file" | awk '{print $2}')
    if [[ -z "$skill_ver" ]]; then
        log_fail "$name: 无法读取版本号"
    else
        log_pass "$name: $skill_ver"
    fi
done
echo ""

# --- 汇总 ---
echo "========================"
if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✅ 全部检查通过${NC}"
else
    echo -e "${RED}❌ 发现 $ISSUES 个问题${NC}"
fi
echo "共检查 $CHECKS 项"
exit $ISSUES
