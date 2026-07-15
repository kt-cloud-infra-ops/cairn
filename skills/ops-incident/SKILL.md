---
name: ops-incident
description: "운영 장애 인지 → 임시 회피 → 원인 분석 → 보고서(인시던트 관리 시스템/Confluence) → 후속 운영개선 태스크 생성 + hotfix handoff까지 표준화. harness-service-ops branch의 운영 장애 sub-owner."
---

## 스킬 규칙

### ALWAYS
- Phase 0 분류(장애 등급/영향범위) 사용자 명시 확인 후 다음 단계 진입
- 외부 시스템 변경(모니터링 DB / 관제 시스템 / 인시던트 관리 시스템 / Confluence) 전 GATE 통과 필수
- 보고서 작성 전 미확정 항목(인시던트 ID / 상황반장 / 복구반장 / 발생·복구 시각 / VOC)은 `[미확인]`/`[확인 필요]`로 마킹
- 임시 회피 기록은 **시각 + 액션 + 책임자** 3항목 필수
- 후속 운영개선 태스크 생성 시 **서비스 종류로 Jira 프로젝트 분기** (인프라 → `${JIRA_PROJECT_KEY}` / devops → 별도 프로젝트)
- Phase 4 hotfix 구현은 **`harness-dev-process` (dev branch) 로 명시적 handoff**, 본 스킬 내에서 구현 금지

### NEVER
- GATE 0 통과 전 임시 회피 실행 또는 외부 시스템 변경 금지
- GATE 2 통과 전 인시던트 관리 시스템/Confluence 보고서 생성 금지
- Phase 4 hotfix 구현을 본 스킬 내에서 직접 수행 금지 (dev branch 위임 필수)
- 등급/영향범위/시각 추정 기재 금지 — 사용자 확인 또는 `[미확인]` 마킹
- 운영개선 태스크의 Jira 프로젝트를 추정으로 결정 금지 — `rules/service-mapping.md` 참조 후 결정

## 실행 절차

### Phase 0: 인지 & 분류

1. **장애 신고 수집** — 슬랙 / 알람 / 인시던트 번호 / 외부 운영팀 신고
2. **시스템 식별** — 어느 서비스 (`<서비스명>` 등 — 사용 환경에 맞게 서비스 목록 설정), 어느 컴포넌트 (scheduler / web / DB)
3. **등급 추정** — 1~4등급 / 관리장애 / 이상징후 (사내 장애 대응 프로세스 참조: `references/incident-response-process.md`)
4. **영향 범위 식별** — 채널/서비스 한정 여부, 고객 영향 여부, VOC 발생 가능성

#### [GATE 0] 분류 확정
- [ ] 장애 등급 사용자 명시 확인 또는 `[미확인]` 마킹
- [ ] 영향 범위 확인 (서비스명, 채널, 내부/외부 영향)
- [ ] 인시던트 관리 시스템 번호 (또는 발급 필요 여부)
- [ ] 서비스 분류 — 인프라 서비스 vs DevOps 서비스 (환경에 맞는 서비스 목록 설정) — Phase 4 프로젝트 분기 결정용

### Phase 1: 임시 회피

5. **회피 옵션 정리** — 영향도 낮은 순으로 2~3개 (예: row 1건 격리 / if_idx 점프 / 일시 비활성화)
6. **사용자/운영팀 결정 대기** — 옵션 + 영향 + 책임자 명시

#### [GATE 1] 회피 실행 승인
- [ ] 회피 방안 사용자 명시 승인
- [ ] 실행 책임자 확인 (본인 / 운영팀 / 외부)
- [ ] 회피로 인한 부작용(데이터 누락 등) 사용자 인지 확인

7. **임시 회피 실행** — 운영팀 또는 본인이 실행
8. **회피 기록** — 시각 + 액션 + 책임자 기록 (작업일지 + 인시던트 관리 시스템 description)

### Phase 2: 원인 분석

9. **로그/DB 흔적 조사** — 운영 DB 로그, 배치 이벤트 로그, 모니터링 시스템 events/alerts 등
10. **재현** — 로컬 환경 우선, 가능하면 brute force로 다양 패턴 검증
11. **시계열/패턴 분석** — line 번호 변화, 분당 증가율, 분포 등으로 가설 검증
12. **root cause 확정** — 재현 + 시계열 + 코드 메커니즘 3중 검증

미확정 시 한계 명시:
- "유력 가설 + 재현 검증" 톤으로 보고
- 추가 자료(alerts.message / 운영 로그 raw)로 100% 확정 가능한지 명시

### Phase 3: 보고서 작성

13. **미확정 항목 사용자 확인** — 인시던트 ID / 상황반장 / 복구반장 / 발생·인지·복구 시각 / VOC

#### [GATE 2] 보고서 작성 전 확인
- [ ] 미확정 항목 전부 사용자 확인 완료 또는 `[미확인]` 마킹
- [ ] root cause 확정 또는 `[유력 가설]` 명시
- [ ] 재발 방지 대책 초안 (코드 개선 + 배포 일정)

14. **Confluence 페이지 작성** — 5섹션 flat (`references/confluence-template.md`)
    - 위치: 사용자가 사전에 생성한 Confluence 페이지 (있으면 그 페이지 ID 사용) 또는 해당 스페이스 신규 생성
    - 양식: 1.기본정보 / 2.원인&영향도 / 3.조치 / 4.Timetable(5컬럼) / 5.재발방지

15. **인시던트 관리 시스템 description ADF append** — 8섹션 (`references/cinm-template.md`)
    - 가. 타임 테이블 / 나. 인시던트 내부 공지 / 다.(선택) 발생 이벤트 / 라. 참고/첨부 / 마. 대응내용 / 바. 원인분석 / 사. 향후대책 / 아. 비고

### Phase 4: 후속 조치

16. **운영개선 태스크 생성** — Jira 프로젝트 분기 (Phase 0 GATE 0 결정 결과 사용)

| 서비스 분류 | Jira 프로젝트 | 비고 |
|-----------|-------------|------|
| 인프라 서비스 (환경에 맞는 서비스 목록으로 설정) | **`${JIRA_PROJECT_KEY}`** | 접두사 파싱 — `rules/service-mapping.md` |
| DevOps 서비스 (예: batch, api — 환경에 맞게 설정) | **별도 devops 프로젝트** | 정확한 키는 사용자 확인 필요 — 미확정 시 사용자 질문 |

태스크 내용:
- summary: `[INCIDENT-{N} 후속] {root cause 요약}` (예: `[INCIDENT-NNN 후속] <서비스>_<컴포넌트> <문제 요약>`)
- description: 사고 요약 + root cause + 재발 방지 대책 (보고서 링크 포함)
- parent: 해당 서비스 운영 에픽 (예: `${JIRA_PROJECT_KEY}-NNN 해당 서비스 운영 에픽`)
- assignee: 복구반장 또는 사용자 확인
- 시작일/기한: 재발 방지 대책 배포 일정 기준

17. **hotfix Jira 티켓 생성** (필요 시) — `${JIRA_PROJECT_KEY}-{N}` (인프라) 또는 devops 프로젝트
    - 운영개선 태스크와 별도 (운영개선 = 재발 방지, hotfix = 즉시 대응)
    - 운영개선 태스크의 sub-task 또는 같은 epic 하위 별도 task

18. **`harness-dev-process` handoff** — hotfix 구현은 dev branch에서 진행
    - handoff 시 전달: Jira 티켓 번호, 인시던트 번호, root cause, 재발 방지 대책, 배포 일정

#### [GATE 3] SHIP
- [ ] Confluence 보고서 URL 확인
- [ ] 인시던트 관리 시스템 description 업데이트 확인 (8섹션 완료)
- [ ] 운영개선 태스크 번호 + 프로젝트 (`${JIRA_PROJECT_KEY}` 또는 devops)
- [ ] (필요 시) hotfix Jira 티켓 번호 + dev branch handoff 완료

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 임시 회피 기록 (시각/액션/책임자)
- [ ] [CONTENT] 재현 증빙 (로컬 테스트 결과 또는 운영 로그 분석)
- [ ] [CONTENT] Confluence 보고서 URL
- [ ] [CONTENT] 인시던트 관리 시스템 description 8섹션 완료
- [ ] [CONTENT] 운영개선 Jira 태스크 번호 (`${JIRA_PROJECT_KEY}` 또는 devops)
- [ ] [GATE] GATE 0~3 모두 통과
- [ ] [GATE] **장애 패턴 환류 (ADR-013)**: 이 장애의 원인·대응·재발방지 패턴을 보고서로 끝내지 말고 해당 도메인 에이전트 `결정이력`/`판단시나리오` 또는 workspace `services/{svc}/sop/`에 적립 (다음 대응자가 헤매지 않게)
- [ ] [MANUAL] (필요 시) hotfix 티켓 + harness-dev-process handoff

## 외부 컨텍스트 처리

- 다른 세션/대화에서 결정된 등급/책임자/조치 시각은 본 스킬로 자동 반영 불가
- 사용자 또는 운영팀이 Phase 0 GATE 0 / Phase 3 GATE 2 단계에서 명시적으로 알려줘야 함
- 운영팀(관제팀, 서비스운영팀 등 — 환경별 팀명 적용)이 인시던트 관리 시스템에 인시던트 생성 시 운영팀 작성한 description의 타임라인이 권위 있는 기록 — 본 스킬은 그 description에 append 형태로 추가

## 관련 문서

- `references/confluence-template.md` — 5섹션 flat 표준 양식
- `references/cinm-template.md` — 인시던트 관리 시스템 8섹션 ADF 표준 양식
- `references/incident-response-process.md` — 사내 장애 대응 프로세스
- `references/incident-report-sample-cases.md` — 장애보고서 작성 예시 (템플릿)
- `rules/service-mapping.md` — 서비스 ↔ Jira 프로젝트 매핑
- `skills/jira-rest-ops/` — Jira REST API 헬퍼 (인시던트 description append, 태스크 생성)
- `skills/harness-dev-process/` — Phase 4 hotfix 구현 위임 대상
- `skills/harness-orchestrator/` — 본 스킬을 `incident` branch owner로 라우팅

## 본 스킬 출현 배경 (재발 방지 메커니즘)

운영 장애 발생 시 `harness-orchestrator`가 "Jira/코드 수정 키워드" 우선 매칭으로 `dev` branch에 잘못 라우팅된 사례에서 파생됨. 운영 장애 보고서 프로세스가 별도 흐름임에도 개발 오케스트레이터(Phase 0~5)로 진입 → 사용자 정정 후 모드 전환.

본 스킬 + `service-ops` 분기 후 장애 시그널 식별로 incident 절차에 진입하여 재발 구조 차단.

## Push back 기준

- **스코프 폭발**: 사고 하나에 여러 서비스 영향 → 각 서비스별로 별도 ops-incident 진행 제안
- **재현 불가 + 자료 부족**: 본문/원본 데이터 모두 소실 → 사용자에게 자료 추가 요청 또는 `[원인 미확정]` 톤으로 보고서 작성 결정
- **HARD-GATE 우회 시도**: "그냥 빨리 보고서 올려" → Phase 0 분류 + GATE 0 통과 필수, 우회 거부 (운영 표준 위반 방지)
