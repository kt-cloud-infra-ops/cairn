#!/bin/bash
# worktree 폐기 원자화. dev-using-git-worktrees 스킬 헬퍼.
# 사용법: wt-done.sh <TICKET> [--force]
#   - 미커밋·미머지 변경 검사 → 안전할 때만 remove + prune + 로컬 브랜치 삭제
#   - --force: 미머지 경고 무시하고 강제 제거 (미커밋은 force여도 차단)
# 종료코드: 0 정리됨 / 1 사용법·검증 실패 / 2 안전검사 차단
set -uo pipefail

TICKET="${1:-}"
FORCE="${2:-}"

if [ -z "$TICKET" ]; then
  echo "사용법: wt-done.sh <TICKET> [--force]" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$ROOT" ] && { echo "❌ git repo가 아닙니다." >&2; exit 1; }
[ -d "$ROOT/.git" ] || { echo "❌ 메인 체크아웃에서 실행하세요." >&2; exit 1; }

REPO="$(basename "$ROOT")"
WT_DIR="$(dirname "$ROOT")/${REPO}-${TICKET}"
BRANCH="feature/${TICKET}"

if ! git worktree list --porcelain | grep -qF "worktree $WT_DIR"; then
  echo "❌ worktree 없음: $WT_DIR" >&2
  exit 1
fi

# 실제 브랜치명 재확인 (feature/{TICKET}-설명 형태 허용)
ACTUAL_BRANCH="$(git -C "$WT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "$BRANCH")"

# 1) 미커밋 검사 (force여도 차단)
DIRTY="$(git -C "$WT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
if [ "$DIRTY" -gt 0 ]; then
  echo "🔴 미커밋 변경 ${DIRTY}건 — 정리 차단. 커밋/stash 후 재실행." >&2
  exit 2
fi

# 2) 미머지 검사. 생성 base(upstream) 기준 — 서비스 repo의 develop 통합 브랜치 대응.
#    (origin/HEAD는 main을 가리켜 develop 기반 worktree를 오판하므로 upstream 우선)
git -C "$WT_DIR" fetch origin --quiet 2>/dev/null || true
REF="$(git -C "$WT_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
[ -z "$REF" ] && REF="origin/$(git -C "$WT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo main)"
AHEAD="$(git -C "$WT_DIR" rev-list --count "${REF}..HEAD" 2>/dev/null || echo '?')"
if [ "$AHEAD" != "0" ] && [ "$FORCE" != "--force" ]; then
  echo "🟡 ${REF} 대비 미머지 커밋 ${AHEAD}건 — 정리 보류." >&2
  echo "   머지 완료 후 재실행하거나, 폐기 확정 시: wt-done.sh $TICKET --force" >&2
  exit 2
fi

# 3) 제거 + prune + 로컬 브랜치 삭제
echo "→ git worktree remove $WT_DIR"
git worktree remove "$WT_DIR" ${FORCE:+--force}
git worktree prune
if git show-ref --verify --quiet "refs/heads/$ACTUAL_BRANCH"; then
  git branch -d "$ACTUAL_BRANCH" 2>/dev/null || git branch -D "$ACTUAL_BRANCH"
  echo "   로컬 브랜치 삭제: $ACTUAL_BRANCH"
fi

# origin 브랜치 잔존 안내 (자동 삭제 안 함)
if git show-ref --verify --quiet "refs/remotes/origin/$ACTUAL_BRANCH"; then
  echo "ℹ️ origin/$ACTUAL_BRANCH 잔존 — 머지 확인 후 삭제: git push origin --delete $ACTUAL_BRANCH"
fi
echo "✅ worktree 정리 완료: ${REPO}-${TICKET}"
