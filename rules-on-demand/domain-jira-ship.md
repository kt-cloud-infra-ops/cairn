---
triggers:
  - jira-workflow.md
  - phase-gates.md
  - state.json
---

## 준수 규칙

Jira 이슈를 **In Review** 또는 **Done** 상태로 전환하기 전에, 에이전트는 아래 검증을 **순서대로** 수행한다. 1건이라도 실패하면 상태 전환 API를 호출하지 않는다.

전환 ID는 팀 Jira 인스턴스에 따라 다르므로 `${JIRA_TRANSITION_IN_REVIEW}` / `${JIRA_TRANSITION_DONE}` 환경변수 또는 프로필 설정을 따른다.

### 전환 전 필수 5단계 (Canonical: `rules-on-demand/jira-workflow.md`)

| 단계 | 검증 내용 | 실패 시 |
|------|----------|---------|
| 1 | A.C. 형식이 taskList/taskItem인지 확인 | 체크박스로 변환 후 재검증 |
| 2 | A.C. 내용이 구체적인지 검토 | 사용자에게 보완 제안, 승인 대기 |
| 3 | A.C. 체크박스 전체 DONE 확인 | 미완료 항목 목록 표시, 전환 중단 |
| 4 | Description 체크박스 전체 DONE 확인 | 미완료 항목 목록 표시, 전환 중단 |
| 5 | 완료 증적 확인 (브랜치, 환경, 테스트, 스크린샷) | 증적 부족 항목 표시, 전환 중단 |

### A.C. 전체 DONE 검증 절차 (단계 3 상세)

1. Jira REST API로 이슈 description 조회 (ADF 형식)
2. ADF에서 `taskList` → `taskItem` 노드 전수 추출
3. 각 `taskItem`의 `attrs.state` 값 확인
4. `state !== "DONE"` 인 항목이 **1건이라도** 있으면:
   - 미완료 항목 목록을 사용자에게 표시
   - **상태 전환 API 호출 금지**
   - 사용자에게 "A.C. 미완료 항목이 있습니다. 먼저 완료 처리하시겠습니까?" 확인
5. 전체 DONE이면 단계 4로 진행

### Done 전환 권한

- Done 전환 권한 정책은 팀 프로필 설정(`profile/atlassian.yaml` 또는 `.cairn/profile/atlassian.yaml`)을 따른다.
- 일반적으로 Done 전환은 Reporter(보고자) 역할을 가진 팀원만 수행한다.
- 권한 없는 담당자가 Done 전환을 요청하면 "Done은 Reporter만 전환 가능" 안내 후 중단.

### 완료 증적 필수 항목

상태 전환 전에 아래 증적을 Jira 코멘트로 남긴다:

- 브랜치명, 반영 환경 (dev/stg/prd)
- 테스트 확인 결과
- 스크린샷 (화면 변경 시)
- 배포 절차서 링크 (해당 시)

## 배포 검증 분리 (CRITICAL)

개발 티켓 A.C.와 배포 검증은 **별도 채널**에서 관리한다.

| 영역 | 관리 위치 | 항목 |
|------|----------|------|
| 개발 완료 | Jira A.C. 체크박스 | 요구사항 분석, 설계, 구현, 단위 테스트, 코드 리뷰 |
| 배포 검증 | 배포절차서 (Wiki/Confluence) | stg 배포 + 검증, 운영 배포 + 검증 |

### 이유

- stg/운영 배포는 개발 완료와 시점이 다름 (배포 일정, ITSM 승인 등)
- 배포절차서에 DB 변경, 롤백 계획, 검증 항목이 이미 포함
- A.C.에 배포 검증까지 넣으면 개발 완료 판단이 배포 일정에 종속

### 완료 증적에서의 배포 참조

단계 5(완료 증적)에서 배포 관련 증적은 **배포절차서 링크**로 대체:

- 브랜치명, 반영 환경 → 배포절차서에 기록
- 배포절차서 링크를 Jira 코멘트에 첨부
- 화면 변경 스크린샷은 배포절차서 또는 Jira 코멘트에 첨부

## 소스 참조

- `rules-on-demand/jira-workflow.md` — "태스크 완료 처리 5단계" (canonical)
- `skills/harness-dev-process/references/phase-gates.md` — Phase 4: SHIP GATE 조건
