#!/bin/bash
# Project guard: only run in cairn engine repo
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ ! -f "$repo_root/AGENTS.md" || ! -d "$repo_root/hooks" ]] && exit 0

# Hook: 하네스 템플릿 문서 수정 시 자동 계약 검증
# PostToolUse(Edit, Write)
#
# 대상: feature-cps.md, feature-prd.md, feature-architecture.md, task-packet.md

# tool 입력 수집: 현재 하네스는 PostToolUse payload를 stdin JSON으로 전달한다.
# (형제 hook guard-service-orchestration.sh와 동일 계약) 구버전 CLAUDE_TOOL_INPUT env var는 fallback.
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$REPO_ROOT/skills/harness-orchestrator/scripts/validate-doc-contracts.mjs"

# 파일 경로 추출
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"file_path"\s*:\s*"//;s/"$//')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# 피처 문서 DB 변경 섹션 체크 (docs/features/*.md)
if echo "$FILE_PATH" | grep -q "docs/features/.*\.md$"; then
  if [ -f "$FILE_PATH" ] && ! grep -qE "^## (DB 변경|DDL 변경)" "$FILE_PATH"; then
    echo "⚠️ 피처 문서에 '## DB 변경' 섹션이 없습니다: $BASENAME"
    echo "DB 변경이 없으면 '해당 없음'으로 명시하세요."
    echo ""
    echo "  ## DB 변경"
    echo "  해당 없음"
  fi
  exit 0
fi

# 하네스 템플릿 파일인지 확인
case "$BASENAME" in
  feature-cps.md|feature-prd.md|feature-architecture.md|task-packet.md|cps.md|prd.md|architecture.md)
    ;;
  *)
    exit 0
    ;;
esac

# validator 존재 확인
if [ ! -f "$VALIDATOR" ]; then
  exit 0
fi

# 검증 실행
RESULT=$(node "$VALIDATOR" "$FILE_PATH" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "📋 하네스 문서 계약 검증 결과 ($BASENAME):"
  echo "$RESULT"
  echo ""
  echo "수정 후 재검증됩니다."
fi

exit 0
