# Cairn Profile Contract

> 설계 SoT: `cairn-engine-design.md` §1.2, §2.4

---

## 1. Profile이란

Profile은 **조직값 보관소**다. Cairn core(엔진)는 schema와 key 이름만 정의하고 실제 값은 보관하지 않는다. Profile은 workspace의 `.cairn/profile/` 디렉터리에 YAML 파일로 저장된다.

### 핵심 원칙

- **조직값 집중**: Jira project key, Confluence space, git 조직, 서비스 카탈로그, 팀 구성 등 조직별로 다른 모든 값은 profile에만 존재한다.
- **Secret 제외**: API token, 비밀번호, 개인 accountId는 profile YAML에 보관하지 않는다. `local.env` 또는 OS keychain/env var 사용.
- **Git 공유 가능**: profile YAML 자체는 git에 커밋한다. secret이 없으므로 팀 전체가 공유 가능.
- **Env var 참조**: `${VAR_NAME}` 형식으로 환경변수를 참조한다. 실제 값은 `local.env`(gitignore) 또는 시스템 env에 있다.

### 조직값 0 판정 규칙 (cairn core 기준)

cairn core에 아래 값이 직접 있으면 위반이다:

| 유형 | 예 | 허용 위치 |
|------|----|----------|
| 조직/회사/팀명 | 특정 조직명, 부서명 | `profile/org.yaml` |
| Jira/Confluence 식별자 | project key, space key, numeric pageId | `profile/atlassian.yaml` |
| Git 조직/레포 prefix | git org명, 서비스 repo명 | `profile/git.yaml`, `.cairn/sources.yaml` |
| 서비스 카탈로그 | 서비스명, 서비스별 TASKS | `profile/services.yaml` |
| SOP/도메인룰 | 사내 워크플로우, 장애 프로세스 | `runbooks/`, `domains/` |
| 인프라 값 | Vault path, ArgoCD app, Harbor host, DB host/port | `profile/infra.yaml` 또는 user local env |
| 개인값/secret | 실명, 사번, accountId, API token | git 금지. `local.env`, OS keychain, env var |

허용 예외 (cairn core docs): `<YOUR_ORG>`, `${JIRA_PROJECT_KEY}`, `yourcompany.atlassian.net`, `PROJ` 같은 placeholder만 허용.

---

## 2. `.cairn/profile/` 파일별 역할

```text
.cairn/profile/
├── org.yaml          # org/team 표시명, 타임존, 언어
├── atlassian.yaml    # baseUrl, project key, space, field id
├── git.yaml          # git 조직, 기본 브랜치, wiki 규칙
├── infra.yaml        # Vault/ArgoCD/Harbor/Jenkins 네이밍
├── services.yaml     # 서비스 카탈로그 + Jira prefix 매핑
├── teams.yaml        # 역할, 팀 alias (개인 accountId는 local/env 권장)
└── hooks.yaml        # profile-aware hooks enable/disable
```

---

## 3. 각 파일 스키마 및 예시

### 3.1 `org.yaml`

조직과 팀의 기본 정보. 도구 전반에서 표시명/언어/타임존 기본값으로 사용.

```yaml
# .cairn/profile/org.yaml
schema: "cairn.profile.org/v1"

org:
  display_name: "${ORG_DISPLAY_NAME}"
  short_name: "${ORG_SHORT_NAME}"

team:
  display_name: "${TEAM_DISPLAY_NAME}"
  timezone: "${TEAM_TIMEZONE}"      # 예: "Asia/Seoul"
  language: "${TEAM_LANGUAGE}"      # 예: "ko"
```

### 3.2 `atlassian.yaml`

Jira/Confluence 연동에 필요한 식별자. 실제 URL과 key 값은 env var로 참조.

```yaml
# .cairn/profile/atlassian.yaml
schema: "cairn.profile.atlassian/v1"

base_url: "${ATLASSIAN_BASE_URL}"    # 예: https://yourcompany.atlassian.net

jira:
  default_project: "${JIRA_PROJECT_KEY}"
  projects:
    platform_ops: "${JIRA_PROJECT_KEY}"
    # 추가 프로젝트: key: "${JIRA_PROJECT_KEY_2}"
  fields:
    acceptance_criteria: "${JIRA_AC_FIELD_ID}"
    # 추가 커스텀 필드 선언
  issue_types:
    task: "Task"
    epic: "Epic"
    bug: "Bug"

confluence:
  default_space: "${CONFLUENCE_SPACE_KEY}"
  spaces:
    team: "${CONFLUENCE_SPACE_KEY}"
    # 추가 스페이스: docs: "${CONFLUENCE_DOCS_SPACE_KEY}"
```

### 3.3 `git.yaml`

Git 조직, 기본 브랜치 전략, wiki repo 규칙.

```yaml
# .cairn/profile/git.yaml
schema: "cairn.profile.git/v1"

org: "${GIT_ORG}"                    # 예: git org 이름

defaults:
  branch: "develop"                   # 기본 작업 브랜치
  main_branch: "main"
  release_branch_pattern: "release/*"
  hotfix_branch_pattern: "hotfix/*"

wiki:
  pattern: "${GIT_ORG}/{repo}.wiki.git"
  operations_path: "operations"       # ops SQL 발행 경로
```

### 3.4 `infra.yaml`

인프라 도구 네이밍 규칙. 실제 호스트/포트는 local.env로.

```yaml
# .cairn/profile/infra.yaml
schema: "cairn.profile.infra/v1"

vault:
  address: "${VAULT_ADDR}"
  path_prefix: "${VAULT_PATH_PREFIX}"  # 예: secret/data/myteam

argocd:
  server: "${ARGOCD_SERVER}"
  app_name_pattern: "${ARGOCD_APP_PATTERN}"  # 예: {service}-{env}

registry:
  host: "${REGISTRY_HOST}"
  project_prefix: "${REGISTRY_PROJECT_PREFIX}"

ci:
  server: "${CI_SERVER_URL}"
  job_name_pattern: "${CI_JOB_PATTERN}"    # 예: {service}/build

db:
  # host/port/password는 local.env 전용 — 여기 기록 금지
  default_port: 5432
  naming:
    table_prefix: "<YOUR_TABLE_PREFIX>"
```

### 3.5 `services.yaml`

서비스 카탈로그. Jira prefix ↔ 서비스 폴더 매핑의 SoT.

```yaml
# .cairn/profile/services.yaml
schema: "cairn.profile.services/v1"

defaults:
  jira_project: "${JIRA_PROJECT_KEY}"

catalog:
  - key: "service-a"
    display_name: "<YOUR_SERVICE_DISPLAY_NAME>"
    jira_prefix: "<YOUR_JIRA_EPIC_PREFIX>"
    repo: "${GIT_ORG}/service-a"
    folder: "services/service-a"
    tags: ["backend", "critical"]

  - key: "service-b"
    display_name: "<YOUR_SERVICE_B_DISPLAY_NAME>"
    jira_prefix: "<YOUR_JIRA_EPIC_PREFIX_B>"
    repo: "${GIT_ORG}/service-b"
    folder: "services/service-b"
    tags: ["frontend"]

unmapped_policy: "ask"    # ask | skip | error
```

### 3.6 `teams.yaml`

팀 역할과 alias. 개인 accountId는 팀 공유 파일에 넣지 않고 `local.env`에서 env var로 관리.

```yaml
# .cairn/profile/teams.yaml
schema: "cairn.profile.teams/v1"

roles:
  reporter: "${JIRA_REPORTER_ACCOUNT_ID}"     # local.env 참조
  default_assignee: "${JIRA_ASSIGNEE_ACCOUNT_ID}"  # local.env 참조

aliases:
  # 팀 alias는 표시용이며 secret이 아닌 경우 기재 가능
  # 예: team_lead: "team-lead-alias"

slack:
  workspace: "${SLACK_WORKSPACE}"
  default_channel: "${SLACK_DEFAULT_CHANNEL}"
```

### 3.7 `hooks.yaml`

어떤 profile-aware hook을 활성화할지 선언. hook 실행 파일 경로는 workspace 내부 상대 경로만 허용.

```yaml
# .cairn/profile/hooks.yaml
schema: "cairn.profile.hooks/v1"

hooks:
  jira_transition_guard:
    enabled: true                                    # false로 비활성화 가능
    command: "hooks/guard-jira-transition.sh"        # workspace 상대 경로
    events: ["PreToolUse"]
    project_keys: ["${JIRA_PROJECT_KEY}"]

  service_orchestration_guard:
    enabled: true
    command: "hooks/guard-service-orchestration.sh"
    events: ["PreToolUse"]
    require_bootstrap_state: true

  feature_jira_sync:
    enabled: true
    command: "hooks/check-feature-jira-sync.sh"
    events: ["PostToolUse"]
```

보안 규칙:

- hook command는 workspace 내부 파일이어야 한다 (절대 경로, `..` 탐색 금지).
- `${CLAUDE_PLUGIN_ROOT}`는 core hook만 참조한다.
- secret은 hook argv/env에 직접 출력하지 않는다.

---

## 4. Secret 관리 원칙

| 유형 | 저장 위치 | Git 여부 |
|------|---------|---------|
| API token, 비밀번호 | `local.env` (workspace root) 또는 OS keychain | git 금지 |
| Jira accountId (개인) | `local.env` 또는 env var | git 금지 |
| DB 접속 정보 | `local.env` 또는 env var | git 금지 |
| 조직 표시명, URL, key | `profile/*.yaml` | git 허용 (env var 참조) |
| 서비스 카탈로그 메타 | `profile/services.yaml` | git 허용 |

`local.env` 예시:

```env
# .cairn/local.env — gitignore 필수
ATLASSIAN_BASE_URL=https://yourcompany.atlassian.net
JIRA_PROJECT_KEY=PROJ
JIRA_AC_FIELD_ID=customfield_10000
CONFLUENCE_SPACE_KEY=TEAM
GIT_ORG=your-org

# 개인 secret (절대 git 커밋 금지)
JIRA_REPORTER_ACCOUNT_ID=<your-account-id>
JIRA_ASSIGNEE_ACCOUNT_ID=<your-account-id>
ATLASSIAN_API_TOKEN=<your-api-token>
```

---

## 5. Profile Schema Validation

cairn core는 profile YAML을 Node validator로 검증한다. shell hook은 Node helper를 호출하는 래퍼다.

검증 트리거:

- `cairn init` — 생성 직후 schema validate
- `cairn pull` — sources.yaml 로드 전 validate
- `cairn capture` — workspace.yaml의 storage 경로 resolve 전 validate

검증 실패 처리:

- required field 누락 → error (중단)
- unknown key → warning (계속)
- env var 미정의 → warning (값 없이 진행, 연동 시 실패)

---

## 관련 문서

- [WORKSPACE_MODEL.md](WORKSPACE_MODEL.md) — 3계층 모델, workspace 레이아웃
- [templates/profile/](../templates/profile/) — 각 profile YAML 파일 템플릿
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) — 기존 자산을 profile로 이관하는 절차
