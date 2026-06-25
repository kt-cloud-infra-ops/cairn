# Current-State Analysis Harness

코드 기반 current-state 화면 분석을 재현 가능하게 만드는 증적형 하네스 규칙.

## 목적

- 화면 분석 결과가 어떤 참조와 어떤 판단을 거쳐 나왔는지 추적 가능하게 유지
- 서브에이전트가 달라져도 최소 근거 수준과 체크 기준을 동일하게 유지
- `공통처럼 보이지만 실제로 다른 동작`을 너무 빨리 공통화하지 않도록 제어

## 적용 대상

- 레거시 current-state 화면/팝업 분석
- 외부연동 포함 화면 요구사항 복원
- 도메인 에이전트가 화면별 SoT 문서를 축적하는 작업

## 적용하지 않는 대상

- 단순 질의응답
- 오타/형식 수정
- 근거 파일이 늘어나지 않는 경미한 문서 편집

## 원칙

### 1. 프롬프트 하네스보다 결과 하네스 우선

- 모든 서브에이전트에게 모든 규칙 파일을 읽게 강제하지 않는다.
- 대신 **결과 문서가 어떤 근거와 어떤 체크를 통과했는지**를 남긴다.

### 2. 문서 단위 = 화면/팝업 단위

- trace 기본 단위는 도메인 전체가 아니라 `화면 ID` 기준이다.
- `<DOMAIN>-<SCREEN>`, `<DOMAIN>-DETAIL`, `<DOMAIN>-UPDATE`처럼 서비스 inventory와 같은 ID를 쓴다.

### 3. 현재 상태 보존

- 다른 화면과 규칙이 달라도 우선 현행 그대로 기록
- 공통화 전 검토가 필요하면 `[검토필요]`
- 근거 부족이면 `[미확인]`

### 4. 링크 우선

- 도메인 에이전트의 current-state 문서 포인터는 **직접 링크**로 둔다.
- 에이전트가 문서명을 복사해 다시 찾지 않게 한다.
- trace 템플릿은 프로젝트별 복사본이 아니라 `templates/harness-trace.md`를 canonical로 둔다.

## 필수 산출물

### 도메인 에이전트

- `domains/<YOUR_SERVICE>/agents/{도메인}.md`
- `현재 운영 기준 문서 포인터` 또는 `상세 문서 포인터`를 markdown link로 유지

### 프로젝트 문서

- `docs/specs/current-state-analysis-harness.md`
- 현재 프로젝트에서 어떤 trace 계약을 쓰는지 설명

### 실행 산출물

- `{project}/.harness/current-state/state.json`
- `{project}/.harness/current-state/README.md`
- `{project}/.harness/current-state/traces/{screen-id}.md` 또는 동등 산출물
- trace 템플릿 canonical: `templates/harness-trace.md`

## trace 최소 계약

각 trace에는 아래가 있어야 한다.

| 항목 | 내용 |
|------|------|
| 대상 | 화면 ID, 결과 문서, 작성일 |
| 결과 문서 | 최종 spec 문서 링크 |
| 참조 문서 | 도메인 overview, 공통 문서, 연관 화면 문서 |
| 코드 근거 | JSP, JS, Controller/API, SQL, 외부연동 근거 |
| 체크 결과 | 어떤 규칙을 확인했고 어떤 항목이 N/A인지 |
| 차이점 | `[검토필요]` 목록 |
| 불확실성 | `[미확인]` 목록 |
| 작성 주체 | 메인 에이전트 / 서브에이전트 / 수동 보정 여부 |

## 화면 유형별 최소 근거

### 데이터 조회/저장 화면

- JSP
- 공통 JS 또는 화면 JS
- Controller/API
- SQL

### popup / include popup

- popup JSP
- caller 화면 또는 부모 popup
- API/SQL이 있으면 포함
- API가 없으면 부모 rowData/DOM 주입 근거 포함

### 외부연동 화면

- 기본 근거 +
- Service/Util/외부 config 또는 external adapter

### legacy 정적 화면

- JSP
- route/controller
- API/SQL 없음이 확인되면 그 사실 자체를 결과에 기록

## 체크리스트

각 결과는 아래 항목을 **확인 여부까지 포함해** 남긴다. 전부 `Y`일 필요는 없고 `N/A` 가능하다.

| 체크 | 설명 |
|------|------|
| UI/DOM | 화면 입력, 버튼, grid, hidden field 확인 |
| Caller/Include | 부모 화면 의존성, callback, DOM 주입 확인 |
| Request Chain | `DOM -> param -> API -> SQL` 연결 확인 |
| Auth/Session | 권한/세션/메뉴 노출과 서버 가드 확인 |
| Common Source | 코드값, 드롭다운, 공통 popup source 확인 |
| External Integration | 외부 시스템 연동(모니터링, LDAP, 메시지, ITSM 등) 확인 |
| Cross-Domain | 연관 도메인 테이블/API 영향 확인 |
| Current-State Difference | 공통처럼 보이지만 다른 규칙 확인 |
| Unresolved | `[검토필요]`, `[미확인]` 기록 여부 확인 |
| Evidence Links | 근거 파일/문서 링크 수록 여부 확인 |

## 판정 규칙

### pass

- 화면 유형별 최소 근거 충족
- 체크리스트 전 항목에 `Y`/`N/A`/`[검토필요]` 판정 존재
- 결과 문서와 trace의 화면 ID가 일치

### fail

- JSP만 읽고 API/SQL 없이 계약을 확정
- 외부연동 화면인데 외부연동 근거가 없음
- 차이점이 있는데 `[검토필요]` 표시가 없음
- 문서 포인터가 텍스트만 있고 직접 링크가 없음

## 권장 운영 방식

### Lite

- 화면 1개
- trace를 문서 하단 근거 섹션으로 대체 가능

### Standard

- 화면 여러 개 또는 popup family
- `.harness/current-state/state.json` + `traces/{screen-id}.md`

### External

- 외부연동, 권한, cross-domain 후처리 포함
- Standard + 외부연동/후처리 체크 필수

## 안티패턴

- 모든 서브에이전트에게 전체 rules 세트를 읽게 강제
- 결과 문서 없이 요약만 남김
- `[검토필요]`를 제거하려고 현행 차이를 임의로 통합
- 도메인 에이전트 포인터를 plain text 경로로만 유지

## 관련 규칙

- `rules/agents.md`
- `rules/doc-organization.md`
- `rules-on-demand/impact-analysis.md`
- `agents/harnessing.md` (엔진 plugin 레이어 에이전트)
