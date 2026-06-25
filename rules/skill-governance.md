# Skill Governance

## 새 스킬 생성 전 필수 체크 (CRITICAL)

`skills/` 하위에 새 스킬 폴더를 생성하기 전에 아래 절차를 반드시 수행한다.

### Step 1: 중복 확인

1. 기존 스킬 목록 확인: `ls -d skills/*/`
2. prefix 그룹 내 유사 기능 검색 (daily-*, jira-*, dev-*, harness-*, cicd-*, workspace-*, analytics-*, meta-*, service-ops-*, `{서비스}-*`)
3. vendor/ 스킬에 동일 기능 있는지 확인: `ls skills/vendor/`
4. 기존 스킬의 description과 새 스킬 목적 비교

### Step 2: 판단

| 상황 | 행동 |
|------|------|
| 기존 스킬이 80%+ 커버 | **기존 스킬 수정** (새 스킬 생성 금지) |
| 기존 스킬과 30~80% 겹침 | **기존 스킬 확장** (references/ 추가 또는 절차 보강) |
| 겹침 30% 미만 | **새 스킬 생성 허용** |
| vendor에 동등 기능 | **vendor 채택 검토** (SUPPLEMENT/REPLACE 판정) |

### Step 3: 최소 요건 (새 스킬 생성 시)

- [ ] `SKILL.md` 필수 (`templates/skill-template.md` 양식)
- [ ] frontmatter: `name`, `description` 필수
- [ ] `## 스킬 규칙` — ALWAYS 또는 NEVER 최소 1개
- [ ] `## 실행 절차` — 최소 1단계
- [ ] `## 완료 조건 (DONE WHEN)` — 최소 1개 태그 ([MANUAL], [FILE], [GIT], [CONTENT])
- [ ] prefix 네이밍 준수 (기존 그룹과 일관)
- [ ] **GATE 필수 영역 해당 시 [GATE] 1개 이상 명시** (아래 "GATE 필수 영역" 섹션 참조)

### Step 4: 등록

- AGENTS.md 스킬 테이블에 추가
- 공통룰 변경이므로 `rules/` 브랜치 분리 권장

---

## 기존 스킬 수정 규칙

- 양식 변경 (스킬 규칙/실행 절차/완료 조건): 팀 공유 영향 → `/review-rules`
- 내용만 보강 (references/ 추가, 절차 상세화): 자유 커밋
- 스킬 삭제: 참조 0건 확인 후 삭제 + AGENTS.md 갱신

---

## Vendor 스킬 채택 절차

1. Discovery: GitHub에서 SKILL.md 포맷 레포 탐색
2. Evaluation: `manifest.json`에 `enabled: false`로 등록 → `sync-vendor.sh diff`
3. Adoption: REPLACE / SUPPLEMENT / REDUNDANT / INDEPENDENT 판정
4. Maintenance: `/harnessing vendor`로 정기 점검

### Vendor 원본 직접 호출 (1-depth 직접 복사 패턴)

vendor SKILL.md를 사용자가 **직접 호출**(예: `/caveman lite`)하려면 Claude Code의 SKILL 자동 인식이 1-depth만 지원하므로 1-depth로 노출한다.

- vendor 원본: `skills/vendor/{repo-id}/{skill-name}/` (3-depth, 미인식)
- 노출 위치: `skills/{skill-name}/` (1-depth, 인식)

**symlink 금지** — git symlink는 Windows에서 plain text 파일로 체크아웃되어 SKILL 미인식. 대신 `sync-vendor.sh expose`로 **직접 복사**한다 (모든 OS 호환).

```bash
# vendor → 1-depth 일괄 복사 (manifest의 exposedAs 기준)
bash skills/sync-vendor.sh expose

# 노출 제거
bash skills/sync-vendor.sh unexpose
```

manifest.json에 `exposedAs` 필드로 노출 경로를 명시한다. vendor 원본 갱신 시(`sync-vendor.sh sync`) 노출본도 다시 `expose`로 재동기화한다.

### Vendor hook/script 의존성 점검 (직접 호출 시 필수)

vendor가 hook, script, MCP middleware, subagent 정의에 의존하면 SKILL.md만 import해서는 작동하지 않는다. 직접 호출 노출 시 manifest.json에 아래 필드를 기록:

- `hookDependency` — 의존 파일/메커니즘 (예: `mode-tracker.js`, `scripts/__main__.py`, `subagent 등록`)
- `functionalStatus` — 우리 환경 작동 여부: `OK` / `PARTIAL` / `BROKEN`

`BROKEN`/`PARTIAL` 스킬은 사용자에게 공식 plugin install 안내 또는 noop 사실을 표기한다.

---

## Prefix 네이밍 규칙

| Prefix | 용도 | 예시 |
|--------|------|------|
| `daily-` | 일상 업무 루틴 | daily-work-start, daily-wrap |
| `jira-` | Jira 운영/동기화 | jira-work-tasks, jira-rest-ops |
| `harness-` | 개발 프로세스/Phase Gate | harness-dev-process, harness-plan |
| `dev-` | 개발 도구 (TDD, 리뷰, E2E) | dev-tdd, dev-code-review |
| `cicd-` | CI/CD 배포 | cicd-deploy |
| `workspace-` | 환경 설정 | workspace-init, workspace-setup |
| `analytics-` | 분석/학습 | analytics-usage-report |
| `meta-` | 하네스/규칙 관리 | meta-harnessing, meta-review-rules |
| `{서비스}-` | 서비스 특화 (팀 환경에 맞게 추가) | `<YOUR_SERVICE>-datachange`, `<YOUR_SERVICE>-release` |
| `service-ops-` | service-ops branch helper (Vault/Observability/HTTPRoute 등) | service-ops-config |
| `{서비스}-` | 추가 서비스 특화 (신규) | `<YOUR_SERVICE>-*` |
| (없음) | 독립 도구 | apidog-openapi-sync |

---

## GATE 필수 영역 (CRITICAL)

아래 영역에 해당하는 스킬은 절차 내 `[GATE]` 통과 조건을 **최소 1개 이상** 반드시 포함한다. 우회 가능한 절차만 두면 AI 간 결과 차이/사용자 신뢰 훼손이 발생한다.

### 의무 영역

| 영역 | 예시 |
|------|------|
| **외부 시스템 돌이킬 수 없는 변경** | Jira 댓글/필드 등록, Jira Version 갱신, GitHub 머지·push, ArgoCD sync, 운영 DB DML/API |
| **외부 공유 산출물 생성** | 주간보고 댓글, 릴리즈 공지, Slack 발송 |
| **운영 영향 분류·결정** | 데이터 변경 요청 분류, 배포 범위 결정 |
| **사용자 명시 승인 단계** | brainstorm/plan CONFIRM, SHIP 전 최종 승인 |

### 비필수 영역 (DONE WHEN으로 충분)

| 영역 | 예시 |
|------|------|
| **단순 도구성** | read-only helper (`auth-check`, 조회 전용 검색/분석) |
| **읽기 전용 분석** | analytics-* (외부 변경 없음) |
| **개인 루틴** | daily-* (영향 제한) |
| **자체 강제 절차** | dev-tdd (RED→GREEN 순서 자체 강제), dev-build-fix (빌드 통과 자동 검증) |

주의:
- `jira-rest-ops`처럼 read/write가 함께 있는 스킬은 **조회 경로만 비필수**로 본다
- `create/update/comment/transition`처럼 외부 시스템 상태를 바꾸는 경로는 GATE 필수 영역으로 분류한다

### GATE 작성 규칙

상세는 `templates/skill-template.md` "(선택) GATE 패턴" 섹션 참조. 핵심:

1. **번호 부여**: GATE 0(데이터 수집) → GATE 1(분류·확인) → GATE 2(실행 전 검증) → DONE 직전 GATE(최종 승인)
2. **체크박스 형식 필수**: `- [ ]`로 통과 조건 명시
3. **NEVER 룰 병행**: `[GATE N] 통과 전 {행위} 금지`
4. **데이터 소스 우선순위 표** (다중 소스 사용 시): PRIMARY/SECONDARY/FORBIDDEN
5. **외부 컨텍스트 처리** (스킬로 해결 불가 부분): 선행 데이터 갱신 또는 GATE에서 사용자 추가 경로 명시

### 권장 한도

- 스킬당 GATE 최대 3개 이내 (예외: `harness-dev-process` Phase Gate 5개는 핵심 개발 흐름 특수 사례)
- 형식적 GATE 금지 — 실제 우회 가능 지점에만 배치

### 위반 시 처리

- 신규 스킬: PR 리뷰에서 GATE 누락 지적 → 보강 후 재제출
- 기존 스킬: 마이그레이션 Phase에 따라 단계적 보강 (Phase 1 HIGH → Phase 2 MEDIUM)

### Phase 1/2/3 마이그레이션 현황

GATE 마이그레이션은 팀 환경에 맞게 HIGH → MEDIUM → template+governance 순서로 진행한다.

| Phase | 대상 기준 | 비고 |
|-------|----------|------|
| Phase 1 (HIGH) | 외부 시스템 돌이킬 수 없는 변경 스킬 (예: cicd-deploy, 릴리즈 동기화, 데이터 변경 요청 자동화, 주간보고) | 팀 환경에 해당하는 스킬 목록으로 대체 |
| Phase 2 (MEDIUM) | 계획/검증 스킬 (예: harness-plan, dev-subagent-driven) | 팀 환경에 해당하는 스킬 목록으로 대체 |
| Phase 3 (template + governance) | skill-template.md / skill-governance.md (본 파일) | ✅ 완료 |
