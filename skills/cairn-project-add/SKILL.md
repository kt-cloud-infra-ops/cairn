---
name: cairn-project-add
description: "Cairn workspace의 .cairn/sources.yaml에 프로젝트 source를 등록하고, 선택적으로 clone까지 수행한다."
---

# Cairn Project Add

새 프로젝트, 문서 repo, wiki repo, 지원 repo를 clone/pull 기반 workspace source로 등록한다. 기본 모델은 symlink가 아니라 `sources.yaml`에 선언된 git source다.

## 스킬 규칙

### ALWAYS
- 상위 경로에서 `.cairn/workspace.yaml`을 찾아 workspace root를 확정한다.
- `.cairn/sources.yaml`을 읽고 기존 `name`/`path` 중복을 확인한다.
- repo URL, ref, local path, role, pull policy 변경 preview를 사용자에게 제시한다.
- local path는 workspace 내부 상대 경로만 허용한다.
- clone 전에 대상 경로 존재 여부와 dirty 상태를 확인한다.

### NEVER
- [GATE-SOURCE-ADD] 통과 전 `.cairn/sources.yaml`을 수정하지 않는다.
- repo URL에 token/password/secret을 포함하지 않는다.
- 기존 디렉터리나 dirty worktree를 자동 덮어쓰지 않는다.
- symlink를 기본 전략으로 만들지 않는다. 필요 시 `strategy: link`를 명시하고 별도 확인을 받는다.

## 입력

| 입력 | 설명 |
|------|------|
| `repo` | git URL. secret 포함 금지 |
| `--name <name>` | source id. 기본값은 repo 이름에서 추론 |
| `--branch <branch>` | branch ref |
| `--tag <tag>` | tag ref |
| `--commit <sha>` | commit ref |
| `--role service|domain|docs|wiki|support|platform` | source 역할 |
| `--path <path>` | workspace 상대 경로. 기본값은 `projects/{name}` |
| `--service-key <key>` | profile service key |
| `--pull-policy manual|auto|on-start|scheduled` | source pull 정책 |
| `--clone` / `--no-clone` | 등록 후 clone 수행 여부 |

## 출력

- 갱신된 `.cairn/sources.yaml`
- 선택 시 `projects/{name}` 또는 지정 path clone 결과
- `.cairn/state/sources.lock.json` 상태 갱신

## 실행 스크립트

이 스킬은 core script를 우선 사용한다. 기본 실행은 preview only이며, `sources.yaml` 수정과 clone은 GATE 확인 후 `--yes`를 붙여 재실행한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cairn-project-add" <repo-url> --name <name> --branch <branch> --role service --dry-run
"${CLAUDE_PLUGIN_ROOT}/scripts/cairn-project-add" <repo-url> --name <name> --branch <branch> --role service --yes
```

로컬 개발 repo에서 직접 실행할 때:

```bash
/path/to/cairn/scripts/cairn-project-add <repo-url> --name <name> --branch <branch> --role service --dry-run
```

## 실행 절차

1. 스크립트를 `--dry-run` 또는 `--yes` 없이 실행해 source add preview를 만든다.
2. preview에서 workspace root, repo URL, ref, role, path, clone 여부, 기존 path 상태를 확인한다.
3. [GATE-SOURCE-ADD]를 사용자에게 확인한다.
4. 승인되면 같은 인자를 유지하고 `--yes`를 붙여 스크립트를 재실행한다.
5. 스크립트가 `sources.yaml` 중복/name/path/secret/path escape를 검사한 뒤 source를 등록한다.
6. 기본값은 clone 수행이다. 등록만 필요하면 `--no-clone`을 명시한다.
7. 결과와 `.cairn/state/sources.lock.json` 갱신 여부를 확인한다.

#### [GATE-SOURCE-ADD] source 등록 승인
이 GATE를 통과해야 `sources.yaml` 수정 또는 clone을 수행한다.
- [ ] workspace root 확인
- [ ] repo URL, ref, role, path preview 확인
- [ ] 기존 source name/path 중복 없음
- [ ] 대상 path가 workspace 내부 상대 경로임
- [ ] clone 수행 여부 확인

WARN 처리:
- 대상 path가 존재하고 remote가 다름 → 중단
- 대상 path가 dirty worktree → 중단하고 사용자에게 정리 요청
- repo URL에 credential 패턴 감지 → 중단

## 완료 조건 (DONE WHEN)

- [CONTENT] `.cairn/sources.yaml` contains source `name`
- [CONTENT] `.cairn/sources.yaml` contains source `repo`
- [CONTENT] `.cairn/sources.yaml` contains source `path`
- [FILE] clone 수행 시 source path 존재
- [MANUAL] source name/path 중복이 없음을 확인
- [MANUAL] repo URL에 secret이 없음을 확인
