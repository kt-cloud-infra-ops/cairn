#!/bin/bash
# Project guard: only run in ai-team-standards repo
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ ! -f "$repo_root/AGENTS.md" || ! -d "$repo_root/.claude/hooks" ]] && exit 0

# 증적 수집 스크립트 — Phase 4 SHIP 지원
# 용도: Jira In Review/Done 전환 시 증적 텍스트 자동 생성
#
# 사용법: bash .claude/hooks/collect-evidence.sh [이슈키]
# 출력: Jira 코멘트용 마크다운

ISSUE_KEY="${1:-}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "## 완료 증적"
echo ""

# 1. 브랜치
BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
echo "| 항목 | 내용 |"
echo "|------|------|"
echo "| 브랜치 | \`$BRANCH\` |"
echo "| 반영 환경 | [TBD - dev/stg/prd] |"
echo "| 일시 | $(date '+%Y-%m-%d %H:%M') |"
echo ""

# 2. 관련 커밋 (이슈 키가 있으면 필터링)
echo "### 관련 커밋"
echo ""
if [ -n "$ISSUE_KEY" ]; then
  COMMITS=$(git -C "$REPO_ROOT" log --oneline -20 --grep="$ISSUE_KEY" 2>/dev/null)
  if [ -z "$COMMITS" ]; then
    # 이슈 키로 못 찾으면 오늘 커밋
    COMMITS=$(git -C "$REPO_ROOT" log --oneline --since="$(date '+%Y-%m-%d')T00:00:00" 2>/dev/null | head -10)
    echo "(이슈 키 매칭 커밋 없음 — 오늘 커밋 표시)"
    echo ""
  fi
else
  COMMITS=$(git -C "$REPO_ROOT" log --oneline --since="$(date '+%Y-%m-%d')T00:00:00" 2>/dev/null | head -10)
fi

echo '```'
echo "$COMMITS"
echo '```'
echo ""

# 3. 변경 파일 통계
echo "### 변경 파일"
echo ""
echo '```'
git -C "$REPO_ROOT" diff --stat main...HEAD 2>/dev/null | tail -5
echo '```'
echo ""

# 4. 피처 문서 존재 여부
if [ -n "$ISSUE_KEY" ]; then
  # docs/features/ 탐색
  FEATURE_DOCS=$(grep -rl "$ISSUE_KEY" "$REPO_ROOT"/*/docs/features/*.md 2>/dev/null)
  if [ -z "$FEATURE_DOCS" ]; then
    # 단일 프로젝트 구조도 지원
    FEATURE_DOCS=$(grep -rl "$ISSUE_KEY" "$REPO_ROOT/docs/features/"*.md 2>/dev/null)
  fi
  if [ -n "$FEATURE_DOCS" ]; then
    echo "### 피처 문서"
    echo ""
    echo "$FEATURE_DOCS" | sed "s|$REPO_ROOT/||" | sed 's/^/- /'
    echo ""
  fi
fi

# 5. 테스트 결과 (TBD)
echo "### 테스트 결과"
echo ""
echo "- [ ] 단위 테스트 통과"
echo "- [ ] 통합 테스트 통과"
echo "- [ ] E2E 테스트 통과 (해당 시)"
echo "- [ ] 로컬 검증 완료 (DB → API → UI)"
