---
workspace: "<YOUR_WORKSPACE_NAME>"
profile: "<YOUR_PROFILE_NAME>"
cairn_schema: "cairn.workspace/v1"
---

# <YOUR_WORKSPACE_NAME> Workspace

> Cairn workspace. 모든 AI 도구(Claude Code, Codex, Cursor 등)는 이 파일을 진입점으로 읽는다.

## 1. Cairn Core 로딩

이 workspace는 `cairn` 엔진과 아래 profile을 사용한다.

```text
Profile: .cairn/profile/
Config:  .cairn/config.json
Sources: .cairn/sources.yaml
```

Cairn 설치 확인:

```bash
# plugin이 등록되어 있으면 workspace를 자동 감지
cairn status
```

## 2. Profile 로딩 순서

1. `.cairn/workspace.yaml` — workspace identity 확인
2. `.cairn/profile/*.yaml` — 조직값 로드 (Jira key, Confluence space, 서비스 카탈로그 등)
3. `.cairn/local.env` — 개인 secret/token 로드 (gitignore 파일)
4. `AGENTS.md` (본 파일) — workspace 컨텍스트 로드

## 3. 프로젝트 접근

관리 프로젝트는 `projects/`에 clone/pull로 관리된다.

```bash
# 전체 pull
cairn pull --all

# 특정 source pull
cairn pull --source service-a

# dry-run 확인
cairn pull --dry-run
```

등록된 source 목록: `.cairn/sources.yaml` 참조

## 4. 주요 폴더

| 폴더 | 역할 |
|------|------|
| `projects/` | 서비스 코드 repo (clone/pull 관리) |
| `services/` | 서비스 카탈로그 + TASKS + SOP 링크 (인덱스) |
| `runbooks/` | 운영 SOP/절차서 (canonical) |
| `decisions/` | ADR/의사결정 이력 |
| `knowledge/` | 팀/AI 학습 내용 |
| `support-projects/` | 외부 요청/지원 프로젝트 |
| `.cairn/profile/` | 조직값 (Jira/Confluence/서비스 카탈로그 등) |

## 5. Capture Loop

세션 종료 후 `cairn capture`로 학습/결정/SOP를 workspace storage에 저장한다.

```text
lesson   → knowledge/lessons/
decision → decisions/
sop      → runbooks/
feature  → projects/{source}/docs/features/
```

## 6. Secret 관리

개인 token, accountId, DB 비밀번호는 `.cairn/local.env`에만 보관한다 (git 금지).

```env
# .cairn/local.env 예시
ATLASSIAN_BASE_URL=https://yourcompany.atlassian.net
ATLASSIAN_API_TOKEN=<your-api-token>
JIRA_PROJECT_KEY=PROJ
```

## 7. 규칙 + 스킬

- 팀 규칙: `rules/` (core 자동 로드)
- 팀 스킬: `skills/` (커맨드 목록은 cairn 문서 참조)
- 도메인별 규칙: `domains/{domain}/rules-on-demand/`
- 도메인별 스킬: `domains/{domain}/skills/`

## 8. 온보딩

신규 팀원 체크리스트:

- [ ] `cairn` 플러그인 설치 확인
- [ ] `.cairn/local.env` 생성 (팀 비공개 가이드 참조)
- [ ] `cairn pull --all` 실행하여 프로젝트 clone
- [ ] `cairn status`로 workspace 상태 확인
