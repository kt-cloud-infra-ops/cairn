#!/bin/bash
# skill-sync-claude-2-codex / sync.sh
# Claude Code의 스킬(agents/skills/*)을 Codex가 인식하도록 ~/.codex/skills/에 심볼릭 링크
#
# 주의:
#   - vendor/ 는 제외
#   - skill-sync-claude-2-codex 자신은 제외 (자기 참조 방지)
#   - ~/.codex/skills/.system/ 은 건드리지 않음
#   - 이미 링크된 것은 재링크 (-f)

set -euo pipefail

# scripts/sync.sh → skill-sync-claude-2-codex/ → skills/ → agents/ → repo root
REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/agents/skills"
CODEX_DIR="$HOME/.codex/skills"

if [ ! -d "$CODEX_DIR" ]; then
  mkdir -p "$CODEX_DIR"
  echo "생성: $CODEX_DIR"
fi

echo "Sync: $SKILLS_DIR → $CODEX_DIR"
echo ""

COUNT=0
for dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$dir")
  [[ "$name" == "vendor" ]] && continue
  [[ "$name" == "skill-sync-claude-2-codex" ]] && continue
  [[ ! -f "$dir/SKILL.md" ]] && continue

  # 기존 링크/폴더 제거 (.system 보호)
  target="$CODEX_DIR/$name"
  if [ -L "$target" ] || [ -d "$target" ]; then
    rm -rf "$target"
  fi

  ln -sf "$dir" "$target"
  printf "  ✓ %s\n" "$name"
  COUNT=$((COUNT + 1))
done

echo ""
echo "✅ $COUNT 개 스킬 동기화 완료"
echo ""
echo "Codex에서 사용하려면 Codex 세션을 재시작하세요."
