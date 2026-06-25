#!/bin/bash
# Project guard: only run in cairn engine repo
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ ! -f "$repo_root/AGENTS.md" || ! -d "$repo_root/hooks" ]] && exit 0

# Hook: 하네스 구성 변경 감지 → /harnessing 실행 권장
# PostToolUse(Edit, Write)
#
# 변경 감지 대상:
#   rules/*.md — 규칙 변경
#   rules-on-demand/*.md — on-demand 규칙 변경
#   skills/*.md — 스킬 변경
#   hooks/*.sh — Hook 변경
#   .claude/settings.json — Hook 등록 변경
#   skills/harness-orchestrator/ — 하네스 오케스트레이터 변경
#   AGENTS.md — 통합 지침 변경

# tool 입력 수집: 현재 하네스는 PostToolUse payload를 stdin JSON으로 전달한다.
# (형제 hook guard-service-orchestration.sh와 동일 계약) 구버전 CLAUDE_TOOL_INPUT env var는 fallback.
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"

# 파일 경로 추출
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"file_path"\s*:\s*"//;s/"$//')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 하네스 구성 파일인지 확인
case "$FILE_PATH" in
  */rules/*|*/rules-on-demand/*|*/skills/*|*/hooks/*|*/.claude/settings.json|*/skills/harness-orchestrator/*|*/AGENTS.md)
    echo "⚠️ 하네스 구성이 변경됐습니다: $(basename $FILE_PATH)"
    echo "정합성 검토가 필요하면 /harnessing 을 실행하세요."
    ;;
esac

exit 0
