#!/bin/bash
# guard-capture-secret.sh — Cairn Capture Loop Invariant: Secret 차단
# PreToolUse(Edit|Write)
#
# 동작:
#   Cairn 컨텍스트(cairn plugin 루트 또는 cairn-<team> workspace)에서만 발동.
#   캡처 저장 경로(.md)에 secret 패턴이 포함되면 하드 차단(exit 2).
#   ENV_STANDARD 토큰/플레이스홀더 패턴은 통과.
#
# 차단 패턴:
#   xoxb-/xoxs-/xoxa-/xoxp- (Slack token)
#   ghp_/gho_/github_pat_ (GitHub PAT)
#   AKIA[A-Z0-9]{16}           (AWS Access Key)
#   accountId 712020:          (Jira account ID 실값)
#   8자리 사번 숫자             (82xxxxxx 패턴)
#   password= / passwd= / pwd= (비밀번호 할당)
#   jdbc:.*:\/\/.+:.+@        (JDBC URL with credentials)
#
# 통과 패턴(ENV_STANDARD):
#   ${...} 환경변수 토큰
#   <YOUR_...> 플레이스홀더
#   # 주석 라인의 예시

set -euo pipefail

# ── Cairn 컨텍스트 판정 ──
# ${CLAUDE_PLUGIN_ROOT}는 Cairn plugin 설치 루트로 세팅됨
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

is_cairn_context() {
  # 1) CLAUDE_PLUGIN_ROOT가 cairn plugin 루트를 가리키면 OK
  if [ -n "$PLUGIN_ROOT" ] && [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    if grep -q '"name"[[:space:]]*:[[:space:]]*"cairn"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null; then
      return 0
    fi
  fi
  # 2) cwd가 cairn 또는 cairn-* workspace (AGENTS.md + knowledge/ 또는 decisions/ 마커)
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ]; then
    if { [ -d "$root/knowledge" ] || [ -d "$root/decisions" ] || [ -d "$root/runbooks" ]; } \
       && [ -f "$root/.claude-plugin/plugin.json" ]; then
      return 0
    fi
    # cairn-<team> workspace: services/ + decisions/ 패턴
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

# file_path 없으면 통과
[ -z "$FILE_PATH" ] && exit 0

# .md 파일만 검사
echo "$FILE_PATH" | grep -q '\.md$' || exit 0

# ── 캡처 저장 경로 판정 ──
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

# ── ENV_STANDARD 통과 패턴 제거 (치환 후 검사) ──
# 환경변수 토큰 ${...}, 플레이스홀더 <YOUR_...>는 안전 → 임시 마스킹
MASKED_CONTENT=$(echo "$CONTENT" | \
  sed 's/\${[A-Z_][A-Z0-9_]*}/__ENV_TOKEN__/g' | \
  sed 's/<YOUR_[A-Z_]*>/__PLACEHOLDER__/g' | \
  sed 's/#[^\n]*//' )

# ── Secret 패턴 검사 ──
SECRET_HIT=""

# Slack tokens (xox로 시작, 뒤에 b/s/a/p 등)
if echo "$MASKED_CONTENT" | grep -qE 'xox[bsap]-[0-9]{10,}-[A-Za-z0-9]+'; then
  SECRET_HIT="Slack API token (xox*-)"
fi

# GitHub PAT (ghp_/gho_/ghs_/ghr_/github_pat_ 패턴, 20자 이상이면 충분)
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -qE 'gh[psohr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{40,}'; then
    SECRET_HIT="GitHub Personal Access Token (ghp_/gho_/ghs_/github_pat_)"
  fi
fi

# AWS Access Key ID
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -qE 'AKIA[A-Z0-9]{16}'; then
    SECRET_HIT="AWS Access Key ID (AKIA...)"
  fi
fi

# Jira accountId 실값 (712020: 패턴)
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -qE 'accountId[[:space:]]*[=:][[:space:]]*[0-9]{6}:[a-f0-9-]{36}'; then
    SECRET_HIT="Jira accountId 실값"
  fi
fi

# 8자리 사번 (82xxxxxx 패턴) — 숫자만 8자리 중 82로 시작
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -qE '\b82[0-9]{6}\b'; then
    SECRET_HIT="사번 실값 (8자리, 82xxxxxx)"
  fi
fi

# password/passwd/pwd 할당 (값이 비어있지 않은 경우)
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -iqE '(password|passwd|pwd)\s*=\s*[^$<{][^\s]{3,}'; then
    SECRET_HIT="비밀번호 실값 (password=/passwd=/pwd=)"
  fi
fi

# JDBC URL with credentials (jdbc:driver://user:pass@host)
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -qE 'jdbc:[a-z]+://[^:]+:[^@]+@'; then
    SECRET_HIT="JDBC URL with credentials"
  fi
fi

# Bearer token (Authorization: Bearer <long-token>)
if [ -z "$SECRET_HIT" ]; then
  if echo "$MASKED_CONTENT" | grep -qiE 'Authorization\s*:\s*Bearer\s+[A-Za-z0-9._-]{20,}'; then
    SECRET_HIT="Bearer token (Authorization: Bearer ...)"
  fi
fi

# ── 결과 처리 ──
if [ -n "$SECRET_HIT" ]; then
  echo "🚫 [guard-capture-secret] SECRET 차단: $SECRET_HIT" >&2
  echo "" >&2
  echo "파일: $FILE_PATH" >&2
  echo "" >&2
  echo "Cairn Capture Loop 불변 원칙 2:" >&2
  echo "  NEVER: secret·token·API key·개인정보·사번 실값을 캡처 md에 포함하지 않는다." >&2
  echo "" >&2
  echo "조치:" >&2
  echo "  - API key/token → \${ENV_VARIABLE_NAME} 으로 대체 (config/ENV_STANDARD.md 참조)" >&2
  echo "  - 사번/accountId → <YOUR_EMPLOYEE_ID> / \${JIRA_ACCOUNT_ID} 으로 대체" >&2
  echo "  - 비밀번호 → \${DB_PASSWORD} 또는 <YOUR_PASSWORD> 로 대체" >&2
  exit 2
fi

exit 0
