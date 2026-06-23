---
name: harness-dev-process
description: 에이전트 무관 동일 결과를 위한 하네스 오케스트레이터. Charter Preflight → CPS → PRD → Architecture → Task Packet → 검증까지 Phase Gate 기반으로 진행.
---

## 스킬 규칙
### ALWAYS
- Phase Gate 순서: INIT → PLAN → IMPL → VERIFY → SHIP
- 각 Phase GATE 통과 전 필수 산출물 확인
- Charter Preflight → CPS → PRD → Architecture → Task Packet
- 이 스킬은 `dev` branch canonical owner로만 사용
### NEVER
- Phase 순서 건너뛰기 금지
- 추정 금지, 불확실한 항목은 [미확인]
- 서비스 bootstrap/운영관리 intent를 이 스킬로 흡수 금지

## branch ownership

- 이 스킬의 책임 범위는 `dev` branch다.
- 새 서비스/프로젝트 bootstrap → `harness-service-bootstrap`
- Vault/ArgoCD/DB 등 운영 반영 → `harness-service-ops`
- rules/skills/hooks 구조 변경 → `meta-harnessing`
- 비개발 intent는 short-circuit delegate가 원칙이며 `.harness/state.json`도 이 스킬이 소유하는 `dev` 흐름에서만 사용한다.

## 언제 사용하는가

- 새 기능 개발 시 (요구사항 → 설계 → 구현 → 검증)
- 기존 기능 변경 시 (영향도 분석 → 설계 → 구현 → 검증)
- 에이전트 무관 동일 결과가 필요할 때

## 언제 사용하지 않는가

- 단순 질문/검색
- 문서 수정 (오타, 형식)
- 설정 변경 1줄
- 새 서비스/프로젝트 bootstrap
- 서비스 운영 반영, 활성화, 배포 환경 설정

## 실행 절차

```
Phase 0: INIT
├── Charter Preflight 수행
├── CPS(Context-Problem-Solution) 작성
└── GATE 0→1 통과

Phase 1: PLAN
├── PRD 작성
├── Architecture 작성
├── CPS/PRD → 피처 문서 승격 (canonical 위치)
├── 사용자 승인
└── GATE 1→2 통과

Phase 2: IMPL
├── [GATE WORKTREE] 멀티 AI 동시 작업 또는 피쳐 단위 작업 시 worktree 분리 의무
│   ├── 메인 디렉토리는 머지/조정 전용 — 코드 작업 금지
│   ├── 생성: `dev-using-git-worktrees` scripts/wt-new.sh {TICKET} [base] (base 판정·명명강제·중복차단 자동)
│   ├── 이름 규약: {repo}-{TICKET} (wt-new가 강제)
│   ├── 같은 브랜치를 2개 worktree에 동시 checkout 불가
│   ├── docs/ 수정은 worktree가 아닌 메인 디렉토리의 현재 표준 브랜치에서 직접 (git-workflow.md 참조)
│   └── 로컬 서비스 충돌 회피: WAS 포트(8080→8081), DB 트랜잭션 롤백, ticket prefix 시드
├── Task Packet 분해
├── 에이전트별 작업 수행 (각자 자기 worktree에서)
├── 빌드 확인
└── GATE 2→3 통과

Phase 3: VERIFY
├── 테스트 실행
├── 코드 리뷰
├── 보안 체크
└── GATE 3→4 통과

Phase 4: SHIP
├── [GATE pre-commit] dev-code-review 의무 호출
│   ├── staged 변경 검토 (보안/품질/도메인/언어별/Cross-cutting)
│   ├── 커밋 단위 목적 단일성 판정 (혼재 시 분리 권고)
│   ├── `.harness/review-evidence.json` 생성 (5분 이내, checks pass)
│   └── 미생성 시 `guard-git-commit.sh`가 commit 차단 (exit 2)
├── 저장소 표준 merge/promotion 순서 준수
│   ├── ai-team-standards: `rules/*` 브랜치 → PR → `main`
│   └── 서비스 저장소 예시: `develop` → `stage` → `production` → `main`
├── 배포 계획 확인
├── Jira A.C. 완료
├── [WORKTREE 정리] `dev-using-git-worktrees` scripts/wt-done.sh {TICKET} (미커밋·미머지 검사 후 remove+prune+브랜치 삭제, 미머지면 차단)
│   ├── 머지 완료 후 사용한 worktree 디렉토리 제거
│   ├── 로컬/원격 feature 브랜치 삭제
│   └── prunable 잔재 정리 (다음 작업자 충돌 방지)
└── GATE 4→DONE
```

### Worktree 안티패턴

| 안티패턴 | 증상 | 대응 |
|---------|------|------|
| 같은 브랜치 2개 worktree checkout | git "already checked out" 오류 | 새 브랜치 생성 후 추가 |
| worktree 정리 누락 | `git worktree list`에 prunable 잔재 | Phase 4 SHIP 정리 단계 + `git worktree prune` |
| 메인 디렉토리에서 feature 코드 작업 | working tree dirty, 머지 시 docs 사고 | worktree 사용 |
| `workspace/` 내부에 worktree 생성 | guard hook 오탐 가능 | 상위 디렉토리(`../{repo}-{TICKET}`) 패턴 사용 |
| worktree에서 docs 수정 후 머지 | 기본 브랜치 머지 시 docs 삭제 사고 | docs는 메인 디렉토리의 표준 브랜치에서 직접 커밋 |

### Worktree base branch 판정

- `ai-team-standards` 같은 `main` 단일 저장소: `{repo-default-branch}=origin/main`
- 서비스 저장소처럼 통합 브랜치가 `develop`인 경우: `{repo-default-branch}=origin/develop`
- 추정 금지. 저장소 원격 브랜치 구조를 먼저 확인한 뒤 worktree 생성

## Harness Level 선택

작업 시작 시 Level을 먼저 판정:

| 조건 | Level |
|------|-------|
| 변경 파일 5개 이하 + DDL 없음 + 외부 연동 없음 | Lite |
| 그 외 | Standard |
| DDL 변경 + 외부 연동 + 영향 테이블 10개 이상 | Full |

## CRITICAL: 2단계 로딩 (토큰 절약)

이 스킬은 SKILL.md만 먼저 읽는다. 부속 파일은 해당 Phase 진입 시에만 읽는다.

| Phase | 읽을 파일 | 읽지 않는 파일 |
|-------|----------|--------------|
| 0: INIT | `references/charter-preflight.md` + `templates/feature-cps.md` | PRD, Architecture, Task Packet |
| 1: PLAN | `templates/feature-prd.md` + `templates/feature-architecture.md` | Task Packet |
| 2: IMPL | `templates/task-packet.md` | CPS, PRD (이미 작성 완료) |
| 3~4: VERIFY/SHIP | `references/phase-gates.md` (Gate 조건 확인용) | 템플릿 불필요 |
| Gate 검증 | `scripts/validate-*.mjs` 실행 (스크립트 읽기 불필요, 실행만) | |

**금지**: Phase 0에서 PRD/Architecture 템플릿을 미리 읽지 않는다.

## References

- Charter Preflight: `references/charter-preflight.md`
- Phase Gates: `references/phase-gates.md`
- Output Schema: `references/output-schema.md`

## Templates

- CPS: `templates/feature-cps.md`
- PRD: `templates/feature-prd.md`
- Architecture: `templates/feature-architecture.md`
- Task Packet: `templates/task-packet.md`

## Validators

- 문서 필수 섹션 검증: `scripts/validate-doc-contracts.mjs`
- Phase Gate 통과 검증: `scripts/validate-phase-gates.mjs`

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 현재 Phase GATE 조건 충족
- [ ] [MANUAL] 필수 산출물 생성 확인 (CPS/PRD/Architecture/Task Packet)
- [ ] [MANUAL] 사용자 GATE 통과 승인
