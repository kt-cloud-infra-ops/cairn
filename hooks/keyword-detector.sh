#!/bin/bash
# Cross-repo self-guard (ADR-011): 가드 대상 repo만, 무관 repo 즉시 통과
# user 레벨(${CLAUDE_HOME:-$HOME/.claude}/settings.json) 절대경로 실행 → worktree 포함 모든 cwd 발동.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
is_guarded_repo() {
  local root="$1"
  [ -z "$root" ] && return 1
  [ -f "$root/AGENTS.md" ] && [ -d "$root/agents/skills" ] && return 0   # cairn plugin repo
  [ -d "$root/.harness" ] && return 0                                     # 하네스 활성 프로젝트
  return 1
}
is_guarded_repo "$repo_root" || exit 0

# Hook: 사용자 입력에서 키워드 감지 → branch/phase hint 유도
# UserPromptSubmit
#
# 동작:
#   1. 사용자 입력에서 키워드 매칭
#   2. 매칭되면 해당 Phase 안내 메시지를 에이전트에 주입
#   3. 슬래시 커맨드(/)로 시작하면 skip
#   4. 정보 질문(뭐야, 설명해)이면 skip

PROMPT="${CLAUDE_USER_PROMPT:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRIGGERS="$SCRIPT_DIR/triggers.json"
LOG="/tmp/claude-hook-hits.log"

# ── 세션 첫 호출: 미커밋 하네스 변경 감지 ──
# PPID 기반 플래그로 세션당 1회만 실행
HARNESS_SESSION_FLAG="/tmp/claude-harness-checked-$PPID"
if [ ! -f "$HARNESS_SESSION_FLAG" ]; then
  touch "$HARNESS_SESSION_FLAG"
  HARNESS_DIRTY=$(git diff --name-only HEAD 2>/dev/null | grep -E '(agents/rules/|agents/rules-on-demand/|agents/skills/|\.claude/hooks/|\.claude/settings\.json|AGENTS\.md)' 2>/dev/null)
  if [ -n "$HARNESS_DIRTY" ]; then
    COUNT=$(echo "$HARNESS_DIRTY" | wc -l | tr -d ' ')
    FILES=$(echo "$HARNESS_DIRTY" | head -5 | sed 's/^/  - /')
    echo "⚠️ 미커밋 하네스 변경 ${COUNT}건 감지:"
    echo "$FILES"
    [ "$COUNT" -gt 5 ] && echo "  - ... 외 $((COUNT-5))건"
    echo "정합성 검토: /harnessing | 커밋 필요 시 알려주세요."
  fi
fi

# triggers.json 없으면 통과
if [ ! -f "$TRIGGERS" ]; then
  exit 0
fi

# 슬래시 커맨드면 skip
if echo "$PROMPT" | grep -qE '^\s*/'; then
  exit 0
fi

# 정보 질문 skip
SKIP_PATTERNS=$(python3 -c "
import json
with open('$TRIGGERS') as f:
    d = json.load(f)
print('|'.join(d.get('skipPatterns', [])))
" 2>/dev/null)

if [ -n "$SKIP_PATTERNS" ] && echo "$PROMPT" | grep -qE "$SKIP_PATTERNS"; then
  exit 0
fi

# 키워드 매칭 — command|message 형식으로 출력
MATCH=$(python3 -c "
import json, sys

prompt = '''$PROMPT'''

with open('$TRIGGERS') as f:
    triggers = json.load(f)

for mapping in triggers['mappings']:
    for keyword in mapping['keywords']:
        if keyword in prompt:
            print(mapping['command'] + '|||' + mapping['message'])
            sys.exit(0)
" 2>/dev/null)

if [ -z "$MATCH" ]; then
  exit 0
fi

MATCHED_CMD="${MATCH%%|||*}"
MATCHED_MSG="${MATCH#*|||}"

echo "$(date +%Y-%m-%dT%H:%M:%S) KEYWORD_MATCH: $MATCHED_CMD" >> "$LOG"

# ── service-bootstrap / service-ops / harnessing-route: branch hint 안내 ──
if [ "$MATCHED_CMD" = "service-bootstrap" ] || [ "$MATCHED_CMD" = "service-ops" ] || [ "$MATCHED_CMD" = "harnessing-route" ]; then
  echo "$MATCHED_MSG"
# ── workflow 명령: dev branch state.json 기반 동적 phase 체크 ──
elif [ "$MATCHED_CMD" = "workflow" ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  STATE_FILE=""
  # .harness/state.json 탐색 (현재 디렉토리 기준 최근 harness)
  if [ -n "$REPO_ROOT" ]; then
    STATE_FILE=$(find "$REPO_ROOT/.harness" -name "state.json" 2>/dev/null | head -1)
    if [ -z "$STATE_FILE" ]; then
      STATE_FILE="$REPO_ROOT/.harness/state.json"
    fi
  fi

  if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
    python3 -c "
import json, sys
with open('$STATE_FILE') as f:
    s = json.load(f)

ticket  = s.get('ticket', '[미확인]')
phase   = s.get('phase', 'UNKNOWN')
level   = s.get('harnessLevel', '?')
ev      = s.get('evidence', {})

phases = [
  ('INIT',   'Phase 0 INIT  → CPS + 영향도 분석 8항목'),
  ('PLAN',   'Phase 1 PLAN  → PRD + Architecture + 사용자 승인'),
  ('IMPL',   'Phase 2 IMPL  → 구현 + Task Packet'),
  ('VERIFY', 'Phase 3 VERIFY→ 빌드 + 테스트 + 코드리뷰 + 보안검토'),
  ('SHIP',   'Phase 4 SHIP  → 배포 + Jira A.C. DONE + 작업일지'),
]
order = [p[0] for p in phases]
current_idx = order.index(phase) if phase in order else -1

print(f'🔄 개발 Phase 체크 [{ticket}] (level={level})')
print()
for i, (p, desc) in enumerate(phases):
    if i < current_idx:
        mark = '✅'
    elif i == current_idx:
        mark = '▶ '
    else:
        mark = '⬜'
    print(f'  {mark} {desc}')
print()

# evidence 미완 항목
pending = [k for k, v in ev.items() if v.get('status') != 'pass']
if pending:
    print('  미완 evidence: ' + ', '.join(pending))
print()
print(f'  state.json: $STATE_FILE')
" 2>/dev/null || echo "$MATCHED_MSG"
  else
    # state.json 없음 → 자동 생성 (Phase=INIT)
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" << 'STATEOF'
{
  "phase": "INIT",
  "harnessLevel": "standard",
  "ticket": "[TBD]",
  "createdAt": "auto",
  "evidence": {}
}
STATEOF
    # createdAt을 실제 시간으로 교체
    python3 -c "
import json, datetime
f = '$STATE_FILE'
d = json.load(open(f))
d['createdAt'] = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
json.dump(d, open(f, 'w'), indent=2, ensure_ascii=False)
" 2>/dev/null

    echo "🔄 하네스 프로세스 시작 — state.json 생성 (Phase 0: INIT)"
    echo ""
    echo "  ✅ .harness/state.json 생성 완료"
    echo "  📍 Phase 0: INIT — CPS(Charter Preflight) 먼저 작성"
    echo ""
    echo "  ⬜ Phase 0 INIT  → CPS 작성: Charter + 영향도 분석 8항목"
    echo "  ⬜ Phase 1 PLAN  → PRD + Architecture + 사용자 승인"
    echo "  ⬜ Phase 2 IMPL  → Charter/PRD 확인 후 구현"
    echo "  ⬜ Phase 3 VERIFY→ 빌드 + 테스트 + 코드리뷰 + 보안검토"
    echo "  ⬜ Phase 4 SHIP  → 배포 + Jira A.C. DONE + 작업일지"
    echo ""
    echo "  ⚠️ 코드 변경(Edit/Write)은 Phase 2(IMPL) 이후에만 허용됩니다."
    echo "  템플릿: agents/skills/harness-dev-process/templates/"
  fi
# ── impl 명령: GATE 1→2 검사 — CPS + PRD 없으면 blocking ──
elif [ "$MATCHED_CMD" = "impl" ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  MISSING=""

  if [ -n "$REPO_ROOT" ]; then
    # CPS 확인 (feature-cps.md 또는 cps.md)
    CPS=$(find "$REPO_ROOT" -name "feature-cps.md" -o -name "cps.md" 2>/dev/null | grep -v ".harness" | head -1)
    # PRD 확인 (feature-prd.md 또는 prd.md)
    PRD=$(find "$REPO_ROOT" -name "feature-prd.md" -o -name "prd.md" 2>/dev/null | grep -v ".harness" | head -1)

    [ -z "$CPS" ] && MISSING="${MISSING}  ❌ feature-cps.md 없음 → Phase 0 INIT 먼저\n"
    [ -z "$PRD" ] && MISSING="${MISSING}  ❌ feature-prd.md 없음 → Phase 1 PLAN 먼저\n"
  else
    MISSING="  ⚠️ Git repo 루트를 찾을 수 없음\n"
  fi

  if [ -n "$MISSING" ]; then
    echo "🚫 GATE 1→2 실패: 선행 Phase 근거 없음"
    echo ""
    printf "%b" "$MISSING"
    echo ""
    echo "구현을 진행하지 마세요. Phase 0→1 완료 후 재시도하세요."
    echo "템플릿: agents/skills/harness-dev-process/templates/"
    exit 2
  else
    echo "✅ GATE 1→2 통과"
    echo "  CPS: $CPS"
    echo "  PRD: $PRD"
    echo ""
    echo "$MATCHED_MSG"
  fi

else
  echo "$MATCHED_MSG"
fi

exit 0
