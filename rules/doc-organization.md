# Document Organization Rules

## Rules 관리 원칙

| 위치 | 역할 | 내용 |
|------|------|------|
| `rules/` (프로젝트) | **팀 표준** (Git 공유) | 코딩, 테스트, 보안, 워크플로우 등 |
| `${CLAUDE_HOME:-$HOME/.claude}/rules/` (개인) | **개인 환경 설정만** | 개인 IDE/설정 의존 파일 |
| `AGENTS.md` | **통합 지침 canonical** | 프로젝트 구조, 팀 규칙, 워크플로우 진입점 |
| `CLAUDE.md`, `CODEX.md` | **도구별 포인터** | `AGENTS.md`와 `rules/`로 연결 |

**규칙 변경 시**: `rules/` 수정 → Git commit으로 팀 공유

---

## 폴더 구분

| 폴더 | 용도 | 대상 |
|------|------|------|
| `workspace/` | **코드 + 프로젝트 문서** | 코드, `docs/` (스펙, 피처, 릴리즈), `agents/` (도메인 에이전트) — 운영 SQL은 git wiki 발행(원칙: 운영 SQL 적용이력은 `{repo}.wiki.git`. 조직 도입 근거는 워크스페이스 `decisions/` 참조), `docs/operations/` 폴더 두지 않음 |
| `services/` | **서비스 허브 + TASKS.md** | 서비스 카탈로그 (인덱스), Jira 태스크, SOP |
| `support-projects/` | **외부 요청 프로젝트** | 외부 개발사 수행, 우리 팀 설계/리뷰 (서비스 태그 필수) |
| `.cairn/personal/` | **개인 문서** | 작업일지, 개인 메모 (본인 폴더만 수정) |
| `temp/` | **임시 작업 문서** | 작업 중 문서, 위키/Confluence 업로드 전 |
| `templates/` | **문서 템플릿** | 작업일지 등 반복 사용 양식 |
| `knowledge/lessons/` | **AI 에이전트 전용** | 학습 내용 (db/, java/, common/) |

**프로젝트 상세 문서(스펙, 피처, 릴리즈)는 프로젝트 레포 `docs/`에 저장.** `services/`는 서비스 카탈로그(인덱스) 역할만 한다. (운영 SQL 적용 이력은 `{repo}.wiki.git` 발행 — 원칙: git wiki 발행, `docs/operations/` 폐기. 조직 도입 근거는 워크스페이스 `decisions/` 참조)

---

## 폴더 구조

전체 저장소 구조 → `AGENTS.md` "프로젝트 구조". 핵심 문서 위치만:

```
workspace/{프로젝트}/docs/   # 프로젝트 SoT (코드 레포 안)
├── README.md               # 인덱스 + 아키텍처 + 외부 의존성
├── specs/                  # 기본설계, 요구사항
├── features/               # 기능 스펙 (Jira 기반, {TICKET}-*) — DB 개선 설계서도 여기
└── releases/               # 릴리즈 노트
# operations/ 폐기 (원칙: 운영 SQL 적용이력은 git wiki 발행. 조직 도입 근거는 워크스페이스 decisions/ 참조)

services/{서비스}/      # 서비스 카탈로그: README, TASKS.md, sop/
.cairn/personal/<YOUR_EMPLOYEE_ID>/worklog # 개인 작업일지 (본인 폴더만)
knowledge/lessons/           # AI 학습 내용 (db/, java/, common/)
temp/                        # 임시 작업 문서
```

---

## 문서 발행 규칙

### 핵심 원칙

- **프로젝트 레포 `docs/` = 개발 중 Source of Truth** (스펙, 피처, 릴리즈)
- **Confluence/Wiki = 공식 발행 채널** (팀/조직 공유용 최종 문서) — 단 **운영 SQL 적용 이력은 git wiki**(원칙. 조직 도입 근거는 워크스페이스 `decisions/` 참조)
- **로컬 temp/ = 임시 작업 문서** (업로드 후 삭제)

### 운영 SQL = git wiki 발행 (main 로컬 보관 X — 원칙. 조직 도입 근거는 워크스페이스 decisions/ 참조)

- 운영 SQL(적용 이력)은 `docs/operations/`에 쌓지 않고 **각 코드 레포의 git wiki(`{repo}.wiki.git`)에 발행**한다. `docs/operations/` 폴더 자체를 두지 않는다(제거).
  - 위치: `{repo}.wiki.git/operations/{request|change}-{TICKET}-{name}.md` (ITIL 2카테고리: request=요청충족/보정, change=변경관리)
  - AI 읽기: `git clone --depth 1 {repo}.wiki.git` → 로컬 grep (Confluence WebFetch 불필요)
- **`{repo}.wiki.git`은 repo와 1:1 자동 분기** — Confluence처럼 folder 경로를 수동 확인/질문할 필요 없음 (서비스=레포 매핑이 곧 발행처).
- 운영 SOP/절차서(workflow-*.md)는 `services/{서비스}/sop/`에 로컬 유지(AI 운영작업 시 Read).

### 단순 wiki 업데이트 = 최저가 모델 (haiku)

- git wiki / 문서 페이지 생성·갱신 같은 **단순·반복 발행 작업은 haiku 등 최저가 모델**에 위임한다 (토큰 절약). git wiki는 clone→commit→push 절차 고정이라 haiku 기본, push 충돌 시 sonnet 에스컬레이션.
- 예외: 초기 구조 설계(분류, cross-repo 링크 정합성 등 판단 필요)는 sonnet 이상.

### 문서 발행 작업 흐름

1. **문서 작성**: `temp/`에 임시 작성
2. **업로드**: REST API로 직접 업로드 (Confluence 또는 팀 위키)
3. **로컬 삭제**: 업로드 완료 후 삭제

`temp/orchestrator/{service}/state.json` 은 문서 초안이 아니라
서비스 bootstrap/ops 선행조건을 기록하는 로컬 오케스트레이션 상태 파일이다.
이 파일도 git/Confluence 동기화 대상이 아니다.

### Confluence 스페이스 설정

Confluence를 사용하는 경우:
- **스페이스**: `${CONFLUENCE_SPACE_KEY}`
- **URL**: `${ATLASSIAN_BASE_URL}/wiki/spaces/${CONFLUENCE_SPACE_KEY}/overview`

### temp/ 정리 주기

- **매주 금요일** `temp/`를 점검한다.
- 정리 기준:
  - 임시 목적이 끝난 파일: 삭제
  - 재사용/공유 가치가 있는 파일: 적절한 정식 폴더로 이동
    - 프로젝트 문서: 해당 프로젝트 레포 `docs/`
    - 지원 프로젝트: `support-projects/{프로젝트}/`
    - 학습: `knowledge/lessons/`

---

## AI 에이전트 전용 문서 (외부 발행 제외)

외부 Confluence/Wiki 동기화 대상이 아닌 AI 에이전트 전용 폴더:

| 폴더/파일 | 용도 |
|----------|------|
| `knowledge/lessons/` | 코딩 스타일, 디자인 패턴, SOP, 자동화 패턴 |

---

## TASKS.md 관리

서비스별 `services/{서비스}/TASKS.md`:
- Jira 이슈와 연동
- `/work-tasks` 커맨드로 조회
- 로컬에서만 관리 (외부 발행 제외)

---

## 자동 저장 규칙

| 작업 유형 | 저장 위치 |
|----------|----------|
| 임시 작업/분석 | `temp/` |
| 프로젝트 설계/스펙 | **프로젝트 레포 `docs/`** (`specs/`, `features/`, `releases/`) |
| **운영 SQL (적용 이력)** | **`{repo}.wiki.git` operations/ 발행** (`docs/operations/` 로컬 보관 X — 원칙. 조직 도입 근거는 워크스페이스 `decisions/` 참조) |
| **운영 SOP/절차서 (workflow)** | `services/{서비스}/sop/` |
| 외부 요청 프로젝트 | `support-projects/{프로젝트}/` (서비스 태그 필수) |
| 학습 내용/SOP | `knowledge/lessons/` (db/, java/, common/) |
| 팀 의사결정 | `decisions/` |
| 개인 작업일지 | `.cairn/personal/<YOUR_EMPLOYEE_ID>/worklog/YYYY/MM/MM-DD.md` |
| 개인 면담/성과 문서 | `.cairn/personal/<YOUR_EMPLOYEE_ID>/1on1/p-1on1-YYYY-Q{N}.md` |
| 문서 템플릿 | `templates/` |
| **최종 문서** | **Confluence/팀 위키 직접 업로드** |

> **Jira 티켓 판별 우선 규칙 (CRITICAL)**: Jira 티켓 키가 붙은 산출물은 작업 초기·수요조사 단계라도 처음부터 `projects/{프로젝트}/docs/features/{TICKET}-{name}.md`에 저장한다. **작업 단계(확정 전/후)는 저장 위치 판단 기준이 아니다** — "초기 단계라 임시"라는 판단으로 `temp/`에 두지 않는다. `temp/`는 Jira 티켓이 없는 일회성 분석 또는 외부 업로드 전 초안에만 사용한다. (프로젝트 레포 docs 작업은 `main` 브랜치에서 — 배포 브랜치 stage/feature 오염 금지, `rules/git-workflow.md` 참조)

---

## Naming Conventions

- kebab-case: `design-patterns.md`
- 설명적 이름 사용
- **features/ 파일**: `{TICKET}-{descriptive-name}.md` 형식 필수 (예: `PROJ-347-event-copy-identifier.md`)
  - 상세: `rules-on-demand/project-docs.md` → "features/ 파일 네이밍 규칙" 섹션

---

## Obsidian 태그 (YAML Frontmatter)

상세: `rules-on-demand/obsidian-tags.md` 참조 (팀 환경에 따라 선택 적용).

---

## 링크 네비게이션 원칙

문서 간 링크 = AI 탐색 비용을 줄이는 지도. 정확해야 토큰 절약.

- **Dangling 링크 금지** — 없는 파일 참조 시 잘못된 추적으로 토큰 낭비
- **상대경로 prefix 정확히** — 같은 폴더 아니면 `../rules-on-demand/x.md`
- **Markdown 링크만** — Obsidian wiki-link `[[name]]`은 일반 marked 뷰어에서 안 뜸
- **외부 URL은 plain** — GitHub PR/Jira 이슈는 markdown link 대신 URL 원문
- **문서 끝 `## 관련 문서` 섹션 유지** — 다음 읽을 파일 명시(탐색 토큰 절약)
- **breadcrumb** `> 상위: [폴더](README.md)` + 새 문서 추가 시 상위 README 인덱스 갱신
- 한 파일에 모든 규칙을 밀어넣지 않는다(필요 시 해당 파일만 Read). 균형점: 파일 200~400줄
