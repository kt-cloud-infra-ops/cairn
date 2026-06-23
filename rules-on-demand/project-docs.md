# 프로젝트 문서 작성 규칙

## 핵심 원칙: 프로젝트 레포 = Source of Truth

프로젝트의 상세 문서(피처 스펙, 운영 SQL, API, ADR)는 **해당 프로젝트 코드 레포**에 저장한다.
`base/services/`는 서비스 허브(인덱스) 역할만 한다.

## 프로젝트 레포 내 표준 구조

```
{프로젝트 레포}/
├── AGENTS.md                        # 프로젝트 지침 + 중앙 에이전트 링크
├── .harness/                        # 하네스 실행 상태
│   ├── config.json                  # profile, harnessLevel
│   ├── state.json                   # phase, ticket, checks
│   └── evidence/                    # 빌드/테스트 증적
├── agents/                          # 도메인 에이전트 (레이어 3)
│   └── {도메인}.md
├── docs/                            # 프로젝트 문서
│   ├── README.md                    # 인덱스 + 아키텍처 + 외부 의존성
│   ├── specs/                       # 기본설계, 요구사항, 화면명세, API
│   ├── features/                    # 기능 변경 스펙 (Jira 티켓 기반)
│   │   ├── README.md                # 영향도 매트릭스
│   │   └── {기능명}.md              # 또는 {티켓}/ (하네스 산출물)
│   ├── operations/                  # 운영 SQL, DML, 프로시저
│   └── releases/                    # 릴리즈 노트
└── src/                             # 코드
```

서비스 bootstrap/ops 오케스트레이션의 로컬 상태는 프로젝트 레포가 아니라
standards 저장소의 `temp/orchestrator/{service}/state.json` 에 둔다.
이 파일은 git/Confluence 동기화 대상이 아니다.

### 필수 항목

| 항목 | 필수 | 설명 |
|------|-----|------|
| `AGENTS.md` | 필수 | 프로젝트 지침 + 중앙 규칙 링크 |
| `docs/README.md` | 필수 | 인덱스 + 아키텍처 + 외부 의존성 |
| `docs/features/` | 필수 | 기능 스펙 + 영향도 매트릭스 |
| `docs/features/README.md` | 필수 | 영향도 매트릭스 (기능 간 cross-cutting) |
| `docs/specs/` | 권장 | 기본설계, 요구사항, 화면명세, API, ERD |
| `docs/operations/` | 해당 시 | 운영 SQL (CRM 대응 등) |
| `docs/releases/` | 해당 시 | 릴리즈 노트 |
| `agents/` | 해당 시 | 도메인 에이전트 (서비스 특화 지식) |
| `.harness/` | 해당 시 | 하네스 실행 상태 (config, state, evidence) |

### 하위 분기 없음

`specs/`, `features/`, `operations/`, `releases/` 하위에 추가 폴더 분기 없이 **파일 네이밍으로 구분**.
예외: 하네스 산출물은 `features/{티켓}/` 폴더 허용 (CPS + PRD + Architecture 묶음).

### features/ 파일 네이밍 규칙

```
{TICKET}-{descriptive-name}.md
```

- `TICKET`: Jira 티켓 키 (예: `${JIRA_PROJECT_KEY}-XXX`)
- `descriptive-name`: 기능 설명 (kebab-case, 영문)
- 예: `PROJ-347-event-copy-identifier.md`
- Jira 티켓 없는 문서 (리뷰, 분석 등): `docs/reviews/` 또는 `docs/specs/`로 분리

## 기능 스펙 문서 필수 섹션

| 섹션 | 내용 |
|------|------|
| Jira 티켓 | 관련 이슈 키 |
| 변경 내용 | 무엇을 왜 바꾸는지 |
| 수정 파일 | 변경 대상 파일 목록 |
| 영향 범위 | 영향받는 다른 기능 |
| 비기능 요구사항 | 타임아웃, 이중화, 알림 등 |
| 배포 버전 | 반영 버전 |

**운영 원칙:**
- 개발 착수 전 해당 기능 문서 + 영향받는 기능 문서 읽기
- `features/README.md`에 영향도 매트릭스 유지
- impact-analysis.md 체크리스트와 병행

## base/services/ — 서비스 허브 (인덱스)

`base/services/{서비스}/`는 **서비스 단위 인덱스**로, 상세 문서는 포함하지 않는다.

```
base/services/{서비스}/
├── README.md               # 서비스 카탈로그 (프로젝트 목록 + 에이전트 + 워크스페이스)
├── TASKS.md                # Jira 동기화
└── sop/                    # 서비스 운영 SOP (선택)
```

### 서비스 README.md 필수 내용

| 섹션 | 내용 |
|------|------|
| 서비스 설명 | 한 줄 설명 |
| 프로젝트 카탈로그 | 프로젝트명, 워크스페이스 경로, GitHub, 에이전트, 설명 |
| 관련 문서 | TASKS.md, SOP 등 |

### 프로젝트 카탈로그 예시

```markdown
| 프로젝트 | 워크스페이스 | GitHub | 에이전트 | 설명 |
|---------|-------------|--------|---------|------|
| <YOUR_SERVICE>_web | `workspace/<YOUR_SERVICE>_web/` | ${GIT_ORG}/<YOUR_SERVICE>_web | domain-a, domain-b | 메인 웹 (예: Spring Boot + JSP) |
| <YOUR_SERVICE>_scheduler | `workspace/<YOUR_SERVICE>_scheduler/` | - | scheduler | 배치 스케줄러 |
```

## 프로젝트 추가 체크리스트

- [ ] 프로젝트 레포에 `docs/` 표준 구조 생성
- [ ] 프로젝트 레포에 `AGENTS.md` 생성
- [ ] `base/services/{서비스}/README.md` 프로젝트 카탈로그 업데이트
- [ ] `agents/subagents/{서비스}/README.md` 라우터에 포인터 추가

## 프로젝트명 규칙

- 서비스 접두사 제거: `<YOUR_SERVICE>_scheduler` → `scheduler`
- 소문자 + 언더스코어: `morning_report`
- 짧고 명확하게: `web`, `api`, `scheduler`

## Confluence 동기화

- `agents/`, `.harness/` 폴더는 동기화 제외 (AI 에이전트 전용)
- 임시 작업 파일은 `temp/`에 저장 (프로젝트 폴더 X)

---

## Related Rules

- [doc-organization.md](../rules/doc-organization.md) - 문서 조직 규칙
