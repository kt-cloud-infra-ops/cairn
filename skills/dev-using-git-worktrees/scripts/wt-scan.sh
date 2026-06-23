#!/bin/bash
# 고아 worktree 스캔. dev-using-git-worktrees 스킬 헬퍼.
# 사용법: wt-scan.sh [workspace-root] [stale-days]
#   - 기본 root: ~/Documents/develop/workspace, 기본 stale: 7일
#   - 각 메인 repo의 worktree 중 "미머지 0(머지완료) + stale-days 이상 방치" = 고아 경고
#   - 읽기 전용. 정리는 wt-done.sh가 수행.
# 종료코드: 항상 0 (점검 도구)
set -uo pipefail

ROOT="${1:-$HOME/Documents/develop/workspace}"
STALE_DAYS="${2:-7}"
NOW="$(date +%s)"
FOUND=0

[ -d "$ROOT" ] || { echo "ℹ️ workspace root 없음: $ROOT"; exit 0; }

# 메인 체크아웃(.git 디렉토리 보유)만 순회
for repo in "$ROOT"/*/; do
  [ -d "${repo}.git" ] || continue
  # 메인 외 worktree 목록 (porcelain)
  git -C "$repo" worktree list --porcelain 2>/dev/null | awk '
    /^worktree /{wt=$2}
    /^branch /{br=$2; print wt"\t"br}
  ' | while IFS=$'\t' read -r wt br; do
    # 메인 자신은 skip
    [ "$wt" = "${repo%/}" ] && continue
    [ -d "$wt" ] || continue
    ref="$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    [ -z "$ref" ] && ref="origin/$(git -C "$wt" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo main)"
    ahead="$(git -C "$wt" rev-list --count "${ref}..HEAD" 2>/dev/null || echo '?')"
    last="$(git -C "$wt" log -1 --format=%ct 2>/dev/null || echo 0)"
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    age_days=$(( (NOW - last) / 86400 ))
    # 고아 조건: 머지완료(ahead=0) + 미커밋 0 + stale 초과
    if [ "$ahead" = "0" ] && [ "$dirty" = "0" ] && [ "$age_days" -ge "$STALE_DAYS" ]; then
      ticket="${wt##*-}"
      echo "🟠 고아 worktree: $(basename "$wt") (머지완료·${age_days}일 방치)"
      echo "   정리: cd '${repo%/}' && bash <skill>/scripts/wt-done.sh ${ticket}"
    fi
  done
done

# prunable 잔재도 함께 보고
for repo in "$ROOT"/*/; do
  [ -d "${repo}.git" ] || continue
  prunable="$(git -C "$repo" worktree list --porcelain 2>/dev/null | grep -c '^prunable' || true)"
  [ "${prunable:-0}" -gt 0 ] && echo "🧹 $(basename "${repo%/}"): prunable worktree ${prunable}건 → git worktree prune"
done

exit 0
