#!/bin/bash
# Project guard: only run in cairn engine repo
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ ! -f "$repo_root/AGENTS.md" || ! -d "$repo_root/hooks" ]] && exit 0

# Hook: 빌드/테스트 실패 감지 → 에이전트에 수정 제안 주입
# PostToolUse(Bash)
#
# exit 0 = 정상 (메시지는 에이전트 컨텍스트에 주입)

# tool 입출력 수집: 현재 하네스는 PostToolUse payload를 stdin JSON으로 전달한다.
# 실측(2026-06): env var(CLAUDE_TOOL_INPUT/OUTPUT/EXIT_CODE) 미전달, payload에 종료코드 필드 없음.
# → command/stdout/stderr만 추출하고, 빌드 실패는 출력 패턴으로 판정한다(EXIT_CODE 비의존).
INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
LOG="/tmp/claude-hook-hits.log"

if [ -n "${CLAUDE_TOOL_INPUT:-}" ]; then
  TOOL_INPUT="$CLAUDE_TOOL_INPUT"
  TOOL_OUTPUT="${CLAUDE_TOOL_OUTPUT:-}"
else
  TOOL_INPUT="$(echo "$INPUT_JSON" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null)"
  TOOL_OUTPUT="$(echo "$INPUT_JSON" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); r=d.get("tool_response",{})
    print((r.get("stdout","") or "")+"\n"+(r.get("stderr","") or ""))
except Exception: pass' 2>/dev/null)"
fi

# evidence writer: nearest .harness/state.json 찾기
update_evidence() {
  local status="$1"
  local key="$2"
  local state_file=""

  # cwd에서 상위로 탐색
  local dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.harness/state.json" ]; then
      state_file="$dir/.harness/state.json"
      break
    fi
    dir="$(dirname "$dir")"
  done

  [ -z "$state_file" ] && return

  # python3으로 JSON 업데이트 (jq 미설치 환경 대응)
  python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    with open('$state_file') as f:
        s = json.load(f)
    if 'evidence' not in s:
        s['evidence'] = {}
    s['evidence']['$key'] = {
        'status': '$status',
        'at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    }
    with open('$state_file', 'w') as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
except Exception:
    pass
" 2>/dev/null
}

# 빌드/테스트 명령어 분류
# grep -c는 매치 0이어도 "0"을 출력하므로 `|| echo 0` 불필요(중복 출력 유발).
IS_TEST=$(echo "$TOOL_INPUT" | grep -ciE 'pytest|npm test|npm run test|pnpm test|yarn test|go test|gradlew test|mvn test' 2>/dev/null)
IS_BUILD=$(echo "$TOOL_INPUT" | grep -ciE 'gradlew|gradle|mvn|npm run build|pnpm build|yarn build|go build|tsc' 2>/dev/null)

# evidence 키 결정: test 명령이면 unitTest, 빌드 명령이면 build
if [ "$IS_TEST" -gt 0 ]; then
  EVIDENCE_KEY="unitTest"
elif [ "$IS_BUILD" -gt 0 ]; then
  EVIDENCE_KEY="build"
else
  EVIDENCE_KEY=""
fi

# 빌드/테스트 명령이 아니면 종료 (감지 대상 아님)
[ -z "$EVIDENCE_KEY" ] && exit 0

# 종료코드가 payload에 없으므로 출력 실패 패턴으로 판정:
#   실패 패턴 매치 → fail / 매치 없음 → pass
if echo "$TOOL_OUTPUT" | grep -qiE 'BUILD FAILED|COMPILATION ERROR|FAILURE: Build failed|Test.*FAILED|npm ERR|pnpm ERR|yarn error|pytest.*FAILED|go test.*FAIL|mvn.*BUILD FAILURE|gradlew.*FAILURE|tsc.*error TS'; then
  echo "$(date +%Y-%m-%dT%H:%M:%S) BUILD_FAIL detected" >> "$LOG"
  update_evidence "fail" "$EVIDENCE_KEY"
  echo "🔴 빌드/테스트 실패 감지. 에러 메시지를 분석하고 수정을 시도하세요."
else
  update_evidence "pass" "$EVIDENCE_KEY"
fi

exit 0
