#!/bin/bash
# worktree 생성 원자화. dev-using-git-worktrees 스킬 헬퍼.
# 사용법: wt-new.sh <TICKET> [base-branch]
#   - 현재 디렉토리를 repo 메인 체크아웃으로 가정
#   - 명명 규약 {repo}-{TICKET} 강제, 상위 디렉토리(../)에 생성 (workspace/ 내부 금지)
#   - base 미지정 시 origin 기본 브랜치 탐지값 출력 + 통합브랜치(develop) 주의
# 종료코드: 0 성공 / 1 사용법·검증 실패
set -euo pipefail

TICKET="${1:-}"
BASE="${2:-}"

if [ -z "$TICKET" ]; then
  echo "사용법: wt-new.sh <TICKET> [base-branch]" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$ROOT" ] && { echo "❌ git repo가 아닙니다 (메인 체크아웃에서 실행)." >&2; exit 1; }

# 링크 worktree가 아닌 메인 체크아웃인지 확인 (.git이 디렉토리)
[ -d "$ROOT/.git" ] || { echo "❌ 메인 체크아웃이 아닙니다(이미 worktree). 메인에서 실행하세요." >&2; exit 1; }

REPO="$(basename "$ROOT")"
WT_DIR="$(dirname "$ROOT")/${REPO}-${TICKET}"
BRANCH="feature/${TICKET}"

# 중복 검사
if git worktree list --porcelain | grep -qF "worktree $WT_DIR"; then
  echo "❌ 이미 존재하는 worktree: $WT_DIR" >&2
  exit 1
fi
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "❌ 이미 존재하는 브랜치: $BRANCH (같은 브랜치 2개 worktree 금지)" >&2
  exit 1
fi

# base branch 판정 (추정 금지 — 탐지값 표기하고 진행)
git fetch origin --quiet 2>/dev/null || true
if [ -z "$BASE" ]; then
  BASE="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || true)"
  [ -z "$BASE" ] && BASE="main"
  echo "ℹ️ base 미지정 → origin 기본 브랜치 '$BASE' 사용."
  echo "   통합 브랜치가 develop인 서비스 repo면: wt-new.sh $TICKET develop 로 재실행하세요."
fi
if ! git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
  echo "❌ origin/$BASE 가 없습니다. base branch를 확인하세요." >&2
  exit 1
fi

echo "→ git worktree add $WT_DIR -b $BRANCH origin/$BASE"
git worktree add "$WT_DIR" -b "$BRANCH" "origin/$BASE"

echo "✅ worktree 생성 완료"
echo "   경로:   $WT_DIR"
echo "   브랜치: $BRANCH (base: origin/$BASE)"
echo "   다음:   cd '$WT_DIR' → 코드 작업 전 하네스 Phase 0(CPS) 진입 (.harness/state.json은 orchestrator가 생성)"
