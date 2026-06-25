---
name: harness-brainstorm
description: "아이디어를 설계로 전환 + 요구사항 명확화. 질문(한 번에 1개) → 2-3개 접근안 → CPS Charter 기반 설계 → 사용자 승인 → Phase 0 bootstrap. 승인 전 구현 금지(HARD-GATE). (origin: superpowers/brainstorming + harness-clarify 흡수)"
---

## 스킬 규칙
### ALWAYS
- **HARD-GATE**: 사용자가 설계를 **명시적으로 승인**하기 전에는 코드 작성·스캐폴딩·구현 스킬 호출 금지
- 질문은 **한 번에 1개** (다중 질문 금지, 단 객관식 선택지는 허용)
- 접근안은 **2-3개** 제시 + 각 trade-off + 추천안 1개
- 설계 문서에 **CPS Charter 9항목** 포함: Goal / Context / Constraints / Done When / In Scope / Out of Scope / Acceptance Criteria / 가정 / 리스크
- 승인 후 Step 9에서 `init-harness-run.sh` 실행으로 `.harness/state.json` + CPS 템플릿 자동 생성
- 그 다음 `harness-plan` 호출 (PRD/Architecture/Task Packet)
- 설계 문서 저장 위치 (택1):
  - `projects/{프로젝트}/docs/features/{TICKET}-{descriptive-name}.md` (Jira 티켓 있고 코드 변경 동반)
  - cairn `temp/brainstorm-{topic}.md` (티켓 없거나 검토만)

### NEVER
- 설계 승인 없이 `dev-tdd`/`harness-plan`/구현 스킬 호출 금지
- "단순한 것 같으니 설계 생략" 금지 — 모든 작업은 최소 1문단 설계 필요
- 스코프 분해 없이 거대 프로젝트 통째 브레인스토밍 금지 (독립 subsystem이면 먼저 분해)
- `temp/brainstorm-...md` 저장 후 git 커밋 금지 (`temp/`는 .gitignore)
- 피처 파일명에 `{topic}` 사용 금지 — 반드시 `{descriptive-name}` (kebab-case)

## 실행 절차

1. **프로젝트 컨텍스트 탐색**
   - 관련 파일, 최근 커밋, 도메인 에이전트 문서 확인
   - 이미 알려진 제약/선호 파악
   - 관련 Jira 티켓 / 에픽 식별
2. **스코프 점검**
   - 거대 프로젝트(다중 독립 subsystem)인가? → 먼저 분해 제안 후 첫 sub-project부터 브레인스토밍
3. **질문 (한 번에 1개)**
   - 목적, 제약, 성공 기준, 사용자/유스케이스
   - 객관식 우선 (필요 시 선택지에 추천안 표시)
4. **접근안 2-3개 제시**
   - 각 옵션: 핵심 아이디어 + 트레이드오프(속도/품질/리스크/유지보수)
   - 추천안 1개 표시
5. **설계 제시 (섹션별, CPS Charter 9항목 포함)**
   - 각 섹션 제시 후 사용자 승인 받은 후 다음 섹션
   - 필수 9항목:
     - **Goal** (목적)
     - **Context** (배경)
     - **Constraints** (제약)
     - **Done When** (완료 기준)
     - **In Scope**
     - **Out of Scope**
     - **Acceptance Criteria**
     - **가정**
     - **리스크**
   - 추가: 접근안 비교(추천 포함) / 최종 설계 / 미확정 항목(TBD)
6. **설계 문서 저장**
   - 위치 분기:
     - **Jira 티켓 + 코드 변경 동반** → `projects/{프로젝트}/docs/features/{TICKET}-{descriptive-name}.md`
     - **티켓 없음 / 검토만** → `temp/brainstorm-{descriptive-name}.md` (커밋 X)
   - 코드 브랜치 동반 규칙: features/ 문서는 해당 코드 feature 브랜치에 동반 커밋 (참조: `rules/git-workflow.md`)
   - 섹션 구성: Step 5 9항목 + 접근안 비교 + 최종 설계 + 미확정
7. **스펙 셀프 리뷰**
   - placeholder(`[TBD]`, `...`) · 모순 · 모호성 · 스코프 과다 체크 → 인라인 수정
   - 9항목 누락 검증 (Goal/Context/Constraints/Done When/In Scope/Out of Scope/A.C./가정/리스크)
8. **사용자 최종 리뷰**
   - 문서 링크로 재확인 요청
   - 명시적 승인 의사 받을 때까지 다음 단계 진행 금지
9. **Transition (Phase 0 bootstrap → Phase 1)**
   - 9-1. 사용자 명시적 승인 확인
   - 9-2. `bash skills/harness-dev-process/scripts/init-harness-run.sh {ticket-or-topic}` 실행 → `.harness/state.json` (phase=INIT) + CPS 템플릿 생성
   - 9-3. CPS Charter 4요소(Goal/Context/Constraints/Done When)는 Step 5 결과를 그대로 입력
   - 9-4. `harness-plan` 호출 (Phase 1 PLAN — PRD/Architecture/Task Packet)

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 접근안 2-3개 + 추천안 제시됨
- [ ] [MANUAL] CPS Charter 9항목 모두 설계 문서에 포함
- [ ] [MANUAL] 사용자 설계 승인 (명시적 "승인" 의사 표현)
- [ ] [FILE] 설계 문서 저장됨 (`projects/{프로젝트}/docs/features/` 또는 `temp/`)
- [ ] [MANUAL] placeholder 0건
- [ ] [FILE] `.harness/state.json` 생성됨 (init-harness-run.sh 실행 결과)
- [ ] [MANUAL] `harness-plan`으로 전환

## 스킬 간 관계

```
[아이디어 또는 모호한 요구사항]
    ↓
harness-brainstorm (이 스킬 — 질문 + 접근안 + 설계 + 승인 + Phase 0 bootstrap)
    ↓ Step 9 init-harness-run.sh
.harness/state.json (phase=INIT) + CPS 템플릿
    ↓
harness-plan (Phase 1 — PRD/Architecture/Task Packet)
    ↓
harness-dev-process (Phase 2 IMPL — Phase Gate 운영)
    ↓
dev-tdd / dev-subagent-driven (구현)
```

**언제 어떤 스킬?**

| 상황 | 스킬 |
|------|------|
| "아이디어/요구사항을 설계로 정리하고 싶어" (요구사항 명확화 포함) | **이 스킬** (`harness-brainstorm`) |
| "설계가 확정됐으니 PRD 쓰고 태스크 쪼개자" | `harness-plan` |
| "전체 하네스 Phase Gate 돌리자" | `harness-dev-process` |
| "구현 단계 진입" | `dev-tdd` |

> **변경 이력 (2026-04-27)**: `harness-clarify` 폐기 → 본 스킬에 흡수. 요구사항 명확화도 본 스킬 Step 3~5에서 처리. 흡수 원칙은 `rules/skill-governance.md`, 조직 도입 근거·번호는 워크스페이스 `decisions/`(존재 시) 참조.

## Push back 기준 (설계 단계에서)

- **스코프 폭발**: 사용자가 거대 프로젝트를 통째 요청 → 분해 제안
- **재발명 감지**: 기존 스킬/규칙/서비스로 해결 가능 → 재사용 제안
- **HARD-GATE 우회 시도**: "그냥 바로 코드부터" → 1문단 설계 먼저 요청 (거부 금지, 설득)
- **9항목 누락 시도**: "Out of Scope 굳이 필요해?" → 누락 시 PRD/구현 단계에서 스코프 분쟁 발생, 모두 작성 요구

## Origin (Vendor 흡수)

| 항목 | 값 |
|------|----|
| 원본 | [obra/superpowers — brainstorming](https://github.com/obra/superpowers) |
| vendor 사본 | [superpowers--brainstorming](../vendor/superpowers--brainstorming/SKILL.md) |
| 흡수 결정 | 스킬 통합(commands→skills) 원칙 — `rules/skill-governance.md`. 조직 도입 근거·번호는 워크스페이스 `decisions/`(존재 시) 참조 |
| 판정 | SUPPLEMENT (HARD-GATE 설계 승인 프로토콜 + CPS Charter 9항목 + Phase 0 bootstrap) |
| 후속 흡수 | `harness-clarify` 폐기 흡수 (2026-04-27, B안) — Charter 항목 + Phase 0 자동 생성 |

## 참조

- 위치: `harness-orchestrator`의 `dev` branch owner 산하 설계 단계 — 변경성 요청이 dev branch로 분기된 뒤 설계 단계에서 호출된다. orchestrator 의무 원칙: `docs/HARNESS_DESIGN_RATIONALE.md` (조직 도입 근거는 워크스페이스 `decisions/`(존재 시) 참조)
- 연관: `harness-plan` (PRD), `harness-dev-process` (전체 Phase Gate)
- 룰: `rules/git-workflow.md` (features 브랜치 동반 규칙), `rules-on-demand/project-docs.md` (features 네이밍)
- 근거: 스킬 통합 원칙 — `rules/skill-governance.md` (조직 도입 근거·번호는 워크스페이스 `decisions/`(존재 시) 참조)
