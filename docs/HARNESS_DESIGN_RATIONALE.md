# 하네스 설계 근거 — 왜 cairn 하네스는 이렇게 동작하는가

cairn 엔진의 하네스(harness)는 "어떤 에이전트가 와도 동일한 결과"를 보장하기 위한 강제 골격이다. 이 문서는 그 **메커니즘 원리만** 담는다. cairn을 설치한 어느 조직이든 이 문서만으로 "왜 변경 요청이 이 흐름을 강제로 타는가"를 즉시 이해할 수 있다.

> 범위: 이 문서는 **엔진(core) 범용 원리**의 SoT다. 특정 조직의 도입 시점·사례·번호가 매겨진 의사결정(ADR) 본문은 여기 두지 않는다. **조직별 도입 근거·사례는 각 워크스페이스 `decisions/`(존재 시)를 참조**한다. (core vs org 경계는 `docs/CORE_VS_ORG_BOUNDARY.md`, 3계층 구조는 `docs/WORKSPACE_MODEL.md`.)

---

## 1. 모든 변경 요청은 orchestrator GATE 0 intent triage를 의무 경유한다

코드·서비스·하네스를 바꾸는 모든 요청은 예외·우회 없이 `skills/harness-orchestrator`의 **GATE 0 (intent triage)**를 먼저 통과한다.

- GATE 0은 실행 엔진이 아니라 **분기 계층**이다. 요청 의도를 `dev / service-bootstrap / service-ops / harnessing` 중 정확히 1개 branch로 라우팅하고, 통과 마커(`.harness/triage.json`)를 남긴다.
- 별도 선평가나 우회 경로를 만들지 않는다 — 모든 변경 요청이 같은 입구를 탄다는 점이 "에이전트 무관 동일 결과"의 출발점이다.
- write를 수반하지 않는 단순 조회/질문/경미한 문서 수정은 branch 강제 없이 direct handling이 허용된다(triage 자체는 거친다).

**왜**: 입구가 하나여야 가드·산출물·검증을 한 곳에서 일관 적용할 수 있다. 입구가 여러 개면 어떤 에이전트는 게이트를 건너뛰고 결과가 갈린다.

---

## 2. 가드는 권고 prose가 아니라 hook으로 물리 강제된다

"코드 변경 전 하네스를 먼저 타라"는 선언이 아니라 **hook으로 물리 차단**된다.

- PreToolUse(Edit/Write/MultiEdit) 가드가 코드 파일 편집 직전 발동하여, 하네스 진입 상태(state)가 없으면 편집을 **BLOCK(exit 2)** 한다.
- 가드는 user 레벨 설정(`${CLAUDE_HOME:-$HOME/.claude}/settings.json`)에서 **절대경로로 발동**하므로, 엔진 저장소 밖의 git worktree나 임의 cwd에서도 동일하게 강제된다 — 코드 작업 위치와 무관.
- git commit 직전에도 가드가 발동하여, 런타임 코드 변경이면 코드리뷰 evidence(`.harness/review-evidence.json`) 없이는 commit을 차단한다.

**왜**: prose 규칙은 에이전트가 무시하거나 잊으면 그만이다. hook은 도구 실행 경로 자체를 막으므로 우회 비용이 높다 — 결과 동일성을 기계가 보장한다.

---

## 3. 가장 가벼운 레벨(Lite)도 최소 state를 요구한다

하네스 레벨(Lite/Standard/Full)은 **산출물의 양**을 조절하지, GATE 통과 자체를 면제하지 않는다.

- Lite는 PRD/Architecture 같은 무거운 산출물을 면제한다.
- 그러나 Lite여도 진입 state(`.harness/state.json`)는 요구된다. **산출물 면제 ≠ GATE 0 면제.**
- state가 아예 없으면(=orchestrator 미진입) Lite든 아니든 코드 편집은 BLOCK된다.

**왜**: "한 줄 수정이니 그냥 하자"가 우회의 시작이다. 최소 state를 요구하면 가장 작은 변경도 같은 입구를 거쳐 추적 가능해진다.

---

## 4. 결정은 게이트를 통과해야 적립된다 (decision-intent gate)

번호가 매겨진 의사결정(ADR류)을 신설·수정·폐기하는 행위는 **사용자 의도 확인 게이트**를 통과해야 한다.

- 인용 가능한 사용자 원문(명시적 발화)이 없으면 결정 문서를 만들지 않는다.
- 발화가 모호하면 1회 확인 질문으로 전환한다. 추정 기반 결정 적립은 금지.
- 이 게이트는 "추정으로 만든 결정이 같은 날 폐기되어 정정 비용을 쏟는" 실패를 구조적으로 막는다.

**왜**: 결정은 한 번 적립되면 후속 작업의 전제가 된다. 전제가 추정이면 그 위에 쌓인 모든 작업이 흔들린다. 게이트가 전제의 출처를 강제한다. (조직별 결정 본문·번호는 워크스페이스 `decisions/`에 적립된다 — 엔진은 적립 *메커니즘*만 소유.)

---

## 5. 레이어 분리 — 엔진 범용 / 워크스페이스 조직 / 프로젝트

하네스 자산은 세 레이어로 분리되며, 각 레이어는 자기 SoT만 소유한다.

| 레이어 | 소유물 | SoT 위치 |
|--------|--------|----------|
| 엔진(core) 범용 | orchestrator·phase gate·capture loop·범용 hook·rule·schema·범용 에이전트 | cairn plugin (`rules/`·`skills/`·`hooks/`·`agents/`·`schemas/`) |
| 워크스페이스(org) 조직 | 조직값·서비스 카탈로그·도메인 룰·조직 결정 본문·운영 runbook·조직 hook 토글 | `cairn-<team>/`(`.cairn/profile/`·`decisions/`·`domains/` 등) |
| 프로젝트 | 코드·프로젝트 스펙/피처/릴리즈 문서 | 각 프로젝트 repo `docs/` |

- 엔진은 **조직값(조직명·서비스명·Jira 키·Confluence·사번·사내 URL·특정 결정 번호)을 절대 하드코딩하지 않는다.** 엔진이 특정 조직 결정 번호에 의존하면, 그 결정이 없는 새 조직에서 근거 접근이 끊긴다.
- 따라서 엔진 canonical은 결정의 *번호*가 아니라 *메커니즘*을 서술하고, 조직별 도입 근거는 워크스페이스 `decisions/`(존재 시)로 추상 포인터를 건다.

**왜**: 레이어가 섞이면 엔진이 특정 조직에 종속되어 마켓플레이스 재사용이 불가능해진다. 경계 판별 상세는 `docs/CORE_VS_ORG_BOUNDARY.md`.

---

## 6. cross-repo 가드 전파 — 가드 대상만, 무관 repo는 즉시 통과

하네스 가드는 user 레벨 설정에서 절대경로로 발동하므로 모든 repo·worktree에서 깨어난다. 그래서 **가드 대상 판정**이 핵심이다.

- 가드 대상: cairn plugin repo(`AGENTS.md` + `skills/` 마커) / `.harness/`를 보유한 하네스 활성 프로젝트 / 조직 origin에 속한 repo.
- 가드 대상이 아니면 **즉시 통과(exit 0)** — 무관 프로젝트에 부작용 0.
- 엔진 자체 비런타임 자산(`docs/`·`rules/`·`skills/`·`agents/`·`templates/`·`hooks/` 등 문서 변경)은 dev 하네스 대상이 아니므로 통과.

**왜**: 가드가 모든 곳에서 깨어나되 대상이 아니면 즉시 비켜야, 하네스를 들고 다니면서도 남의 repo를 방해하지 않는다. 전파 범위 = 가드 대상 판정 함수 하나로 통제된다.

---

## 관련 문서

- `docs/CORE_VS_ORG_BOUNDARY.md` — core/org 경계 판별 기준
- `docs/WORKSPACE_MODEL.md` — 3계층(엔진/워크스페이스/프로젝트) 구조
- `skills/harness-orchestrator/SKILL.md` — GATE 0 intent triage 라우터
- `skills/harness-dev-process/SKILL.md` — Phase Gate 실행 엔진
- `skills/meta-harnessing/SKILL.md` — 하네스 자체를 깎는 절차 + 결정-의도 게이트
- `rules/core.md` — 하네스 선행 의무 + hook 물리 강제
- 조직별 도입 근거·사례 → 각 워크스페이스 `decisions/`(존재 시)
