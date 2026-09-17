#!/usr/bin/env bash
# 부모 프로젝트(SPARROW_PROJECT_KEY) 아래에서 저장소명과 일치하는 자식 projectKey 를 stdout 으로 출력한다.
#
# 왜 REST 인가: 계정에 /api/1/checkers/groups 권한이 없으면 mkproj -PL(project-list)이 403 이라
# 목록을 못 받는다. /api/1/projects 는 조회 가능하므로 REST 로 우회한다.
#
# 사용법: resolve_subproject.sh <REPO_NAME>
#   REPO_NAME : SourceChecker 의 projectName (보통 저장소 디렉터리명)
# 환경변수: SPARROW_ID, SPARROW_PW, SPARROW_PROJECT_KEY, SPARROW_URL
#           (선택) SPARROW_CA=사설 CA 경로 / SPARROW_INSECURE=true
# 종료코드: 0=찾음, 2=환경 미충족, 3=못 찾음(추측하지 말고 사용자에게 질문할 것)
set -euo pipefail
. "$(dirname "$0")/sparrow-env.sh"

REPO_NAME="${1:?저장소명(projectName) 인자가 필요합니다}"
: "${SPARROW_URL:?SPARROW_URL 필요 — .cairn/profile/sparrow.env 또는 export}"
: "${SPARROW_ID:?SPARROW_ID 환경변수 필요}"
: "${SPARROW_PW:?SPARROW_PW 환경변수 필요}"
: "${SPARROW_PROJECT_KEY:?SPARROW_PROJECT_KEY(부모) 환경변수 필요}"

TLS_OPTS="$(sparrow_curl_tls_opts)"

JSON="$(mktemp)"; COOKIE="$(mktemp)"; RESP="$(mktemp)"
trap 'rm -f "$JSON" "$COOKIE" "$RESP"' EXIT
chmod 600 "$JSON" "$COOKIE" "$RESP"

# 로그인 페이로드: 비번을 env→python json 으로 이스케이프. 명령행에 노출하지 않는다.
# force=true: 단일 세션 강제 로그인.
JSON="$JSON" python3 -c 'import json,os;open(os.environ["JSON"],"w").write(json.dumps({"userId":os.environ["SPARROW_ID"],"password":os.environ["SPARROW_PW"],"force":True}))'

# shellcheck disable=SC2086
if ! curl -s $TLS_OPTS -c "$COOKIE" -H 'Content-Type: application/json' \
      --data @"$JSON" "$SPARROW_URL/api/1/login" -o /dev/null -w '%{http_code}' | grep -q '^200$'; then
  echo "ERROR: 로그인 실패. 자동 재시도하지 않습니다(계정 잠금 위험)." >&2
  echo "  확인 순서: ① ~/.zshrc 의 SPARROW_PW 가 작은따옴표인지 ② 계정/비번 ③ 권한·IP" >&2
  exit 2
fi
# shellcheck disable=SC2086
curl -s $TLS_OPTS -b "$COOKIE" "$SPARROW_URL/api/1/projects" -o "$RESP"

REPO_NAME="$REPO_NAME" RESP="$RESP" python3 - <<'PY'
import json, os, sys
try:
    d = json.load(open(os.environ["RESP"]))
except Exception as e:
    sys.stderr.write(f"프로젝트 목록 파싱 실패: {e}\n"); sys.exit(2)
repo = os.environ["REPO_NAME"]; parent = os.environ["SPARROW_PROJECT_KEY"]
items = d.get("list", []) if isinstance(d, dict) else []
# 1순위: 이름 일치 + 부모 키 일치
for p in items:
    if p.get("projectName") == repo and (p.get("parentProject") or {}).get("projectKey") == parent:
        print(p["projectKey"]); sys.exit(0)
# 2순위: 이름만 일치
for p in items:
    if p.get("projectName") == repo:
        print(p["projectKey"]); sys.exit(0)
sys.stderr.write(
    f"하위 프로젝트를 못 찾음: name={repo} parent={parent}\n"
    "→ 키를 추측하지 말고 사용자에게 확인할 것.\n"
    "접근가능 목록: " + ", ".join(f"{p.get('projectName')}({p.get('projectKey')})" for p in items) + "\n")
sys.exit(3)
PY
