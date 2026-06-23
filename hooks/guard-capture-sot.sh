#!/bin/bash
# guard-capture-sot.sh — Cairn Capture Loop Invariant: SoT 단일성 경고
# PreToolUse(Edit|Write)
#
# 동작:
#   Cairn 컨텍스트에서만 발동.
#   새 decision/lesson md 작성 시, 동일 slug가 다른 스코프에 이미 존재하면
#   "SoT 중복 가능성" 경고(soft, exit 0 + stderr).
#
#   예:
#     decisions/foo.md 작성 → services/*/decisions/foo.md 또는
#       projects/*/docs/decisions/foo.md 에 foo.md 존재 → 경고
#     services/svc-a/decisions/bar.md → decisions/bar.md 또는
#       projects/*/docs/decisions/bar.md 존재 → 경고
#
#   SoT는 1곳만 — 상위 스코프는 링크 참조만 권장.
#
# 판정: soft 경고(exit 0) — AI 판단 영역이라 차단보다 경고가 맞음.

set -euo pipefail

# ── Cairn 컨텍스트 판정 ──
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

is_cairn_context() {
  if [ -n "$PLUGIN_ROOT" ] && [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    if grep -q '"name"[[:space:]]*:[[:space:]]*"cairn"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null; then
      return 0
    fi
  fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ]; then
    if { [ -d "$root/knowledge" ] || [ -d "$root/decisions" ] || [ -d "$root/runbooks" ]; } \
       && [ -f "$root/.claude-plugin/plugin.json" ]; then
      return 0
    fi
    if [ -d "$root/services" ] && [ -d "$root/decisions" ]; then
      return 0
    fi
  fi
  return 1
}

is_cairn_context || exit 0

# ── tool 입력 수집 ──
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"

FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', data)
    if not isinstance(ti, dict):
        ti = {}
    print(ti.get('file_path') or data.get('file_path') or '')
except Exception:
    pass
" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# .md 파일만 검사
echo "$FILE_PATH" | grep -q '\.md$' || exit 0

# ── 캡처 저장 경로 판정 (decision/lesson 경로만) ──
is_decision_or_lesson_path() {
  local fp="$1"
  echo "$fp" | grep -qE '/(decisions|knowledge)/' && return 0
  echo "$fp" | grep -qE '/services/[^/]+/decisions/' && return 0
  echo "$fp" | grep -qE '/projects/[^/]+/docs/(decisions|features)/' && return 0
  return 1
}

is_decision_or_lesson_path "$FILE_PATH" || exit 0

# slug = basename without extension
SLUG=$(basename "$FILE_PATH" .md)

# README 등 인덱스 파일은 제외
[ "$SLUG" = "README" ] || [ "$SLUG" = "INDEX" ] || [ "$SLUG" = "index" ] && exit 0

# ── repo root 탐색 ──
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$REPO_ROOT" ] && exit 0

# ── 다른 스코프에 동일 slug 존재 여부 탐색 ──
# 현재 작성 경로 자체는 제외하고 찾는다
DUPLICATES=""

while IFS= read -r found; do
  # 자기 자신은 제외
  [ "$found" = "$FILE_PATH" ] && continue
  # 절대경로를 상대경로로 변환
  rel="${found#$REPO_ROOT/}"
  DUPLICATES="${DUPLICATES}  - ${rel}"$'\n'
done < <(find "$REPO_ROOT" \
    -name "${SLUG}.md" \
    -not -path "$REPO_ROOT/node_modules/*" \
    -not -path "$REPO_ROOT/.git/*" \
    2>/dev/null)

# ── 결과 처리 ──
if [ -n "$DUPLICATES" ]; then
  FILE_REL="${FILE_PATH#$REPO_ROOT/}"
  echo "⚠️  [guard-capture-sot] SoT 중복 가능성 경고" >&2
  echo "" >&2
  echo "작성 대상: $FILE_REL" >&2
  echo "동일 slug '${SLUG}'가 다른 스코프에 이미 존재합니다:" >&2
  echo "$DUPLICATES" >&2
  echo "Cairn Capture Loop 불변 원칙 1:" >&2
  echo "  NEVER: 같은 결정·교훈을 2개 이상의 스코프에 중복 저장하지 않는다." >&2
  echo "  SoT는 1곳, 상위 스코프는 링크 참조만 한다." >&2
  echo "" >&2
  echo "권장 조치 중 하나 선택:" >&2
  echo "  A) 기존 파일을 SoT로 유지하고, 이 경로에는 링크 참조 파일만 생성" >&2
  echo "  B) 이 파일이 새 SoT라면, 기존 파일을 링크 참조로 교체" >&2
  echo "  C) 의도적 분리라면 slug를 더 구체적으로 변경 (예: ${SLUG}-service-level.md)" >&2
  echo "" >&2
  echo "※ 경고만 발생. 판단은 AI/사용자가 결정." >&2
fi

exit 0
