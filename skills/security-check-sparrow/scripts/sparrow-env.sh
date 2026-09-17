#!/usr/bin/env bash
# 공통 환경 해석 — 다른 sparrow 스크립트가 source 해서 쓴다. 단독 실행하지 않는다.
#
# 개인 경로·조직 고유값을 코드에 두지 않는다. 모든 값은 아래 우선순위로 해석한다:
#   1) 이미 export 된 환경변수
#   2) 워크스페이스 .cairn/profile/sparrow.env  (조직 공통값: URL, 부모 키, CA 경로 등)
#   3) 관례적 기본값 (클라이언트 설치 경로 후보)
# 자격증명(SPARROW_ID/SPARROW_PW)은 profile 파일에 두지 않는다. 셸 환경변수로만 받는다.

sparrow_fail() { echo "ERROR: $*" >&2; exit 2; }

# --- .cairn/profile/sparrow.env 로드 (있으면) ---
sparrow_load_profile() {
  local dir="${CAIRN_WORKSPACE:-$PWD}" f
  while [ "$dir" != "/" ]; do
    f="$dir/.cairn/profile/sparrow.env"
    if [ -f "$f" ]; then
      # 이미 set 된 환경변수가 우선하도록, 없는 값만 채운다
      local k v
      while IFS='=' read -r k v; do
        case "$k" in ''|\#*) continue;; esac
        k="${k#export }"; k="$(printf '%s' "$k" | tr -d '[:space:]')"
        v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
        [ -z "$k" ] && continue
        [ -n "${!k:-}" ] && continue
        export "$k=$v"
      done < "$f"
      export SPARROW_PROFILE_FILE="$f"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 0
}

# --- 클라이언트 경로 해석: 명시값 > ~/sparrow_client > ~/sparrow-client ---
sparrow_resolve_client() {
  if [ -n "${SPARROW_CLIENT:-}" ]; then printf '%s' "$SPARROW_CLIENT"; return; fi
  if [ -f "$HOME/sparrow_client/sparrow-client.sh" ]; then printf '%s' "$HOME/sparrow_client"
  else printf '%s' "$HOME/sparrow-client"; fi
}

# --- SPARROW_URL 에서 host/port 추출 ---
sparrow_host() { printf '%s' "${SPARROW_URL:-}" | sed -E 's#^[a-z]+://##; s#/.*$##; s#:.*$##'; }
sparrow_port() {
  local hp; hp="$(printf '%s' "${SPARROW_URL:-}" | sed -E 's#^[a-z]+://##; s#/.*$##')"
  case "$hp" in
    *:*) printf '%s' "${hp##*:}" ;;
    *) case "${SPARROW_URL:-}" in https://*) printf '443' ;; http://*) printf '80' ;; *) printf '' ;; esac ;;
  esac
}

# --- curl TLS 옵션: 기본은 검증 ON. 사설 CA는 SPARROW_CA, 검증 해제는 명시적 opt-in ---
sparrow_curl_tls_opts() {
  if [ -n "${SPARROW_CA:-}" ]; then printf '%s' "--cacert ${SPARROW_CA}"
  elif [ "${SPARROW_INSECURE:-false}" = "true" ]; then printf '%s' "-k"
  fi
}

sparrow_load_profile
