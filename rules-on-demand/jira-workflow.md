# Jira Workflow Rules

## CRITICAL: "지라/Jira" 키워드 감지

사용자가 "지라", "Jira", `${JIRA_PROJECT_KEY}-` 형태의 티켓 키를 사용하면:

1. **먼저 읽기**: 팀 내 Jira REST API 가이드 (예: `runbooks/integrations/atlassian/jira-rest-api-guide.md`)
2. Jira REST 호출 전 `/rest/api/3/myself` 또는 동등한 preflight로 인증 상태를 먼저 확인한다
3. `skills/jira-rest-ops/` shared helper 또는 curl REST API를 사용한다
4. 가이드의 필드 ID, 상태 Transition ID, A.C. 형식을 따른다

> **팀별 커스텀 라우팅**: 팀 특화 요청 유형(통합요청, 데이터 보정 등)이 있으면
> 해당 처리 스킬을 먼저 읽도록 팀 규칙에 추가한다.

---

## 로컬 캐시 (토큰 절약)

### 캐시 위치

```
.claude/cache/jira/
├── issues/           # 이슈별 캐시 ({KEY}.json)
└── searches/         # JQL 검색 캐시 ({hash}.json)
```

### 캐시 전략

| 작업 | TTL | 갱신 조건 |
|------|-----|----------|
| 이슈 조회 | 60분 | 수정 직후 즉시 갱신 |
| JQL 검색 | 30분 | TTL 만료 시 |
| 수정/생성/전환 후 | - | 해당 이슈 캐시 자동 갱신 |

### 캐시 파일 형식

```json
{
  "key": "${JIRA_PROJECT_KEY}-123",
  "cached_at": "2026-01-01T09:00:00+09:00",
  "ttl_minutes": 60,
  "data": { ... }
}
```

---

## 팀 구조

- **보고자(Reporter)**: 팀장 (`${JIRA_REPORTER_ACCOUNT_ID}`) — 모든 이슈 공통
- **담당자(Assignee)**: 실제 작업자 (`${JIRA_ACCOUNT_ID}`)
- **In Review**: 팀장(보고자) 검토 단계

> 팀장 accountId는 `config/team.example.json` 스키마를 참고하여 환경변수로 주입한다.

---

## 이슈 생성/수정 규칙

### 이슈 생성 시 필수 필드

| 필드 | 값 | 비고 |
|------|-----|------|
| **reporter** | `${JIRA_REPORTER_ACCOUNT_ID}` | 항상 팀장(보고자) |
| **assignee** | `${JIRA_ACCOUNT_ID}` (실제 작업자) | 사용자에게 확인 |

### 상태별 엄격도

| 상태 | 엄격도 | 필수 항목 |
|------|--------|----------|
| **Backlog** | 최소 skeleton | Summary, Description, A.C., Reporter, Assignee, Start/Due date |
| **To Do** | 상세 | Summary, Description, A.C., Start/Due date, Epic Link |
| **In Progress** | 엄격 | 위 전부 + 구체적 A.C. 체크박스 |

### 신규 Task 생성 체크리스트

- `summary` 존재
- `description` 존재
- A.C. 필드(`customfield_XXXXX` — 팀 환경에 맞게 설정) 존재
- A.C. 필드가 체크박스(taskList/taskItem) 형식
- `reporter`가 팀장 accountId인지 확인
- `assignee`가 실제 작업자인지 확인
- Start date 필드 존재
- `duedate` 존재
- 해당 프로젝트의 `작업` 이슈면 `Epic Link` 존재 여부 확인
- 생성 직후 재조회 self-audit 수행

> **커스텀 필드 ID**: `customfield_XXXXX`는 팀 Jira 인스턴스에 따라 다르다.
> 팀 가이드(예: `runbooks/integrations/atlassian/jira-rest-api-guide.md`)에서 확인한다.

### Backlog 기본 정책

- `Backlog`라도 비어 있는 placeholder 이슈를 만들지 않는다
- 설계가 덜 정리됐어도 아래 minimum skeleton은 채운다:
  - 배경 1문단
  - 작업 범위 2-4개 bullet
  - 영향도/검토 포인트 1개 이상
  - A.C. 요구사항 체크박스
  - 개발 단계 체크박스

### A.C. 형식 - 반드시 마크다운 체크박스

```markdown
### 요구사항
- [ ] 구체적 완료 기준 1

### 개발 단계
- [ ] 요구사항 분석          ← Phase 0: INIT
- [ ] 설계                   ← Phase 1: PLAN
- [ ] 구현                   ← Phase 2: IMPL
- [ ] 단위 테스트            ← Phase 2: IMPL (TDD)
- [ ] 코드 리뷰              ← Phase 3: VERIFY
```

최소 skeleton 예시:

```markdown
### 요구사항
- [ ] 화면/기능 범위가 기존 current-state 기준과 연결된다
- [ ] 사용자 검토 포인트가 명시된다

### 개발 단계
- [ ] 요구사항 분석
- [ ] 설계
- [ ] 구현
- [ ] 단위 테스트
- [ ] 코드 리뷰
```

> **하네스 연계**: 개발 단계 체크박스는 하네스 Phase Gate와 1:1 매핑된다.
> Canonical 정의: `skills/harness-dev-process/references/phase-gates.md`

> **배포 검증 분리**: stg/운영 배포 검증은 Jira A.C.가 아닌 배포절차서에서 관리한다.
> 개발 티켓 A.C.는 코드 리뷰까지, 배포 검증은 배포절차서 체크리스트로 분리.

### 부족하면 반드시 물어본다

- Summary/Description/A.C. 부족 시 사용자에게 질문
- 설계 내용 없으면 캐물어서 작성
- "개발 완료" 같은 모호한 A.C. 금지 → 구체적 항목으로 제안

---

## 이슈 조회 시 점검

| 항목 | 조치 |
|------|------|
| A.C. 형식 | 체크박스(taskList) 아니면 변환 |
| A.C. 내용 | 부족하면 보완 제안 |
| A.C. 개발 단계 | 없으면 추가 (분석→설계→구현→테스트→리뷰→통합) |
| 보고자 | 팀장(`${JIRA_REPORTER_ACCOUNT_ID}`) accountId 일치 확인 |
| Start/Due date | 없으면 설정 |
| Epic Link | 없으면 연결 |
| Description skeleton | 배경/범위/영향도 수준이 너무 러프하면 보완 |

---

## CRITICAL: 태스크 완료 처리 5단계 (순서 엄수, 건너뛰기 금지)

> **하네스 Phase 4: SHIP** — GATE 4→DONE 조건의 Jira 실행 절차.
> Canonical 정의: `skills/harness-dev-process/references/phase-gates.md`

상태를 In Review/Done으로 변경하기 **전에** 1~4단계를 반드시 순서대로 수행한다.

1. **A.C. 형식 점검** → 체크박스(taskList)가 아니면 **먼저 체크박스(taskList/taskItem)로 변환**
2. **A.C. 내용 검토** → 부족하면 보완 제안
3. **A.C. 체크박스 완료** → 모든 taskItem state를 DONE
4. **Description 체크박스 완료** → 모든 taskItem state를 DONE
5. **상태 변경** → In Review(5) 또는 Done(6)

### 가드 훅 (자동 강제)

`hooks/guard-jira-transition.sh` (PreToolUse Bash hook):
- Jira transition API 호출 시 대상 티켓 A.C. TODO 잔존 검사
- In Review(transition id=5) / Done(transition id=6)로 가는 경우 차단
- 우회 (1회): `touch /tmp/.claude-allow-jira-transition`

본 가드는 룰 정합을 자동 강제한다. 사용자 명시 우회는 가능하지만 누적 추적을 위해 우회 사유를 작업일지에 기록.

## 완료 증적 (CRITICAL)

Done/In Review 전환 전에 **증적을 반드시 확인하고 기록**한다:

- 브랜치명, 반영 환경 (dev/stg/prd)
- 테스트 확인 결과
- 스크린샷 (화면 변경 시)
- 근거를 Jira 코멘트로 남기고, 가능하면 스크린샷 첨부

---

## 이슈 단위 기준

| 유형 | 기간 |
|------|------|
| Epic | 1개월 |
| Task | 1주 |
