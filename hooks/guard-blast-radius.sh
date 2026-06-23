#!/bin/bash
# guard-blast-radius.sh — Cairn Capture Loop Invariant: 영향범위↔위치 불일치 경고
# PreToolUse(Edit|Write)
#
# 동작:
#   Cairn 컨텍스트에서만 발동.
#   저장 위치와 내용의 영향범위(blast radius)가 휴리스틱으로 불일치하면
#   soft 경고(exit 0 + stderr).
#
# 휴리스틱 판정 규칙:
#   1) projects/{single}/docs/** 에 저장 → 내용에 여러 서비스/팀 범위 키워드 → 경고
#      ("팀 전체 결정을 단일 프로젝트에 저장 중?")
#   2) workspace decisions/ (팀 전체 범위) 에 저장 → 내용에 단일 프로젝트 피처 패턴 → 경고
#      ("단일 프로젝트 feature를 팀 결정에 저장 중?")
#   3) knowledge/lessons/** 에 저장 → 내용이 operations/runbook 성격 → 경고
#      (위치 유형 불일치 힌트)
#
# 판정: soft 경고(exit 0) — 휴리스틱 완벽 불가. AI/사용자 최종 판단.

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
echo "$FILE_PATH" | grep -q '\.md$' || exit 0

# ── 캡처 저장 경로만 대상 ──
is_capture_path() {
  local fp="$1"
  echo "$fp" | grep -qE \
    '/(knowledge|decisions|runbooks|operations)/' && return 0
  echo "$fp" | grep -qE \
    '/services/[^/]+/decisions/' && return 0
  echo "$fp" | grep -qE \
    '/projects/[^/]+/docs/' && return 0
  return 1
}

is_capture_path "$FILE_PATH" || exit 0

# ── 작성 내용 추출 ──
CONTENT=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', data)
    if not isinstance(ti, dict):
        ti = {}
    c = ti.get('content') or ti.get('new_string') or ''
    print(c)
except Exception:
    pass
" 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# ── repo root ──
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
FILE_REL="${FILE_PATH#$REPO_ROOT/}"

WARN=""
HINT=""

# ─────────────────────────────────────────────────────────────────────────────
# 규칙 1: projects/{single}/docs/** 저장 → 내용에 복수 서비스/팀 범위 언급
# ─────────────────────────────────────────────────────────────────────────────
if echo "$FILE_REL" | grep -qE '^projects/[^/]+/docs/'; then
  # 서비스명 언급 수 카운트 (2개 이상 다른 서비스 이름 = 팀/크로스 서비스 범위)
  # 휴리스틱: "services:", "all services", "cross-service", "팀 전체", "모든 서비스",
  #   "platform", "공통", "전사", "cross-" 등 팀 범위 키워드
  TEAM_SCOPE_HITS=$(echo "$CONTENT" | grep -icE \
    'cross.service|cross.team|all[[:space:]]+services|platform.standard|팀[[:space:]]*전체|전사|공통[[:space:]]*결정|공통[[:space:]]*표준|서비스[[:space:]]*전체|multiple[[:space:]]+services|팀[[:space:]]*공통' \
    2>/dev/null || true)

  if [ "${TEAM_SCOPE_HITS:-0}" -gt 0 ]; then
    WARN="단일 프로젝트 경로에 팀/크로스 서비스 범위 내용"
    HINT="  저장 경로: $FILE_REL
  감지 이유: 내용에 팀 전체/크로스 서비스 범위 키워드 ${TEAM_SCOPE_HITS}건 포함
  권장: 팀 전체 결정 → decisions/ (workspace 루트 또는 cairn-<team>/decisions/)
        서비스 범위   → services/{svc}/decisions/"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 규칙 2: workspace decisions/ (루트 수준) → 내용이 단일 프로젝트 feature 성격
# ─────────────────────────────────────────────────────────────────────────────
if [ -z "$WARN" ]; then
  # 루트 수준 decisions/ = 팀 전체 결정 스코프
  if echo "$FILE_REL" | grep -qE '^decisions/'; then
    # 단일 프로젝트 feature 신호: "feature", "TICKET-", specific project/repo name
    FEATURE_HITS=$(echo "$CONTENT" | grep -icE \
      '\b(feature|기능[[:space:]]*스펙|단일[[:space:]]*프로젝트|this[[:space:]]+(project|repo|service)\b|해당[[:space:]]*프로젝트|이[[:space:]]*서비스|UI[[:space:]]*스펙|화면[[:space:]]*설계|PRD|product[[:space:]]*requirement)' \
      2>/dev/null || true)

    # JIRA ticket pattern in title or content = project-specific
    TICKET_HITS=$(echo "$CONTENT" | grep -cE '\b[A-Z]+-[0-9]+\b' 2>/dev/null || true)

    if [ "${FEATURE_HITS:-0}" -ge 2 ] || [ "${TICKET_HITS:-0}" -ge 2 ]; then
      WARN="팀 전체 decisions/ 경로에 단일 프로젝트/기능 성격 내용"
      HINT="  저장 경로: $FILE_REL
  감지 이유: feature/ticket 성격 키워드 (feature: ${FEATURE_HITS}, tickets: ${TICKET_HITS})
  권장: 단일 프로젝트 기능 → projects/{proj}/docs/features/ 또는 projects/{proj}/docs/decisions/
        특정 서비스 결정    → services/{svc}/decisions/"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 규칙 3: knowledge/lessons/ 저장 → 내용이 runbook/operations 성격
# ─────────────────────────────────────────────────────────────────────────────
if [ -z "$WARN" ]; then
  if echo "$FILE_REL" | grep -qE '^knowledge/lessons/'; then
    RUNBOOK_HITS=$(echo "$CONTENT" | grep -icE \
      '(step[[:space:]]*[0-9]+|절차|checklist|체크리스트|배포[[:space:]]*순서|장애[[:space:]]*대응|사전[[:space:]]*조건|prerequisites|runbook|run\s*book|on.call|incident[[:space:]]*response|점검[[:space:]]*목록)' \
      2>/dev/null || true)

    if [ "${RUNBOOK_HITS:-0}" -gt 3 ]; then
      WARN="lessons/ 경로에 runbook/operations 성격 내용"
      HINT="  저장 경로: $FILE_REL
  감지 이유: 절차/체크리스트 성격 키워드 ${RUNBOOK_HITS}건
  권장: 반복 운영 절차 → runbooks/
        일상 공통업무 기록 → operations/"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 규칙 4: operations/ 저장 → 내용이 decision/ADR 성격
# ─────────────────────────────────────────────────────────────────────────────
if [ -z "$WARN" ]; then
  if echo "$FILE_REL" | grep -qE '^operations/'; then
    ADR_HITS=$(echo "$CONTENT" | grep -icE \
      '(ADR|architecture[[:space:]]*decision|결정[[:space:]]*배경|결정[[:space:]]*사유|대안|alternatives[[:space:]]*considered|trade.off|decision[[:space:]]*record)' \
      2>/dev/null || true)

    if [ "${ADR_HITS:-0}" -gt 2 ]; then
      WARN="operations/ 경로에 decision/ADR 성격 내용"
      HINT="  저장 경로: $FILE_REL
  감지 이유: ADR/의사결정 성격 키워드 ${ADR_HITS}건
  권장: 의사결정 기록 → decisions/ (또는 services/{svc}/decisions/)"
    fi
  fi
fi

# ── 결과 처리 ──
if [ -n "$WARN" ]; then
  echo "⚠️  [guard-blast-radius] 영향범위↔위치 불일치 가능성" >&2
  echo "" >&2
  echo "감지: $WARN" >&2
  echo "$HINT" >&2
  echo "" >&2
  echo "Cairn Capture Loop 불변 원칙 3:" >&2
  echo "  NEVER: 영향범위와 저장위치가 불일치하는 캡처를 실행하지 않는다." >&2
  echo "" >&2
  echo "위치 결정 원칙 (영향범위 기반):" >&2
  echo "  1개 프로젝트만    → projects/{proj}/docs/" >&2
  echo "  1개 서비스 범위   → services/{svc}/decisions/" >&2
  echo "  여러 서비스/팀    → decisions/" >&2
  echo "  재사용 패턴/교훈  → knowledge/lessons/" >&2
  echo "  반복 운영 절차    → runbooks/" >&2
  echo "  일상 공통업무     → operations/" >&2
  echo "" >&2
  echo "※ 휴리스틱 경고. 실제 판단은 AI/사용자가 최종 결정." >&2
fi

exit 0
