---
tags:
  - type/template
  - audience/team
---

> 상위: [templates](README.md)

# 프로젝트 레포 docs/ 구조 템플릿

## 기본 구조 (모든 프로젝트 공통)

```
{프로젝트 레포}/
├── CLAUDE.md                    # 프로젝트 에이전트 지침 (필수)
├── docs/
│   ├── README.md                # docs 인덱스 (필수)
│   ├── features/                # 기능 스펙 (필수)
│   │   ├── README.md            # 영향도 매트릭스
│   │   └── {기능명}.md
│   └── decisions/               # 프로젝트 ADR (권장)
│       └── {NNN}-{제목}.md
└── src/
```

## 프로젝트 유형별 추가 폴더

### Web/API 프로젝트 (예: <your_service>_web)

```
docs/
├── features/                    # 기능 스펙
├── operations/                  # 운영 SQL (CRM, DML, DDL)
│   ├── README.md                # 운영 이력 인덱스
│   └── {CRM번호}_{설명}.sql
├── refactoring/                 # 리팩토링 설계
├── releases/                    # 릴리즈 노트
│   └── v{X.Y.Z}.md
├── api/                         # API 엔드포인트 문서
├── screens/                     # 화면 명세
└── decisions/                   # ADR
```

### 스케줄러/배치 프로젝트 (예: <your_service>_scheduler)

```
docs/
├── features/                    # 기능 스펙
├── operations/                  # 운영 SQL (프로시저 변경 이력)
├── releases/                    # 릴리즈 노트
└── decisions/                   # ADR
```

### E2E 테스트 프로젝트 (예: <your_service>_e2e)

```
docs/
├── features/                    # 테스트 시나리오 스펙
├── coverage/                    # 커버리지 현황/리포트
└── decisions/                   # ADR
```

### 외부 연동 프로젝트 (예: message_bridge)

```
docs/
├── features/                    # 기능 스펙
├── integrations/                # 외부 시스템 연동 문서
│   └── {시스템명}.md
├── releases/                    # 릴리즈 노트
└── decisions/                   # ADR
```

---

## docs/README.md 템플릿

```markdown
# {프로젝트명} 문서

## 구조

| 폴더 | 내용 | 문서 수 |
|------|------|--------|
| [features/](features/) | 기능 스펙 + 영향도 매트릭스 | N건 |
| [operations/](operations/) | 운영 SQL | N건 |
| [releases/](releases/) | 릴리즈 노트 | N건 |
| [decisions/](decisions/) | 설계 결정 (ADR) | N건 |

## 최근 변경

| 날짜 | 문서 | 변경 |
|------|------|------|
| YYYY-MM-DD | features/{기능}.md | 신규 작성 |

---

**최종 업데이트**: YYYY-MM-DD
```

## features/README.md 템플릿 (영향도 매트릭스)

```markdown
# 기능 목록 및 영향도 매트릭스

## 기능 목록

| 기능 | Jira | 상태 | 배포 버전 | 영향 범위 |
|------|------|------|----------|----------|
| {기능명} | ${JIRA_PROJECT_KEY}-xxx | 완료/진행중 | v2.1.x | {영향 요약} |

## Cross-Cutting 영향도

| 기능 A ↔ 기능 B | 영향 | 비고 |
|----------------|------|------|
| 예시 A ↔ 예시 B | 공통 테이블 참조 | |

---

**최종 업데이트**: YYYY-MM-DD
```

## operations/README.md 템플릿

```markdown
# 운영 SQL 이력

| CRM/티켓 | 날짜 | 대상 | 설명 | 적용 환경 |
|----------|------|------|------|----------|
| CRM26033108942 | 2026-04-01 | inventory_master | Zenius NW 장비 2건 등록 | 로컬 검증 완료 |

## 주의사항

- 운영 적용 전 로컬/STG 검증 필수
- 적용 후 Jira 코멘트로 증적 기록

---

**최종 업데이트**: YYYY-MM-DD
```

## 기능 스펙 문서 템플릿

```markdown
---
tags:
  - type/spec
  - service/{서비스}/{프로젝트}
  - audience/team
---

# {기능명}

## Jira 티켓

{${JIRA_PROJECT_KEY}-xxx}

## 변경 내용

{무엇을 왜 바꾸는지}

### 원인 (버그 수정 시)

### 수정 내용

| # | 수정 위치 | 변경 | 비고 |
|---|----------|------|------|
| 1 | | | |

## 수정 파일

| 파일 | 변경 |
|------|------|
| | |

## 영향 범위

- **{대상 1}**: {영향 설명}
- **{대상 2}**: {영향 설명}

## 비기능 요구사항

- 타임아웃:
- 이중화:
- 알림:

## 검증

| 테스트 케이스 | 기대 결과 |
|-------------|----------|
| | |

## 배포 버전

## 상태

- YYYY-MM-DD {상태 설명}

---

**최종 업데이트**: YYYY-MM-DD
```

---

## 마이그레이션 매핑 (예시)

| 현재 위치 (base/) | 이동 대상 (workspace/) |
|-------------------|----------------------|
| `projects/web/features/` | `<your_service>/docs/features/` |
| `projects/web/operations/` | `<your_service>/docs/operations/` |
| `projects/web/refactoring/` | `<your_service>/docs/refactoring/` |
| `projects/web/releases/` | `<your_service>/docs/releases/` |
| `projects/e2e/` | `<your_service>_e2e/docs/features/` |
| `projects/scheduler/features/` | `<your_scheduler>/docs/features/` |

---

**최종 업데이트**: 2026-04-01
