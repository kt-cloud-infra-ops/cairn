#!/bin/bash
# Guard: workspace skill enforce registry hard gate.
# Runs only inside a Cairn workspace and only for Bash write commands.

set -euo pipefail

INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"
[ -n "$TOOL_INPUT" ] || exit 0

LOG="/tmp/claude-hook-hits.log"

EXTRACTED=$(printf '%s' "$TOOL_INPUT" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

ti = data.get("tool_input", data) if isinstance(data, dict) else {}
tool = data.get("tool_name") or data.get("tool") or ""
command = ti.get("command", "") or data.get("command", "") or ""

print(tool)
print("---CAIRN_FIELD---")
print(command, end="")
')

TOOL_NAME=${EXTRACTED%%$'\n---CAIRN_FIELD---'*}
COMMAND=${EXTRACTED#*$'\n---CAIRN_FIELD---'$'\n'}

[ "$TOOL_NAME" = "Bash" ] || exit 0
[ -n "$COMMAND" ] || exit 0

find_workspace() {
  local dir="$PWD"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/.cairn/workspace.yaml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

WORKSPACE_ROOT="$(find_workspace || true)"
[ -n "$WORKSPACE_ROOT" ] || exit 0

SKILLS_FILE="$WORKSPACE_ROOT/.cairn/skills.yaml"
[ -f "$SKILLS_FILE" ] || exit 0

set +e
MATCH=$(
  COMMAND_TEXT="$COMMAND" SKILLS_FILE="$SKILLS_FILE" python3 - <<'PY'
import os
import re
import sys

cmd = os.environ.get("COMMAND_TEXT", "")
skills_file = os.environ.get("SKILLS_FILE", "")

def has_file_output_redirection(value):
    single_quote = chr(39)
    double_quote = chr(34)
    in_single = False
    in_double = False
    index = 0

    while index < len(value):
        char = value[index]

        if in_single:
            if char == single_quote:
                in_single = False
            index += 1
            continue

        if in_double:
            if char == "\\":
                index += 2
                continue
            if char == double_quote:
                in_double = False
            index += 1
            continue

        if char == single_quote:
            in_single = True
            index += 1
            continue
        if char == double_quote:
            in_double = True
            index += 1
            continue
        if char == "\\":
            index += 2
            continue

        if char != ">":
            index += 1
            continue

        op_end = index + (2 if index + 1 < len(value) and value[index + 1] == ">" else 1)

        fd_start = index
        while fd_start > 0 and value[fd_start - 1].isdigit():
            fd_start -= 1
        fd = value[fd_start:index] if fd_start < index else ""

        target_start = op_end
        while target_start < len(value) and value[target_start].isspace():
            target_start += 1
        target_end = target_start
        while target_end < len(value) and not value[target_end].isspace() and value[target_end] not in ";&|":
            target_end += 1
        target = value[target_start:target_end]

        if target.startswith("&"):
            index = op_end
            continue
        if fd == "2":
            index = op_end
            continue
        if target == "/dev/null":
            index = op_end
            continue

        return True

    return False

def is_write_command(value):
    patterns = [
        r"(^|[;&|]\s*)(touch|mkdir|rm|mv|cp|chmod|chown)\b",
        r"(^|[;&|]\s*)tee\b(?:\s+-[A-Za-z]+)*\s+\S+",
        r"(^|[;&|]\s*)sponge\b\s+\S+",
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
    return has_file_output_redirection(value) or any(re.search(pattern, value, re.IGNORECASE) for pattern in patterns)

def clean_scalar(value):
    value = value.strip()
    if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
        return value[1:-1]
    return value

def split_inline_list(value):
    value = value.strip()
    if not (value.startswith("[") and value.endswith("]")):
        return []
    inner = value[1:-1].strip()
    if not inner:
        return []

    parts = []
    buf = []
    quote = None
    escape = False
    for char in inner:
        if escape:
            buf.append(char)
            escape = False
            continue
        if char == "\\":
            buf.append(char)
            escape = True
            continue
        if quote:
            if char == quote:
                quote = None
            buf.append(char)
            continue
        if char in ("'", '"'):
            quote = char
            buf.append(char)
            continue
        if char == ",":
            item = clean_scalar("".join(buf).strip())
            if item:
                parts.append(item)
            buf = []
            continue
        buf.append(char)

    item = clean_scalar("".join(buf).strip())
    if item:
        parts.append(item)
    return parts

def parse_registry(path):
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []

    skills = []
    current = None
    in_skills = False
    in_enforce = False
    collecting_patterns = False

    for raw in lines:
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue

        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if indent == 0:
            in_skills = stripped == "skills:"
            current = None
            in_enforce = False
            collecting_patterns = False
            continue

        if not in_skills:
            continue

        if indent == 2 and stripped.startswith("- "):
            current = {"name": "", "enforce": {"write_patterns": [], "requires_gate": ""}}
            skills.append(current)
            in_enforce = False
            collecting_patterns = False
            rest = stripped[2:].strip()
            if ":" in rest:
                key, value = rest.split(":", 1)
                if key.strip() == "name":
                    current["name"] = clean_scalar(value)
            continue

        if current is None:
            continue

        if indent == 4 and ":" in stripped:
            key, value = stripped.split(":", 1)
            key = key.strip()
            value = value.strip()
            collecting_patterns = False

            if key == "name":
                current["name"] = clean_scalar(value)
                in_enforce = False
            elif key == "enforce":
                in_enforce = True
            else:
                in_enforce = False
            continue

        if not in_enforce:
            continue

        if indent == 6 and ":" in stripped:
            key, value = stripped.split(":", 1)
            key = key.strip()
            value = value.strip()

            if key == "write_patterns":
                current["enforce"]["write_patterns"] = split_inline_list(value) if value else []
                collecting_patterns = value == ""
            elif key == "requires_gate":
                current["enforce"]["requires_gate"] = clean_scalar(value)
                collecting_patterns = False
            else:
                collecting_patterns = False
            continue

        if collecting_patterns and indent >= 8 and stripped.startswith("-"):
            pattern = clean_scalar(stripped[1:].strip())
            if pattern:
                current["enforce"]["write_patterns"].append(pattern)

    return skills

if not is_write_command(cmd):
    sys.exit(1)

for skill in parse_registry(skills_file):
    name = skill.get("name", "")
    enforce = skill.get("enforce", {})
    gate = enforce.get("requires_gate", "")
    for pattern in enforce.get("write_patterns", []):
        # bare 단어(영숫자/_)는 word-boundary 강제 — `updated_at` 류 부분문자열 오탐 방지(G-A).
        # 정규식 메타문자를 포함한 패턴(`psql.*` 등)은 작성자 의도대로 그대로 사용.
        effective = r"\b" + re.escape(pattern) + r"\b" if re.fullmatch(r"[A-Za-z0-9_]+", pattern) else pattern
        try:
            matched = re.search(effective, cmd, re.IGNORECASE)
        except re.error:
            continue
        if matched:
            print(f"{name}\t{gate}\t{pattern}")
            sys.exit(0)

sys.exit(1)
PY
)
MATCH_STATUS=$?
set -e

[ "$MATCH_STATUS" -eq 0 ] || exit 0

IFS=$'\t' read -r SKILL_NAME GATE_REL MATCH_PATTERN <<< "$MATCH"

case "$GATE_REL" in
  .harness/*) ;;
  *) exit 0 ;;
esac

if [[ "$GATE_REL" == *".."* ]] || [[ "$GATE_REL" = /* ]]; then
  exit 0
fi

GATE_PATH="$WORKSPACE_ROOT/$GATE_REL"

# marker 유효성(G-C): 존재 + (expires_at 없거나 미만료). 만료 marker는 제거하고 차단으로 진행.
if [ -f "$GATE_PATH" ]; then
  EXP_EPOCH=$(GATE_PATH="$GATE_PATH" python3 - <<'PY'
import json, os, datetime
try:
    d = json.load(open(os.environ["GATE_PATH"], encoding="utf-8"))
    exp = d.get("expires_at") if isinstance(d, dict) else None
    if exp:
        dt = datetime.datetime.fromisoformat(str(exp).replace("Z", "+00:00"))
        print(int(dt.timestamp()))
    else:
        print("")  # expires_at 없음 = 무기한(하위호환: 단순 marker)
except Exception:
    print("")  # 파싱 불가 = 무기한 취급(기존 단순 marker 호환)
PY
)
  if [ -z "$EXP_EPOCH" ] || [ "$(date +%s)" -le "$EXP_EPOCH" ]; then
    echo "$(date +%Y-%m-%dT%H:%M:%S) ALLOWED skill-enforce $SKILL_NAME (gate marker)" >> "$LOG"
    exit 0
  fi
  rm -f "$GATE_PATH"
  echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED skill-enforce $SKILL_NAME (marker expired, removed)" >> "$LOG"
fi

echo "$(date +%Y-%m-%dT%H:%M:%S) BLOCKED skill-enforce $SKILL_NAME (no gate marker): $COMMAND" >> "$LOG"
cat >&2 <<EOF
🚫 [guard-skill-enforce] 이 작업은 ${SKILL_NAME}의 GATE를 먼저 거쳐야 합니다.

매칭 패턴: ${MATCH_PATTERN}
필요 marker: ${GATE_PATH}

절차:
  1. ${SKILL_NAME} 스킬을 실행
  2. 스킬의 필수 GATE를 통과
  3. ${GATE_REL} marker 생성 후 write 작업 재시도
EOF
exit 2
