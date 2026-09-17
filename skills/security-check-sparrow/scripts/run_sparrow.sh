#!/usr/bin/env bash
# Sparrow (SourceChecker) SAST 로컬 스캔 래퍼.
# 자격증명은 환경변수에서만 읽고, 값을 로그·영구파일·명령행에 남기지 않는다.
#
# 사용법:
#   run_sparrow.sh [TARGET_DIR] [PROJECT_KEY] [--dry-run]
#     TARGET_DIR  : 스캔 대상 소스 루트 (기본: 현재 디렉터리)
#     PROJECT_KEY : 자식 프로젝트 키 (기본: $SPARROW_PROJECT_KEY)
#     --dry-run   : 실행할 명령만 출력하고 스캔하지 않음
#
# 환경변수:
#   SPARROW_ID  SPARROW_PW  SPARROW_PROJECT_KEY  SPARROW_URL   (필수)
#   SPARROW_CLIENT   클라이언트 설치 경로 (기본 ~/sparrow_client → ~/sparrow-client)
#   SPARROW_LEVEL    분석 레벨 (기본 all)
#   SPARROW_NOUPDATE true(기본)면 -NU 로 자동업데이트 우회
#   IS_FORCE_EXIT    true 면 위험 1건 이상에서 exit 1 (기본 false=경고만)
#
# TARGET_DIR 해석: ':' 다중경로면 그대로 / <dir>/src 있으면 그것 /
#   멀티모듈(<dir>/*/src)이면 ':' 결합 / 아니면 디렉터리 자체.
#
# ⚠ 아래 위험 합산은 보조 지표다. 확정 건수는 REST /api/1/scans/<id>/issues 로 재확인할 것.
set -euo pipefail
. "$(dirname "$0")/sparrow-env.sh"

DRY_RUN=false
ARGS=()
for a in "$@"; do
  case "$a" in --dry-run) DRY_RUN=true ;; *) ARGS+=("$a") ;; esac
done

TARGET_DIR="${ARGS[0]:-$PWD}"
PROJECT_KEY="${ARGS[1]:-${SPARROW_PROJECT_KEY:-}}"
LEVEL="${SPARROW_LEVEL:-all}"
IS_FORCE_EXIT="${IS_FORCE_EXIT:-false}"
NOUPDATE="${SPARROW_NOUPDATE:-true}"
SPARROW_CLIENT="$(sparrow_resolve_client)"

[ -n "${SPARROW_URL:-}" ] || sparrow_fail "SPARROW_URL 이 없습니다. .cairn/profile/sparrow.env 또는 export 로 설정하세요."
[ -n "${SPARROW_ID:-}" ] || sparrow_fail "환경변수 SPARROW_ID 가 없습니다."
[ -n "${SPARROW_PW:-}" ] || sparrow_fail "환경변수 SPARROW_PW 가 없습니다."
[ -n "$PROJECT_KEY" ] || sparrow_fail "프로젝트 키가 없습니다. 2번째 인자 또는 SPARROW_PROJECT_KEY 로 지정하세요."

# -SD 경로 결정
resolve_sd() {
  local t="$1" d; local mods=()
  case "$t" in *:*) printf '%s' "$t"; return;; esac
  [ -d "$t" ] || sparrow_fail "대상 디렉터리 없음: $t"
  if [ -d "$t/src" ]; then printf '%s' "$t/src"; return; fi
  for d in "$t"/*/src; do [ -d "$d" ] && mods+=("$d"); done
  if [ ${#mods[@]} -gt 0 ]; then local IFS=:; printf '%s' "${mods[*]}"; else printf '%s' "$t"; fi
}
SD="$(resolve_sd "$TARGET_DIR")"
IFS=: read -ra _segs <<< "$SD"
for s in "${_segs[@]}"; do [ -d "$s" ] || sparrow_fail "스캔 경로 없음: $s"; done

CLIENT_SH="$SPARROW_CLIENT/sparrow-client.sh"
[ -f "$CLIENT_SH" ] || sparrow_fail "sparrow-client 가 없습니다: $CLIENT_SH
  → 설치 후 SPARROW_CLIENT 로 경로를 지정하세요. 조치: docs/SECURITY_CHECK_SETUP.md 4절"

# 로컬 자동업데이트 우회: 잔재 err_update 제거 + -NU
NU_FLAG=""
if [ "$NOUPDATE" = "true" ]; then rm -f "$SPARROW_CLIENT/err_update"; NU_FLAG="-NU"; fi

echo "INFO: url=$SPARROW_URL project=$PROJECT_KEY level=$LEVEL"
echo "INFO: -SD=$SD"

if [ "$DRY_RUN" = "true" ]; then
  echo "DRY-RUN: bash $CLIENT_SH $NU_FLAG -S $SPARROW_URL -U <SPARROW_ID> -PW <임시파일> -P $PROJECT_KEY -SD $SD -L $LEVEL"
  echo "DRY-RUN: 스캔을 실행하지 않았습니다."
  exit 0
fi

PW_FILE="$(mktemp)"; RESULT_FILE="$(mktemp)"
cleanup() { rm -f "$PW_FILE" "$RESULT_FILE"; }
trap cleanup EXIT
( umask 077; printf '%s' "$SPARROW_PW" > "$PW_FILE" )

echo "INFO: Sparrow 스캔 시작"
bash "$CLIENT_SH" $NU_FLAG -S "$SPARROW_URL" -U "$SPARROW_ID" -PW "$PW_FILE" \
  -P "$PROJECT_KEY" -SD "$SD" -L "$LEVEL" | tee "$RESULT_FILE"

# 위험 합산 (level 1~4, level 5 제외).
# 체커명에 '.' 이 포함되는 경우(예: .KOTLIN)를 놓치지 않도록 [A-Za-z0-9_.]+ 로 매칭한다.
total=0
while read -r line; do
  if [[ "$line" =~ ^[[:space:]]*([1-5])[[:space:]]+[A-Za-z0-9_.]+[[:space:]]+([0-9]+) ]]; then
    lvl="${BASH_REMATCH[1]}"; num="${BASH_REMATCH[2]}"
    [ "$lvl" -ne 5 ] && total=$((total + num))
  fi
done < "$RESULT_FILE"

echo "INFO: Total Risk Sum (보조 지표): $total"
echo "INFO: 확정 건수는 REST /api/1/scans/<id>/issues 로 재확인하세요."
if [ "$total" -eq 0 ]; then
  echo "INFO: 합산 0건 — 스캔 결과 콘솔에서 반드시 교차 확인할 것."
elif [ "$IS_FORCE_EXIT" = "false" ]; then
  echo "WARNING: 위험 ${total} 건 감지 (경고만, 진행)."
else
  echo "ERROR: 위험 ${total} 건 감지. 실패 처리."
  exit 1
fi
