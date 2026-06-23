#!/usr/bin/env bash
# Cairn Capture 능동 제안 hook (Stop 이벤트용).
# 세션 종료 시점에 캡처할 만한 업무 변경이 있으면 cairn-capture를 제안한다.
# config(.cairn/config.json)의 capture.frequency / capture.proactive 를 존중한다.
#
# 등록 예 (hooks/hooks.json):
#   { "Stop": [ { "hooks": [ { "type": "command",
#       "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/cairn-capture-suggest.sh\"" } ] } ] }
#
# 출력 규약: 제안이 있으면 stdout 1블록 출력(사용자에게 노출), 없으면 조용히 종료.

set -euo pipefail

# --- 프로젝트 루트 결정 (git 우선, 실패 시 CWD) ---
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/.cairn/config.json"

# --- config 로드 (없으면 기본값: proactive=true, frequency=session-end) ---
FREQ="session-end"
PROACTIVE="true"
MODE="solo"
MIN_FILES=2
if [ -f "$CONFIG" ]; then
  # jq 있으면 정확히, 없으면 grep 폴백
  if command -v jq >/dev/null 2>&1; then
    FREQ="$(jq -r '.capture.frequency // "session-end"' "$CONFIG" 2>/dev/null || echo session-end)"
    PROACTIVE="$(jq -r '.capture.proactive // true' "$CONFIG" 2>/dev/null || echo true)"
    MODE="$(jq -r '.mode // "solo"' "$CONFIG" 2>/dev/null || echo solo)"
    MIN_FILES="$(jq -r '.capture.minSignal.filesChanged // 2' "$CONFIG" 2>/dev/null || echo 2)"
  fi
fi

# --- frequency=off 또는 proactive=false 면 noop ---
[ "$PROACTIVE" = "false" ] && exit 0
[ "$FREQ" = "off" ] && exit 0

# --- 변경 신호 측정: 워킹트리에서 바뀐 파일 수 (staged + unstaged + untracked) ---
CHANGED=0
if git -C "$ROOT" rev-parse >/dev/null 2>&1; then
  CHANGED="$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -cvE '^\s*$' || echo 0)"
fi

# --- 임계 미만이면 제안하지 않음 (노이즈 방지) ---
if [ "${CHANGED:-0}" -lt "${MIN_FILES:-2}" ]; then
  exit 0
fi

# --- 캡처 후보 힌트: 결정/스펙/SQL/신규파일 등 ---
HINT=""
if git -C "$ROOT" rev-parse >/dev/null 2>&1; then
  FILES="$(git -C "$ROOT" status --porcelain 2>/dev/null | awk '{print $2}' | head -8 | tr '\n' ' ')"
  HINT="변경: ${FILES}"
fi

# --- 제안 출력 ---
cat <<EOF

🪨 Cairn Capture 제안 — 이번 세션의 업무 지식을 남길까요? (${CHANGED}개 파일 변경)
   ${HINT}
   • lesson(재사용 패턴) / decision(결정·ADR) / sop(절차) / feature(설계) 중 분류해 md로 캡처
   • 실행: /cairn:capture   (mode=${MODE}${MODE:+, team이면 커밋·푸시 제안})
   • 끄기: .cairn/config.json 의 capture.frequency=off
EOF

exit 0
