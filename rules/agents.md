# Agent Orchestration

## Core Principle

- Team-standard execution must be reproducible from this repository alone.
- Required sources: `AGENTS.md`, `agents/rules/`, `agents/skills/`.
- Tool-specific home paths (`${CLAUDE_HOME:-$HOME/.claude}/...`, `${CODEX_HOME:-$HOME/.codex}/...`) are optional accelerators only.

## Intent Triage

모든 변경성 요청은 먼저 `Gate 0 = intent triage`를 거친다.
이 단계의 목적은 동일한 Phase를 강제하는 것이 아니라, 적절한 owner 스킬을 고르는 것이다.

### Gate 0 확인 항목

1. 요청이 읽기 전용인지, write를 수반하는지 판정
2. 대상이 `개발`, `서비스/프로젝트 bootstrap`, `서비스 운영 반영`, `하네스 구조 변경` 중 무엇인지 판정
3. owner skill 1개를 정하고, 나머지는 하위 위임으로만 사용
4. branch가 불명확하면 가장 보수적인 branch로 두고 1회만 확인 질문

### Branch Dispatch

| branch | owner skill | 책임 | 비고 |
|--------|-------------|------|------|
| `dev` | `harness-dev-process` | CPS/PRD/Architecture/Task Packet + 구현/검증/ship | 개발 Phase canonical |
| `service-bootstrap` | `harness-service-bootstrap` | template repo, rename, workspace/docs/AGENTS, charts/values 초기화 | `workspace-*` 위임 + `temp/orchestrator/{service}/state.json` 기록 |
| `service-ops` | `harness-service-ops` | Vault, Observability, Actions, ArgoCD, DB/DDL/DML, 접속 검증 + **운영 장애(incident)** | read-only / write 분리 + bootstrap/deploy-ready validator. 운영 장애(incident)는 service-ops 진입 후 `ops-incident` sub-owner로 식별·처리 (장애 임시 회피 write는 bootstrap/deploy-ready 검증 면제) |
| `harnessing` | `meta-harnessing` | rules/skills/hooks/SoT 구조 검토 | 팀 표준 변경 |

### Triage 예외

- 단순 질문/검색
- 읽기 전용 Jira/Confluence 조회
- 경미한 문서 수정
- 설정 1줄 수정처럼 `core.md` 예외에 해당하는 작업

위 경우는 통합 오케스트레이터 branch를 강제하지 않는다.

## Role-Based Agents

| Role | Purpose | When to Use | Model Tier |
|------|---------|-------------|------------|
| planner | Implementation planning | Complex features, refactoring | opus (advisor) / sonnet (executor) |
| architect | System design | Architectural decisions | opus |
| tdd-guide | Test-driven development | New features, bug fixes | sonnet |
| code-reviewer | Code review | After writing code | sonnet (→ opus advisor on CRITICAL) |
| security-reviewer | Security analysis | Before commits | sonnet (→ opus advisor on ambiguous) |
| build-error-resolver | Fix build errors | When build fails | sonnet |
| e2e-runner | E2E testing | Critical user flows | sonnet |
| refactor-cleaner | Dead code cleanup | Code maintenance | sonnet |
| doc-updater | Documentation | Updating docs | haiku |
| harnessing-advisor | Harness/rules/base structure, `agents/rules-on-demand/` 준수 규칙 신설·수정, `[폐기됨]`·`keyword-detector.sh` 트리거 설계·검토 | Structure refactoring, SoT alignment, context reduction, workflow rule design | sonnet |

If a tool supports sub-agents, map these role names to the tool's equivalent feature.
If not, execute the same workflow directly using `agents/skills/` and `agents/rules/`.

## Advisor Pattern (선택적 에스컬레이션)

> 참조: [Anthropic — The Advisor Strategy](https://claude.com/blog/the-advisor-strategy)

**핵심**: sonnet(executor)이 작업을 끝까지 실행하고, 판단이 어려운 지점에서만 opus(advisor)에게 에스컬레이션한다. advisor는 도구 호출 없이 방향만 제시하고, executor가 실행을 재개한다.

### 에스컬레이션 트리거 (sonnet → opus 어드바이저)

**범위: 팀 전체 영향 변경만** — 개별 코드 수정·단순 판단은 Sonnet 단독 처리.

| 상황 | 에스컬레이션 조건 |
|------|----------------|
| code-review | CRITICAL 보안 이슈 발견, **팀 전체 규칙에 영향이 있을 때**만 에스컬레이션 |
| plan | 복잡도 HIGH — 팀 전체 영향 변경 포함 시 (`agents/rules/`, `AGENTS.md` 수정 포함 등) |
| security-review | 취약점이 맞는지 확신할 수 없을 때 |
| harnessing | `AGENTS.md`, `agents/rules/`, `agents/skills/`, `.claude/hooks/`, `agents/rules-on-demand/` 간 구조 충돌이 보일 때 |
| harnessing | `base/` ↔ 프로젝트 레포 `docs/` 간 SoT 변경 또는 문서 경계 재정의가 필요할 때 |
| harnessing | `workflow-guard`, `keyword-detector`, hook 범위, trigger 매핑처럼 자동 트리거/가드 설계를 바꿀 때 |
| harnessing | 구조 변경안을 적용하기 전 최종 검토가 필요할 때 |

### Advisor max_uses 기본값

| 커맨드 | max_uses | 비고 |
|--------|----------|------|
| code-review | **2** | CRITICAL 이슈 2건 이상이면 전체 리뷰 필요 신호 |
| plan | **2** | 초안 방향(1) + 중간 검증(1) |
| security-review | 2 | plan과 동일 |
| harnessing | 2 | 구조 변경 전 검토(1) + 마이그레이션 순서(1) |

max_uses 초과 시 → 사용자에게 판단 위임 (추가 Advisor 호출 금지).

### 에스컬레이션 로그

Advisor 호출 시 결과를 **작업일지 AI협업 섹션**에 기록:

```
| Claude/Opus-advisor | {커맨드} 에스컬레이션 | [결정 내용 요약] |
```

출처 형식: `Claude/Opus-advisor`

### Multi-Perspective vs Advisor 선택 기준

| 방식 | 언제 사용 | 비용 |
|------|---------|------|
| **Advisor** | 단일 작업 흐름에서 특정 판단만 어려울 때 | 낮음 |
| **Multi-Perspective** | 여러 독립적인 시각이 동시에 필요할 때 | 높음 |

- 기본: **Advisor 패턴** (sonnet executor + opus 선택적 에스컬레이션)
- 대용: Multi-Perspective는 코드 리뷰 / 보안 감사 등 여러 전문 시각이 동시에 필요한 경우만

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests - Use **planner** agent
2. Code just written/modified - Use **code-reviewer** agent
3. Bug fix or new feature - Use **tdd-guide** agent
4. Architectural decision - Use **architect** agent
5. Rules/commands/base structure changes - Use **harnessing-advisor** agent
6. `agents/rules-on-demand/` 준수 규칙 신설·수정, `[폐기됨]`·`keyword-detector.sh` 트리거 설계 - Use **harnessing-advisor** agent

### Orchestrator Ownership

- 상위 `harness-orchestrator`는 `Intent Triage + branch dispatch`만 담당한다.
- hook은 `harness-orchestrator`를 직접 실행하는 대신 branch hint를 노출할 수 있다.
- explicit skill invocation이 없는 환경에서는 그 hint를 라우팅 근거로 보고 owner skill을 바로 적용한다.
- 하위 owner skill이 정해지면 CPS/GATE/승인은 owner skill이 소유한다.
- 상위 라우터와 하위 skill이 동시에 CONFIRM/GATE를 요구하는 이중 승인 구조는 금지한다.

### code-reviewer 도메인 참조 절차 (MANDATORY)

code-reviewer 호출 전 아래를 반드시 수행:

1. 변경 파일의 서비스 판별 → `agents/subagents/{서비스}/` 도메인 에이전트 읽기
2. 관련 피처 문서 검색 → 프로젝트 레포 `docs/features/`
3. 피처 문서에 영향도 분석/테스트 설계가 있으면 → **이미 판정된 항목 재지적 금지**
4. `agents/rules-on-demand/security.md` 보안 체크리스트 적용

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth.ts
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utils.ts

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker

## Subagents (도메인/레이어 전문가)

### 배치 원칙

- **도메인 에이전트 본체** → 프로젝트 저장소 (canonical, self-contained)
- **standards 저장소** → 공통 자산(rules/commands/레이어 에이전트) + 서비스별 라우터(README.md)
- **링크 방향** → 프로젝트 → 중앙 (forward link), 역방향 금지
- 서비스별 도메인 에이전트는 `workspace/<YOUR_SERVICE>/agents/`에 배치한다.
  도메인별 **코드 편집 준수 규칙**은 별도 자산으로 `agents/rules-on-demand/<YOUR_SERVICE>/`에 둘 수 있다.

> 서비스별 라우터: `agents/subagents/{서비스}/README.md`

### 구조
- **레이어 에이전트** (크로스 프로젝트): `frontend-dev`, `backend-dev`, `dba`, `code-reviewer`, `harnessing`
- **도메인 에이전트** (서비스별, 사용자 팀 환경에 맞게 정의)

### 호출 원칙
1. **도메인 코드 변경** → 해당 도메인 에이전트 참조 (담당 파일, 테이블, API 확인)
2. **레이어 전문성 필요** → 레이어 에이전트 컨설팅 (DB 쿼리 → dba, UI 패턴 → frontend-dev)
3. **구조/SoT/하네스 변경** → `agents/subagents/harnessing.md` 우선 참조
4. **요구사항 축적** → 도메인 에이전트의 `## 요구사항 이력` 섹션에 확인된 스펙 기록
5. **교차참조 확인** → 각 에이전트 상단 교차참조 테이블로 연관 도메인 파악
6. **새 프로젝트** → 프로젝트 저장소에 도메인 에이전트 생성, `agents/subagents/{서비스}/README.md` 라우터에 링크 추가

### 사용 예시
```
# <YOUR_SERVICE> 이벤트 화면 수정 시
1. agents/rules-on-demand/<YOUR_SERVICE>/event.md 읽기 (담당 파일, 테이블, 준수 규칙 확인)
2. 인시던트 생성 연관 시 → agents/rules-on-demand/<YOUR_SERVICE>/incident.md 교차 확인
3. 필요시 agents/subagents/frontend-dev.md 참조 (UI 패턴)
4. 필요시 agents/subagents/dba.md 참조 (쿼리 최적화)
5. 도메인 에이전트 본체 생성 후에는 해당 에이전트의 요구사항 이력에 확인된 스펙 기록
```
