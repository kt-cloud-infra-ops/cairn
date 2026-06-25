---
name: jira-rest-ops
description: Jira REST API 직접 호출 (MCP 의존 없음, 인증은 환경변수/~/.jira-credentials.json). 신규 Task 생성(create-task), 이슈 필드 업데이트, 상태 전환, A.C. 체크박스 완료, 에픽 링크, description ADF 조작, weekly-report용 에픽 탐색/초안 생성/댓글 등록을 수행. Jira 키워드(프로젝트키, 이슈키) 또는 "weekly-report", "주간보고" 키워드에 반응.
---

## 스킬 규칙
### ALWAYS
- REST 호출 전 `/rest/api/3/myself` preflight 필수
- 신규 Task 생성 시 `summary / description / customfield_14516 / reporter / assignee / start/due date` 검증 필수
- 신규 Task 생성 직후 self-audit 필수
- 상태 변경 전 A.C. 5단계 (jira-workflow.md)
- 캐시 TTL 준수
### NEVER
- 인증 토큰을 stdout/로그에 노출 금지
- [GATE 0] 통과 전 신규 Task 생성 / 이슈 필드 수정 / 댓글 등록 / 상태 전환 금지

## 실행 절차

1. 인증 확인 (preflight: GET `/rest/api/3/myself`)
2. API 호출 (아래 지원 기능 참조)
3. 결과 검증 + 캐시 갱신

## 실행 도구

- `scripts/jira_rest_api.py` — Python 헬퍼 (JiraRestAPI 클래스)
- `skills/scripts/weekly_report.py` — 주간보고 helper (추후 jira-weekly-report 스킬로 이관 예정)
- curl 직접 호출도 가능 (헬퍼 없는 환경)

## 인증

우선순위:
1. `ATLASSIAN_BASE_URL` + `ATLASSIAN_EMAIL` + `ATLASSIAN_API_TOKEN`
2. `JIRA_EMAIL` + `JIRA_API_TOKEN` (+ 선택: `JIRA_BASE_URL`, 없으면 `${ATLASSIAN_BASE_URL}` — 기본값: 환경에 맞는 URL로 설정)
3. `${JIRA_CREDENTIALS_FILE:-~/.jira-credentials.json}` (email + apiToken + baseUrl) — env 미설정 시 로컬 fallback

> **권장: 환경변수(1·2번)를 셸 프로파일(`~/.zshrc`)에 export.** MCP 설정 의존은 제거됨 — REST API 직접 인증만 사용. env·파일 모두 없으면 환경변수 설정 안내 에러.

인증 방식: Basic Auth (`email:apiToken` base64)

필수 preflight:
- 이슈 조회/검색/수정 전 먼저 `python3 skills/jira-rest-ops/scripts/jira_rest_api.py auth-check`
- 또는 `GET /rest/api/3/myself` 호출로 현재 토큰 유효성 확인
- `401 AUTHENTICATED_FAILED`면 권한 문제가 아니라 토큰/인증정보 오류로 간주하고 즉시 중단

진단 원칙:
- `/myself`가 `401`이면 인증 실패
- `/myself`는 `200`인데 특정 이슈만 `404`/빈 결과면 이슈 부재 또는 권한 범위 문제
- stale `${JIRA_CREDENTIALS_FILE:-~/.jira-credentials.json}`이 있으면 env가 우선해야 한다

## 지원 기능

| 기능 | 메서드 | 엔드포인트 |
|------|--------|-----------|
| 신규 Task 생성 | POST | `/rest/api/3/issue` |
| 이슈 필드 업데이트 | PUT | `/rest/api/3/issue/{key}` |
| 상태 전환 | POST | `/rest/api/3/issue/{key}/transitions` |
| 전환 목록 조회 | GET | `/rest/api/3/issue/{key}/transitions` |
| 이슈 검색 (JQL) | GET | `/rest/api/3/search/jql` |
| 이슈 조회 | GET | `/rest/api/3/issue/{key}` |
| 댓글 등록 | POST | `/rest/api/3/issue/{key}/comment` |

## 운영 규칙

- **Search API v3 필수**: `/rest/api/2/search` 폐기됨 → `/rest/api/3/search/jql` 사용
- **신규 Task 생성 기본 경로**: `create-task` helper 또는 동등한 검증 로직 사용. ad-hoc `POST /issue` 금지
- **Task 생성 minimum skeleton**: `Backlog`라도 `description + A.C. + reporter + assignee + start/due date`를 채운다
- **생성 후 self-audit 필수**: `summary, description, customfield_14516, reporter, assignee, customfield_10015, duedate, customfield_10014`
- 상태 변경 전 A.C. 5단계 필수 (rules/jira-workflow.md 참조)
- 인증 토큰을 stdout/로그에 노출하지 않는다
- 캐시: `.claude/cache/jira/` (이슈 60분, 검색 30분)

#### [GATE 0] write 작업 실행 전
read-only 조회(`auth-check`, `search`, `get issue`)는 제외하고, 아래 쓰기 작업은 실행 전에 이 GATE를 통과한다.

<!-- [MODEL: haiku] read-only 조회 분기(auth-check, search, get issue)는 단순 GET + 결과 매핑이라 haiku로 충분.
     write 작업(create/update/transition/comment)은 GATE 0 통과 + 판단 필요 → sonnet 유지. -->

- [ ] `auth-check` 또는 `/rest/api/3/myself`로 현재 토큰 유효성 확인
- [ ] 대상 project/issue key/transition/comment 위치 확인
- [ ] 변경 payload preview 확인 (`summary`, `description`, `A.C.`, `reporter`, `assignee`, `start/due`, `Epic Link`)
- [ ] `create-task`면 reporter가 지정된 보고자 accountId(`${JIRA_REPORTER_ACCOUNT_ID}`)인지 확인
- [ ] `${JIRA_PROJECT_KEY}` 이슈면 `Epic Link` 예외 여부까지 명시

## 상태 전환 ID (프로젝트별 실제 ID 확인 필요)

| ID | 상태 |
|----|------|
| 2 | Backlog |
| 3 | To Do |
| 4 | In Progress |
| 5 | In Review |
| 6 | Done |
| 7 | Cancel |

## 주요 커스텀 필드

| 필드 ID | 이름 |
|---------|------|
| customfield_10014 | Epic Link |
| customfield_14516 | A.C. (Acceptance Criteria) |
| customfield_10015 | Start date |

## create-task 계약

### 입력 필수

- `summary`
- `description` (ADF 또는 plain text → ADF 변환)
- `customfield_14516` (`taskList/taskItem` ADF)
- `reporter.accountId` (지정된 보고자, `${JIRA_REPORTER_ACCOUNT_ID}`)
- `assignee.accountId`
- `customfield_10015`
- `duedate`

### `${JIRA_PROJECT_KEY}` Task 추가 규칙

- `issuetype=작업`이면 `Epic Link(customfield_10014)`를 기본 요구로 본다
- 에픽 없이 생성해야 하면 명시적 예외 판단을 남긴다

### 출력 필수

1. 생성 필드 요약 또는 payload preview
2. 생성된 이슈 key/id
3. 생성 직후 self-audit 결과
4. 누락/정합성 위반 필드 존재 시 실패 처리

## 출력 계약

각 API 호출 후:
1. 성공/실패 상태
2. 변경된 필드 요약
3. 캐시 갱신 여부
4. 인증 실패 시 auth source와 preflight 재확인 안내
5. `create-task`인 경우 self-audit 결과

## weekly-report 사용례

- 대상은 "내가 담당인 에픽"이 아니라 "내 태스크가 연결된 상위 에픽"
- `discover`로 에픽 목록과 child task를 먼저 모은다
- `discover`는 worklog 공백, 최신 댓글 섹션 누락, 포맷 불일치, worklog 근거 부족을 `OK / WARN`로 같이 보여준다
- 공유 에픽이면 에픽 담당자와 비교해 bullet 앞에 `(내이름)` 접두사를 붙인다
- 주간보고 문체는 기존 댓글을 따르는 **개조식 명사형 보고체**가 기본이다
- `완료/확정/착수/진행/반영/검토` 식으로 짧게 끝내고, `했습니다/예정입니다`는 피한다
- `draft`로 승인용 초안을 먼저 만들고, 사용자 확인 후 `comment`로 에픽 댓글을 등록한다

## 참조

- `references/automation-pattern.md` — 상세 코드 예시 (jira-rest-ops references에서 관리)
- `rules/jira-workflow.md` — Jira 운영 규칙 원본
- 주간보고 자동화 패턴 — 팀 knowledge base 참조

## 완료 조건 (DONE WHEN)
- [ ] [GATE] write 작업 시 [GATE 0] 통과 확인
- [ ] [MANUAL] API 호출 성공/실패 상태 보고
- [ ] [MANUAL] 변경 필드 요약 표시
- [ ] [MANUAL] 캐시 갱신 완료
- [ ] [MANUAL] 신규 Task 생성 시 self-audit 결과 확인
