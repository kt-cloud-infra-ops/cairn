# 🪨 Cairn

> **내 업무를 AI에게 학습시켜 팀에 공용화하는 workspace-level 개발 하네스**
> *Build your workspace, capture your work, share it with your team.*

등산로에 **돌탑(케른)** 을 쌓아 다음 사람이 길을 찾듯 — Cairn은 당신이 일하며 남긴 **지식·결정·절차를 AI가 마크다운으로 쌓고**, `git commit` 한 번으로 **팀 전체의 길잡이**로 만든다.

```
흔적(내 업무)  →  돌탑(markdown)  →  이정표(팀 공용화)
```

---

## 왜 Cairn인가

혼자 머릿속에만 있던 업무 노하우는 사라진다. Cairn은 **일하는 과정 자체에서** AI가 지식을 끄집어내 문서로 남기고, git으로 공유해 팀의 자산으로 축적한다.

Cairn은 단일 프로젝트에 붙이는 도구가 아니라 **여러 프로젝트를 clone/pull로 관리하는 workspace-level harness**다. 내가 계속 들고 다니는 자산은 플러그인 설치 디렉터리가 아니라 **Cairn workspace**다.

| 모드 | 동작 |
|------|------|
| **Solo (개인)** | 혼자 일하며 자기 지식 라이브러리를 로컬에 축적. 다음 세션은 이미 "학습된" 상태로 시작 |
| **Team (공용)** | `git commit/push`로 공유 → 팀원이 같은 workspace를 clone해 동일한 하네스 + 축적 지식을 함께 사용 |

---

## 3계층 구조

```
cairn              = 범용 엔진 플러그인. 조직값 0.
                     workspace를 생성·검증·읽고 실행하는 core engine.

cairn-<your-team>  = 팀/조직 workspace 인스턴스.
                     서비스 카탈로그, 팀 Jira/Confluence 매핑, 사내 SOP, 도메인 룰 보관.
                     예: cairn-pe (PE팀 레퍼런스 구현), cairn-sre, cairn-data, cairn-acme 등.

```

- `cairn` — 마켓플레이스에 배포되는 코어. 어떤 조직도 설치 가능.
- `cairn-<your-team>` — 각 팀이 직접 소유하는 workspace 인스턴스. `cairn init --profile <name>`으로 생성.
  - `cairn-pe` — PE팀 레퍼런스 구현. 다른 팀이 복제할 수 있는 템플릿 역할.
- 조직값(Jira 프로젝트 키, Confluence space, 서비스명 등)은 전부 `cairn-<your-team>/.cairn/profile/`에만 있다.

---

## ⭐ Capture Loop — 차별화 기능

오케스트레이터가 **일하는 동안 능동적으로** 지식 캡처를 제안한다.

```
업무 수행 (개발 / 운영 / 분석)
  → 오케스트레이터가 "캡처 시점" 감지 → 제안
      "이 작업, 재사용 패턴(lesson)으로 남길까요?"
      "이 결정, ADR로 기록할까요?"
      "이 절차, runbook으로 만들까요?"
  → 승인 → markdown 자동 생성 → workspace storage에 저장
             (knowledge/lessons / decisions / runbooks)
  → git commit (공용화)
  → 다음 세션: 그 markdown이 컨텍스트로 로드 → 학습된 상태로 시작
```

- **수동 호출**: `/cairn:capture [주제]`
- **능동 제안**: 세션 종료 시 Stop hook이 제안 (`.cairn/config.json`의 `capture.frequency`로 조절: `off` / `session-end` / `per-task` / `active`)
- **저장 위치**: workspace `.cairn/config.json`의 `capture.targets`가 가리키는 경로 (`knowledge/lessons`, `decisions`, `runbooks`, `projects/{project}/docs/features`)
- **공용화 게이트**: Team 모드에서 git push는 사용자 승인 후에만 (`[GATE-SHARE]`)

---

## 빠른 시작

### 1. 플러그인 설치

```bash
# git 레포를 마켓플레이스로 추가
/plugin marketplace add <YOUR_GIT_URL>

# 플러그인 설치
/plugin install cairn@cairn-marketplace
```

### 2. Workspace 생성 (`cairn-init`)

```bash
# 새 workspace 만들기 (빈 디렉터리에서)
/cairn:cairn-init --path ~/my-cairn-workspace --profile <your-team> --mode team
# 예: --profile pe (cairn-pe), --profile sre (cairn-sre), --profile data (cairn-data)

# 또는 기존 workspace clone
/cairn:cairn-init --from git@github.com:<YOUR_ORG>/cairn-<your-team>.git
```

`cairn-init`이 생성하는 것:

```
my-cairn-workspace/
├── .cairn/
│   ├── workspace.yaml    # workspace identity, mode, schema
│   ├── config.json       # capture 설정
│   ├── sources.yaml      # 프로젝트 clone/pull 레지스트리
│   └── profile/          # 조직값 보관 (조직별 채움)
├── projects/             # clone/pull로 관리되는 프로젝트들
├── knowledge/            # 축적된 lesson/패턴
├── decisions/            # ADR
├── runbooks/             # SOP/절차서
├── services/             # 서비스 카탈로그
└── AGENTS.md             # workspace 진입점
```

### 3. 프로젝트 연결 (`cairn-project-add` / `cairn-project-pull`)

```bash
# 프로젝트 등록 + clone
/cairn:cairn-project-add git@github.com:<YOUR_ORG>/service-a.git \
  --name service-a --branch develop --role service

# 모든 registered source pull
/cairn:cairn-project-pull --all

# 특정 source만
/cairn:cairn-project-pull --source service-a
```

### 4. 일하며 Capture

```bash
# 개발 시작 (Phase Gate)
/cairn:harness-dev-process

# 세션 종료 시 오케스트레이터가 캡처 제안 (또는 수동)
/cairn:capture
```

### 5. Team 모드로 공용화

```bash
# .cairn/config.json: "mode": "team" 으로 설정 후
git add knowledge/ decisions/ runbooks/ && git commit -m "docs: capture <주제>" && git push
# 팀원은 workspace를 clone하면 축적 지식까지 함께 사용
```

---

## 환경변수 셋업 (아틀라시안 연동 시)

Cairn 코어는 **조직값 0** — 모든 조직값을 profile 또는 환경변수로 받는다.

```bash
# ~/.zshrc 또는 ~/.profile
export ATLASSIAN_BASE_URL="https://yourcompany.atlassian.net"
export JIRA_PROJECT_KEY="PROJ"
export JIRA_REPORTER_ACCOUNT_ID="..."
export CONFLUENCE_SPACE_KEY="TEAM"
export GIT_ORG="your-org"
```

> 전체 변수 목록: [`config/ENV_STANDARD.md`](config/ENV_STANDARD.md)
> 설정 샘플: [`config/cairn.config.example.json`](config/cairn.config.example.json)
> 서비스/팀 매핑 샘플: [`config/services.example.json`](config/services.example.json), [`config/team.example.json`](config/team.example.json)

profile 방식을 쓰면 `workspace/.cairn/profile/atlassian.yaml` 등에 `${ENV_VAR}` 참조로 관리한다. secret(API token 등)은 profile에 커밋하지 않고 환경변수 또는 `.cairn/local.env`(gitignore)에 둔다.

---

## Workspace 구조 상세

```
cairn-workspace/
├── .cairn/
│   ├── workspace.yaml          # workspace identity, mode, schema version
│   ├── config.json             # capture/team/runtime config
│   ├── sources.yaml            # managed project clone/pull registry
│   ├── profile/                # 조직값 (org, atlassian, git, infra, services, teams, hooks)
│   ├── local.env               # gitignore — 개인 token/accountId/local override
│   ├── state/                  # sources.lock.json, capture-state.json
│   └── cache/
├── projects/                   # clone/pull 대상 프로젝트
│   ├── service-a/
│   └── service-b/
├── services/                   # 서비스 카탈로그, TASKS, service-level SOP index
├── runbooks/                   # 운영 SOP/절차서
├── decisions/                  # ADR/의사결정
├── knowledge/                  # lessons/patterns (Capture Loop 저장소)
├── support-projects/           # 외부 요청/지원 프로젝트
├── templates/
└── AGENTS.md                   # workspace entry. AI 도구 공용
```

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **Workspace Engine** | `cairn-init` → workspace 생성/감지. `sources.yaml`로 프로젝트 clone/pull 관리 |
| **Capture Loop** ⭐ | 업무 → workspace storage markdown → git 공용화. 팀 지식 자산화 |
| **Profile 시스템** | `.cairn/profile/`에 조직값 집중. core는 조직값 0 유지 |
| **오케스트레이터** | 요청을 `dev / service-bootstrap / service-ops / harnessing` branch로 분기 |
| **Phase Gate** | INIT → PLAN → IMPL → VERIFY → SHIP 5단계 하드 게이트 (`harness-dev-process`) |
| **개발 하네스** | TDD · 코드리뷰 · 빌드수정 · E2E · 증적관리 (`dev-*` skills) |
| **아틀라시안 연동** | Jira/Confluence 증적 연동 (base URL/project key는 env/profile) |
| **가드레일 hooks** | charter / git-commit / skill-create / build-fail 자동 검사 |

---

## 오케스트레이터 형상

`harness-orchestrator`(GATE 0 intent triage)가 요청을 4개 branch로 분기하고, 각 owner 스킬이 Phase Gate로 실행한다.

📊 **형상 도식 (SoT)** — [`docs/orchestrator-topology.html`](docs/orchestrator-topology.html): Phase별 **문서·훅·rules·스킬·에이전트** 매핑 + GATE 통과/차단(exit 2) 영향을 도식화. **구조 변경 시 이 도식을 함께 갱신한다.**

| branch | owner skill | Phase / GATE |
|--------|-------------|--------------|
| `dev` | `harness-dev-process` | INIT → PLAN → IMPL → VERIFY → SHIP |
| `service-bootstrap` | `harness-service-bootstrap` | SCAN → REGISTER(GATE 1) → APPLY → VERIFY |
| `service-ops` | `harness-service-ops` (+`ops-incident` sub) | PRECHECK(GATE 0) → CONFIG → DEPLOY → DATA(GATE 2) → VERIFY → RELEASE |
| `harnessing` | `meta-harnessing` | ADR-INTENT(GATE 0) → 스캔 → 정합 → 제안 → 적용 |

전 branch 공통: 모든 commit 전 `dev-code-review` → `.harness/review-evidence.json` → `guard-git-commit` 검증. 단일 진입 가드 `guard-orchestrator-entry`(triage.json 마커), Phase 가드 `guard-charter`(state.json).

---

## 플러그인 vs Workspace 디렉터리

```
cairn/                         ← 플러그인 설치 디렉터리 (엔진 코드)
  skills/, rules/, hooks/ ...  ← core assets

my-cairn-workspace/            ← 내가 만들고 들고 다니는 workspace
  .cairn/, projects/, knowledge/ ...
```

플러그인 설치 디렉터리(`cairn/`)는 업데이트 시 교체된다.
내가 쌓는 지식과 프로젝트 연결은 **workspace**에 있으므로 플러그인 업데이트에 영향받지 않는다.

---

## 라이선스

MIT. 일부 스킬(`caveman*`)은 [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (MIT) 유래.

---

*🪨 Cairn — 당신의 업무가 팀의 이정표가 됩니다.*
