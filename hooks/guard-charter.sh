#!/bin/bash
# Cross-repo 하네스 가드. SoT: ai-team-standards/.claude/hooks/guard-charter.sh
# 배포: ~/.claude/settings.json(user)에서 절대경로 직접 실행 → git worktree 포함 모든 cwd 발동.
# 근거: base/guides/decisions/011-harness-guard-cross-repo-propagation.md
# PreToolUse(Edit, Write, MultiEdit)
#
# 동작:
#   가드 대상 repo가 아니면 즉시 통과 (무관 프로젝트 부작용 0)
#   docs/·base/·agents/·temp/ 문서 변경 → 통과
#   프로젝트 코드 변경 → nearest project root(.harness/state.json)에서 Phase/Level 차단
#
# Phase × Level 차단 매트릭스:
#   state.json 없음 → BLOCK (GATE 0 미통과 = orchestrator 미진입)
#   INIT → 모든 Level BLOCK (CPS 먼저)
#   PLAN + Standard/Full → BLOCK (PRD/Architecture 먼저)
#   PLAN + Lite → 통과 (Lite는 CPS만, PRD 불필요)
#   IMPL 이후 / DONE → 통과

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

# ── 가드 대상 repo 판정 (무관 프로젝트는 즉시 통과) ──
# user 레벨 발동이므로 self-guard 역할이 "ai-team-standards 한정"에서
# "가드 대상 repo만 검사, 무관 repo는 빠른 통과"로 재정의됨 (ADR-011).
is_guarded_repo() {
  local root="$1"
  [ -z "$root" ] && return 1
  # 1) ai-team-standards 자체 (팀 표준 SoT)
  [ -f "$root/AGENTS.md" ] && [ -d "$root/agents/skills" ] && return 0
  # 2) 하네스 활성 프로젝트 (.harness 마커 존재)
  [ -d "$root/.harness" ] && return 0
  # 3) known 코드 repo (.harness 부트스트랩 전에도 가드) — origin 화이트리스트
  git -C "$root" remote get-url origin 2>/dev/null | grep -qE 'kt-cloud-infra-ops/' && return 0
  return 1
}
is_guarded_repo "$repo_root" || exit 0

# tool 입력 수집: 현재 하네스는 PreToolUse payload를 stdin JSON으로 전달한다.
# (형제 hook guard-service-orchestration.sh와 동일 계약) 구버전 CLAUDE_TOOL_INPUT env var는 fallback.
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"

# file_path 추출
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -oE '/[^"]*' | head -1)

# 비차단 경고: temp/에 Jira 티켓 키 포함 산출물 생성 시 위치 재확인 안내
if echo "$FILE_PATH" | grep -qE 'temp/[^"]*(TECHIOPS26|LUPR)-[0-9]'; then
  echo "ℹ️ temp/에 Jira 티켓 산출물 생성 감지. Jira 티켓 기반 문서는 프로젝트 레포 docs/features/{TICKET}-{name}.md가 최초 저장처입니다 (doc-organization.md 'Jira 티켓 판별 우선 규칙'). 일회성 분석/Confluence 업로드 전 초안이 아니면 위치를 재확인하세요."
fi

# 비차단 경고: 폐기된 docs/operations/ 재생성 감지 (ADR-012)
if echo "$FILE_PATH" | grep -qE '/docs/operations/'; then
  echo "⚠️ docs/operations/ 는 ADR-012로 폐기된 폴더입니다. 운영 SQL 적용이력은 {repo}.wiki.git operations/ 발행, DB/기능 개선 설계서는 docs/features/{TICKET}-{name}.md를 사용하세요."
fi

# file_path 추출 실패 → 판단 불가 → 통과
[ -z "$FILE_PATH" ] && exit 0

# docs/ 하위는 non-runtime → 통과 (어느 repo/worktree든. workspace/ 문자열 비의존)
echo "$FILE_PATH" | grep -qE '/docs/' && exit 0

# ai-team-standards 자체 자산(base/ agents/ temp/) → 통과 (dev 하네스 대상 아님)
echo "$FILE_PATH" | grep -qE '/(base|agents|temp)/' && exit 0

# ── 프로젝트 코드 변경 → nearest project root에서 .harness 검사 ──
DIR=$(dirname "$FILE_PATH" 2>/dev/null)

while [ -n "$DIR" ] && [ "$DIR" != "." ] && [ "$DIR" != "/" ]; do
  # pom.xml 또는 package.json이 있으면 프로젝트 루트
  if [ -f "$DIR/pom.xml" ] || [ -f "$DIR/package.json" ]; then
    PROJECT=$(basename "$DIR")

    if [ -f "$DIR/.harness/state.json" ]; then
      # state.json에서 phase 읽기
      PHASE=$(python3 -c "import json; print(json.load(open('$DIR/.harness/state.json')).get('phase',''))" 2>/dev/null)

      # config.json에서 level 읽기 (없으면 state에서, 그것도 없으면 standard)
      LEVEL="standard"
      if [ -f "$DIR/.harness/config.json" ]; then
        LEVEL=$(python3 -c "import json; print(json.load(open('$DIR/.harness/config.json')).get('harnessLevel','standard'))" 2>/dev/null)
      else
        LEVEL=$(python3 -c "import json; print(json.load(open('$DIR/.harness/state.json')).get('harnessLevel','standard'))" 2>/dev/null)
      fi

      # DONE → 이전 피처 완료 상태 → 통과
      [ "$PHASE" = "DONE" ] && exit 0

      # INIT → 모든 Level에서 차단
      if [ "$PHASE" = "INIT" ]; then
        echo "⚠️ $PROJECT 프로젝트가 INIT 단계입니다. CPS(Charter Preflight)를 먼저 작성하세요."
        exit 2
      fi

      # PLAN + Standard/Full → 차단 (PRD 먼저 작성). Lite는 통과.
      if [ "$PHASE" = "PLAN" ] && [ "$LEVEL" != "lite" ]; then
        echo "⚠️ $PROJECT 프로젝트가 PLAN 단계입니다 (Level: $LEVEL). PRD/Architecture를 먼저 작성하세요."
        echo "Lite Level이면 PRD 없이 진행 가능합니다."
        exit 2
      fi
    else
      # state.json 없음 → orchestrator 미진입(GATE 0 미통과) → BLOCK
      # Lite여도 state.json은 요구 (ADR-011: Lite는 산출물 면제이지 GATE 0 면제 아님)
      echo "⚠️ $PROJECT 프로젝트에 .harness/state.json이 없습니다."
      echo "코드 변경 전 하네스 프로세스를 시작하세요 (GATE 0 intent triage):"
      echo "  → '피처 개발 시작' 또는 Jira 티켓번호 + 구현/개발/수정 키워드"
      echo "  → Phase 0(CPS) → Phase 1(설계) → Phase 2(구현) 순서 진행"
      exit 2
    fi

    break
  fi
  DIR=$(dirname "$DIR")
done

# === 참조 가드 (soft) — 코드 편집 시 도메인 결정층 참조 권고 (결정 루프 ㉠) ===
# 편집 코드의 triggers 매칭 도메인 에이전트를 이 세션 transcript에서 Read했는지 확인.
# 미참조 시 soft 경고(차단 X). PostToolUse/PreToolUse payload의 transcript_path 활용(#79 stdin 계약 이후).
ATS_ROOT="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
DOMAIN_DIR="$ATS_ROOT/agents/rules-on-demand/luppiter"
if [ -d "$DOMAIN_DIR" ]; then
  BN=$(basename "$FILE_PATH")
  AGENT=$(grep -rlF "$BN" "$DOMAIN_DIR"/*.md 2>/dev/null | grep -v 'README' | head -1)
  if [ -n "$AGENT" ]; then
    AN="luppiter/$(basename "$AGENT")"
    TRANSCRIPT=$(echo "$INPUT_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
    if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] || ! tail -3000 "$TRANSCRIPT" 2>/dev/null | grep -qF "$AN"; then
      echo "ℹ️ [참조 권고] $BN 편집 — 도메인 결정층 '$AN'(결정 이력·판단 시나리오)을 먼저 확인하세요. (soft, 미차단)"
    fi
  fi
fi

# 프로젝트 루트를 못 찾은 경우 (pom.xml/package.json 없음) → 통과
exit 0
