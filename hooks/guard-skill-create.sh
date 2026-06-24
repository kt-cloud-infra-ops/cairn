#!/bin/bash
# Guard: Skill 생성 시 중복 확인 + 필수 메타데이터 가이드
# Trigger: Write on agents/skills/*/SKILL.md, domains/*/skills/*/SKILL.md,
#          operations/skills/*/SKILL.md

set -euo pipefail

INPUT_JSON="$(cat 2>/dev/null || echo '{}')"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-$INPUT_JSON}"
[ -z "$TOOL_INPUT" ] && exit 0

echo "$(date): guard-skill-create triggered" >> /tmp/claude-hook-hits.log

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

is_cairn_context=false
if [ -f "$repo_root/AGENTS.md" ] || [ -f "$repo_root/.cairn/workspace.yaml" ] || [ -f "$repo_root/.claude-plugin/plugin.json" ]; then
  is_cairn_context=true
fi

[ "$is_cairn_context" = "true" ] || exit 0

EXTRACTED=$(printf '%s' "$TOOL_INPUT" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

ti = data.get("tool_input", data) if isinstance(data, dict) else {}
file_path = ti.get("file_path", "") or data.get("file_path", "") or ""
content = ti.get("content")
if content is None:
    content = ti.get("new_string")
if content is None:
    content = ""

print(file_path)
print("---CAIRN_CONTENT---")
print(content, end="")
')

FILE_PATH=${EXTRACTED%%$'\n---CAIRN_CONTENT---'*}
CONTENT=${EXTRACTED#*$'\n---CAIRN_CONTENT---'$'\n'}
[ -n "$FILE_PATH" ] || exit 0

REL_PATH="$FILE_PATH"
if [[ "$FILE_PATH" == "$repo_root/"* ]]; then
  REL_PATH=${FILE_PATH#"$repo_root/"}
fi

case "$REL_PATH" in
  agents/skills/*/SKILL.md)
    SKILL_SCOPE="core"
    REGISTRY_HINT=false
    ;;
  domains/*/skills/*/SKILL.md)
    SKILL_SCOPE="domain"
    REGISTRY_HINT=true
    ;;
  operations/skills/*/SKILL.md)
    SKILL_SCOPE="operations"
    REGISTRY_HINT=true
    ;;
  *)
    exit 0
    ;;
esac

if [ -f "$FILE_PATH" ] || [ -f "$repo_root/$REL_PATH" ]; then
  exit 0
fi

SKILL_NAME=$(printf '%s' "$REL_PATH" | sed -E 's|.*/skills/([^/]+)/SKILL\.md$|\1|')
PREFIX=$(printf '%s' "$SKILL_NAME" | sed 's/-[^-]*$//')

MISSING_FRONTMATTER=$(printf '%s' "$CONTENT" | python3 -c '
import re
import sys

text = sys.stdin.read()
required = ["name", "description", "triggers"]
fields = set()

if text.startswith("---"):
    match = re.search(r"\n---\s*(\n|$)", text[3:])
    if match:
        end = 3 + match.start()
        frontmatter = text[3:end]
        for line in frontmatter.splitlines():
            m = re.match(r"^\s*([A-Za-z0-9_-]+)\s*:", line)
            if m:
                fields.add(m.group(1))

missing = [key for key in required if key not in fields]
print(",".join(missing))
')

EXISTING_CORE=""
if [ -d "$repo_root/agents/skills" ]; then
  EXISTING_CORE=$(find "$repo_root/agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null | sed -E 's|.*/agents/skills/([^/]+)/SKILL\.md$|\1|' | grep -v '^vendor$' | sort || true)
fi

EXISTING_ENGINE=""
if [ -d "$repo_root/skills" ]; then
  EXISTING_ENGINE=$(find "$repo_root/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null | sed -E 's|.*/skills/([^/]+)/SKILL\.md$|\1|' | sort || true)
fi

EXISTING_WORKSPACE=""
if [ -d "$repo_root/domains" ] || [ -d "$repo_root/operations/skills" ]; then
  EXISTING_WORKSPACE=$(
    {
      [ -d "$repo_root/domains" ] && find "$repo_root/domains" -path '*/skills/*/SKILL.md' -print 2>/dev/null
      [ -d "$repo_root/operations/skills" ] && find "$repo_root/operations/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null
    } | sed "s|^$repo_root/||" | sort || true
  )
fi

SIMILAR=$(printf '%s\n%s\n' "$EXISTING_CORE" "$EXISTING_ENGINE" | grep "^${PREFIX}-" 2>/dev/null || true)

echo "⚠️ 새 스킬 생성 감지: $SKILL_NAME ($SKILL_SCOPE)"
echo ""
echo "📋 중복 확인 필수"
echo ""

if [ -n "$SIMILAR" ]; then
  echo "🔍 같은 prefix($PREFIX-*) 기존 스킬:"
  echo "$SIMILAR" | sed 's/^/  - /'
  echo ""
  echo "→ 기존 스킬 수정으로 해결 가능한지 먼저 확인하세요."
  echo ""
fi

if [ -n "$EXISTING_CORE" ]; then
  echo "📦 agents/skills:"
  echo "$EXISTING_CORE" | sed 's/^/  - /'
  echo ""
fi

if [ -n "$EXISTING_ENGINE" ]; then
  echo "📦 skills:"
  echo "$EXISTING_ENGINE" | sed 's/^/  - /'
  echo ""
fi

if [ -n "$EXISTING_WORKSPACE" ]; then
  echo "📦 workspace skills:"
  echo "$EXISTING_WORKSPACE" | sed 's/^/  - /'
  echo ""
fi

echo "✅ 최소 요건:"
echo "  - [ ] frontmatter: name, description, triggers"
echo "  - [ ] 준수 규칙 또는 GATE"
echo "  - [ ] 실행 절차"
echo "  - [ ] 완료 조건"

if [ "$REGISTRY_HINT" = "true" ]; then
  echo "  - [ ] .cairn/skills.yaml에 name/path/branch/triggers/description 등록"
fi
echo ""

if [ -n "$MISSING_FRONTMATTER" ]; then
  echo "🚫 차단: frontmatter 필수 항목 누락 ($MISSING_FRONTMATTER)"
  exit 2
fi

exit 0
