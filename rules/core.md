# Core Rules

팀 공통 AI 에이전트의 핵심 행동 규칙. 매 세션 자동 로드.

---

## 공유 vs 개인 영역

| 영역 | 위치 | Git 공유 | 변경 시 |
|------|------|---------|---------|
| 팀 규칙 | `agents/rules/` | O | `/review-rules` |
| 커맨드 | `agents/skills/` | O | `/review-rules` |
| 통합 지침 | `AGENTS.md` | O | `/review-rules` |
| 서비스 문서 | `base/services/` | O | 자유 커밋 |
| 개인 문서 | `base/personal/{사번}/` | O | 본인만 수정 |
| 워크스페이스 | `workspace/` | X | 코드+프로젝트 문서 전용 |
| 임시 파일 | `temp/` | X | 작업 후 삭제 |

## 금지 사항

1. **인증정보 커밋 금지** — API 키, 비밀번호, 토큰
2. **workspace에 비프로젝트 문서 저장 금지** — 작업일지/개인 메모는 `base/`에
3. **다른 팀원 개인 폴더 수정 금지**
4. **규칙 무단 변경 금지** — `agents/rules/` 변경 시 `/review-rules` 필수

## CRITICAL: 개발 작업 시 하네스 선행 의무

코드 파일(`src/**`, `*.java`, `*.jsp`, `*.js`, `*.ts`, `*.sql`, `*.xml` 등)을 **수정/생성**하는 작업 시작 전 `harness-dev-process` Phase 0(INIT/CPS)을 **반드시 먼저 발화**한다.

### 적용 대상 (하네스 선행 의무)
- 신규 기능 구현 / 버그 수정 / 리팩터링
- 보안 취약점 분석 + 대응 (예: 모의해킹 PT 후속)
- 외부 API 연동 변경
- DB 쿼리/스키마 변경

### 예외 (하네스 발화 X)
- **Jira 티켓 단순 조회/현황 확인** — 모든 Jira 티켓이 개발건은 아님
- **통합요청 / 데이터 보정** — `luppiter-datachange-request-automation` 사용
- **운영 SQL 1회성 적용** — 운영 변경 SOP에 따라 별도
- **단순 질문/검색** — 코드 변경 없음
- **문서(`docs/`) 수정** — 작업일지, 메모, 리마인더
- **오타 수정 1건 / 설정 1줄 변경** — Lite 레벨 자동 판정 가능

### NEVER
- 위 적용 대상에서 Phase 0 산출물(CPS) 없이 코드 작업 시작 금지
- 직접 Edit/Write로 코드 변경 후 후행적으로 Phase 산출물 생성 금지

### 자동 강제 (worktree 포함)

본 의무는 선언이 아니라 hook으로 물리 강제된다 (ADR-011):

- `guard-charter.sh`(PreToolUse Edit/Write/MultiEdit)가 코드 파일 편집 전 `.harness/state.json`을 검사
- **state.json 없음 → BLOCK** (orchestrator/GATE 0 미진입). Lite여도 state.json은 요구 (산출물 면제 ≠ GATE 0 면제)
- `~/.claude/settings.json`(user 레벨)에서 절대경로로 발동하므로 **ai-team-standards 밖 git worktree(예: luppiter_web)에서도 강제**된다 — 코드작업 위치 무관
- 가드 대상: ai-team-standards / `.harness/` 보유 프로젝트 / origin이 `kt-cloud-infra-ops`인 repo. 무관 repo는 통과
- 신규 환경 onboarding 시 `/workspace-setup`이 user settings hook을 멱등 등록

### 위반 시 처리
- 작업 진행 중 발견 시 즉시 중단 → harness-dev-process 명시 호출 → Phase 0 부터 정식 진입
- 본 룰 위반은 작업일지 AI 협업 섹션에 기록 (재발 방지)

## 규칙 변경 프로세스

경미(오타) → 바로 커밋 / 일반(보완) → 팀 채널 공유 / 중요(신규) → 팀원 확인 / CRITICAL(워크플로우) → 팀 미팅

## 공용룰 우선 원칙

반복 가능성 높은 절차, 여러 에이전트가 따라야 하는 방식 → `agents/rules/`에 canonical 반영 우선.

---

## 일일 업무 루틴

### 시작 (첫 요청)

그날 첫 요청 시 `/work-start` 실행 여부 문의 + `main` 최신본 반영 확인.

### 업무 중

- 요청 1건 완료 시 **작업일지 자동 반영** (질문 없이 바로 기입)
- "검토해" 요청 시 도메인+레이어 에이전트 **병렬 검토** → 작업일지 AI 협업에 출처 기록

### 종료 (18:00 전후)

17:40~18:20에 `/work-end` 문의 1회. 마무리 시: 커밋 요약 + 공통룰 변경 PR 분리 안내.

### AI 협업 출처

`Claude`, `Claude/{에이전트명}`, `Codex` 형식으로 명시.

---

## 사용자 선호

### 언어 피드백

- 영어 요청 → 기본 교정 + 네이티브 버전
- 한글 요청 → 네이티브 영어 버전

### 추정 금지 (CRITICAL)

절대 추정하지 않는다. 확인 안 된 사실은 `[미확인]`/`[TBD]`로 명시. "아마", "~일 것이다" 금지.

#### 응답 작성 전 자가 점검 (의무)

응답에 외부 시스템 상태(서비스 운영 여부, Jira 상태, 큐 길이, 옆 세션 완성도 등) 또는 owner/소유자/사실을 단정하는 내용이 들어가면:

1. 해당 사실을 **도구 호출로 확인했는가** 검토 (jira-rest-ops / cmux read-screen / git log / Read / Grep / Bash)
2. 확인 안 됐으면 → `[미확인]` 또는 `[TBD]` 마킹으로 전환
3. 또는 사용자에게 질문으로 전환 ("X 상태가 확인 안 됨, 알려주실래요?")

#### 위반 패턴 (실제 사고 기반)

| 패턴 | 사고 예시 |
|------|---------|
| 사용자 의도 추정 | ADR-007 작성 시 "owner skill 직접 호출" 의도라고 추정 → 당일 폐기, PR 4건 정정 |
| 외부 시스템 상태 추정 | "infraops-api 운영 중", "Jira 상태 In Progress" 등 확인 없이 단정 |
| 인상비평 | "옆 세션 70% 완성", "큐 OI-1~12" 등 측정 없이 어림 |
| owner 추정 | modified 파일 작성자 추측 (cmux로 검증한 경우는 모범 사례) |

#### 모범 사례

- modified 파일 작성자 의심 → `cmux read-screen`으로 옆 세션 확인 후 정정
- Jira 상태 의심 → jira-rest-ops로 조회
- 코드 동작 의심 → Read + Grep으로 실제 코드 확인

### 응답 스타일 (CRITICAL)

- **개조식(명사형 종결)** — "~완료", "~진행" 형태
- trailing summary 금지, 테이블/리스트로 구조화
- 설명/교육/토론 요청 시에는 자연스러운 문장 허용

### 실행 위임 정책

- 기본: **자동 진행** (CRITICAL 변경만 사용자 확인)
- `수동으로 진행` → 단계별 확인 / `자동으로 진행` → 기본 복귀

---

## 첫 실행 감지

`.claude/settings.local.json` 미존재 시 `/init` 실행 안내.

## PR 운영 (공통룰 변경 시)

승인 대기 안내만, PR 즉시 생성 가능, 후속 소통은 PR 댓글.
