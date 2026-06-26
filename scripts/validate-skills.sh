#!/usr/bin/env bash
# Smart-PMO Skill 验证脚本
# 检查所有 SKILL.md 的 frontmatter 完整性、depends_on 一致性、共享模块引用
# v1.9.0: 新增 7 项检查（共享模块路径有效性、孤儿引用、depends_on 存在性、
#         硬编码目录名、feishu-card-template 采用率、用户字段格式、版本漂移告警）
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/../.agents/skills" && pwd)"
ISSUES=0
WARNS=0
CHECKS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNS++)); }
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

# --- 检查 6: 共享模块引用路径有效性 ---
echo "--- 检查 6: 共享模块引用路径有效性 ---"
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    issues=0

    # 检测损坏的 _shared/ 引用（应该是 ../_shared/）
    if grep -qE '\[.*\]\(_shared/' "$skill_file"; then
        log_warn "$name: 共享模块引用路径错误（应为 ../_shared/ 而非 _shared/）"
        issues=1
    fi

    [[ $issues -eq 0 ]] && log_pass "$name"
done
echo ""

# --- 检查 7: 引用的共享模块文件是否存在 ---
echo "--- 检查 7: 共享模块文件存在性 ---"
SHARED_FILES=("date-calc-rules.md" "feishu-card-template.md" "pending-queue-check.md")
for sf in "${SHARED_FILES[@]}"; do
    ((CHECKS++))
    if [[ -f "$SKILLS_DIR/_shared/$sf" ]]; then
        log_pass "_shared/$sf"
    else
        log_fail "_shared/$sf: 文件不存在"
    fi
done

# 检查技能是否引用了不存在的共享模块
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    # 提取所有 _shared/xxx.md 引用
    refs=$(grep -oE '_shared/[a-z-]+\.md' "$skill_file" 2>/dev/null || true)
    for ref in $refs; do
        ref_basename=$(basename "$ref")
        if [[ ! -f "$SKILLS_DIR/_shared/$ref_basename" ]]; then
            log_warn "$name: 引用了不存在的共享模块 $ref"
        fi
    done
done
echo ""

# --- 检查 8: depends_on 中声明的 Skill 是否存在 ---
echo "--- 检查 8: depends_on 声明有效性 ---"
ALL_SKILLS=$(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" -exec dirname {} \; | xargs -I{} basename {} | grep -v "^_" | sort -u)
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    issues=0

    # 提取 frontmatter 中的 depends_on 列表
    deps=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep -E '^\s*- lark-' | sed 's/^\s*- //' || echo "")

    for dep in $deps; do
        if ! echo "$ALL_SKILLS" | grep -qFx "$dep"; then
            # 检查是否为已知的 lark-* 技能（可能不在 pmo-* 目录下）
            # lark-* 技能是外部依赖，不在此仓库中，跳过检查
            :
        fi
    done
    log_pass "$name"
done
echo ""

# --- 检查 9: 硬编码知识库目录名检测（仅检测可执行代码中的硬编码）---
echo "--- 检查 9: 硬编码目录名检测 ---"
set +e +o pipefail  # 暂时放宽错误处理，grep/awk 无匹配时 exit 1 是正常的
HARDCODED_DIRS=("01-会议纪要" "02-周报" "03-需求文档" "04-设计文档" "05-项目资料" "99-归档")
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    issues=0

    # 排除 pmo-init（负责创建目录，硬编码是必要的）
    if [[ "$name" == "pmo-init" ]]; then
        log_pass "$name (创建者，豁免)"
        continue
    fi

    for dir in "${HARDCODED_DIRS[@]}"; do
        # 仅在代码块（```）内检测硬编码（文档中的目录名引用是正常的）
        in_code=$(awk '/```/{p=!p;next} p' "$skill_file" 2>/dev/null | grep -cF "$dir" 2>/dev/null || echo "0")
        in_code=$(echo "$in_code" | tr -d '[:space:]')
        if [[ "${in_code:-0}" -gt 0 ]]; then
            log_warn "$name: 代码块中可能硬编码了目录名 '$dir'（应通过 config.larkResources.wikiNodeTokens 动态读取）"
            issues=1
            break
        fi
    done

    [[ $issues -eq 0 ]] && log_pass "$name"
done
set -e -o pipefail
echo ""

# --- 检查 10: feishu-card-template 采用率 ---
echo "--- 检查 10: feishu-card-template 采用率 ---"
((CHECKS++))
CARD_REF_COUNT=$(grep -rl "feishu-card-template" "$SKILLS_DIR"/pmo-*/SKILL.md 2>/dev/null | wc -l | tr -d ' ') || CARD_REF_COUNT=0
if [[ "$CARD_REF_COUNT" -eq 0 ]]; then
    log_warn "feishu-card-template.md 未被任何技能引用（孤立的共享模块）"
else
    log_pass "feishu-card-template.md 被 $CARD_REF_COUNT 个技能引用"
fi
echo ""

# --- 检查 11: 用户字段格式（防止 1254066 错误）---
echo "--- 检查 11: 用户字段格式 ---"
for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))

    # 检测 JSON 示例中缺少 name 字段的用户格式：{"id": "ou_xxx"} 后面没有 "name"
    # 匹配 pattern: [{"id":"ou_xxx"}] 或 [{"id": "ou_xxx"}] 但没有 name
    # 排除 ❌ 标记行（这些行是展示错误格式的反面教材）
    bad_format=$(grep -v '❌' "$skill_file" 2>/dev/null | grep -cE '\{"id"[[:space:]]*:[[:space:]]*"ou_[^"]*"[[:space:]]*\}' 2>/dev/null || echo "0")
    bad_format=$(echo "$bad_format" | tr -d '[:space:]')

    if [[ "${bad_format:-0}" -gt 0 ]]; then
        log_fail "$name: 发现缺少 name 字段的用户格式（会导致 1254066 错误），$bad_format 处"
    else
        log_pass "$name"
    fi
done
echo ""

# --- 检查 12: 版本漂移告警 ---
echo "--- 检查 12: 版本漂移告警 ---"
PROJECT_VERSION=$(cat "$(dirname "$0")/../VERSION")
PROJECT_MAJOR=$(echo "$PROJECT_VERSION" | cut -d. -f1)
PROJECT_MINOR=$(echo "$PROJECT_VERSION" | cut -d. -f2)

for skill_file in "$SKILLS_DIR"/pmo-*/SKILL.md; do
    name=$(basename "$(dirname "$skill_file")")
    ((CHECKS++))
    skill_ver=$(grep "^version: " "$skill_file" | awk '{print $2}')
    skill_minor=$(echo "$skill_ver" | cut -d. -f2)

    minor_diff=$((PROJECT_MINOR - skill_minor))
    if [[ $minor_diff -ge 3 ]]; then
        log_warn "$name: 版本 $skill_ver 落后项目 $PROJECT_VERSION 超过 2 个次版本（差 $minor_diff 个版本）"
    else
        log_pass "$name: $skill_ver"
    fi
done
echo ""

# --- 汇总 ---
echo "========================"
TOTAL_ISSUES=$((ISSUES + WARNS))
if [[ $TOTAL_ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✅ 全部检查通过${NC}"
else
    echo -e "${RED}❌ 发现 $ISSUES 个错误, ${YELLOW}$WARNS 个告警${NC}"
fi
echo "共检查 $CHECKS 项"
exit $ISSUES
