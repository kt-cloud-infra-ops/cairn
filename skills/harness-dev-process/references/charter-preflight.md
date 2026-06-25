---
tags:
  - type/reference
  - audience/team
---

# Charter Preflight

## 목적

모든 에이전트가 작업 착수 전에 동일한 범위 확인을 거치게 한다.
이 프리플라이트를 통과해야 실제 작업에 진입할 수 있다.

## MANDATORY: 기존 자산 확인 (4요소 작성 전)

Charter 작성 전에 반드시 아래 순서로 기존 자산을 확인한다.
Jira Description만으로 CPS를 작성하면 정확도가 떨어진다.

1. **피처 문서(설계) 검색**: `projects/{프로젝트}/docs/features/` 에서 관련 문서 확인 — 피처 문서는 설계 산출물이며 CPS보다 먼저 존재할 수 있음
2. **도메인 에이전트 필수 참조**: 해당 서비스의 도메인 에이전트(`domains/<YOUR_SERVICE>/agents/`)를 **반드시** 호출하여 코드 레벨 영향도 확인 — 피처 문서 유무와 무관하게 항상 수행
3. **피처 문서 있으면** → 피처 문서를 CPS 입력으로 수용 (Jira Description보다 우선)
4. **피처 문서 없으면** → 도메인 에이전트 검토 결과를 기반으로 CPS 작성

> **교훈**: Jira Description(SQL 1줄 수정)과 피처 문서(5개 파일 수정 + action 분기)가 불일치.
> Jira만 보고 "Lite"로 판정했으나 실제는 "Standard" 레벨이었음.

## MANDATORY: 4요소 확인

어떤 에이전트(Claude, Codex, Cursor, Copilot, Gemini)를 쓰든,
작업 시작 전 아래 4요소를 명시적으로 작성한다.

```
CHARTER_CHECK:
  Goal: {무엇을 만들/고칠/바꿀 것인가}
  Context: {관련 파일, 문서, 에러, 현재 상태}
  Constraints: {아키텍처 규칙, 표준, 금지 사항 — 최소 3개}
  Done When: {테스트 가능한 완료 기준 — 모호한 표현 금지}
```

## Clarification Level

4요소 작성 후 정보 충분도를 판정한다.

| Level | 판정 기준 | 행동 |
|-------|----------|------|
| **LOW** | 4요소 모두 명확, 추가 질문 없음 | 바로 진행 |
| **MEDIUM** | 일부 불명확하지만 합리적 기본값 존재 | 옵션 나열 + 가장 가능한 것으로 진행 + 적용한 가정 명시 |
| **HIGH** | 핵심 정보 부족, 추정 시 방향이 완전히 달라질 수 있음 | **blocked** — 질문 목록만 제시, 진행 금지 |

## 금지 사항

- Goal 없이 작업 시작 금지
- Done When이 "완료", "개발 완료" 같은 모호한 표현이면 구체화 요구
- Constraints 없이 진행 금지 (최소 3개 명시)
- HIGH인데 추정으로 진행하는 것 금지

## 예시

### 좋은 Charter

```
CHARTER_CHECK:
  Goal: cmon_service_inventory_master 테이블에 zone 컬럼 추가
  Context:
    - 현재 DDL: doc/ddl/cmon_service_inventory_master.sql
    - 관련 매퍼: InventoryMapper.xml (30+ 쿼리에서 JOIN)
    - 영향 화면: 인벤토리 목록, 대시보드 통계
  Constraints:
    - 기존 데이터 마이그레이션 포함 (NULL 허용 + 기본값)
    - 기존 쿼리 JOIN 패턴 변경 금지 (추가만 허용)
    - rules-on-demand/impact-analysis.md 8레이어 체크 필수
  Done When:
    - ALTER TABLE DDL 작성 완료
    - 영향받는 매퍼 쿼리 30개 zone 조건 추가 완료
    - 인벤토리 목록 화면에서 zone 필터 동작 확인
    - 단위 테스트 zone 조건 포함 3건 이상
```

### 나쁜 Charter

```
CHARTER_CHECK:
  Goal: zone 기능 추가
  Context: 인벤토리 관련
  Constraints: 없음
  Done When: 개발 완료
```

→ 이 Charter는 거부됨. Goal이 모호하고, Context가 불충분하고, Constraints가 없고, Done When이 측정 불가능.

## CPS ↔ 피처 문서 관계 (CRITICAL)

CPS와 피처 문서는 **동등 공존이 아니라 역할이 다르다**.

| 산출물 | 역할 | 위치 | 수명 |
|--------|------|------|------|
| **CPS** | Bootstrap — 초기 범위 확인 + Charter 고정 | `.harness/feature-cps.md` 또는 작업 디렉토리 | 작업 중 임시 |
| **피처 문서** | Canonical spec — 최종 설계 기준 | `projects/{프로젝트}/docs/features/` | 영구 |

### 흐름

1. **피처 문서가 이미 있는 경우**
   - CPS는 피처 문서를 압축/재정렬한 작업 브리지
   - CPS의 Context/Problem/Solution은 피처 문서에서 추출
   - PLAN 완료 시 CPS/PRD 내용을 피처 문서에 환류 (테스트 설계 등)

2. **피처 문서가 없는 경우**
   - CPS가 초기 범위를 정의
   - PLAN 완료 시 CPS/PRD 내용으로 피처 문서 신규 생성 → canonical 위치에 배치
   - state.json의 `docs.featureDoc`에 경로 기록

3. **VERIFY/SHIP 단계**
   - 피처 문서가 canonical spec
   - code-reviewer, validator, 에이전트 모두 피처 문서를 기준으로 검증
   - CPS는 참조용으로만 유지

> **금지**: CPS와 피처 문서가 같은 내용을 다른 형식으로 독립 유지하는 것 (drift 발생)

## 적용 범위

- `harness-plan` 실행 시 자동 적용
- `harness-brainstorm` Step 9에서 4요소 수집 (Goal/Context/Constraints/Done When)
- 에이전트가 직접 코드를 작성하기 전 반드시 수행
- 단순 질문/검색은 제외 (코드 변경이 수반되는 작업만)

## 참고

- oh-my-agent: `.agents/*.md`의 Charter Preflight 패턴
- 우리 기존 규칙: `rules/core.md` "추정 금지" 원칙의 기계적 구현
