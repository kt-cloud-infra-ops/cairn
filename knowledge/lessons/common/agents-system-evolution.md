---
tags:
  - type/reference
  - audience/claude
  - domain/harness
aliases: []
---

> 상위: [common](README.md) · [lessons](../README.md)

# 에이전트 시스템 진화 — 변경 이력 · 고민 · 레슨런

`ai-team-standards` 저장소에서 에이전트/스킬/룰 구조를 다도구(Claude Code, Codex 등) 공유 자산으로 정착시키기까지의 변경 흐름과 고민. 신규 합류자, 향후 구조 재논의 시 참고용.

---

## 1. 출발점과 문제 인식

| 항목 | 초기 상태 | 문제 |
|------|----------|------|
| 진입점 | 도구별로 흩어진 `CLAUDE.md`, `.codex/`, `commands/`, `automations/` | 도구별 규칙 분기, 동일 작업도 결과 불일치 |
| 명령 체계 | `commands/` (Claude 전용) + `skills/` (Anthropic 표준) 혼재 | 동일 명령이 두 위치에 존재 → 표류(drift) 발생 |
| 도메인 지식 | `agents/` 한 폴더에 레이어/도메인/라우터 혼재 | "어디를 봐야 하나" 라우팅 비용 증가 |
| 외부 자산 | `superpowers`, `oh-my-agent`, `dk-*` 같은 외부 스킬을 임시 복사 | upstream 변경 추적 불가, 원본 출처 소실 |

**핵심 문제**: Claude/Codex가 같은 룰을 다르게 해석 → 같은 작업도 산출물이 달라짐. "도구 무관, 규칙 단일 소스"가 모든 변경의 공통 동기.

---

## 2. 변경 타임라인 (2026-04 ~ 2026-05)

| 시점 | 변경 | 동기 |
|------|------|------|
| 04-13 | `agents/` → `subagents/` 이름 변경 | "agent" 단어가 도메인/레이어/라우터/스킬에 모두 쓰여 의미 분화 |
| 04-13~14 | Phase 0~8 (commands → skills 통합, ADR-006) | 명령 체계 단일화, Claude/Codex 공유 |
| 04-15 | 스킬 양식 표준화 (27개 SKILL.md 일괄 적용) | 양식 표류 방지, 가드 자동화 기반 |
| 04-16 | <YOUR_SERVICE> 도메인 에이전트 프로젝트 레포 이관 (8개) | 프로젝트별 자기완결 원칙 |
| 04-21~24 | Superpowers vendor 4개 도입 + 우리 스킬 4개 생성 | 외부 자산 명시적 채택, 출처(origin) 표기 |
| 04-23~28 | Runtime 배포 순서 규칙 / Obsidian 링크 감사 / PR 묶음 원칙 | 운영 사고 방지(공통룰 즉시 머지·배포 우회) |
| 04-29~30 | ADR-006 마이그레이션 완료, vendor 판정 갱신 | 통합 종결 |
| 05-06 | AGENTS.md frontmatter 표준 도입 (Phase 1) | 서비스 매핑 자동화 기반 |
| 05-07 | 스킬 GATE 패턴 표준화 | Codex/Claude 결과 불일치 해소 |

---

## 3. 핵심 결정과 그때의 고민

### 3.1 agents → subagents 이름 변경 (04-13, 771a0bf)

**고민**: `agents/` 단일 폴더에 (a) 도메인 라우터 (b) 레이어 전문가 (c) 도메인 본체 (d) 스킬 진입점이 섞여 있어 라우팅 비용이 큼.

**결정**: 폴더를 역할별로 분리.
- `agents/subagents/` — 라우터 + 레이어/도메인 에이전트
- `agents/skills/` — 실행 단위
- `agents/rules/` — 자동 로드 룰
- `agents/knowledge/` — 학습 lessons

**레슨런**: 이름 한 글자가 라우팅 명료성을 결정. `agents/agents/`처럼 같은 이름 중첩은 향후 절대 피한다.

---

### 3.2 commands → skills 통합 (ADR-006, 04-13~14, Phase 0~8)

**고민**: Claude `commands/`는 markdown 진입점, Anthropic 표준은 `skills/SKILL.md`. 두 체계를 유지하면 매번 동기화 비용 + 표류.

**판정 기준 (vendor)**: 대체(REPLACE) / 보강(SUPPLEMENT) / 중복(REDUNDANT) / 독립(INDEPENDENT).

**Phase 분할**:
| Phase | 작업 |
|-------|------|
| 0 | herness_cutting → harness-* 스킬로 이관, TASKS.md 매핑 |
| 1+2 | automations 해체, tools 이동, tdd-wrapper 삭제 |
| 3 | commands → skills 26개 생성 |
| 5+7 | commands 포인터 전환 + workflows 이관 |
| 6+7+8 | commands/ 삭제, workflow-guard 폐기, 정합성 검증 |

**레슨런**:
- 대규모 구조 변경은 Phase로 쪼개고 각 Phase에 GATE를 둬야 중간 검증 가능. 한 번에 다 바꾸면 롤백 단위가 너무 큼.
- `[폐기됨]` 마커 + `keyword-detector.sh` 트리거를 넣어 재발견 시 자동 안내.

---

### 3.3 도메인 에이전트 위치 — 프로젝트 레포 vs 중앙 (04-16, e4a8c2f)

**고민**: <YOUR_SERVICE> 도메인 에이전트 8종(evt/icd/ctl/dash/stt/mng/zab/common)을 어디에 둘 것인가.
- 중앙(`ai-team-standards`)에 두면 한곳에서 보기 쉬우나, 프로젝트별 격리 안 됨
- 프로젝트 레포에 두면 자기완결이지만, 중앙 라우터에서 정방향 링크만 유지 필요

**결정**: 본체는 프로젝트 레포, 중앙엔 라우터(`agents/subagents/{서비스}/README.md`)만. 단 <YOUR_SERVICE>는 **임시로 중앙에 보관** 중(이전 예정).

**레슨런**:
- "임시 위치"가 6개월 이상 살아남을 가능성 → 임시라고 적어두면 후임자가 신뢰함. **이전 기한(deadline) 명시**가 필요.
- 정방향 링크만 허용(프로젝트 → 중앙). 역방향은 중앙이 프로젝트 디테일을 알게 되어 결합도 증가.

---

### 3.4 Vendor 도입 — Superpowers / oh-my-agent / dk-* (04-21~24)

**고민**: 외부 좋은 스킬을 어떻게 받아들일 것인가.
- 그대로 복사 → upstream 표류, 원본 출처 사라짐
- 무시 → 바퀴 재발명

**결정**: `agents/skills/vendor/{repo}--{skill}/` 디렉토리 + `manifest.json`으로 활성화 여부/판정 관리. 우리 스킬에는 description에 `(origin: superpowers/xxx)` 명시.

**판정 4종**:
| 판정 | 의미 |
|------|------|
| 대체 (REPLACE) | 우리 스킬을 vendor로 대체 |
| 보강 (SUPPLEMENT) | vendor를 흡수해 우리 스킬 보강 |
| 중복 (REDUNDANT) | 이미 우리 자산으로 커버됨 |
| 독립 (INDEPENDENT) | vendor 그대로 사용 |

**레슨런**:
- vendor 채택은 "복사+잊기"가 아니라 **정기 점검 워크플로우**(`/harnessing vendor`)가 필요. 안 하면 6개월 후 upstream 변경 누락.
- 흡수 시 출처 표기 의무 — 추적 가능성이 가치의 절반.

---

### 3.5 스킬 양식 표준화 + GATE 패턴 (04-15, 05-07)

**고민 1 (양식)**: SKILL.md frontmatter, 규칙 섹션, 절차, 완료 조건이 스킬마다 달라 신규 합류 AI/사람이 매번 적응.

**결정**: 27개 스킬에 동일 양식(`agents/templates/skill-template.md`) 일괄 적용. `## 스킬 규칙` ALWAYS/NEVER, `## 실행 절차`, `## 완료 조건 (DONE WHEN)` 필수. 가드 hook으로 신규 스킬 생성 차단.

**고민 2 (결과 일치성)**: 동일 스킬을 Claude vs Codex가 실행할 때 결과가 다름.

**결정 (05-07, d863e38)**: GATE 패턴 도입.
- Phase 1 (HIGH 3개): 외부 변경 직전 GATE 강제 — `cicd-deploy`, `<your_service>-release-e2e-sync`, `<your_service>-datachange-request-automation`
- Phase 2 (MEDIUM 2개): 사용자 승인 GATE — `harness-plan`, `dev-subagent-driven`
- Phase 3: 템플릿/거버넌스에 GATE 필수 영역 룰 추가

**GATE 필수 영역**:
- 의무: 외부 시스템 변경 / 공유 산출물 / 운영 분류 / 사용자 승인 직전
- 비필수: 도구성 / 읽기 전용 / 개인 루틴

**레슨런**:
- "양식만 통일"로는 결과 일치 안 됨. **데이터 소스 우선순위표 + 외부 컨텍스트 처리 규칙**까지 명시해야 도구 무관 동일 결과.
- GATE 최대 3개 권장 — 너무 많으면 사용자 피로, 너무 적으면 우회 가능.

---

### 3.6 rules vs rules-on-demand 분리

**고민**: 자동 로드되는 `rules/`가 너무 커지면 매 세션 컨텍스트 비용 증가. 그러나 자주 안 쓰는 룰도 가끔 필요.

**결정**:
- `agents/rules/` — 매 세션 자동 로드 (core, security, git-workflow, testing, doc-organization 등 13개)
- `agents/rules-on-demand/` — 키워드 트리거 시 로드 (apidog, project-docs, performance, <your_service>/* 등)

**레슨런**:
- 항상 필요한 룰과 가끔 필요한 룰의 분리는 **컨텍스트 토큰 사용량을 직접 줄이는 가장 효과적인 수단**.
- 트리거 키워드 매핑(`keyword-detector.sh`)을 함께 두지 않으면 on-demand 룰은 사실상 죽은 문서.

---

### 3.7 PR 묶음 원칙 + Runtime 배포 순서 (04-23, 04-28)

**고민**: 공통룰 변경 PR이 건건이 올라와 리뷰 부담. 또한 일부 코드 변경이 `feature/* → main` 직접 머지로 운영 단계 우회.

**결정**:
- 공통룰 PR은 같은 주제 묶어 1회 PR. 서브에이전트가 임의로 PR 생성 금지.
- Runtime 변경은 `feature/* → develop → stage → production → main` 순서 필수. AI가 임의 단계 생략 금지.

**레슨런**:
- "AI는 빠르니 PR 자주 올려도 됨"은 잘못된 직관. **사람이 리뷰 부담을 결정**한다.
- 배포 순서는 룰 문서만으로는 부족 — PR 리뷰에서 강제하고, 향후 가드 훅(`guard-branch-sequence.sh`) 도입 검토.

---

## 4. 정착된 운영 원칙

| 영역 | 원칙 |
|------|------|
| 진입점 | `AGENTS.md` (정본) ← `CLAUDE.md`/`CODEX.md` 포인터 |
| 룰 | `agents/rules/` 자동 로드 + `agents/rules-on-demand/` 트리거 로드 |
| 스킬 | `agents/skills/{prefix}-{name}/SKILL.md` 단일 양식 |
| 외부 자산 | `agents/skills/vendor/` + manifest 판정 |
| 도메인 에이전트 | 프로젝트 레포 본체 + 중앙 라우터 정방향 링크 |
| 변경 PR | 같은 주제 묶음, runtime/non-runtime 브랜치 분리 |
| GATE | 외부 변경/공유 산출물 직전 사용자 명시 승인 |
| 출처 표기 | vendor 흡수 스킬은 origin 명시 |

---

## 5. 미해결 긴장 / 후속 과제

| 항목 | 현재 상태 | 다음 단계 |
|------|----------|----------|
| 도메인 에이전트 이전 | 중앙 임시 보관 | 프로젝트 레포로 이관 (기한 미정) |
| `guard-branch-sequence.sh` | 미도입, 룰 문서로만 강제 | 자동 가드 훅 설계 |
| vendor 정기 점검 | 수동 | `/harnessing vendor` 정기 실행 자동화 |
| GATE 패턴 적용률 | Phase 1~3 5개 스킬 + 템플릿 | 신규 스킬 자동 검증 hook 도입 검토 |
| `keyword-detector.sh` 커버리지 | rules-on-demand 일부만 매핑 | 누락 룰 매핑 추가 |
| AGENTS.md frontmatter | Phase 1 도입 | 전체 프로젝트 확산 |
| Codex ↔ Claude 결과 일치 검증 | 수동 비교 | 동일 스킬 회귀 테스트 자동화 |

---

## 6. 메타 레슨

1. **"단일 소스"는 룰만 통일해서는 안 된다.** 양식, 데이터 소스 우선순위, 외부 컨텍스트 처리, GATE까지 모두 표준화되어야 도구 무관 동일 결과.
2. **임시 위치는 영구가 된다.** "임시"라고 쓸 때는 기한 + 소유자를 함께 적는다.
3. **외부 자산은 출처 표기가 가치의 절반이다.** 복사한 순간 origin이 사라지면 향후 검증/업데이트 불가.
4. **PR 묶음 원칙은 AI 시대에 더 중요하다.** 빠른 변경이 곧 좋은 변경은 아님. 사람의 리뷰 처리 한도가 병목.
5. **Phase 분할 + GATE는 대형 구조 변경의 표준 패턴.** 한 번에 바꾸면 롤백 비용이 폭발.
6. **이름 정리는 비용이 아니라 투자다.** `agents/agents/` 같은 중첩, `commands/skills/` 같은 중복은 라우팅 비용을 영속적으로 발생시킨다.

---

## 관련 문서

- [ADR-006 — 스킬 통합](../../../../base/guides/decisions/006-skill-unification.md) — commands→skills 통합 결정
- [ADR-005 — 프로젝트 문서 표준](../../../../base/guides/decisions/005-project-docs-standard.md) — 프로젝트 레포 docs/ 표준
- [ADR-004 — 룰 통합](../../../../base/guides/decisions/004-rules-consolidation.md) — rules 통합
- [agents/rules/agents.md](../../../rules/agents.md) — 에이전트 오케스트레이션 룰
- [agents/rules/skill-governance.md](../../../rules/skill-governance.md) — 스킬 거버넌스
- [agents/subagents/harnessing.md](../../../subagents/harnessing.md) — 하네스 어드바이저
- [documentation-architecture.md](documentation-architecture.md) — 문서 아키텍처
- [rule-design-principles.md](rule-design-principles.md) — 룰 설계 원칙
- [rule-system-architecture.md](rule-system-architecture.md) — 룰 시스템 구조
