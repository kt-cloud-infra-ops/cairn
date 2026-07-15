#!/bin/bash
# Cross-repo 하네스 가드.
# 배포: ${CLAUDE_HOME:-$HOME/.claude}/settings.json(user)에서 절대경로 직접 실행 → git worktree 포함 모든 cwd 발동.
# PreToolUse(Edit, Write, MultiEdit)
#
# 동작:
#   가드 대상 repo가 아니면 즉시 통과 (무관 프로젝트 부작용 0)
#   docs/·rules/·rules-on-demand/·skills/·agents/·templates/·hooks/·temp/ 문서 변경 → 통과
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
# user 레벨 발동이므로 self-guard 역할이 "cairn 엔진 한정"에서
# "가드 대상 repo만 검사, 무관 repo는 빠른 통과"로 재정의됨 (cross-repo 가드 전파 원칙 — docs/HARNESS_DESIGN_RATIONALE.md).
is_guarded_repo() {
  local root="$1"
  [ -z "$root" ] && return 1
  # 1) cairn plugin repo (AGENTS.md + skills/ 마커)
  [ -f "$root/AGENTS.md" ] && [ -d "$root/skills" ] && return 0
  # 2) 하네스 활성 프로젝트 (.harness 마커 존재)
  [ -d "$root/.harness" ] && return 0
  return 1
}

# 워크스페이스 루트 탐색 (.cairn/workspace.yaml 상향) — guard-orchestrator-entry.sh와 동일 계약.
# triage.json(Gate 0 마커) 위치를 찾기 위함.
find_workspace_root() {
  local start="$1" dir
  if [ -n "$start" ] && [[ "$start" == /* ]]; then dir="$(dirname "$start")"; else dir="$PWD"; fi
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    [ -f "$dir/.cairn/workspace.yaml" ] && { printf '%s\n' "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

is_guarded_repo "$repo_root" || exit 0

# tool 입력 수집: 현재 하네스는 PreToolUse payload를 stdin JSON으로 전달한다.
# (형제 hook guard-service-orchestration.sh와 동일 계약) 구버전 CLAUDE_TOOL_INPUT env var는 fallback.
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"

# file_path 추출
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -oE '/[^"]*' | head -1)

# file_path 추출 실패 → 판단 불가 → 통과
[ -z "$FILE_PATH" ] && exit 0

# docs/ 하위는 non-runtime → 통과 (어느 repo/worktree든. workspace/ 문자열 비의존)
echo "$FILE_PATH" | grep -qE '/docs/' && exit 0

# cairn 엔진 자체 자산(rules/ rules-on-demand/ skills/ agents/ templates/ hooks/ temp/) → 통과 (dev 하네스 대상 아님)
echo "$FILE_PATH" | grep -qE '/(rules|rules-on-demand|skills|agents|templates|hooks|temp)/' && exit 0

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
      # ops/bootstrap/harnessing branch는 dev 전용 Phase 게이트(guard-charter) 대상이 아니다 —
      # Gate 0(triage)이 이미 진입을 책임지므로 소유권 분리(deference)로 오차단을 막는다 (ADR-015).
      # 예: ops sql이 pom.xml 트리 안(src/main/resources/db/migration/*.sql)에 있어 dev로 오인되던 BLOCK 버그.
      WS_ROOT="$(find_workspace_root "$FILE_PATH")"
      TRIAGE_BRANCH=$(python3 -c "import json; print(json.load(open('$WS_ROOT/.harness/triage.json')).get('branch',''))" 2>/dev/null || true)
      if [ -n "$TRIAGE_BRANCH" ] && [ "$TRIAGE_BRANCH" != "dev" ]; then
        exit 0
      fi
      # state.json 없음 + (dev branch 또는 triage 없음) → orchestrator 미진입(GATE 0 미통과) → BLOCK
      # Lite여도 state.json은 요구 (원칙: Lite는 산출물 면제이지 GATE 0 면제 아님 — docs/HARNESS_DESIGN_RATIONALE.md)
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

# === 참조 가드 (soft) — 코드 편집 시 도메인 결정층 참조 권고 (결정 루프 ㉠, ADR-013) ===
# 편집 파일명이 workspace rulepacks/{svc}/agents/*.md 에 언급되면, 이 세션 transcript에서
# 해당 도메인 에이전트를 Read했는지 확인. 미참조 시 soft 경고(차단 X).
# rulepacks/ 없는 워크스페이스는 무동작. (ats d8f23c5의 luppiter 하드코딩을 일반화)
BN=$(basename "$FILE_PATH")
case "$BN" in
  *.java|*.kt|*.kts|*.jsp|*.js|*.ts|*.tsx|*.py|*.sql|*.xml)
    WS_ROOT="${WS_ROOT:-$(find_workspace_root "$FILE_PATH")}"
    if [ -d "$WS_ROOT/rulepacks" ]; then
      AGENT=$(grep -rlF "$BN" "$WS_ROOT"/rulepacks/*/rules-on-demand/*.md "$WS_ROOT"/rulepacks/*/agents/*.md 2>/dev/null | grep -v 'README' | head -1)
      if [ -n "$AGENT" ]; then
        AN="${AGENT#"$WS_ROOT"/}"
        TRANSCRIPT=$(echo "$TOOL_INPUT" | python3 -c "import json,sys;print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
        if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] || ! tail -3000 "$TRANSCRIPT" 2>/dev/null | grep -qF "$(basename "$AGENT")"; then
          echo "ℹ️ [참조 권고] $BN 편집 — 도메인 결정층 '$AN'(결정 이력·판단 시나리오)을 먼저 확인하세요. (soft, 미차단)"
        fi
      fi
    fi
    ;;
esac

# 프로젝트 루트를 못 찾은 경우 (pom.xml/package.json 없음) → 통과
exit 0
