---
name: cairn-project-pull
description: ".cairn/sources.yaml 기준으로 workspace 프로젝트를 clone/update한다. dirty worktree는 기본 skip하며 파괴적 동작은 사용자 승인 없이는 수행하지 않는다."
---

# Cairn Project Pull

workspace의 managed source를 `sources.yaml` 기준으로 동기화한다. 없는 source는 clone하고, 있는 source는 remote/ref/dirty 상태를 확인한 뒤 안전한 pull만 수행한다.

## 스킬 규칙

### ALWAYS
- 상위 경로에서 `.cairn/workspace.yaml`을 찾아 workspace root를 확정한다.
- `.cairn/sources.yaml`을 schema validation 대상으로 취급한다.
- `--dry-run` 결과로 source별 planned action을 먼저 보여준다.
- dirty worktree는 기본 `skip`으로 처리하고 summary에 남긴다.
- clone/pull 결과를 `.cairn/state/sources.lock.json`에 기록한다.

### NEVER
- [GATE-PULL-DIRTY] 통과 전 dirty source에 stash/rebase/reset을 수행하지 않는다.
- `git reset --hard`, force checkout, untracked 삭제를 자동 실행하지 않는다.
- `sources.yaml`에 없는 임의 프로젝트를 pull하지 않는다.
- repo URL에 secret이 포함된 source를 사용하지 않는다.

## 입력

| 입력 | 설명 |
|------|------|
| `--all` | 모든 source 대상 |
| `--source <name>` | 특정 source만 대상 |
| `--role <role>` | role 필터 |
| `--dry-run` | 실행 없이 planned action 출력 |
| `--policy manual|auto|on-start|scheduled` | 실행할 pull policy 필터 |
| `--include-dirty` | dirty source 처리 계획을 사용자에게 묻기 위해 포함 |

## 출력

- source별 상태: `cloned`, `updated`, `skipped`, `dirty`, `failed`
- `.cairn/state/sources.lock.json`
- 실패/skip summary

## 실행 스크립트

이 스킬은 core script를 우선 사용한다. 기본 실행은 preview only이며, clone/update는 preview 확인 후 `--yes`를 붙여 재실행한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cairn-project-pull" --all --dry-run
"${CLAUDE_PLUGIN_ROOT}/scripts/cairn-project-pull" --all --yes
```

로컬 개발 repo에서 직접 실행할 때:

```bash
/path/to/cairn/scripts/cairn-project-pull --workspace <workspace-root> --all --dry-run
```

## 실행 절차

1. 스크립트를 `--dry-run` 또는 `--yes` 없이 실행해 source별 clone/update/skip 계획을 만든다.
2. preview에서 대상 source, ref, path, dirty 상태, 실패 가능 항목을 확인한다.
3. dirty source가 있으면 [GATE-PULL-DIRTY]를 사용자에게 확인한다. 기본 동작은 skip/fail이며 destructive reset은 지원하지 않는다.
4. 승인되면 같은 인자를 유지하고 `--yes`를 붙여 스크립트를 재실행한다.
5. 스크립트가 없는 path는 clone하고, clean git repo는 fetch/pull/checkout을 수행한다.
6. dirty worktree, remote mismatch, non-git path는 자동 수정하지 않고 skipped/failed로 기록한다.
7. source별 결과와 `.cairn/state/sources.lock.json` 갱신 여부를 확인한다.

#### [GATE-PULL-DIRTY] dirty source 처리 승인
이 GATE를 통과해야 dirty source에 영향을 주는 작업을 수행한다.
- [ ] dirty file 목록을 사용자에게 제시함
- [ ] 처리 방식이 `skip`, `stash`, `fail` 중 하나로 확인됨
- [ ] rebase/stash가 필요한 경우 대상 source와 command preview를 제시함
- [ ] destructive reset이 아님을 확인함

WARN 처리:
- 사용자가 명시 승인하지 않으면 dirty source는 skip
- untracked 파일 삭제가 필요하면 중단
- remote mismatch가 있으면 중단

## 완료 조건 (DONE WHEN)

- [CONTENT] `.cairn/sources.yaml` schema is `cairn.sources/v1`
- [FILE] `.cairn/state/sources.lock.json` 갱신 또는 dry-run summary 생성
- [MANUAL] dirty source는 skip 또는 승인된 처리만 수행
- [MANUAL] source별 cloned/updated/skipped/failed summary 보고
