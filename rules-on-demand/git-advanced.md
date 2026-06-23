# Git Workflow — 상세 (on-demand)

> 상위: [git-workflow.md](../rules/git-workflow.md) — 매 세션 자동 로드되는 핵심 규칙
> 이 파일은 커밋 메시지 작성·PR 생성·프로젝트 레포 docs/ 동시작업 등 **특정 상황에서만** 필요한 상세를 담는다.
> 트리거: `커밋 메시지 작성`, `PR 생성`, `docs/ 머지 충돌`, `caveman-commit`

---

## 커밋 메시지 상세 (caveman-commit 흡수)

> Origin: `agents/skills/vendor/juliusbrussee--caveman/caveman-commit/SKILL.md` (MIT)

핵심 길이/스타일 룰은 git-workflow.md `Commit Message Format` 참조. 아래는 예시와 근거.

**예시**:

❌ `feat: add a new endpoint to get user profile information from the database`

✅
```
feat: PROJ-128 add GET /users/:id/profile

Mobile client needs profile data without full user payload
to reduce LTE bandwidth on cold-launch screens.

Closes #128
```

**BREAKING CHANGE 예시**:

```
feat: PROJ-200 rename /v1/orders to /v1/checkout

BREAKING CHANGE: clients on /v1/orders must migrate to /v1/checkout
before 2026-06-01. Old route returns 410 after that date.
```

**우리 표준과의 차이**:
- caveman 원본: `Co-Authored-By: ...AI...` 금지
- 우리 룰: **Co-Authored-By: Claude Opus ... 자동 추가 강제** (PR #50 review-evidence와 연계, AI 협업 추적)
- → caveman 룰 중 Subject/body 길이/imperative mood/why-over-what만 흡수, attribution 룰은 거부

---

## 프로젝트 레포 docs/ 동시 작업 규칙 (상세)

핵심: **코드 브랜치(feature/develop/stg)에서 docs/ 커밋 금지** (git-workflow.md에 명시). 아래는 그 근거와 사고 복구 절차.

### 개인 수정 워크플로우

```bash
# 1. main으로 전환
git checkout main && git pull origin main

# 2. docs/ 수정
# ... 편집 ...

# 3. main에 바로 커밋
git add docs/
git commit -m "docs: {내용 요약}"
git push origin main
```

- dirty 상태 방치 금지 — 편집 완료 후 즉시 커밋
- worktree 분리 불필요 — 배포 영향 없음

### 코드 브랜치와 머지 시 충돌 방지

코드 브랜치는 docs/를 모르는 채로 유지한다. git 3-way merge 기준:

| merge base | main | 코드 브랜치 | 결과 |
|------------|------|------------|------|
| docs/ 없음 | docs/ 추가 | docs/ 변화 없음 | main docs/ 유지 ✓ |
| docs/ 있음 | docs/ 수정 | docs/ 변화 없음 | main docs/ 유지 ✓ |
| docs/ 있음 | docs/ 수정 | docs/ **삭제** | **충돌 — docs/ 날아감 ✗** |

코드 브랜치에서 docs/를 삭제했다면, main 머지 전에 복원 필요:

```bash
# main 머지 전 코드 브랜치에서 docs/ 복원
git checkout main -- docs/
git add docs/
git commit -m "chore: docs/ restore before merge to main"
```

### .gitattributes 보험 (선택)

main에 아래를 추가하면 어떤 브랜치가 docs/를 삭제해도 main 것을 유지:

```
# .gitattributes
docs/  merge=ours
```

---

## 공통룰 변경 분리 절차 (상세)

`agents/rules/`, `agents/skills/`, `AGENTS.md`, `agents/templates/` 변경은 main 기반 `rules/{설명}` 브랜치로 분리한다(git-workflow.md). 일상 브랜치에서 감지 시:

```bash
# 1. main 기반 브랜치 생성 (필요시 git stash)
git stash
git checkout -b rules/{설명} main
# 2. 공통룰 파일만 커밋
git add agents/rules/... agents/skills/... AGENTS.md
git commit -m "rules: {설명}"
git push -u origin rules/{설명}
# 3. PR 생성 후 원래 브랜치 복귀
git checkout {원래 브랜치}
git stash pop
```

이미 일상 브랜치에 공통룰 변경을 커밋한 경우 → cherry-pick으로 분리하거나, 다음 커밋부터 분리.

---

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

## Feature Implementation Workflow

1. **Plan First**
   - Use `/plan` workflow (or a planner role agent if supported)
   - Identify dependencies and risks
   - Break down into phases

2. **TDD Approach**
   - Use `/tdd` workflow (or a tdd-guide role agent if supported)
   - Write tests first (RED)
   - Implement to pass tests (GREEN)
   - Refactor (IMPROVE)
   - Verify 80%+ coverage

3. **Code Review**
   - Use `/code-review` workflow (or a code-reviewer role agent if supported)
   - Address CRITICAL and HIGH issues
   - Fix MEDIUM issues when possible

4. **Commit & Push**
   - Detailed commit messages
   - Follow conventional commits format

---

## 관련 문서

- [git-workflow.md](../rules/git-workflow.md) — 핵심 규칙 (커밋 포맷, 브랜치 전략, 배포 순서)
- [skill-governance.md](../rules/skill-governance.md) — 공통룰 변경 PR 가드레일
