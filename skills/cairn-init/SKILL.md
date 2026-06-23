---
name: cairn-init
description: "Cairn workspace를 생성하거나 기존 workspace를 감지한다. .cairn 스캐폴드, profile 초기화, sources.yaml 생성, 기본 storage 디렉터리를 준비한다."
---

# Cairn Init

여러 프로젝트를 관리하는 Cairn workspace를 초기화한다. Cairn은 단일 프로젝트에만 붙는 도구가 아니라 workspace-level harness이므로, 단일 repo에서 호출되면 먼저 제한 사항을 안내한다.

## 스킬 규칙

### ALWAYS
- `.cairn/workspace.yaml`을 상위 경로에서 먼저 탐색해 기존 workspace 여부를 확인한다.
- 생성 전 workspace root, mode, profile path, 생성 파일 목록을 preview한다.
- `schemas/workspace.schema.json`, `schemas/sources.schema.json`, `schemas/profile.schema.json` 계약을 따른다.
- 조직/팀/서비스/Jira/Confluence 실제 값은 profile placeholder 또는 사용자 workspace profile에만 둔다.
- 기존 파일이 있으면 보존하고, 덮어쓰기는 사용자 승인 후 backup/merge 경로로만 처리한다.

### NEVER
- [GATE-WORKSPACE] 통과 전 `.cairn/` 또는 root `AGENTS.md`를 생성하지 않는다.
- [GATE-PROFILE] 통과 전 조직 profile 값을 임의 생성하지 않는다.
- 개인 secret, accountId, token, 실명, 사번을 scaffold 파일에 쓰지 않는다.
- 단일 프로젝트 repo에서 workspace 기능이 완전히 적용된다고 안내하지 않는다.

## 입력

| 입력 | 설명 |
|------|------|
| `--path <dir>` | workspace root. 기본값은 현재 디렉터리 |
| `--profile <name|path>` | 사용할 profile scaffold 또는 빈 profile 이름 |
| `--mode multi-project|solo|project-local` | 기본값은 `multi-project` |
| `--from <git-url>` | 기존 Cairn workspace repo를 clone하여 시작 |
| `--register-current` | 현재 git repo를 첫 source로 등록 |

## 출력

- `.cairn/workspace.yaml`
- `.cairn/config.json`
- `.cairn/sources.yaml`
- `.cairn/profile/`
- `.cairn/state/`, `.cairn/cache/`
- `projects/`, `knowledge/`, `decisions/`, `runbooks/`, `services/`, `support-projects/`, `templates/`
- root `AGENTS.md` 또는 기존 `AGENTS.md`에 대한 수동 연결 안내

## 실행 스크립트

이 스킬은 core script를 우선 사용한다. 기본 실행은 preview only이며, 실제 파일 생성은 GATE 확인 후 `--yes`를 붙여 재실행한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cairn-init" --path <workspace-root> --mode multi-project --dry-run
"${CLAUDE_PLUGIN_ROOT}/scripts/cairn-init" --path <workspace-root> --mode multi-project --yes
```

로컬 개발 repo에서 직접 실행할 때:

```bash
/path/to/cairn/scripts/cairn-init --path <workspace-root> --mode multi-project --dry-run
```

## 실행 절차

1. 스크립트를 `--dry-run` 또는 `--yes` 없이 실행해 preview를 만든다.
2. preview에서 workspace root, mode, profile source, 기존 파일 충돌, 단일 repo 경고를 확인한다.
3. [GATE-WORKSPACE]와 [GATE-PROFILE]을 사용자에게 확인한다.
4. 승인되면 같은 인자를 유지하고 `--yes`를 붙여 스크립트를 재실행한다.
5. 스크립트 결과로 `.cairn/`, storage 디렉터리, `workspace.yaml`, `config.json`, `sources.yaml`, profile placeholder 파일 생성을 확인한다.
6. `--register-current`를 사용했다면 `sources.yaml`의 첫 source 후보를 확인한다.
7. 다음 단계(`cairn-project-add`, `cairn-project-pull`)를 보고한다.

#### [GATE-WORKSPACE] workspace 생성 위치 확인
이 GATE를 통과해야 파일을 생성한다.
- [ ] workspace root가 절대 경로로 확인됨
- [ ] mode가 `multi-project`, `solo`, `project-local` 중 하나로 확인됨
- [ ] 단일 프로젝트 repo에서 실행 중이면 제한 사항을 사용자에게 안내함
- [ ] 생성/충돌 파일 preview를 사용자에게 제시함

WARN 처리:
- 기존 `.cairn/` 발견 → init 중단 또는 repair로 전환
- workspace root가 git repo 내부이고 mode가 `multi-project` → 사용자 확인 없이는 진행 금지

#### [GATE-PROFILE] profile 초기화 확인
이 GATE를 통과해야 `.cairn/profile/`을 작성한다.
- [ ] profile source가 empty scaffold인지, 외부 scaffold인지 확인됨
- [ ] profile에는 실제 조직값/secret이 core plugin 파일로 들어가지 않음
- [ ] 개인값은 `.cairn/local.env` 또는 OS/env var로 분리됨

WARN 처리:
- profile에 token/accountId/secret 후보가 있으면 저장 전 중단

## 완료 조건 (DONE WHEN)

- [FILE] `.cairn/workspace.yaml` 존재
- [FILE] `.cairn/config.json` 존재
- [FILE] `.cairn/sources.yaml` 존재
- [FILE] `.cairn/profile/` 존재
- [CONTENT] `.cairn/workspace.yaml` contains `schema: "cairn.workspace/v1"`
- [CONTENT] `.cairn/sources.yaml` contains `schema: "cairn.sources/v1"`
- [MANUAL] 조직값/secret이 scaffold에 포함되지 않았는지 확인
