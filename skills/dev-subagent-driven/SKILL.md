---
name: dev-subagent-driven
description: "구현 플랜을 병렬 subagent로 디스패치 실행. 각 태스크마다 fresh context + 2단계 리뷰(스펙→품질). 현재 세션에서 진행. (origin: superpowers/subagent-driven-development)"
---

## 스킬 규칙
### ALWAYS
- 태스크별 **fresh subagent** 디스패치 — 메인 세션 컨텍스트 상속 금지
- subagent에 필요한 컨텍스트만 **명시적으로 구성**해서 전달
- 각 태스크 완료 후 **2단계 리뷰**: (1) 스펙 준수 → (2) 품질
- 모든 태스크 완료 후 **전체 최종 리뷰** 1회 추가
- TodoWrite로 진행 추적
- **태스크 단위 순서**: 구현 → [GATE 1: 스펙 리뷰] → [GATE 2: 품질 리뷰] → 다음 태스크
- **종료 직전**: 모든 태스크 완료 후 [GATE FINAL: 전체 최종 리뷰] 통과

### NEVER
- subagent가 메인 세션의 history/todo를 상속받게 두기 금지
- 리뷰 단계 건너뛰기 금지 (스펙만 OK → 품질 생략 X)
- 태스크 간 컨텍스트 오염 금지 (fresh 원칙)
- **[GATE 1] 통과 전 [GATE 2] 진행 금지** (스펙 미통과로 품질 리뷰 의미 없음)
- **[GATE FINAL] 통과 전 종료/Phase 3 이동 금지**

## GATE 통과 조건

### [GATE 1] 스펙 리뷰 통과 (각 태스크별)
- [ ] 스펙 리뷰 subagent 디스패치 완료
- [ ] 스펙 gap 0건 — 발견 시 구현 subagent 재디스패치 후 재리뷰

### [GATE 2] 품질 리뷰 통과 (각 태스크별)
- [ ] 품질 리뷰 subagent 디스패치 완료
- [ ] 품질 이슈 0건 — 발견 시 수정 후 재리뷰
- [ ] TodoWrite 태스크 완료 표시

### [GATE FINAL] 전체 최종 리뷰 통과 (종료 직전)
- [ ] 모든 태스크 [GATE 1] + [GATE 2] 통과 확인
- [ ] 전체 구현 대상 최종 리뷰 subagent 디스패치 완료
- [ ] 최종 리뷰 이슈 0건 또는 사용자 명시 동의로 이월 결정

## 실행 절차

1. **플랜 읽기**: 구현 플랜에서 독립 태스크 전체 추출 → TodoWrite 등록
2. **태스크별 루프**:
   - a. 구현 subagent 디스패치 (명시적 컨텍스트 구성)
   - b. subagent가 질문하면 → 답변 + context 보강 후 재디스패치
   - c. subagent가 구현/테스트/커밋/self-review 수행
   - d. **스펙 리뷰 subagent** 디스패치 → 스펙 준수 확인
   - e. 스펙 gap 발견 → 구현 subagent가 수정 → 재리뷰
   - f. **품질 리뷰 subagent** 디스패치 → 품질 승인 확인
   - g. 품질 이슈 → 수정 → 재리뷰
   - h. TodoWrite에 태스크 완료 표시
3. **최종 전체 리뷰**: 모든 태스크 완료 후 전체 구현 대상 최종 리뷰 subagent 디스패치
4. **종료**: `harness-dev-process` Phase 3 VERIFY로 이동 또는 `jira-work-tasks`로 A.C. 처리

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 모든 태스크가 2단계 리뷰 통과
- [ ] [MANUAL] Fresh context 유지 확인 (subagent 간 오염 없음)
- [ ] [MANUAL] 전체 최종 리뷰 완료
- [ ] [GIT] 각 태스크 커밋이 분리되어 있음

## 언제 사용하나

| 조건 | 사용 여부 |
|------|----------|
| 구현 플랜 있음 + 태스크 대부분 독립 + 현재 세션 유지 | ✅ 이 스킬 |
| 플랜 없음 | → `harness-plan` 먼저 |
| 태스크 강하게 결합 | → 수동 실행 |
| 별도 세션 권장 | → (향후) executing-plans 스킬 |

## 우리 하네스 연계

- **선행**: `harness-plan` (PRD/Architecture/Task Packet 생성)
- **Phase**: `harness-dev-process` Phase 2 IMPL 대체 옵션
- **후속**: `dev-code-review` (최종 리뷰) + `jira-work-tasks` (A.C.)
- **Advisor Pattern과 차이**: Advisor는 단일 태스크 내 판단 에스컬레이션, 이 스킬은 태스크 단위 병렬 디스패치

## Origin (Vendor 흡수)

| 항목 | 값 |
|------|----|
| 원본 | [obra/superpowers — subagent-driven-development](https://github.com/obra/superpowers) |
| vendor 사본 | [superpowers--subagent-driven-development](../vendor/superpowers--subagent-driven-development/SKILL.md) |
| 흡수 결정 | 스킬 통합(commands→skills) 원칙 — `rules/skill-governance.md`. 조직 도입 근거·번호는 워크스페이스 `decisions/`(존재 시) 참조 |
| 판정 | SUPPLEMENT (병렬 subagent + 2단계 리뷰) |

## 참조

- 관련 스킬: `dev-parallel-agents` (독립 병렬), `dev-receiving-code-review` (리뷰 피드백 수용)
