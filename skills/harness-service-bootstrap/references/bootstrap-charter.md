# Bootstrap Charter — 신규 서비스 신설 결정 가이드

`harness-service-bootstrap` GATE 0 통과를 위한 상세 결정 가이드.

근거: ADR-008 (orchestrator 의무) + ADR-009 (비전 카탈로그 정합성 + 자율 repo 존중)

---

## 1. 파트 결정

팀 비전 페이지(Confluence pageId ${CONFLUENCE_PAGE_ID}) 기반 파트 분류:

| 파트 | 정의 | 신규 서비스 판단 기준 |
|------|------|-------------------|
| **`<YOUR_PART_A>`** | (팀 정의에 맞게 입력) | 해당 파트 기준 서비스 판단 |
| **`<YOUR_PART_B>`** | (팀 정의에 맞게 입력) | 해당 파트 기준 서비스 판단 |
| **공통** | 인증/형상/공용 도구 | 팀 내외 공용 컴포넌트 |

위치 결정:
- `services/{파트}/{서비스}/`
- `domains/<YOUR_SERVICE>/agents/{서비스}.md` (도메인 에이전트, 필요 시)

## 2. 카테고리 결정 (비전 OSS 분류)

| 카테고리 | 예시 |
|---------|------|
| 공통 | `<YOUR_SERVICE>` (공통 인증/형상/공용 도구) |
| 관제 & 모니터링 | `<YOUR_SERVICE>` (운영 관제, Observability) |
| Infra 운영 자동화 | `<YOUR_SERVICE>` (Infra 관리, 배치, API, Config, IP Scanner) |
| CICD 운영 | `<YOUR_SERVICE>` (Platform Admin, Region 배포 도구) |
| 작업 관리 | `<YOUR_SERVICE>` (ITSM, 워크플로우 관리) |

## 3. 계층 결정 (배포 위치)

| 계층 | 정의 |
|------|------|
| 공통 시스템 | 외부 팀 공용 서비스 |
| 운영 시스템 | 메인 운영 시스템 |
| Platform | Platform 자체 개발 인프라 (Okta, Github, Central Git-tea 등) |
| Classic Infra | Classic Zone 장비 (CloudStack, XenServer, vCenter 등) |
| <YOUR_SERVICE> Infra | <YOUR_SERVICE> Region 장비 (OpenStack Community, ACI 등) |

## 4. 인증 방식 결정

| 인증 | 사용 케이스 |
|------|---------|
| `okta` | 사용자 ↔ 메인 시스템 |
| `Keycloak` | 별도 인증 시스템 사용 서비스 |
| `Local` | 자체 로컬 인증 서비스 |
| `TOKEN` | 메인 ↔ Region/Zone 서비스 간 연동 |
| `TOKEN white list` | 제한 호출자용 서비스 |
| `KT AD` | 외부 조직 연동 (LDAP/AD) |
| `인증서` | mTLS 인증 서비스 |

## 5. 배포 환경 결정

| 환경 | 사용 케이스 |
|------|---------|
| `POD (메인)` | 메인 운영 시스템 (대부분 신규 서비스) |
| `POD (<YOUR_SERVICE> Region)` | <YOUR_SERVICE> Region 분산 배포 |
| `VM (Classic Zone)` | Classic Zone 레거시 |
| `HW` | 향후 필요 시스템 |

## 6. Roadmap 단계 결정

| 표기 | 의미 |
|------|------|
| `1차 YYYY.MM` | 1차 구축 예정 |
| `2차 YYYY.MM` | 2차 범위 확장 |
| `Yellow` | 진행 중 |
| `Green` | 운영 (안정) |
| `Red` | 종료 예정 |
| `미정` | 일정 미확정 |

## 7. 자율 repo 여부 결정 (ADR-009)

### 우리 표준 적용 (Default)
- 영문 conventional commit (`feat:/fix:/refactor:/docs:/test:/chore:/rules:`)
- Jira 티켓 키 필수 (`${JIRA_PROJECT_KEY}-NNN`)
- `dev-code-review` evidence 생성 의무
- Co-Authored-By 자동 추가
- spec/plan 위치: `projects/{프로젝트}/docs/features/{TICKET}-*.md`
- AGENTS.md/CLAUDE.md는 cairn 참조

### 자율 repo (예외 — 사용자 명시 합의 필요)
조건:
- 주력 작성자가 자체 워크플로우 정착 (예: `<SERVICE_A> <YOUR_TEAM_MEMBER>`)
- README가 단일 작업 지침 (자체 가이드 풍부)
- `docs/superpowers/{plans,specs}` 같은 자체 spec 시스템 운영

자율 시:
- repo 자체 룰 보존 (한글 commit, 자체 spec 위치 등)
- 우리 카탈로그 메타만 관리 (`services/{파트}/{서비스}/README.md` frontmatter)
- 도메인 에이전트(`domains/<YOUR_SERVICE>/agents/{서비스}.md`)에 자율성 메타 명시 필수

판단 기준 예시:
- ✅ `<SERVICE_A>` (자율): README 300줄+, docs/superpowers 충분, 자체 commit 규칙 정착
- ❌ `<SERVICE_B>` (표준 적용 대상): 초기 단계, docs/superpowers 없음

## 8. service-mapping.md 등록

신설 서비스마다 `rules/service-mapping.md` 행 추가:

```markdown
| `{서비스명}`, `{한글별명}` | {파트}/{서비스} | {비고} |
```

## 9. frontmatter 표준 (필수 6 필드)

```yaml
---
tags:
  - type/reference
  - service/{서비스명}
  - audience/team
vision_category: "{카테고리}"
vision_layer: "{계층}"
part: "{<YOUR_PART_A>|<YOUR_PART_B>|공통}"
roadmap_stage: "{1차/2차 YYYY.MM} {Yellow|Green|Red|미정}"
auth_method: "{SSO|Token|Local|Certificate|기타}"
deployment: "{K8s|VM|HW|기타}"
---
```

## 10. 도메인 에이전트 메타정보 (자율 repo 필수)

위치: `domains/<YOUR_SERVICE>/agents/{서비스}.md`

필수 섹션:
- repo 정보 (경로/주력 작성자/활성 기간)
- 비전 매핑
- 자율 사유 (자율 repo 시)
- 자체 룰 영역 vs 우리 표준 영역
- AI 작업 시 진입 규칙

표준 적용 repo는 메타 신설 선택. 자율 repo는 **필수**.

## 결정 체크리스트 (요약)

GATE 0 통과 시 본 모든 결정이 명시되어야 함:

- [ ] 파트
- [ ] 카테고리
- [ ] 계층
- [ ] 인증 방식
- [ ] 배포 환경
- [ ] Roadmap 단계
- [ ] 자율 repo 여부
- [ ] service-mapping.md 행 작성
- [ ] frontmatter 6 필드 채움
- [ ] 도메인 에이전트 신설 여부 결정

## 11. demo-be 템플릿 표준 (외부 자율 repo, source of truth)

신규 서비스 fork는 **demo-be 표준 문서를 source of truth로 따른다**. demo-be repo는 ADR-009 자율 repo 원칙 적용 — repo 자체가 표준의 단일 source, cairn는 진입 포인터만 관리.

| 영역 | demo-be 표준 문서 | 핵심 |
|------|----------------|------|
| Helm Chart | `doc/md/chart-standard.md` | OTel annotation 3건, host-logs hostPath + initContainer chown, Downward API env 4건 |
| 품질 게이트 | `doc/md/lint-standard.md` | ktlint 14.1.0 + detekt 2.0.0-alpha.2 plugin, `.editorconfig` 140자, `./gradlew check` PR gate |
| Observability | `doc/md/observability.md` | micrometer-registry-prometheus + Actuator prometheus endpoint, logback trace_id MDC, dev/local RollingFile |
| 전체 체크 | `doc/md/bootstrap-checklist.md` | 10영역 전수 점검 (코드/품질/Observability/Chart/Values/Vault/ConfigMap/카탈로그/Jira/배포) |

repo: `${GIT_ORG}/demo-backend-kt` (workspace symlink: `workspace/<YOUR_TEMPLATE_REPO>/`)

### 신규 서비스 fork 시 참조 순서

1. **demo-be `doc/md/bootstrap-checklist.md`** — 10영역 체크리스트 (작업 진행 도구)
2. **demo-be `doc/md/chart-standard.md`** — chart 생성 시 (Helm)
3. **demo-be `doc/md/lint-standard.md`** — build.gradle.kts/`.editorconfig`/`config/detekt/detekt.yml` 설정 시
4. **demo-be `doc/md/observability.md`** — Spring Boot dependency + application.yaml + logback 설정 시
5. **본 charter (`bootstrap-charter.md`)** — cairn 카탈로그 메타 결정 시 (파트/카테고리/계층/인증/배포/Roadmap/frontmatter)

### demo-be 표준 + 본 charter 정합

| 결정 항목 (본 charter) | demo-be 표준 매핑 |
|---------------------|---------------|
| §3 계층 — 배포 환경 | `chart-standard.md` deployment-svc.yaml |
| §4 인증 방식 | `chart-standard.md` envFrom + secrets-provider |
| §5 배포 환경 | `chart-standard.md` host-logs + Downward API |
| §9 frontmatter `auth_method` / `deployment` | `chart-standard.md` OTel + host-logs |
| §9 frontmatter `vision_category` | `observability.md` Grafana 자동 연동 |

### 외부 자율 repo 처리 (ADR-009)

demo-be는 자체 룰 보존 영역 — 우리 표준 강제 X:
- commit 메시지: **한글 conventional** (`기능:`/`문서:`/`버그수정:`)
- Jira 키 포함: `${JIRA_PROJECT_KEY}-NNN` (정규식 매칭으로 추출)
- README 단일 source (AGENTS/CLAUDE/GEMINI는 README 위임)
- spec/plan 위치: repo 내부 (docs/superpowers 등)

cairn는 demo-be의 표준을 **link 포인터로만** 참조. demo-be 표준이 변경되면 본 charter도 후속 갱신.

## 관련 문서

- [ADR-008](../../../../decisions/008-orchestrator-mandatory.md) — orchestrator 의무
- [ADR-009](../../../../decisions/009-vision-catalog-alignment.md) — 비전 정합성 + 자율 repo 존중
- [services/README.md](../../../../services/README.md) — 카탈로그 인덱스
- [rules/service-mapping.md](../../../../rules/service-mapping.md) — 매핑 룰
- **demo-be 템플릿 표준** (source of truth):
  - `workspace/<YOUR_TEMPLATE_REPO>/doc/md/chart-standard.md`
  - `workspace/<YOUR_TEMPLATE_REPO>/doc/md/lint-standard.md`
  - `workspace/<YOUR_TEMPLATE_REPO>/doc/md/observability.md`
  - `workspace/<YOUR_TEMPLATE_REPO>/doc/md/bootstrap-checklist.md`
  - GitHub: https://github.com/${GIT_ORG}/demo-backend-kt (develop 브랜치)
- 비전 페이지: Confluence pageId ${CONFLUENCE_PAGE_ID} (Roadmap/OSS/배포환경)
