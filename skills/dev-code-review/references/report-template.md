# 코드 리뷰 결과 리포트 템플릿

`dev-code-review` 스킬 결과 출력 표준. 모든 리뷰 결과는 본 6단 양식을 따른다.

> Origin: 팀원 제안 `review-and-commit` 스킬 흡수.

---

## 정상 리포트 (이상 0건 또는 자동 수정 후 통과)

```markdown
## 리뷰 결과 — 정상

### 1. 변경 요약
- 파일: {N}건 staged
- 주요 변경: {기능/버그수정/리팩터링/문서/보안 분류}
- Jira: {${JIRA_PROJECT_KEY}-xxx | N/A}

### 2. 검사 실행 결과
| 검사 | 실행 | 결과 |
|------|------|------|
| lint ({도구명}) | ✅ | 0 error |
| 정적 분석 ({도구명}) | ✅ | 0 warning |
| 테스트 | ✅ | {N}건 통과 |
| 빌드 | ✅ | 성공 |

### 3. 자동 수정 내역 (있는 경우)
- {파일:라인} — {수정 사유}
- 수정 후 재검사 통과 ✅

### 4. 클린코드
- 함수 50줄 / 파일 800줄 이내 ✅
- 불변성 ✅ / 임시 코드 0건 ✅

### 5. 보안
- 시크릿 노출 ✅ / 입력 검증 ✅ / 권한 체크 ✅
- <YOUR_ORG> 가드레일 적용 ✅

### 6. 커밋 단위 판정
- 목적 단일성 ✅ (또는 분리 권고 — 아래 분리안)
- 제안 커밋 메시지:
  ```
  feat: ${JIRA_PROJECT_KEY}-xxx {변경 요약}

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

### 7. evidence 저장
- `.harness/review-evidence.json` 생성 — staged 파일 SHA + 검사 결과 + timestamp
- commit 진행 가능 (guard-git-commit.sh 통과)
```

---

## 이상 리포트 (commit 중단)

```markdown
## 리뷰 결과 — 이상 발견 (commit 중단)

### 1. 심각도
- {CRITICAL | HIGH | MEDIUM | LOW}

### 2. 문제
- {항목별로 구체적 기술}
- 예: "IP 검색 조건이 AND가 아닌 OR로 동작할 가능성"

### 3. 영향
- {기능/보안/품질 관점에서 영향 분석}
- 예: "검색 결과 과다 조회 → 요구사항 위반"

### 4. 위치
- {파일:라인 또는 파일 묶음}
- 예: `workspace/<your_service>/src/.../XxxService.kt:120`

### 5. 권장 조치
- {구체적 수정 방향}
- {신규 테스트 추가 필요 여부}

### 6. 커밋 상태
- ❌ 현재 상태 commit 중단
- `.harness/review-evidence.json` 미생성 → `guard-git-commit.sh` 차단 발효
- 수정 또는 커밋 분리 후 재리뷰 필요
```

---

## 커밋 분리 권고 (목적 혼재 시)

```markdown
## 리뷰 결과 — 커밋 분리 권고

### 분리 사유
- {조합 식별: 기능+버그수정 / 로직+포맷 / 보안+일반 등}

### 분리안

#### Commit 1
- 파일: {목록}
- 메시지: `feat: ${JIRA_PROJECT_KEY}-xxx {목적}`

#### Commit 2
- 파일: {목록}
- 메시지: `fix: ${JIRA_PROJECT_KEY}-xxx {목적}`

### 작업 순서
```bash
git reset HEAD
git add {commit 1 파일}
# review-and-commit 재실행
git commit -m "feat: ${JIRA_PROJECT_KEY}-xxx ..."

git add {commit 2 파일}
# review-and-commit 재실행
git commit -m "fix: ${JIRA_PROJECT_KEY}-xxx ..."
```
```

---

## evidence JSON 형식

`.harness/review-evidence.json` 표준 스키마:

```json
{
  "reviewedAt": "2026-05-19T10:30:00Z",
  "stagedFiles": [
    {
      "path": "workspace/<your_service>/src/.../XxxService.java",
      "sha": "abc123..."
    }
  ],
  "checks": {
    "lint": { "tool": "checkstyle", "status": "pass", "errors": 0 },
    "staticAnalysis": { "tool": "spotbugs", "status": "pass", "warnings": 0 },
    "test": { "status": "pass", "passed": 42, "failed": 0 },
    "build": { "status": "pass" }
  },
  "security": {
    "secretLeak": "pass",
    "inputValidation": "pass",
    "authCheck": "pass",
    "orgGuardrail": "pass"
  },
  "cleanCode": {
    "functionSize": "pass",
    "fileSize": "pass",
    "immutability": "pass"
  },
  "commitPurpose": {
    "singular": true,
    "type": "feat",
    "jiraTicket": "${JIRA_PROJECT_KEY}-XXX",
    "suggestedMessage": "feat: ${JIRA_PROJECT_KEY}-XXX {변경 요약}"
  },
  "autoFixed": []
}
```

`guard-git-commit.sh`가 본 파일을 검사하여:
- 존재 여부
- `reviewedAt` 5분 이내
- `stagedFiles` SHA가 현재 staged 파일 SHA와 일치
- 모든 `checks` status = `pass`
- `commitPurpose.singular` = true

조건 미충족 시 commit 차단 (exit 2).

---

## PR 코멘트 압축 형식 (옵트인, caveman-review 흡수)

PR(GitHub/GitLab) 직접 코멘트 작성 시 압축 형식 사용 가능. 우리 표준 review 워크플로우는 그대로 (evidence + 보안 체크리스트 + 도메인 정합성) — **출력 형식만 압축 옵션 제공**.

> Origin: `skills/vendor/juliusbrussee--caveman/caveman-review/SKILL.md` (MIT License, Julius Brussee)

### 코멘트 형식

```
L<line>: <problem>. <fix>.
```

또는 multi-file diff:

```
<file>:L<line>: <problem>. <fix>.
```

### 심각도 prefix (혼재 시)

- 🔴 **bug:** — 깨진 동작, 인시던트 유발
- 🟡 **risk:** — 작동하지만 취약 (race, null 누락, swallowed error)
- 🔵 **nit:** — 스타일/명명/마이크로 최적화. 무시 가능
- ❓ **q:** — 질문 (제안 아님)

### 제거 대상

- "I noticed that...", "It seems like...", "You might want to consider..."
- "This is just a suggestion but..." → `nit:` 사용
- "Great work!", "Looks good overall but..." → 코멘트마다 X (PR 상단 1회만)
- 코드 동작 반복 설명 — 리뷰어가 diff 직접 읽음
- Hedging ("perhaps", "maybe", "I think") → 불확실하면 `q:` 사용

### 보존 대상

- 정확한 라인 번호
- 정확한 심볼/함수/변수명 (백틱)
- 구체적 fix ("consider refactoring" 같은 모호한 표현 X)
- 명확한 *why* (problem 자체로 안 보이면)

### 예시

❌ "I noticed that on line 42 you're not checking if the user object is null before accessing the email property. This could potentially cause a crash if the user is not found in the database. You might want to add a null check here."

✅ `L42: 🔴 bug: user can be null after .find(). Add guard before .email.`

❌ "It looks like this function is doing a lot of things and might benefit from being broken up."

✅ `L88-140: 🔵 nit: 50-line fn does 4 things. Extract validate/normalize/persist.`

❌ "Have you considered what happens if the API returns a 429?"

✅ `L23: 🟡 risk: no retry on 429. Wrap in withBackoff(3).`

### Auto-Clarity (압축 해제)

다음 경우 압축 해제 + 일반 문장 사용:
- **보안 발견** (CVE-class) — full explanation + reference
- **아키텍처 이견** — rationale 필요
- **onboarding 컨텍스트** — 신규 작성자에게 "why" 필요

위 경우만 normal 문장, 나머지는 압축 형식 유지.

### 우리 룰 정합

- 우리 evidence/security/Cross-cutting/도메인 정합성 검사는 그대로 (압축 X)
- PR 코멘트 텍스트만 압축 형식 (옵트인)
- 한글 코멘트 시: `L42: 🔴 bug: user .find() 후 null 가능. .email 접근 전 guard 추가.` 같은 형식
