#!/bin/bash
# Project guard: only run in ai-team-standards repo
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ ! -f "$repo_root/AGENTS.md" || ! -d "$repo_root/.claude/hooks" ]] && exit 0

# Hook: 새 스킬 생성 시 중복 확인 + 최소 요건 가드레일
# PreToolUse(Write)
#
# 동작:
#   1. Write 대상이 agents/skills/*/SKILL.md인지 확인
#   2. 해당 파일이 아직 없으면 (신규 생성) → 가드레일 발동
#   3. 기존 스킬 목록 + 유사 이름 매칭 표시
#   4. 최소 요건 리마인더 표시

# tool 입력 수집: 현재 하네스는 PreToolUse payload를 stdin JSON으로 전달한다.
# (형제 hook guard-service-orchestration.sh와 동일 계약) 구버전 CLAUDE_TOOL_INPUT env var는 fallback.
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"
[ -z "$TOOL_INPUT" ] && exit 0

# file_path 추출
FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    # stdin payload는 tool_input 중첩, 구버전 env var는 tool_input 객체 직접 → 둘 다 대응
    ti = d.get('tool_input', d)
    print(ti.get('file_path', '') or d.get('file_path', ''))
except:
    pass
" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# agents/skills/*/SKILL.md 패턴인지 확인
if ! echo "$FILE_PATH" | grep -qE 'agents/skills/[^/]+/SKILL\.md$'; then
  exit 0
fi

# 이미 존재하는 파일이면 수정 → 가드레일 불필요
if [ -f "$FILE_PATH" ]; then
  exit 0
fi

# === 신규 스킬 생성 감지 ===

# 새 스킬 이름 추출
SKILL_NAME=$(echo "$FILE_PATH" | sed 's|.*/agents/skills/||;s|/SKILL\.md$||')

# 기존 스킬 목록
EXISTING=$(ls -d "$repo_root/agents/skills"/*/ 2>/dev/null | xargs -I{} basename {} | grep -v vendor | sort)
SKILL_COUNT=$(echo "$EXISTING" | wc -l | tr -d ' ')

# prefix 추출
PREFIX=$(echo "$SKILL_NAME" | sed 's/-[^-]*$//')

# 같은 prefix 스킬 찾기
SIMILAR=$(echo "$EXISTING" | grep "^${PREFIX}-" 2>/dev/null)

# vendor 스킬 목록
VENDOR=$(ls -d "$repo_root/agents/skills/vendor"/*/ 2>/dev/null | xargs -I{} basename {} | sort)

echo "⚠️ 새 스킬 생성 감지: $SKILL_NAME"
echo ""
echo "📋 중복 확인 필수 (agents/rules/skill-governance.md)"
echo ""

if [ -n "$SIMILAR" ]; then
  echo "🔍 같은 prefix($PREFIX-*) 기존 스킬:"
  echo "$SIMILAR" | sed 's/^/  - /'
  echo ""
  echo "→ 기존 스킬 수정으로 해결 가능한지 먼저 확인하세요."
  echo ""
fi

echo "📦 기존 스킬 ${SKILL_COUNT}개:"
echo "$EXISTING" | sed 's/^/  /'
echo ""

if [ -n "$VENDOR" ]; then
  echo "🏪 vendor 스킬:"
  echo "$VENDOR" | sed 's/^/  /'
  echo ""
fi

echo "✅ 최소 요건:"
echo "  - [ ] frontmatter: name, description"
echo "  - [ ] ## 스킬 규칙 (ALWAYS/NEVER 최소 1개)"
echo "  - [ ] ## 실행 절차 (최소 1단계)"
echo "  - [ ] ## 완료 조건 (DONE WHEN) (최소 1개 태그)"
echo "  - [ ] prefix 네이밍 준수"
echo ""
echo "양식: agents/templates/skill-template.md"
