---
tags:
  - type/reference
  - audience/team
---

# Output Schema

## 목적

각 Phase의 산출물이 어떤 형식이어야 하는지 정의한다.
이 스키마를 벗어난 산출물은 validator에서 FAIL 처리된다.

## Phase별 산출물

| Phase | 산출물 | 템플릿 | 필수 섹션 |
|-------|--------|--------|----------|
| 0: INIT | CPS | `templates/feature-cps.md` | Charter, Context, Problem, Solution, Acceptance Criteria, 영향도 분석 |
| 1: PLAN | PRD | `templates/feature-prd.md` | 기본 정보, 기능 요구사항, 풀스택 레이어, 테스트 계획 |
| 1: PLAN | Architecture | `templates/feature-architecture.md` | 컴포넌트, 데이터 모델, API 상세, 보안 |
| 2: IMPL | Task Packet | `templates/task-packet.md` | Charter, 입력, 변경 파일, 출력, 검증 체크리스트 |

## 필수 섹션 검증 규칙

### CPS (feature-cps.md)

```yaml
required_sections:
  - "## Charter"
  - "## Context"
  - "## Problem"
  - "## Solution"
  - "## Acceptance Criteria"
  - "## 영향도 분석"
  - "## 테스트 전략"
  - "## Cross-cutting 필수 체크리스트"

required_patterns:
  - pattern: "CHARTER_CHECK:"
    message: "Charter Preflight가 없습니다"
  - pattern: "Goal:"
    message: "Goal이 정의되지 않았습니다"
  - pattern: "Done When:"
    message: "완료 기준이 없습니다"
  - pattern: "- \\[ \\]"
    message: "Acceptance Criteria 체크박스가 없습니다"
```

### PRD (feature-prd.md)

```yaml
required_sections:
  - "## 기본 정보"
  - "## 기능 요구사항"
  - "## 풀스택 레이어 설계"
  - "## 테스트 계획"

required_patterns:
  - pattern: "Jira 티켓"
    message: "Jira 티켓이 연결되지 않았습니다"
  - pattern: "\\|\\s*(Y|N|해당없음|해당 없음)\\s*\\|"
    count: 8
    message: "풀스택 8레이어가 모두 판정되지 않았습니다"

conditional_sections:
  - condition: "UI 변경이 있을 때"
    section: "## UI 변경"
    required_patterns:
      - "목업 파일"
```

### Architecture (feature-architecture.md)

```yaml
required_sections:
  - "## 시스템 구조"
  - "## 데이터 모델"
  - "## 보안 고려사항"

conditional_sections:
  - condition: "외부 연동이 있을 때"
    section: "## 외부 연동"
    required_patterns:
      - "실제 응답 샘플"
```

### Task Packet (task-packet.md)

```yaml
required_sections:
  - "## Charter"
  - "## 입력"
  - "## 수행 내용"
  - "## 출력"
  - "## 검증 체크리스트"

required_patterns:
  - pattern: "CHARTER_CHECK:"
    message: "Charter가 없습니다"
  - pattern: "- \\[ \\]"
    message: "검증 체크리스트가 없습니다"
```

## 금지 패턴

모든 산출물에서 아래 패턴이 감지되면 WARNING:

```yaml
forbidden_patterns:
  - pattern: "\\[TBD\\]"
    level: "WARNING"
    message: "미확인 항목이 있습니다. Phase 진행 전 해소 필요"
  - pattern: "\\[미확인\\]"
    level: "WARNING"
    message: "미확인 항목이 있습니다"
  - pattern: "추정컨대|아마|~일 것이다"
    level: "ERROR"
    message: "추정 표현 금지. 확인된 사실만 기술"
  - pattern: "개발 완료|구현 완료"
    level: "ERROR"
    in_section: "Done When"
    message: "모호한 완료 기준. 테스트 가능한 구체적 기준으로 변경"
```
