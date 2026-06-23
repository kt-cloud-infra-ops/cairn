# Git Workflow

## Commit Message Format

```
<type>: <Jira티켓> <description>

<optional body>
```

- **type (canonical)**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `rules`, `commands`
- `<scope>` 형식은 사용 안 함
- Subject ≤50자 권장(72 hard cap), 마침표 X, imperative
- Body는 비명백한 *why*만. 단 **BREAKING CHANGE / 보안 fix / 데이터 마이그레이션 / revert는 body 필수**
- **금지**: AI attribution `🤖 Generated with` — 우리 표준은 `Co-Authored-By` trailer만 허용

### CRITICAL: Jira 티켓 키 필수

코드/서비스 관련 커밋에는 **Jira 티켓 키(예: `${JIRA_PROJECT_KEY}-xxx`)**를 반드시 포함한다.
- 예: `feat: PROJ-379 이벤트 삭제 기능 추가`
- 예외: 작업일지, 하네스 규칙, 개인 메모 등 Jira 티켓이 없는 순수 문서 커밋

> 커밋 예시·BREAKING CHANGE 샘플 → `agents/rules-on-demand/git-advanced.md`

## 브랜치 전략

### CRITICAL: 개인/서비스 문서는 main 직접 커밋

작업일지, 리마인더, 개인 문서(`base/personal/`), 서비스 문서(`base/services/`), 지원 프로젝트(`base/support-projects/`) 등 **Git 배포에 영향이 없는 일상 작업은 `main` 브랜치에 직접 커밋·푸시**한다. 브랜치/PR 만들지 않음. `daily-work-start`/`daily-work-end`도 이 원칙을 따른다.

### CRITICAL: Runtime / Non-runtime 분리

코드와 비코드 변경을 같은 브랜치에 섞지 않는다. 파일 경로가 아니라 **실행 영향 여부**로 판단.

| 구분 | 대상 | 권장 브랜치 |
|------|------|------------|
| **Runtime** (서비스 동작·배포·운영DB 변경) | Java/JSP/JS/CSS/MyBatis/API/테스트, 배포·빌드·실행 스크립트, DDL/DML/프로시저 | `feature/` `fix/` `refactor/` |
| **Non-runtime** (배포 영향 없음) | `docs/`, `agents/`, README/TASKS, 작업일지/분석 메모 | `docs/` `agents/` `chore/` `work/<YOUR_EMPLOYEE_ID>/YYYY-MM-DD` |

판단 기준 보강:
- `docs/features/{TICKET}-*` 설계 문서 = 그 티켓 **구현 코드와 1:1** → 코드와 **같은 브랜치 흐름**으로 함께 관리(설계만 main 직접하면 코드와 단절·추적 불가). 구현 계획이 없는 순수 분석 메모만 main 직접.
- `docs/operations/` = **폐기**(ADR-012). 운영 SQL 적용이력은 `{repo}.wiki.git` 발행, 운영 SOP는 `base/services/{서비스}/sop/`.

운영 원칙:
1. runtime/non-runtime 동시 필요 → **브랜치부터 분리**
2. 이미 섞였으면 커밋 단위 분리, 다음 커밋부터 브랜치 분리
3. owner 불명확 → 임의 커밋 말고 HOLD 후 확인
4. `.DS_Store`, `.claude/`, `application-local.properties` 로컬성 파일은 의도된 경우만 포함

> 예외: standards 저장소처럼 저장소 자체가 non-runtime 자산이면 일상 작업은 `work/<YOUR_EMPLOYEE_ID>/YYYY-MM-DD` 브랜치 사용.

### CRITICAL: 기능 단위 커밋 분리 기준

**하나의 커밋은 하나의 기능적 목적**만. 아래 조합이 섞이면 분리:
- 기능 추가 + 버그 수정
- 비즈니스 로직 + 포맷팅/정리
- API 계약 변경 + 내부 리팩터링
- 보안 수정 + 일반 기능 (별도 추적 + 핫픽스 가능성)
- 문서 변경 + 코드 변경 (runtime 분리 룰과 함께)

판단: "무엇이 바뀌었는가"가 아닌 **"왜 바뀌었는가"**로 묶는다. 같은 Jira 티켓도 목적 다르면 분리(1:N 매핑). **자동 강제**: `dev-code-review`가 혼재 감지 → evidence 미생성 → `guard-git-commit.sh`가 commit 차단.

### CRITICAL: Runtime 변경 배포 순서 필수

프로젝트 레포(workspace/{프로젝트}/)의 **Runtime 변경**은 다음 순서를 **반드시** 따른다.

```
feature/{설명} → develop → stage → production → main
(작업)          (통합)    (스테이징)  (운영)     (릴리즈 기록)
```

- **절대 금지**: `feature/*`·`fix/*` → main 직접 머지, 단계 건너뛰기 (예: develop→main, feature→production)
- **절대 금지**: AI가 사용자 명시 승인 없이 단계 건너뛰기
- **docs-only 예외**: 프로젝트 레포 `docs/`·`agents/` 하위만(실행성 파일 제외)이면 main 직접 커밋 허용
- **hotfix 예외**: `hotfix/{설명} → stage → production → main → develop(역병합)`. 사용자 명시 승인 필수, AI 임의 판단 금지

#### Runtime 판별 파일 패턴

아래 1건이라도 있으면 Runtime, 순차 배포 필수:
```
src/**/*.java, src/**/*.jsp, src/**/*.js, src/**/*.css
src/**/resources/**, src/**/*.xml      # MyBatis mapper, Spring config
pom.xml, build.gradle, Dockerfile
sql/**/*.sql, ddl/**/*.sql              # DDL/DML
*.sh (배포 스크립트)
```
> 단 `*.md`여도 프로젝트 루트 `README.md`처럼 배포 산출물에 영향 주면 runtime. `.sh`·`settings.json`·훅 스크립트는 `agents/` 하위여도 runtime.

### 프로젝트 레포 docs/ 동시 작업 규칙

- **docs/ = non-runtime** → main 직접 커밋 (작업일지/README/순수 분석 메모).
- **예외: `docs/features/{TICKET}-*` 설계서는 구현 코드와 같은 브랜치 흐름** (feature→develop→…→main).
- **CRITICAL: 코드 브랜치(feature/, develop, stg)에서 docs/ 커밋 금지** — add도 delete도 하지 않는다 (코드 브랜치가 docs/를 건드리면 main 머지 시 docs/ 삭제 사고). 단 `features/{TICKET}-*` 설계서는 예외 허용(코드 1:1), 이때 일관되게 코드 흐름으로 둔다(혼재가 머지 삭제 사고 원인).

> docs/ 머지 충돌·복원 절차·.gitattributes → `agents/rules-on-demand/git-advanced.md`

### CRITICAL: 코드 레포에 `.claude/` 비커밋 (ADR-011)

- 코드 레포 **어느 브랜치에도 `.claude/settings.json`·hooks를 커밋하지 않는다** (모든 코드 브랜치에 `.claude`가 퍼지면 머지 사고 위험).
- 하네스 가드는 **`${CLAUDE_HOME:-$HOME/.claude}/settings.json`(user 레벨)에서 standards hook을 절대경로로 직접 실행**하여 worktree까지 강제. 신규 환경은 `/workspace-setup`이 멱등 등록.
- `.harness/`는 로컬 상태 디렉토리 — git 추적 대상 아님(gitignore 권장).

### CRITICAL: 공통룰 변경은 별도 브랜치

`agents/rules/`, `agents/skills/`, `AGENTS.md`, `agents/templates/` 변경은 **팀 전원 영향** → 일상 브랜치에 섞지 말고 **main 기반 `rules/{설명}` 브랜치로 분리 PR**. `guard-git-commit.sh`가 비-rules 브랜치에서 이 경로 변경 시 경고.

- 이미 일상 브랜치에 커밋됨 → cherry-pick 분리 또는 다음 커밋부터 분리
- **PR 묶음**: 같은 주제 변경은 확정 후 1개 PR로. 중간 건건 PR 금지. 서브에이전트엔 "PR 생성 금지" 명시. 독립 주제는 PR 분리.

> 분리 절차 bash·cherry-pick 상세 → `agents/rules-on-demand/git-advanced.md`

## 브랜치 정리

머지 완료된 브랜치는 즉시 삭제(로컬+리모트). `/work-end` 루틴에서도 잔존 확인.
```bash
git branch -d {브랜치} && git push origin --delete {브랜치}
```

## Pull Request / Feature Implementation Workflow

PR 작성 절차와 기능 구현 흐름(Plan→TDD→Code Review→Commit)은 각 스킬이 담당: `harness-plan` / `dev-tdd` / `dev-code-review`. 상세 → `agents/rules-on-demand/git-advanced.md`.

## 관련 문서

- [git-advanced.md](../rules-on-demand/git-advanced.md) — 커밋 예시, 분리 절차 bash, docs/ 머지 충돌, PR/Feature Workflow 상세
- [skill-governance.md](skill-governance.md) — 공통룰 변경 PR 가드레일
