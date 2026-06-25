#!/bin/bash
# Project guard: only run in cairn engine repo
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ ! -f "$repo_root/AGENTS.md" || ! -d "$repo_root/hooks" ]] && exit 0

# Hook: 릴리즈 액션 맥락 판별 + 차단
# PreToolUse(Bash)
#
# 맥락별 동작:
#   commit: staged 파일 기준 → workspace/ 코드면 차단
#   push/tag/PR: 최근 커밋 기준 → workspace/ 코드면 차단
#   문서/작업일지만 → 허용
#
# Override: /tmp/.claude-allow-commit (1회 허용)

# tool 입력 수집: 현재 하네스는 PreToolUse payload를 stdin JSON으로 전달한다.
# (형제 hook guard-service-orchestration.sh와 동일 계약) 구버전 CLAUDE_TOOL_INPUT env var는 fallback.
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"
LOG="/tmp/claude-hook-hits.log"

# checkout 안전 경고: 미커밋 변경이 있으면 경고
if echo "$TOOL_INPUT" | grep -qE 'git\s+(checkout|switch)\s'; then
  DIRTY=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  TOTAL=$((DIRTY + STAGED + UNTRACKED))
  if [ "$TOTAL" -gt 0 ]; then
    echo "⚠️ 미커밋 변경 ${DIRTY}건(unstaged) + ${STAGED}건(staged) + ${UNTRACKED}건(untracked) 있음. checkout/switch 시 유실 가능."
    echo "먼저 커밋하거나 git stash를 실행하세요."
  fi
  exit 0
fi

# 릴리즈 액션이 아니면 통과
if ! echo "$TOOL_INPUT" | grep -qE 'git\s+(commit|push|tag)|gh\s+pr\s+(create|merge)'; then
  exit 0
fi

ACTION=$(echo "$TOOL_INPUT" | grep -oE 'git\s+(commit|push|tag)|gh\s+pr\s+(create|merge)' | head -1)

# Override 파일 확인 (1회 허용)
if [ -f /tmp/.claude-allow-commit ]; then
  rm -f /tmp/.claude-allow-commit
  echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED $ACTION (override)" >> "$LOG"
  exit 0
fi

# 변경 파일 목록 수집 (액션에 따라 다른 소스)
FILES=""
case "$ACTION" in
  "git commit")
    FILES=$(git diff --cached --name-only 2>/dev/null)
    ;;
  "git push")
    # push 대상: 로컬에만 있는 커밋의 변경 파일
    REMOTE=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "origin/main")
    FILES=$(git diff --name-only "$REMOTE"..HEAD 2>/dev/null)
    ;;
  "git tag"|"gh pr create"|"gh pr merge")
    # 최근 커밋 범위의 변경 파일
    FILES=$(git diff --name-only origin/main..HEAD 2>/dev/null)
    ;;
esac

# 변경 파일이 없으면 통과
if [ -z "$FILES" ]; then
  exit 0
fi

# === git commit 전 review-evidence 검증 (orchestrator 의무 원칙 + dev-code-review — docs/HARNESS_DESIGN_RATIONALE.md) ===
# .harness/review-evidence.json 존재 + 5분 이내 + checks pass 검사
# 적용 범위: runtime 코드(projects/**, hooks/**, skills/**/scripts/**)만
# 면제: services/**, runbooks/**, knowledge/**, docs/**, *.md, SKILL.md, references/** 등 단순 문서
# 없거나 stale 시 commit 차단
if [ "$ACTION" = "git commit" ]; then
  # staged 파일이 runtime 코드를 포함하는지 검사
  REQUIRES_EVIDENCE=false
  RUNTIME_FILES=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
      # Runtime 코드 패턴 (evidence 필수)
      *.java|*.kt|*.kts|\
      *.jsp|*.js|*.ts|*.tsx|\
      *.py|*.go|*.rb|\
      *.sql|\
      pom.xml|build.gradle|build.gradle.kts|\
      Dockerfile|docker-compose.yml|\
      hooks/*.sh|.claude/settings.json|\
      skills/*/scripts/*)
        REQUIRES_EVIDENCE=true
        RUNTIME_FILES="$RUNTIME_FILES  - $file"$'\n'
        ;;
    esac
  done <<< "$FILES"

  if [ "$REQUIRES_EVIDENCE" = false ]; then
    # 모두 문서/메타 변경 → evidence 면제
    echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED $ACTION (no runtime files, evidence skipped)" >> "$LOG"
    # 이후 검사는 계속 진행 (workspace 코드 검사, 공통룰 분리 검사 등)
  else
    EVIDENCE="$repo_root/.harness/review-evidence.json"

    if [ ! -f "$EVIDENCE" ]; then
    echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED $ACTION (no review-evidence)" >> "$LOG"
    echo "⚠️ commit 전 코드 리뷰 evidence가 없습니다." >&2
    echo "" >&2
    echo "orchestrator 의무 원칙: 모든 변경 수반 요청은 orchestrator → owner skill → dev-code-review를 거친다 (docs/HARNESS_DESIGN_RATIONALE.md)." >&2
    echo "git commit 전에 dev-code-review 스킬을 호출하여 .harness/review-evidence.json을 생성하세요." >&2
    echo "" >&2
    echo "절차:" >&2
    echo "  1. dev-code-review 스킬 호출 (staged 변경 검토)" >&2
    echo "  2. 정상 통과 시 .harness/review-evidence.json 자동 생성" >&2
    echo "  3. guard-git-commit.sh가 evidence 검증 → 통과 시 commit 진행" >&2
    echo "" >&2
    echo "긴급 우회 (사용자 승인 필요): touch /tmp/.claude-allow-commit 후 재시도" >&2
    exit 2
  fi

  # evidence timestamp 5분 이내 검증 (python3 있을 때만)
  if command -v python3 >/dev/null 2>&1; then
    EVIDENCE_AGE=$(python3 -c "
import json, datetime, sys
try:
    with open('$EVIDENCE') as f:
        data = json.load(f)
    reviewed = datetime.datetime.fromisoformat(data['reviewedAt'].replace('Z', '+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    print(int((now - reviewed).total_seconds()))
except Exception:
    sys.exit(1)
" 2>/dev/null)
    if [ -n "$EVIDENCE_AGE" ] && [ "$EVIDENCE_AGE" -gt 300 ]; then
      echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED $ACTION (review-evidence stale: ${EVIDENCE_AGE}s)" >> "$LOG"
      echo "⚠️ review-evidence가 ${EVIDENCE_AGE}초 전 작성 — 5분 초과(stale)." >&2
      echo "dev-code-review 스킬을 다시 호출하여 evidence를 갱신하세요." >&2
      exit 2
    fi
  fi

  # checks 결과 = pass 검증 (단순 grep)
  if ! grep -q '"status"[[:space:]]*:[[:space:]]*"pass"' "$EVIDENCE"; then
    echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED $ACTION (review-evidence checks not pass)" >> "$LOG"
    echo "⚠️ review-evidence에 통과(pass) 항목이 없습니다." >&2
    echo "dev-code-review 결과가 정상이어야 commit 가능." >&2
    exit 2
  fi

    echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED $ACTION (evidence verified, runtime files:" >> "$LOG"
    printf '%s' "$RUNTIME_FILES" >> "$LOG"
    echo ")" >> "$LOG"
  fi  # end of REQUIRES_EVIDENCE else
fi  # end of git commit block

# 맥락 분류: REQUIRES_EVIDENCE=true였던 경우 이미 evidence 검증을 거쳤음
# push/tag/PR 경로에서 런타임 파일이 포함되면 확인 요청
HAS_CODE=false

if [ "$ACTION" != "git commit" ]; then
  while IFS= read -r file; do
    case "$file" in
      *.java|*.kt|*.kts|*.jsp|*.js|*.ts|*.tsx|*.py|*.go|*.rb|*.sql|\
      pom.xml|build.gradle|build.gradle.kts|Dockerfile|docker-compose.yml)
        HAS_CODE=true ;;
    esac
  done <<< "$FILES"
fi

# 개발 코드가 포함된 push/tag/PR이면 확인 요청
if [ "$HAS_CODE" = true ]; then
  echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED $ACTION (runtime code detected)" >> "$LOG"
  echo "⚠️ 런타임 코드 변경이 포함된 $ACTION 입니다."
  echo "사용자에게 확인을 받았다면: touch /tmp/.claude-allow-commit 후 재시도하세요."
  exit 2
fi

# === 공통룰 변경의 브랜치 분리 검사 (경고만) ===
# rules/git-workflow.md: 공통룰 변경은 rules/* 브랜치로 분리해야 함
# 현재 브랜치가 rules/*가 아닌데 공통룰 파일이 포함되면 경고

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ ! "$CURRENT_BRANCH" =~ ^rules/ ]]; then
  HAS_COMMON_RULE=false
  COMMON_RULE_FILES=""
  while IFS= read -r file; do
    case "$file" in
      rules/*|skills/*|templates/*|\
      hooks/*|.claude/settings.json|.claude/agents|\
      AGENTS.md|rules-on-demand/*)
        HAS_COMMON_RULE=true
        COMMON_RULE_FILES="$COMMON_RULE_FILES  - $file"$'\n'
        ;;
    esac
  done <<< "$FILES"

  if [ "$HAS_COMMON_RULE" = true ]; then
    echo "$(date +%Y-%m-%dT%H:%M:%S) WARN $ACTION (common-rule on non-rules branch: $CURRENT_BRANCH)" >> "$LOG"
    echo "⚠️ 공통룰 파일이 포함된 $ACTION 입니다. 현재 브랜치: $CURRENT_BRANCH"
    echo ""
    echo "감지된 공통룰 파일:"
    echo "$COMMON_RULE_FILES"
    echo "권장: 공통룰 변경은 rules/{설명} 브랜치로 분리 (rules/git-workflow.md)"
    echo "  git stash push -- <공통룰 파일들>"
    echo "  git checkout -b rules/{설명} main"
    echo "  git stash pop && git commit"
    echo ""
    echo "※ 경고만 발생. 그대로 진행해도 차단되지 않음."
  fi
fi

# 문서/설정만이면 허용
echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED $ACTION (no workspace code)" >> "$LOG"
exit 0
