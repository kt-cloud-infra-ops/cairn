# Cairn Workspace Model

> 설계 SoT: `cairn-engine-design.md` §1–2, §8

---

## 1. 3계층 아키텍처

Cairn은 단일 프로젝트에 붙이는 도구가 아니라 **여러 프로젝트를 clone/pull로 관리하는 workspace-level harness**다. 사용자가 계속 들고 가는 결과물은 플러그인 설치 디렉터리가 아니라 **Cairn workspace**다.

```text
cairn              = 범용 엔진 플러그인 (조직값 0)
cairn-<your-team>  = 팀/조직 workspace 인스턴스 (조직값 집중)
                     예: cairn-pe (PE팀 레퍼런스 구현), cairn-sre, cairn-data, cairn-acme 등
ats                = ai-team-standards (마이그레이션 소스 → archive)
```

> **`cairn-pe`는 PE팀의 레퍼런스 구현(reference implementation)**이다. 고정된 유일한 workspace 이름이 아니라, 다른 팀이 복제할 수 있는 템플릿 예시다. 각 팀은 `cairn init --profile <name>`으로 `cairn-<name>` workspace를 직접 생성한다.

### 계층별 경계 표

| 계층 | 역할 | 들어가는 것 | 들어가면 안 되는 것 |
|------|------|------------|-------------------|
| `cairn` | 범용 엔진/플러그인 | orchestrator, phase gates, capture loop, workspace contract, profile schema, clone/pull skill, generic hooks, generic Atlassian client | 조직명, Jira project key, Confluence space/pageId, 서비스명, 개인명, 사번, 사내 URL, 서비스 SOP |
| `cairn-<your-team>` | 팀 workspace 인스턴스 | `.cairn/profile/*`, 서비스 카탈로그, 팀 Jira/Confluence 매핑, 사내 SOP, 도메인 룰, 운영 runbook, 조직 hooks 토글 | 개인 secret/token, 개인 로컬 경로, 범용 core 코드 fork |
| `ats` | migration source | 현재 자산 원본. 이관 검증 전까지만 SoT | 신규 기능 장기 유지, 신규 조직 표준 축적 |

---

## 2. Workspace 레이아웃

`cairn init`이 생성하거나 `cairn-pe`가 제공하는 기준 구조:

```text
cairn-workspace/
├── .cairn/
│   ├── workspace.yaml          # workspace identity, mode, schema version
│   ├── config.json             # capture/team/runtime 설정
│   ├── sources.yaml            # 관리 프로젝트 clone/pull 레지스트리
│   ├── profile/
│   │   ├── org.yaml            # org/team 표시명, 타임존, 언어
│   │   ├── atlassian.yaml      # baseUrl, project key, space, field id
│   │   ├── git.yaml            # git 조직, 기본 브랜치, wiki 규칙
│   │   ├── infra.yaml          # Vault/ArgoCD/Harbor/Jenkins 네이밍
│   │   ├── services.yaml       # 서비스 카탈로그 + Jira prefix 매핑
│   │   ├── teams.yaml          # 역할, 팀 alias (개인 accountId는 local/env)
│   │   └── hooks.yaml          # profile-aware hooks enable/disable
│   ├── local.env               # gitignore 필수. 개인 token/accountId/로컬 override
│   ├── state/
│   │   ├── sources.lock.json   # clone/pull 상태 lock
│   │   └── capture-state.json  # capture loop 상태
│   └── cache/                  # 일시적 캐시 (gitignore 권장)
├── projects/                   # clone/pull 대상 프로젝트 루트 (symlink 기본값 아님)
│   ├── service-a/
│   └── service-b/
├── services/                   # 서비스 카탈로그, TASKS, service-level SOP index
├── rulepacks/                  # 도메인별 실행팩 (rules-on-demand·agents·skills). 구 domains/ (ADR-014 개명, 전환기 동시허용)
├── runbooks/                   # 운영 SOP/절차서 (canonical)
├── decisions/                  # ADR/의사결정
├── knowledge/                  # lessons/patterns
├── operations/                 # 팀 공통 운영 활동이력 + operations/skills/ (조직 횡단 스킬, 레지스트리 마운트)
├── support-projects/           # 외부 요청/지원 프로젝트
├── templates/                  # 문서 템플릿
└── AGENTS.md                   # workspace 진입점. cairn core + profile 로딩 안내
```

### 폴더별 역할 요약

| 폴더 | 역할 | SoT 위치 |
|------|------|---------|
| `.cairn/profile/` | 조직값 보관소 (secret 제외) | workspace repo |
| `projects/` | 실제 코드 repo (clone 관리) | 각 소스 repo |
| `services/` | 서비스 카탈로그 인덱스 + TASKS + SOP 링크 | workspace repo |
| `runbooks/` | 운영 SOP canonical | workspace repo |
| `decisions/` | ADR 이력 | workspace repo |
| `knowledge/` | AI/팀 학습 내용 (횡단 조사·리뷰) | workspace repo |
| `rulepacks/` | 도메인별 실행팩(rules-on-demand·agents·skills). 구 `domains/` 개명(ADR-014, 전환기) | workspace repo |
| `operations/` | 팀 공통 운영 활동이력 + 횡단 스킬 마운트(`operations/skills/`, 레지스트리·브라우즈축 직교) | workspace repo |
| `support-projects/` | 외부 요청 프로젝트 | workspace repo |

---

## 3. Workspace 모드

### 3.1 `multi-project` (권장, 기본값)

여러 서비스 repo를 `sources.yaml`로 관리. `.cairn/workspace.yaml`의 `mode: "multi-project"`.

- `projects/` 하위에 각 서비스가 clone/pull로 관리됨
- `services/`는 카탈로그/인덱스 역할만 (코드 아님)
- capture target이 workspace storage로 고정 (`knowledge/`, `decisions/`, `runbooks/`)
- profile이 required (`config.json` → `profile.required: true`)

### 3.2 `solo`

혼자 단일 workspace를 운영. `mode: "solo"`.

- profile이 optional (조직 연동 없이 사용 가능)
- Atlassian/CI 연동은 선택

### 3.3 `project-local`

단일 코드 repo 내부에서 제한적으로 cairn 실행. `mode: "project-local"`.

- 현재 디렉터리가 git repo일 때 `cairn init`이 이 모드를 제안
- 핵심 기능 제한: clone/pull 관리, workspace-level capture, cross-project search 불가
- 진입 시 안내: "Cairn 전체 기능은 workspace에서 동작합니다. workspace 생성을 권장합니다."

---

## 4. 왜 plugin이 아니라 workspace인가

### 문제 (기존 모델)

기존 `cairn`은 "설치형 플러그인 안에 지식이 같이 들어가는 제품"처럼 설계되어 있었다.

- 조직값(Jira key, Confluence space, 서비스명 등)이 플러그인 디렉터리에 박혀 있음
- 여러 조직에서 재사용 불가: marketplace 배포 불가
- 팀 자산(SOP, TASKS, ADR, 도메인 룰)이 플러그인 업데이트와 얽힘
- 사용자가 "들고 가는 것"이 플러그인인지 지식인지 불명확

### 해결 (3계층 + workspace 모델)

```text
cairn              → 범용 엔진. 조직값 0. 어느 팀도 설치 가능.
cairn-<your-team>  → 팀 workspace 인스턴스. 조직값 집중. 팀이 직접 관리.
                      cairn-pe = PE팀 레퍼런스 구현 (다른 팀이 복제할 템플릿 예시)
workspace          → 팀이 들고 가는 결과물. Git으로 관리.
```

- **엔진과 조직 지식 분리**: cairn은 schema/skill/hook만, 조직값은 profile
- **마켓플레이스 가능**: cairn core는 어느 팀도 설치 가능
- **지식 지속성**: workspace가 직접 git repo → 인원 변경/도구 교체에 영향 없음
- **프로젝트 확장**: `sources.yaml`로 서비스 repo를 선언 → `cairn pull`로 동기화

### 결정 요약 (설계 §8)

| 관점 | 산출물 | 성공 기준 |
|------|--------|---------|
| Marketplace core | `cairn` | 조직값 0, workspace contract 제공, generic skills/hooks, profile schema |
| ATS migration | `cairn-pe` (PE팀 레퍼런스 구현) | ATS shared 자산 손실 없이 이관, profile에 조직값 집중, projects clone/pull. 일반 패턴: `cairn-<your-team>` |

---

## 관련 문서

- [PROFILE_CONTRACT.md](PROFILE_CONTRACT.md) — profile YAML 스키마 상세
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) — ATS → cairn-pe 이관 절차
- [templates/workspace/](../templates/workspace/) — workspace.yaml, sources.yaml, AGENTS.md 템플릿
- [templates/profile/](../templates/profile/) — profile YAML 파일별 템플릿
