#!/usr/bin/env bash
# Sparrow 스캔 전 환경 점검. 4항목을 ✅/❌ 로 출력한다.
# 자격증명 값은 절대 출력하지 않는다(set 여부만).
#
# 사용법: bash skills/security-check-sparrow/scripts/preflight.sh
# 종료코드: 0=전부 통과, 1=미충족 항목 있음
set -uo pipefail
. "$(dirname "$0")/sparrow-env.sh"

ok=0; ng=0
mark() { if [ "$1" = "y" ]; then echo "✅ $2"; ok=$((ok+1)); else echo "❌ $2"; ng=$((ng+1)); fi; }

echo "── Sparrow preflight ──"
[ -n "${SPARROW_PROFILE_FILE:-}" ] && echo "   profile: $SPARROW_PROFILE_FILE"

# 1) 서버 주소 + 내부망 도달
if [ -z "${SPARROW_URL:-}" ]; then
  mark n "SPARROW_URL 미설정 (조직 서버 주소 — .cairn/profile/sparrow.env 또는 export)"
else
  H="$(sparrow_host)"; P="$(sparrow_port)"
  if [ -z "$H" ] || [ -z "$P" ]; then
    mark n "SPARROW_URL 파싱 실패: $SPARROW_URL"
  elif command -v nc >/dev/null 2>&1; then
    nc -z -w5 "$H" "$P" >/dev/null 2>&1 && mark y "내부망 도달 ($H:$P)" || mark n "내부망 도달 불가 ($H:$P) — VPN/방화벽 확인"
  else
    mark n "nc 미설치 — 내부망 도달 확인 불가"
  fi
fi

# 2) 자격증명 (set 여부만)
[ -n "${SPARROW_ID:-}" ] && mark y "SPARROW_ID" || mark n "SPARROW_ID"
[ -n "${SPARROW_PW:-}" ] && mark y "SPARROW_PW" || mark n "SPARROW_PW"
[ -n "${SPARROW_PROJECT_KEY:-}" ] && mark y "SPARROW_PROJECT_KEY (부모 키)" || mark n "SPARROW_PROJECT_KEY (부모 키)"

# 3) 클라이언트 설치
C="$(sparrow_resolve_client)"
[ -f "$C/sparrow-client.sh" ] && mark y "sparrow-client: $C" || mark n "sparrow-client 미설치 ($C/sparrow-client.sh 없음)"

# 4) TLS 설정 안내(판정 아님)
if [ -n "${SPARROW_CA:-}" ]; then echo "   TLS: 사설 CA 사용 ($SPARROW_CA)"
elif [ "${SPARROW_INSECURE:-false}" = "true" ]; then echo "   ⚠ TLS 검증 비활성(SPARROW_INSECURE=true) — 사설 CA 등록 권장"
else echo "   TLS: 기본 검증"
fi

echo "──"
if [ "$ng" -eq 0 ]; then
  echo "PASS: $ok 항목 충족. 스캔 진행 가능."
  exit 0
fi
echo "FAIL: 미충족 $ng 건. 스캔하지 말 것."
echo "→ 조치: docs/SECURITY_CHECK_SETUP.md 4절 (security-check-sparrow) 참조"
exit 1
