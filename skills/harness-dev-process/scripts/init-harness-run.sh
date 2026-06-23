#!/bin/bash
# init-harness-run.sh — 하네스 작업 시작 시 폴더 + state 자동 생성
#
# Usage: ./init-harness-run.sh <project-dir> [--level lite|standard|full] [--ticket ${JIRA_PROJECT_KEY}-XXX]

set -euo pipefail

PROJECT_DIR="${1:-.}"
LEVEL="standard"
TICKET=""

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --level) LEVEL="$2"; shift 2 ;;
    --ticket) TICKET="$2"; shift 2 ;;
    *) shift ;;
  esac
done

HARNESS_DIR="$PROJECT_DIR/.harness"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"

echo "🔧 Harness 초기화: $PROJECT_DIR (Level: $LEVEL)"

# 1. 디렉토리 생성
mkdir -p "$HARNESS_DIR"

# 2. state.json 생성 (evidence pointer 구조)
cat > "$HARNESS_DIR/state.json" << EOF
{
  "harnessLevel": "$LEVEL",
  "ticket": "$TICKET",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": "INIT",
  "docs": {
    "cps": null,
    "prd": null,
    "architecture": null,
    "taskPacket": null,
    "featureDoc": null
  },
  "approvals": {
    "user": false
  },
  "evidence": {
    "build": { "status": null, "log": null, "at": null },
    "unitTest": { "status": null, "report": null, "at": null },
    "codeReview": { "status": null, "report": null, "at": null },
    "securityReview": { "status": null, "report": null, "at": null },
    "regression": { "status": null, "report": null, "at": null },
    "localVerification": { "status": null, "at": null },
    "jiraAcceptance": { "status": null, "at": null },
    "worklog": { "status": null, "path": null, "at": null }
  }
}
EOF

# 3. 템플릿 복사
if [ -f "$TEMPLATE_DIR/feature-cps.md" ]; then
  cp "$TEMPLATE_DIR/feature-cps.md" "$PROJECT_DIR/feature-cps.md" 2>/dev/null || true
  echo "  ✓ feature-cps.md 복사"
fi

if [ "$LEVEL" != "lite" ]; then
  cp "$TEMPLATE_DIR/feature-prd.md" "$PROJECT_DIR/feature-prd.md" 2>/dev/null || true
  cp "$TEMPLATE_DIR/feature-architecture.md" "$PROJECT_DIR/feature-architecture.md" 2>/dev/null || true
  cp "$TEMPLATE_DIR/task-packet.md" "$PROJECT_DIR/task-packet.md" 2>/dev/null || true
  echo "  ✓ PRD, Architecture, Task Packet 복사"
fi

# 4. 피처 문서 자동 탐색 (ticket 기준)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [ -n "$TICKET" ]; then
  # 프로젝트 레포 docs/features/ 탐색 (workspace 내)
  FEATURE_DOC=$(grep -rl "$TICKET" "$REPO_ROOT/workspace/"*/docs/features/*.md 2>/dev/null | grep -v README.md | head -1)
  # fallback: 프로젝트 레포 루트가 workspace 밖에 있을 경우 (직접 지정된 프로젝트)
  if [ -z "$FEATURE_DOC" ] && [ -n "$PROJECT_DIR" ]; then
    FEATURE_DOC=$(grep -rl "$TICKET" "$PROJECT_DIR/docs/features/"*.md 2>/dev/null | grep -v README.md | head -1)
  fi
  if [ -n "$FEATURE_DOC" ]; then
    REL_PATH="${FEATURE_DOC#$REPO_ROOT/}"
    # state.json에 featureDoc 경로 기록
    python3 -c "
import json
with open('$HARNESS_DIR/state.json') as f:
    s = json.load(f)
s['docs']['featureDoc'] = '$REL_PATH'
with open('$HARNESS_DIR/state.json', 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
" 2>/dev/null
    echo "  ✓ 피처 문서 연결: $REL_PATH"
  fi
fi

echo "  ✓ state.json 생성 ($HARNESS_DIR/state.json)"
echo ""
echo "✅ 초기화 완료. 다음 단계:"
echo "   1. feature-cps.md 작성 (Charter Preflight 포함)"
echo "   2. node validate-doc-contracts.mjs feature-cps.md --type cps"
echo "   3. node validate-phase-gates.mjs . --phase PLAN"
