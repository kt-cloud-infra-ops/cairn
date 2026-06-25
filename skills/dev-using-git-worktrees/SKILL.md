---
name: dev-using-git-worktrees
description: "git worktree로 작업 공간 격리. 현재 워크스페이스를 건드리지 않고 feature/구현 작업을 병렬로 진행할 때 사용. wt-new/wt-done/wt-scan 헬퍼로 생성·폐기·고아점검 원자화. (origin: superpowers/using-git-worktrees)"
---

## 스킬 규칙
### ALWAYS
- 생성·폐기·점검은 `scripts/` 헬퍼 사용 (수동 git 명령 지양 — 누락·명명일탈 방지)
- worktree는 **메인 체크아웃 상위 디렉토리**에 생성 (`workspace/` 내부 금지 — guard 오탐)
- 폐기 전 미커밋·미머지 검사 통과 (`wt-done`이 강제)

### NEVER
- 메인 체크아웃과 같은 브랜치를 worktree로 동시 checkout 금지
- worktree 생성 후 첫 액션으로 코드 수정 금지 — 브랜치/의존성 먼저 확인
- 작업 완료 후 worktree 방치 금지 (`wt-scan`이 고아 감지)
- worktree에서 docs/ 수정 후 머지 금지 (기본 브랜치 머지 시 docs 삭제 사고)

## 실행 절차

메인 체크아웃에서 헬퍼 실행 (스킬 `scripts/`):

```bash
bash scripts/wt-new.sh  <TICKET> [base-branch]   # 생성: base 판정+명명강제+중복차단
bash scripts/wt-done.sh <TICKET> [--force]       # 폐기: 미커밋·미머지 검사 후 정리
bash scripts/wt-scan.sh [workspace-root] [days]  # 고아 점검 (읽기 전용, 기본 7일)
```

- 생성 후 코드 작업 전 하네스 Phase 0(CPS) 진입 — `.harness/state.json`은 orchestrator가 생성(스크립트가 시드 안 함 → GATE 0 유지)
- 미머지 검사는 **생성 base(upstream)** 기준 — 서비스 repo develop 통합 브랜치 대응(origin/HEAD=main 오판 회피)
- base 판정·안티패턴 상세 → `harness-dev-process` GATE WORKTREE

## 격리 2-track

| 작업 유형 | 방식 | 정리 |
|-----------|------|------|
| 장기 feature (멀티 세션) | 명시 worktree (`wt-new`/`wt-done`) | `wt-done` 검증 후 |
| 단발 병렬 태스크 | Agent/Workflow `isolation:'worktree'` | 자동 (작업 종료 시) |

→ 정리 부담 없는 단발 병렬은 내장 자동 worktree 사용. 명시 worktree는 장기 feature에 한정.

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] worktree 경로에서 모든 커밋 완료
- [ ] [GIT] 원본 워킹트리 미변경
- [ ] [MANUAL] `wt-done.sh`로 worktree 제거 + 브랜치 정리

## 언제 사용하나

병렬 작업 / 격리 필요(실험적 변경) / 긴급 hotfix / 코드리뷰 시뮬레이션

## Origin (Vendor 흡수)

| 항목 | 값 |
|------|----|
| 원본 | [obra/superpowers — using-git-worktrees](https://github.com/obra/superpowers) |
| vendor 사본 | [superpowers--using-git-worktrees](../vendor/superpowers--using-git-worktrees/SKILL.md) |
| 흡수 결정 | 스킬 통합(commands→skills) 원칙 — `rules/skill-governance.md`. 조직 도입 근거·번호는 워크스페이스 `decisions/`(존재 시) 참조 |
| 판정 | SUPPLEMENT (worktree 격리 작업 공간) |
| 헬퍼 추가 | wt-new/wt-done/wt-scan 원자화 (rules/worktree-lifecycle) |
