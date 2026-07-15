---
tags:
  - type/reference
  - audience/team
---

# Phase Gates

## 목적

각 Phase를 넘어가기 전에 충족해야 하는 조건을 정의한다.
게이트를 통과하지 못하면 다음 Phase로 진행하지 않는다.

## Phase 정의

```
Phase 0: INIT     → CPS 작성
Phase 1: PLAN     → PRD + Architecture 작성
Phase 2: IMPL     → 코드 구현
Phase 3: VERIFY   → 테스트 + 리뷰
Phase 4: SHIP     → 배포 준비
```

## CRITICAL: Canonical 소스 매핑

기존에 4곳에 분산되어 있던 워크플로우 정의를 **이 Phase Gate가 단일 기준**으로 통합한다.
각 소스는 Phase Gate를 참조하며, 자체적으로 워크플로우를 재정의하지 않는다.

| 기존 소스 | 위치 | 하네스 Phase 매핑 | 역할 |
|----------|------|-----------------|------|
| Jira A.C. 개발 단계 | Jira Description 체크리스트 | Phase 0~4 전체 | **진행 상태 추적** (체크박스) |
| 피처 문서 테스트 설계 | `features/*.md` 6.x절 | Phase 0 (CPS 테스트 전략) → Phase 1 (PRD 상세) | **테스트 설계 산출물** |
| Jira 완료 처리 5단계 | `rules/jira-workflow.md` | Phase 4: SHIP | **완료 증적 + 상태 전환** |
| 하네스 Phase Gate | 이 파일 | — | **워크플로우 정의 (Canonical)** |

### Jira A.C. 개발 단계 ↔ Phase 매핑

```
### 개발 단계
- [ ] 요구사항 분석          ← Phase 0: INIT (CPS)
- [ ] 설계                   ← Phase 1: PLAN (PRD + Architecture)
- [ ] 구현                   ← Phase 2: IMPL
- [ ] 단위 테스트            ← Phase 2: IMPL (TDD)
- [ ] 코드 리뷰              ← Phase 3: VERIFY
```

> **배포 검증 분리**: stg/운영 배포 검증은 A.C.가 아닌 Confluence 배포절차서에서 관리.
> 상세: `rules-on-demand/domain-jira-ship.md` "배포 검증 분리" 섹션.

### 피처 문서 테스트 설계 ↔ Phase 매핑

| 피처 문서 섹션 | Phase | 산출물 |
|-------------|-------|--------|
| 6.0 테스트 설계 기준 | Phase 0 | CPS `## 테스트 전략 (초안)` |
| 6.1~6.4 상세 테스트 | Phase 1 | PRD `## 테스트 설계` |
| 6.5~6.8 회귀/예외 | Phase 1 | PRD `## 회귀 + 예외 스코프` |
| 실행 결과 | Phase 3 | VERIFY Gate 통과 증적 |

## Gate 조건

### GATE 0→1: INIT → PLAN

| # | 조건 | 검증 방법 |
|---|------|----------|
| 1 | CPS 문서 존재 | `feature-cps.md` 파일 존재 |
| 2 | Charter 4요소 모두 작성됨 | Goal, Context, Constraints, Done When 비어있지 않음 |
| 3 | Clarification Level이 HIGH가 아님 | HIGH이면 blocked, 질문 해소 후 진행 |
| 4 | Acceptance Criteria 1개 이상 | 체크박스 항목 존재 |
| 5 | 영향도 분석 8항목 판정 완료 | "해당없음" 포함 모두 채워짐 |

### GATE 1→2: PLAN → IMPL

| # | 조건 | 검증 방법 |
|---|------|----------|
| 1 | PRD 문서 존재 | `feature-prd.md` 파일 존재 |
| 2 | Architecture 문서 존재 | `feature-architecture.md` 파일 존재 |
| 3 | 풀스택 8레이어 판정 완료 | 모든 레이어에 Y/N/해당없음 기입 |
| 4 | API 설계 완료 (해당 시) | URL, Method, Request/Response 정의 |
| 5 | DDL 변경 정의 (해당 시) | ALTER/CREATE 문 작성 |
| 6 | 외부 연동 스펙 확인 (해당 시) | 실제 응답 샘플 포함 (유추 아님) |
| 7 | UI 목업 확인 (해당 시) | UI 변경이 있으면 목업 파일 존재 + 사용자 확인 |
| 8 | 사용자 승인 | 사용자가 설계(목업 포함)를 확인함 |

> **승인 정책 (Harness Level별)**:
> - **Lite**: 승인 불필요 (Charter + 빌드/테스트만)
> - **Standard**: GATE 1→2에서 1회 승인, 이후 자동 진행
> - **Full**: 각 주요 Gate마다 승인

### GATE 2→3: IMPL → VERIFY

| # | 조건 | 검증 방법 |
|---|------|----------|
| 1 | 빌드 성공 | `./gradlew build` 또는 `npm run build` 통과 |
| 2 | PRD의 변경 파일 목록과 실제 변경 일치 | 예상하지 않은 파일 변경 없음 |
| 3 | 단위 테스트 작성됨 | 변경 로직에 대해 성공 1 + 실패 1 이상 |
| 4 | Task Packet의 Done When 충족 | 모든 완료 기준 체크됨 |

### GATE 3→4: VERIFY → SHIP

| # | 조건 | 검증 방법 |
|---|------|----------|
| 1 | 모든 테스트 통과 | Unit + Integration + E2E (해당 시) |
| 2 | 코드 리뷰 CRITICAL/HIGH 없음 | code-reviewer 에이전트 결과 |
| 3 | 보안 체크 통과 | security-reviewer 에이전트 결과 |
| 4 | 영향받는 기존 테스트 통과 | 기존 테스트 스위트 전체 |
| 5 | 로컬 검증 완료 | DB → API → UI 순서 확인 |
| 6 | **결정 적립** (Standard/Full) | 설계·도메인 판단 발생 시 도메인 에이전트 `결정이력`/`판단시나리오` 또는 `docs/decisions/` ADR에 적립. `dev-code-review`가 `decisionLogged` 기록 → `guard-git-commit` 검증. Lite·판단 없음(`none`) 면제 — **ADR-013** |

### GATE 4→DONE: SHIP

| # | 조건 | 검증 방법 |
|---|------|----------|
| 1 | 배포 계획 작성됨 | PRD 배포 계획 섹션 |
| 2 | 롤백 계획 존재 | 롤백 방법 명시 |
| 3 | Jira 이슈 A.C. 전체 DONE | 모든 taskItem state=DONE |
| 4 | 작업일지 반영됨 | worklog에 기록 |

## Harness Level (강도 조절)

모든 기능에 Full Gate를 적용하면 과도할 수 있다.
기능 규모에 따라 Level을 선택한다.

| Level | 대상 | 적용 Gate |
|-------|------|----------|
| **Lite** | 단순 버그 수정, 설정 변경 | GATE 0→1 (Charter만) + GATE 2→3 (빌드+테스트) |
| **Standard** | 일반 기능 추가 | 전체 Gate |
| **Full** | 대규모 기능, 외부 연동, 스키마 변경 | 전체 Gate + 사용자 승인 강화 |

### Level 판정 기준

```
변경 파일 5개 이하 + DDL 없음 + 외부 연동 없음 → Lite
그 외 → Standard
DDL 변경 + 외부 연동 + 영향 테이블 10개 이상 → Full
```

## state.json — Evidence Pointer 구조

Gate 통과 증거를 `checks.*` boolean 대신 `evidence.*` pointer로 기록한다.

### 구조

```json
{
  "harnessLevel": "standard",
  "ticket": "${JIRA_PROJECT_KEY}-XXX",
  "phase": "INIT",
  "docs": {
    "cps": "feature-cps.md",
    "prd": "feature-prd.md",
    "architecture": "feature-architecture.md",
    "taskPacket": "task-packet.md",
    "featureDoc": "services/.../features/xxx.md"
  },
  "approvals": { "user": false },
  "evidence": {
    "build":            { "status": "pass"|"fail"|null, "log": "경로", "at": "ISO8601" },
    "unitTest":         { "status": "pass"|"fail"|null, "report": "경로", "at": "ISO8601" },
    "codeReview":       { "status": "pass"|"fail"|null, "report": "경로", "at": "ISO8601" },
    "securityReview":   { "status": "pass"|"fail"|null, "report": "경로", "at": "ISO8601" },
    "regression":       { "status": "pass"|"fail"|null, "report": "경로", "at": "ISO8601" },
    "localVerification":{ "status": "pass"|"fail"|null, "at": "ISO8601" },
    "jiraAcceptance":   { "status": "pass"|"fail"|null, "at": "ISO8601" },
    "worklog":          { "status": "pass"|"fail"|null, "path": "경로", "at": "ISO8601" }
  }
}
```

### 설계 원칙

1. **Writer 책임**: 각 evidence는 해당 작업을 수행한 주체(빌드 스크립트, 리뷰 에이전트, Jira helper 등)가 기록
2. **Validator 우선순위**: evidence pointer → 문서 artifact → state boolean (하위 호환)
3. **수동 boolean 최소화**: `checks.*` 형식은 하위 호환으로 유지하되, 신규 작성 시 `evidence.*` 사용
4. **CPS ↔ 피처 문서**: `docs.featureDoc`에 canonical spec 경로 기록. CPS는 bootstrap, 피처 문서가 canonical
