---
name: plan
description: "dev-process Phase 1 PLAN 안에서 PRD/Architecture/Task Packet handoff를 정리"
---

## 스킬 규칙
### ALWAYS
- 사용자 CONFIRM 전까지 계획 제시만
- Charter Preflight 수행: 피처 문서 → 도메인 에이전트 → CPS 입력
- 영향도 분석 8항목 포함 (impact-analysis.md)
- **순서**: 분석 → 계획 제시 → [GATE CONFIRM] → 다음 단계 위임
### NEVER
- 사용자 CONFIRM 전 코드 수정 금지
- 추정 금지 — 확인 안 된 사실은 [TBD]
- **[GATE CONFIRM] 통과 전 다음 단계 진행 금지** (TDD/구현/dev-subagent-driven 등)
- **명시적 affirmative 응답 없이 계획 자동 실행 금지**

## [GATE CONFIRM] 통과 조건

이 GATE를 통과해야 다음 단계(TDD/구현/dev-subagent-driven 등)로 진행한다.
- [ ] 요구사항 재정의 + 단계별 계획 + 리스크 + 영향도 8항목 모두 제시
- [ ] 사용자 명시 affirmative 응답 ("yes", "proceed", "진행" 등)
- [ ] 사용자 수정 요청 ("modify:", "different approach:") 시 재검토 후 재제시 → CONFIRM 재획득
- [ ] HIGH 복잡도 시 Advisor 호출 결과 반영 완료 (max_uses 2 이내)

## 위치

- 이 스킬은 `harness-dev-process`의 `Phase 1: PLAN` 안에서 호출된다.
- 자체 Phase taxonomy를 만들지 않으며, 상위 owner인 `harness-dev-process`의 gate와 승인을 그대로 따른다.

## What This Skill Does

1. **Restate Scope** - Phase 0 INIT 산출물을 기준으로 구현 범위를 다시 정리한다.
2. **Draft PRD** - 제품/기능 요구사항을 `feature-prd.md` 구조로 정리한다.
3. **Draft Architecture** - 구현 구조, 레이어 영향, 통합 포인트를 `feature-architecture.md` 구조로 정리한다.
4. **Prepare Implementation Handoff** - 다음 단계에서 사용할 Task Packet 분해 기준과 handoff outline을 제시한다.
5. **Wait for Confirmation** - GATE 1→2 통과 전까지는 다음 단계 실행으로 넘어가지 않는다.

## When to Use

Use `/plan` when:
- `harness-dev-process`의 Phase 0 INIT 산출물(CPS, Charter Preflight)이 준비된 뒤 Phase 1 PLAN에 진입할 때
- 구현 전에 PRD, Architecture, 구현 분해 기준을 한 번에 정리해야 할 때
- 여러 파일/레이어/도메인에 걸친 변경이라 설계와 handoff 정리가 필요한 때
- 사용자가 "계획", "설계", "단계별 진행"을 명시적으로 요청했을 때

## When Not to Use

- Phase 0 INIT 이전 요구사항 명확화 단계
  - 이 경우 `harness-brainstorm`가 owner다.
- 새 서비스/프로젝트 bootstrap 또는 운영 반영 계획
  - 각각 `harness-service-bootstrap`, `harness-service-ops`로 분기한다.
- 이미 승인이 끝난 뒤 바로 구현만 진행하는 단계
  - 이 경우 상위 owner의 Phase 2 IMPL 절차를 따른다.

## How It Works

1. **INIT 산출물 확인**
   - CPS, Charter Preflight, 관련 피처 문서/도메인 문서를 읽고 Phase 1 입력이 충분한지 본다.
   - 입력이 부족하면 계획을 확정하지 않고 부족한 근거를 먼저 명시한다.
2. **요구사항 재정의**
   - 무엇을 바꾸는지, 왜 바꾸는지, Done When이 무엇인지 짧고 명확하게 다시 적는다.
   - 영향도 분석 8항목과 주요 리스크를 같이 정리한다.
3. **PRD 작성**
   - `skills/harness-dev-process/templates/feature-prd.md`를 기준으로 범위, 사용자/운영 관점 요구사항, 비기능 요구사항을 정리한다.
   - 풀스택 8레이어는 해당 없음도 포함해 명시적으로 판정한다.
4. **Architecture 작성**
   - `skills/harness-dev-process/templates/feature-architecture.md`를 기준으로 구조, 데이터 흐름, 연동, 롤백/배포 고려사항을 정리한다.
   - 구현 owner가 바로 착수할 수 있도록 수정 대상 레이어와 책임 경계를 명확히 남긴다.
5. **Task Packet handoff outline 준비**
   - `skills/harness-dev-process/templates/task-packet.md`를 기준으로 다음 단계에서 어떻게 나눌지 분해 기준을 제시한다.
   - 실제 구현 실행과 세부 packet 운용은 `harness-dev-process`의 Phase 2 IMPL이 소유한다.
6. **확인 대기**
   - PRD + Architecture + handoff outline + 리스크를 사용자에게 제시한다.
   - 명시적 affirmative 응답 전까지는 구현/TDD/dev-subagent-driven으로 넘어가지 않는다.

## Example Usage

```
User: /plan ${JIRA_PROJECT_KEY}-999 변경 계획 정리해줘

Agent (planner):
# PLAN Package

## Requirements Restatement
- 어떤 문제를 해결하는지
- 이번 변경 범위와 제외 범위
- 완료 기준(Done When)

## PRD Outline
- 사용자/운영 요구사항
- 비기능 요구사항
- 영향도 분석 8항목

## Architecture Outline
- 수정 대상 레이어
- 주요 데이터 흐름
- 연동/배포/롤백 고려사항

## Task Packet Handoff
- 구현 단위 분해 기준
- 선행 의존성
- 병렬화 가능 영역

## Risks
- HIGH/MEDIUM/LOW 별 주요 리스크

**WAITING FOR CONFIRMATION**: Proceed to Phase 2 IMPL? (yes/no/modify)
```

## References

- Owner flow: `skills/harness-dev-process/SKILL.md`
- PRD template: `skills/harness-dev-process/templates/feature-prd.md`
- Architecture template: `skills/harness-dev-process/templates/feature-architecture.md`
- Task Packet template: `skills/harness-dev-process/templates/task-packet.md`

## Advisor Pattern 적용

복잡도 **HIGH** 또는 아키텍처 결정 포함 시 → **Advisor 패턴** 적용:

1. sonnet executor가 초안 계획을 작성
2. 아키텍처/기술 결정 지점에서 opus advisor에게 에스컬레이션
3. opus는 방향·대안·리스크만 제시 (도구 호출 없음)
4. sonnet이 advisor 피드백을 반영하여 최종 계획 완성 후 사용자 확인 대기

복잡도 **MEDIUM 이하** → sonnet executor 단독으로 계획 완성.

### 에스컬레이션 조건 (HIGH 판단 기준)

아래 조건 중 하나라도 해당하면 복잡도 HIGH로 분류 → Advisor 호출:

- 팀 전체 영향 변경 포함 (`rules/`, `AGENTS.md`, `skills/` 수정 포함 시)
- 복수 아키텍처 옵션이 존재하고 팀 컨텍스트 기반 선택이 필요한 경우
- 5개 이상 레이어/서비스에 걸치는 Cross-cutting 변경

위 조건 미해당 시 → sonnet executor 단독 처리 (Advisor 호출 금지).

### Advisor 호출 제한

- **max_uses: 2** — 초안 방향 결정(1회) + 중간 검증(1회). 2회 초과 시 사용자에게 판단 위임
- advisor는 도구 호출 없이 방향 제시만 수행

### 에스컬레이션 로그

Advisor 호출 시 결과를 **작업일지 AI협업 섹션**에 기록:

```
| Claude/Opus-advisor | plan 에스컬레이션 | [결정 내용 요약] |
```

## Related Roles

- Prefer a planner sub-agent if your tool supports it.
- If not, follow this document directly.
- Do not require tool-specific home paths to execute this command.

## 실행 절차

(본문 참조)

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 사용자 CONFIRM 받음
- [ ] [MANUAL] 리스크 식별 + 단계별 계획 제시 완료
- [ ] [MANUAL] 영향도 분석 8항목 포함
