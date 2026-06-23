# Jira Workflow Rules

## CRITICAL: "지라/Jira" 키워드 감지

### TECHIOPS26 통합요청 우선 라우팅

- 사용자가 `통합요청`, 데이터 보정, 이벤트 해소, 인벤토리 변경·삭제를 언급하면 일반 Jira 처리 전에 반드시 `agents/skills/luppiter-datachange-request-automation/SKILL.md`를 먼저 읽는다.
- 통합요청은 **TECHIOPS26 프로젝트 이슈타입**으로 처리된다.
- `jira-rest-ops` 단독으로 시작하지 않고, 위 skill의 분류/처리 수단/API·DML 규칙을 먼저 따른다.

사용자가 "지라", "Jira", "LUPR-", "TECHIOPS26-" 키워드를 사용하면:

1. **먼저 읽기**: `base/guides/ktcloud/atlassian/jira-rest-api-guide.md`
2. Jira REST 호출 전 `/rest/api/3/myself` 또는 동등한 preflight로 인증 상태를 먼저 확인한다
3. `agents/skills/jira-rest-ops/` shared helper 또는 curl REST API를 사용한다
4. 가이드의 필드 ID, 상태 Transition ID, A.C. 형식을 따른다

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
  "key": "LUPR-683",
  "cached_at": "2026-02-06T14:30:00+09:00",
  "ttl_minutes": 60,
  "data": { ... }
}
```

---

## 팀 구조

- **보고자(Reporter)**: 팀장 (김정남/bill.kim) — 모든 이슈 공통
- **담당자(Assignee)**: 실제 작업자
- **In Review**: 팀장(보고자) 검토 단계

---

## 이슈 생성/수정 규칙

### 이슈 생성 시 필수 필드

| 필드 | 값 | 비고 |
|------|-----|------|
| **reporter** | bill.kim (accountId: 712020:1253fda5-0458-4f4d-836a-2646b0576e3c) | 항상 팀장 |
| **assignee** | 실제 작업자 accountId | 사용자에게 확인 |

### 상태별 엄격도

| 상태 | 엄격도 | 필수 항목 |
|------|--------|----------|
| **Backlog** | 최소 skeleton | Summary, Description, A.C., Reporter, Assignee, Start/Due date |
| **To Do** | 상세 | Summary, Description, A.C., Start/Due date, Epic Link |
| **In Progress** | 엄격 | 위 전부 + 구체적 A.C. 체크박스 |

### 신규 Task 생성 체크리스트

- `summary` 존재
- `description` 존재
- `customfield_14516` 존재
- `customfield_14516`가 체크박스(taskList/taskItem) 형식
- `reporter`가 팀장 `bill.kim` accountId인지 확인
- `assignee`가 실제 작업자인지 확인
- `customfield_10015` 존재
- `duedate` 존재
- `TECHIOPS26`의 `작업` 이슈면 `Epic Link` 존재 여부 확인
- 생성 직후 재조회 self-audit 수행

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
> Canonical 정의: `agents/skills/harness-dev-process/references/phase-gates.md`

> **배포 검증 분리**: stg/운영 배포 검증은 Jira A.C.가 아닌 **Confluence 배포절차서**에서 관리한다.
> 개발 티켓 A.C.는 코드 리뷰까지, 배포 검증은 배포절차서 체크리스트로 분리.
> 참조: `agents/rules-on-demand/domain-jira-ship.md`

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
| 보고자 | 팀장(bill.kim) accountId 일치 확인 |
| Start/Due date | 없으면 설정 |
| Epic Link | 없으면 연결 |
| Description skeleton | 배경/범위/영향도 수준이 너무 러프하면 보완 |

---

## CRITICAL: 태스크 완료 처리 5단계 (순서 엄수, 건너뛰기 금지)

> **하네스 Phase 4: SHIP** — GATE 4→DONE 조건의 Jira 실행 절차.
> Canonical 정의: `agents/skills/harness-dev-process/references/phase-gates.md`

상태를 In Review/Done으로 변경하기 **전에** 1~4단계를 반드시 순서대로 수행한다.

1. **A.C. 형식 점검** → 체크박스(taskList)가 아니면 **먼저 체크박스(taskList/taskItem)로 변환**
2. **A.C. 내용 검토** → 부족하면 보완 제안
3. **A.C. 체크박스 완료** → 모든 taskItem state를 DONE
4. **Description 체크박스 완료** → 모든 taskItem state를 DONE
5. **상태 변경** → In Review(5) 또는 Done(6)

#
### 가드 훅 (자동 강제)

`.claude/hooks/guard-jira-transition.sh` (PreToolUse Bash hook):
- Jira transition API 호출 시 대상 티켓 A.C. (`customfield_14516`) TODO 잔존 검사
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
