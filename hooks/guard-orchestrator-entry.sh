#!/bin/bash
# Guard: code/config/ops write 작업은 orchestrator Gate 0 marker 필요
# Exemptions: pure markdown docs, .harness marker writes, read-only commands,
#             one-shot /tmp bypass marker.

set -euo pipefail

INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"
[ -n "$TOOL_INPUT" ] || exit 0

LOG="/tmp/claude-hook-hits.log"
BYPASS_MARKER="/tmp/.cairn-allow-orchestrator-entry"

EXTRACTED=$(printf '%s' "$TOOL_INPUT" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

ti = data.get("tool_input", data) if isinstance(data, dict) else {}
tool = data.get("tool_name") or data.get("tool") or ""
file_path = ti.get("file_path", "") or data.get("file_path", "") or ""
command = ti.get("command", "") or data.get("command", "") or ""

print(tool)
print("---CAIRN_FIELD---")
print(file_path)
print("---CAIRN_FIELD---")
print(command, end="")
')

TOOL_NAME=${EXTRACTED%%$'\n---CAIRN_FIELD---'*}
REST=${EXTRACTED#*$'\n---CAIRN_FIELD---'$'\n'}
FILE_PATH=${REST%%$'\n---CAIRN_FIELD---'*}
COMMAND=${REST#*$'\n---CAIRN_FIELD---'$'\n'}

find_workspace_root() {
  local start="$1"
  local dir
  if [ -n "$start" ] && [[ "$start" == /* ]]; then
    dir="$(dirname "$start")"
  else
    dir="$PWD"
  fi

  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/.cairn/workspace.yaml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  git rev-parse --show-toplevel 2>/dev/null || pwd
}

WORKSPACE_ROOT="$(find_workspace_root "$FILE_PATH")"
TRIAGE="$WORKSPACE_ROOT/.harness/triage.json"

rel_path() {
  local path="$1"
  if [[ "$path" == "$WORKSPACE_ROOT/"* ]]; then
    printf '%s\n' "${path#"$WORKSPACE_ROOT/"}"
  else
    printf '%s\n' "$path"
  fi
}

is_harness_path() {
  local rel
  rel="$(rel_path "$1")"
  [[ "$rel" == .harness/* || "$rel" == "$WORKSPACE_ROOT/.harness/"* ]]
}

is_tmp_path() {
  [[ "$1" == /tmp/* || "$1" == /private/tmp/* ]]
}

is_pure_md_doc_path() {
  local path="$1"
  local rel base
  rel="$(rel_path "$path")"
  base="$(basename "$rel")"

  [[ "$rel" == *.md ]] || return 1
  case "$base" in
    AGENTS.md|CLAUDE.md|CODEX.md|SKILL.md) return 1 ;;
  esac
  case "$rel" in
    .claude/*|.claude-plugin/*|hooks/*|scripts/*|schemas/*|skills/*|\
    agents/rules/*|agents/rules-on-demand/*|rules/*|rules-on-demand/*|\
    domains/*/skills/*|operations/skills/*)
      return 1
      ;;
  esac
  return 0
}

is_bash_write_intent() {
  COMMAND_TEXT="$1" python3 -c '
import os
import re
import sys

cmd = os.environ.get("COMMAND_TEXT", "")
patterns = [
    r"(^|[;&|]\s*)(touch|mkdir|rm|mv|cp|chmod|chown)\b",
    r"(^|[;&|]\s*)(cat|printf|echo)\b[^;&|]*(>|>>)",
    r"\btee\b",
    r"\bsed\s+-i\b",
    r"\bperl\s+-pi\b",
    r"\bgit\s+(add|commit|push|tag|merge|rebase|reset|checkout\s+--|clean)\b",
    r"\bgh\s+pr\s+(create|merge|close|edit)\b",
    r"\bkubectl\s+(apply|delete|patch|scale|rollout|create|replace)\b",
    r"\bhelm\s+(upgrade|install|uninstall|rollback)\b",
    r"\bargocd\s+app\s+(sync|set|delete|terminate-op)\b",
    r"\bvault\s+kv\s+(put|patch|delete|undelete|destroy)\b",
    r"\b(psql|mysql)\b.*\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE|GRANT|REVOKE)\b",
    r"\b(node|python3?|ruby)\b.*\b(writeFile|appendFile|fs\.write|File\.write)\b",
]
sys.exit(0 if any(re.search(p, cmd, re.IGNORECASE) for p in patterns) else 1)
'
}

is_harness_or_tmp_only_command() {
  COMMAND_TEXT="$1" python3 -c '
import os
import re
import sys

cmd = os.environ.get("COMMAND_TEXT", "")
if not re.search(r"(\.harness/|/tmp/|/private/tmp/)", cmd):
    sys.exit(1)

clean = re.sub(r"(\./)?\.harness/[^\s;&|<>]+", "", cmd)
clean = re.sub(r"/(?:private/)?tmp/[^\s;&|<>]+", "", clean)
danger = re.search(
    r"(src/|app/|lib/|hooks/|scripts/|schemas/|skills/|domains/|operations/|services/|"
    r"\.cairn/|\.claude/|\.claude-plugin/|AGENTS\.md|CLAUDE\.md|CODEX\.md|"
    r"package\.json|\.ya?ml|\.json|\.sh|\.sql|Dockerfile|Makefile)",
    clean,
)
sys.exit(1 if danger else 0)
'
}

is_pure_md_doc_command() {
  COMMAND_TEXT="$1" python3 -c '
import os
import re
import sys

cmd = os.environ.get("COMMAND_TEXT", "")
md_paths = re.findall(r"(?<![A-Za-z0-9_.-])([./A-Za-z0-9_@%+-][^ \t\n;&|<>]*\.md)", cmd)
if not md_paths:
    sys.exit(1)

for path in md_paths:
    base = path.rsplit("/", 1)[-1]
    if base in {"AGENTS.md", "CLAUDE.md", "CODEX.md", "SKILL.md"}:
        sys.exit(1)
    if re.search(r"(^|/)(\.claude|\.claude-plugin|hooks|scripts|schemas|skills|rules|rules-on-demand)(/|$)", path):
        sys.exit(1)
    if re.search(r"(^|/)domains/[^/]+/skills/|(^|/)operations/skills/", path):
        sys.exit(1)

clean = cmd
for path in md_paths:
    clean = clean.replace(path, "")
danger = re.search(
    r"(src/|app/|lib/|hooks/|scripts/|schemas/|skills/|domains/|operations/|services/|"
    r"\.cairn/|\.claude/|\.claude-plugin/|AGENTS\.md|CLAUDE\.md|CODEX\.md|"
    r"package\.json|\.ya?ml|\.json|\.sh|\.sql|Dockerfile|Makefile)",
    clean,
)
sys.exit(1 if danger else 0)
'
}

REQUIRES_TRIAGE=false
TARGET=""

case "$TOOL_NAME" in
  Write|Edit|MultiEdit)
    [ -n "$FILE_PATH" ] || exit 0
    TARGET="$FILE_PATH"
    if is_tmp_path "$FILE_PATH" || is_harness_path "$FILE_PATH" || is_pure_md_doc_path "$FILE_PATH"; then
      exit 0
    fi
    REQUIRES_TRIAGE=true
    ;;
  Bash)
    [ -n "$COMMAND" ] || exit 0
    TARGET="$COMMAND"
    if ! is_bash_write_intent "$COMMAND"; then
      exit 0
    fi
    if is_harness_or_tmp_only_command "$COMMAND" || is_pure_md_doc_command "$COMMAND"; then
      exit 0
    fi
    REQUIRES_TRIAGE=true
    ;;
  *)
    exit 0
    ;;
esac

[ "$REQUIRES_TRIAGE" = "true" ] || exit 0

if [ -f "$BYPASS_MARKER" ]; then
  rm -f "$BYPASS_MARKER"
  echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED orchestrator-entry (tmp bypass)" >> "$LOG"
  exit 0
fi

if [ -f "$TRIAGE" ]; then
  echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED orchestrator-entry (triage marker)" >> "$LOG"
  exit 0
fi

echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED orchestrator-entry (no triage marker): $TOOL_NAME $TARGET" >> "$LOG"
cat >&2 <<EOF
🚫 [guard-orchestrator-entry] 오케스트레이터 Gate 0 미통과

코드/설정/운영 write 의도는 먼저 orchestrator Gate 0을 통과해야 합니다.
필요 marker: $TRIAGE

절차:
  1. harness-orchestrator로 intent triage 수행
  2. Gate 0 분류 결과를 .harness/triage.json에 기록
  3. write 작업 재시도

면제:
  - 순수 markdown 문서 편집
  - .harness/ 자체 기록
  - 읽기 전용 Bash
  - 긴급 1회 우회: touch $BYPASS_MARKER
EOF
exit 2
