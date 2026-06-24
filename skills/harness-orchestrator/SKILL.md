---
name: harness-orchestrator
description: "변경성 요청을 `dev / service-bootstrap / service-ops / harnessing` branch로 분기하는 상위 라우터. GATE 0 intent triage만 담당하고 실제 실행은 하위 owner 스킬에 위임한다. 운영 장애(incident)는 service-ops 분기 후 `ops-incident` sub-owner로 식별·처리한다."
---

## 스킬 규칙
### ALWAYS
- `GATE 0 = intent triage`를 먼저 수행
- branch owner는 정확히 1개만 선택
- write를 수반하지 않는 질문/조회/경미한 문서 수정은 branch 강제 없이 direct handling 허용
- 하위 owner 스킬의 canonical phase/gate를 존중
### NEVER
- CPS/PRD/Architecture/Task Packet을 직접 소유 금지
- 개발 Phase(`INIT → PLAN → IMPL → VERIFY → SHIP`)를 재정의 금지
- 상위 라우터와 하위 owner 스킬의 이중 CONFIRM/GATE 생성 금지
- **사용자 명시 발화 없는 외부 시스템 상태 추정 금지** — 서비스 운영 여부, Jira 상태, 큐 길이, 옆 세션 완성도, owner/소유자 등은 도구 호출(`jira-rest-ops`, `cmux read-screen`, `git log`, `Read`, `Grep`, `Bash`)로 확인 후 진술. 확인 안 됐으면 `[미확인]`/`[TBD]` 마킹 또는 사용자 질문으로 전환

## 운영 장애 식별 (service-ops 분기 후)

모든 변경 요청은 예외·우회 없이 GATE 0 intent triage를 경유한 뒤 트리거 매칭으로 분기한다(별도 선평가 없음). 아래 장애 시그널이 1개라도 감지되면 `service-ops` branch로 분기한 뒤 `harness-service-ops` 진입 직후 `ops-incident` sub-owner를 적용한다.

| 시그널 유형 | 패턴 예시 |
|-----------|---------|
| 인시던트 ID | `INC-`, `관리장애`, `N등급`, `이상징후` |
| 외부 신고 | "운영 신고", "장애 신고", "팀장님", "운영팀" |
| 장애 상태 | "장애", "사고", "incident", "서비스 중단", "알람 미적재", "이벤트 미적재", "적재 정지" |
| 회피/분석 의도 | "임시 회피", "원인 분석", "재현", "brute force 재현", "장애 분석" |
| 운영 흔적 | "ERROR 로그", "unterminated CSV", "배치 실패" |

위 시그널 감지 시: `service-ops`로 분기 → `harness-service-ops` PRECHECK에서 비계획 장애로 식별 → `ops-incident` sub-owner 적용. 장애 임시 회피 write는 bootstrap/deploy-ready 검증 면제.

예외:
- 순수 코드 개선 목적("INC-N 후속 hotfix 구현 시작") — `ops-incident` Phase 4 완료 후 `dev` branch로 명시적 handoff
- 단순 정보 조회 ("INC-N 상태 알려줘") — read-only, branch 강제 없이 direct handling 가능

# Harness Orchestrator

변경성 요청의 진입점을 표준화하는 상위 라우터.
이 스킬은 실행 엔진이 아니라 branch dispatch 계층이다.

## 실행 모델

- hook/trigger가 branch hint를 먼저 제시할 수 있다.
- explicit skill invocation이 없는 환경에서는 이 문서를 라우팅 정책으로 사용하고, 에이전트가 owner skill을 바로 적용한다.
- 즉, `harness-orchestrator`의 실질 동작은 `intent triage 결과를 owner skill 선택으로 연결하는 것`이다.
- 별도의 상위 phase는 만들지 않되, Gate 0 통과 마커로 `.harness/triage.json`을 기록한다.
- 다만 서비스 bootstrap/ops 선행조건은 `temp/orchestrator/{service}/state.json` 로컬 상태 파일로 검증한다.

## branch map

| branch | owner skill | 책임 |
|--------|-------------|------|
| `dev` | `harness-dev-process` | 개발 설계/구현/검증/ship |
| `service-bootstrap` | `harness-service-bootstrap` | 새 서비스/프로젝트 bootstrap |
| `service-ops` | `harness-service-ops` | 서비스 운영 반영/활성화 + 운영 장애(`ops-incident` sub-owner) |
| `harnessing` | `meta-harnessing` | rules/skills/hooks 구조 변경 |

## 워크스페이스 스킬 디스패치 (조직 특화 스킬 — CRITICAL)

코어 owner skill은 **기본틀**(dev/service-ops 등 범용 절차)이다. 각 조직·팀·개인이 자유 생성하는 **operation 스킬**(CRM 처리·데이터 보정·인벤토리 변경 등 서비스 특화)은 워크스페이스 레지스트리로 디스패치한다. 이건 hint가 아니라 **보장된 흐름**이다.

### 디스패치 절차 (Gate 0 분류 직후, owner skill보다 우선 확인)

1. 워크스페이스 `.cairn/skills.yaml`(레지스트리, `schemas/skills.schema.json` 준수) 존재 시 로드
2. 정해진 **branch + 요청 트리거**가 매칭되는 조직 스킬을 검색
3. **매칭 → 그 `path`의 SKILL.md를 Read하고 절차를 수행** (도구 중립 — claude의 `/cairn:`이든 codex의 직접 Read든 동일하게 동작)
4. 매칭 없음 → 코어 owner skill(`harness-service-ops` 등) 적용

### 원칙

- 조직 스킬은 `domains/{svc}/skills/` 또는 `operations/skills/`에 두고 `.cairn/skills.yaml`에 **등록**한다.
- **등록이 곧 디스패치 계약** — 미등록 스킬은 디스패치되지 않고 단순 참조 문서일 뿐이다.
- 각 팀·개인은 SKILL.md 작성 + 레지스트리 엔트리 1줄 추가로 자유 확장한다. 코어(엔진)는 건드리지 않는다.
- 예: "CRM 데이터 보정 요청" → Gate 0 → `service-ops` 분기 → `.cairn/skills.yaml`에서 `triggers:[CRM, 데이터보정]` 매칭 → `luppiter-datachange` SKILL.md 수행.

`triggers`는 요청 키워드를 보고 조직 스킬을 제안·디스패치하는 **soft 계약**이고, `enforce`는 실제 Bash write 패턴을 보고 marker 없으면 차단하는 **hard 계약**이다. 위험 운영작업(DB DML, 대량 삭제, 운영 API write 등)은 `.cairn/skills.yaml`에 `enforce.write_patterns`와 `requires_gate`를 등록하고, 해당 스킬의 필수 GATE 통과 시 `.harness/skill-{name}.json` marker를 생성한다.

> 코어/조직 경계: **엔진(plugin)이 제공하면 core, 워크스페이스 레지스트리에 등록되면 org**. core는 불변 기본틀, org는 자유 확장.

## 실행 절차

1. `intent triage`
   - read-only vs write 판정
   - 대상이 코드/프로젝트/bootstrap/운영/하네스 중 무엇인지 판정 (예외·우회 없이 GATE 0 경유 후 트리거 매칭)
   - Gate 0 분류 결과를 `.harness/triage.json`에 기록한다.
   - 장애 시그널 매칭 시 `service-ops`로 분기 (위 "운영 장애 식별" 표 참조)
   - 불명확하면 1회만 확인 질문
2. branch owner 선택
   - `dev` → `harness-brainstorm`, `harness-plan`, `harness-dev-process`, `dev-*`
   - `service-bootstrap` → `harness-service-bootstrap`, `workspace-*`
   - `service-ops` → `harness-service-ops`, `jira-*`, `cicd-*`, `<your_service>-*`, 운영 장애 시 `ops-incident` sub-owner
   - `harnessing` → `meta-harnessing`
3. owner 위임
   - owner skill이 phase/gate를 소유
   - 상위 라우터는 상태를 유지하지 않음

## cross-branch dependency

- `service-ops` intent라도 bootstrap evidence가 없으면 owner는 `harness-service-bootstrap`로 되돌린다.
- `cicd-*`는 `service-ops` helper다. 초기 서비스 생성 전용 진입점이 아니다.
- 따라서 "배포부터", "CI/CD부터" 같은 요청은 먼저 bootstrap prerequisite를 확인한 뒤 branch를 유지하거나 재분기한다.
- `guard-service-orchestration.sh` 는 서비스명이 잡히는 CI/CD write 시 `deploy-ready` validator를 통과하지 못하면 Bash 실행을 차단한다.

## commit 전 review 의무 (모든 branch 공통)

모든 branch는 owner skill의 ship/commit 단계 직전에 **`dev-code-review` 의무 호출**을 거친다.

- `dev` branch → `harness-dev-process` Phase 4 SHIP 직전
- `service-bootstrap` branch → bootstrap 결과 commit 직전
- `service-ops` branch → state.json/config 변경 commit 직전
- `harnessing` branch → rules/skills/hooks 변경 commit 직전

검증:
- `.harness/review-evidence.json` 생성 (5분 이내 + checks pass)
- `.claude/hooks/guard-git-commit.sh`가 commit 직전 자동 검증
- evidence 없으면 commit 차단 (exit 2)

근거: ADR-008 + `agents/skills/dev-code-review/SKILL.md`

## Capture Loop (cross-cutting, 모든 branch 공통)

owner skill이 작업을 완료한 뒤, 의미 있는 변경/결정/절차가 남았으면 `cairn-capture`를 **제안**한다 (강제 아님 — Cairn의 정체성: "내 업무를 AI에게 학습시켜 팀에 공용화").

- 트리거: 각 branch owner skill 완료 시 + Stop hook(`hooks/cairn-capture-suggest.sh`)
- 캡처 유형: `lesson`(재사용 패턴) / `decision`(ADR) / `sop`(절차) / `feature`(설계)
- `.cairn/config.json`의 `capture.proactive`/`capture.frequency` 존중 (`off`면 제안 안 함, 노이즈 방지)
- solo 모드: 로컬 저장까지. team 모드: 캡처 후 git 커밋/푸시 제안([GATE-SHARE] 사용자 승인 필수)
- branch별 자연 캡처 지점:
  - `dev` → Phase 4 SHIP 후 lesson/decision
  - `service-ops` → 운영 반영/장애 처리 후 sop/decision
  - `harnessing` → 구조 변경 후 decision(ADR)

## 상태 파일

- 위치: `temp/orchestrator/{service}/state.json`
- 목적: `service-bootstrap` 완료 증적과 `service-ops PRECHECK` 완료 여부를 로컬에서 기계적으로 검증
- 생성/검증:

```bash
node agents/skills/harness-orchestrator/scripts/service-orchestration.mjs init {service}
node agents/skills/harness-orchestrator/scripts/service-orchestration.mjs validate {service} --require bootstrap
node agents/skills/harness-orchestrator/scripts/service-orchestration.mjs validate {service} --require deploy-ready
```

## 분기 기준

| 요청 유형 | branch |
|----------|--------|
| 기능 구현, 버그 수정, 리팩터링, 테스트 추가 | `dev` |
| 새 서비스/프로젝트 생성, template repo, workspace/docs/AGENTS/charts 초기화 | `service-bootstrap` |
| Vault, Observability, ArgoCD, DB, DDL/DML, 운영 반영 | `service-ops` |
| **운영 장애 인지/회피/원인 분석/보고서/후속 운영개선** | **`service-ops`** → `ops-incident` sub-owner |
| rules/skills/hooks/trigger/SoT 변경 | `harnessing` |

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] read-only vs write 판정 완료
- [ ] [MANUAL] branch owner 1개 선택 완료
- [ ] [MANUAL] 하위 owner 스킬로 위임 경로 제시 완료
