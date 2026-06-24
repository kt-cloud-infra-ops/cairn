---
name: dev-parallel-agents
description: "2개 이상의 독립 태스크를 동시 병렬 에이전트로 실행. 상태 공유/순차 의존성 없는 작업에 사용. (origin: superpowers/dispatching-parallel-agents)"
---

## 스킬 규칙
### ALWAYS
- 태스크 간 **공유 상태 없음**을 확인 후 병렬 실행
- 각 에이전트에 **명시적 컨텍스트** 구성 (메인 세션 history 상속 X)
- 단일 메시지 내 **여러 Agent tool call 동시 발행** (순차 발행 금지)
- 병렬 실행 결과를 **취합 후 검증**

### NEVER
- 태스크 간 의존성 있는데 병렬 실행 금지 → `dev-subagent-driven` (순차 + 리뷰) 사용
- 에이전트끼리 **상태 공유 가정** 금지
- 병렬 결과를 검증 없이 바로 머지 금지

## 실행 절차

1. 태스크 독립성 검증
   - 공유 파일 수정? → 의존성 있음
   - 순서가 결과에 영향? → 의존성 있음
   - 둘 다 NO → 병렬 OK
2. 각 에이전트용 컨텍스트 명시적 구성 (어떤 파일/정보 필요한지)
3. **단일 메시지에 N개 Agent tool call 발행**
4. 모든 결과 도착 후 취합
5. 충돌/누락 검증 → 정상 시 커밋

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 모든 병렬 태스크 결과 도착
- [ ] [MANUAL] 결과 간 충돌 없음 확인
- [ ] [MANUAL] 각 결과의 검증 통과

## 언제 사용하나

| 상황 | 사용 여부 |
|------|---------|
| 독립 태스크 2+ 개 + 순차 의존성 없음 | ✅ 이 스킬 |
| 태스크가 순차적이고 2단계 리뷰 필요 | → `dev-subagent-driven` |
| 단일 태스크만 | → 직접 실행 or Agent 1회 |

## 의사결정 트리 (어떤 dev-* 스킬 쓸지)

```
태스크가 독립적인가?
├─ NO → dev-subagent-driven (순차 + 2단계 리뷰)
└─ YES
   ├─ 파일 충돌 없이 동일 레포에서 실행?
   │  └─ YES → dev-parallel-agents (이 스킬, fresh context)
   └─ 파일 충돌 있음 or 물리 격리 필요?
      └─ dev-using-git-worktrees + dev-parallel-agents 조합
         (worktree별 분리 후 병렬 dispatch)
```

## `dev-subagent-driven`와 차이

| | dev-parallel-agents | dev-subagent-driven |
|---|---|---|
| 실행 | **동시 병렬** | 순차 per-task |
| 리뷰 | 최종 취합 검증 | 각 태스크 2단계 리뷰 (스펙→품질) |
| 사용처 | 독립 태스크 모음 (버그 3개 수정 등) | 구현 플랜 전체 실행 |
| 컨텍스트 | 각 에이전트 fresh, 메인 세션 유지 | 각 태스크 fresh subagent, 메인 세션 유지 |

## `dev-using-git-worktrees` 조합 시나리오

같은 파일/폴더를 여러 태스크가 건드려야 할 때:

1. `dev-using-git-worktrees`로 태스크별 worktree 생성
2. 각 worktree 경로를 컨텍스트로 주고 `dev-parallel-agents`로 동시 dispatch
3. 각 에이전트가 자기 worktree에서 커밋 → 메인으로 머지

## Origin (Vendor 흡수)

| 항목 | 값 |
|------|----|
| 원본 | [obra/superpowers — dispatching-parallel-agents](https://github.com/obra/superpowers) |
| vendor 사본 | [superpowers--dispatching-parallel-agents](../vendor/superpowers--dispatching-parallel-agents/SKILL.md) |
| 흡수 결정 | [ADR-006](../../../decisions/006-skill-unification.md) — PR #31 |
| 판정 | SUPPLEMENT (독립 태스크 병렬 실행) |
