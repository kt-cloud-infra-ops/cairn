#!/usr/bin/env bash
# Cairn profile hook router.
# Finds the nearest Cairn workspace, reads .cairn/profile/hooks.yaml, and runs
# only enabled hooks for the requested event. Missing workspace/profile is no-op.

set -u

EVENT="${1:-}"
INPUT_JSON="$(cat 2>/dev/null || true)"

find_workspace() {
  local dir
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.cairn/workspace.yaml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

WORKSPACE_ROOT="$(find_workspace || true)"
[ -z "$WORKSPACE_ROOT" ] && exit 0

HOOKS_FILE="$WORKSPACE_ROOT/.cairn/profile/hooks.yaml"
[ -f "$HOOKS_FILE" ] || exit 0

parse_hooks() {
  python3 - "$HOOKS_FILE" "$EVENT" <<'PY'
import re
import sys

hooks_file = sys.argv[1]
event = sys.argv[2] if len(sys.argv) > 2 else ""

def normalize_event(value):
    raw = re.sub(r"[^A-Za-z]", "", (value or "")).lower()
    aliases = {
        "pretool": "pretooluse",
        "pretooluse": "pretooluse",
        "posttool": "posttooluse",
        "posttooluse": "posttooluse",
        "userprompt": "userpromptsubmit",
        "userpromptsubmit": "userpromptsubmit",
        "stop": "stop",
    }
    return aliases.get(raw, raw)

def clean_scalar(value):
    value = value.strip()
    if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
        value = value[1:-1]
    return value

def parse_bool(value):
    return clean_scalar(value).lower() in ("true", "yes", "on", "1")

def parse_inline_list(value):
    value = value.strip()
    if not (value.startswith("[") and value.endswith("]")):
        return []
    inner = value[1:-1].strip()
    if not inner:
        return []
    return [clean_scalar(part.strip()) for part in inner.split(",") if part.strip()]

try:
    lines = open(hooks_file, encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(0)

hooks = {}
current = None
in_hooks = False
collecting_events = False

for raw_line in lines:
    line = raw_line.split("#", 1)[0].rstrip()
    if not line.strip():
        continue

    indent = len(line) - len(line.lstrip(" "))
    stripped = line.strip()

    if indent == 0:
        in_hooks = stripped == "hooks:"
        current = None
        collecting_events = False
        continue

    if not in_hooks:
        continue

    if indent == 2 and stripped.endswith(":"):
        current = stripped[:-1].strip()
        hooks[current] = {"enabled": False, "command": "", "events": []}
        collecting_events = False
        continue

    if not current:
        continue

    if indent == 4 and ":" in stripped:
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip()
        collecting_events = key == "events" and value == ""

        if key == "enabled":
            hooks[current]["enabled"] = parse_bool(value)
        elif key == "command":
            hooks[current]["command"] = clean_scalar(value)
        elif key == "events":
            hooks[current]["events"] = parse_inline_list(value)
        continue

    if collecting_events and indent >= 6 and stripped.startswith("-"):
        hooks[current]["events"].append(clean_scalar(stripped[1:].strip()))

requested = normalize_event(event)
for name, spec in hooks.items():
    if not spec.get("enabled"):
        continue
    command = spec.get("command", "")
    if not command:
        continue
    events = [normalize_event(item) for item in spec.get("events", []) if item]
    if requested and events and requested not in events:
        continue
    print(f"{name}\t{command}")
PY
}

run_status=0

while IFS=$'\t' read -r hook_name command; do
  [ -z "${hook_name:-}" ] && continue

  if [[ "$command" = /* ]] || [[ "$command" == *".."* ]] || [[ "$command" =~ [[:space:]] ]]; then
    printf '[cairn-hook-router] skipped unsafe hook command: %s\n' "$hook_name" >&2
    continue
  fi

  hook_path="$WORKSPACE_ROOT/$command"
  if [ ! -f "$hook_path" ]; then
    printf '[cairn-hook-router] skipped missing hook: %s (%s)\n' "$hook_name" "$command" >&2
    continue
  fi

  if [ -x "$hook_path" ]; then
    printf '%s' "$INPUT_JSON" | "$hook_path" "$EVENT"
  else
    printf '%s' "$INPUT_JSON" | bash "$hook_path" "$EVENT"
  fi

  hook_status=$?
  if [ "$hook_status" -ne 0 ]; then
    run_status="$hook_status"
    break
  fi
done < <(parse_hooks)

exit "$run_status"
