# Core vs Org 경계 — 무엇이 엔진(core)이고 무엇이 워크스페이스(org)인가

부트스트랩·일상 운영에서 반복되는 질문: **"이 자산은 cairn 엔진(core)에 두나, 워크스페이스(org)에 두나?"** 이 문서가 판별 기준이다.

> 배경: 부트스트랩 테스트에서 claude/codex 둘 다 "skills·hooks·domain-agents가 core인지 org인지 기준이 없다"(C4)고 지적했다. 이 경계가 모호하면 포팅 시 과/누락이 생긴다.

---

## 1차 기준 (한 문장)

**엔진(plugin)이 제공하면 `core`, 그 조직에만 의미 있으면 `org`.**

판별 질문: **"다른 조직도 이걸 그대로 쓰나?"** → Yes = core, No = org.

| | **core** (엔진/plugin) | **org** (워크스페이스 `cairn-<team>`) |
|--|------------------------|--------------------------------------|
| 정의 | 범용 — 모든 조직 동일 | 조직 특화 — 그 조직만 |
| 위치 | cairn plugin (`skills/`·`rules/`·`hooks/`·`templates/`·`schemas/`) | `cairn-<team>/` (`domains/`·`services/`·`.cairn/`) |
| 변경 주체 | 엔진 릴리즈 (팀 무관) | 각 팀·개인 자유 |
| 배포 | 마켓플레이스 | 사내 private repo |

---

## 경계 모호 케이스 판별 (C4 해소)

### 스킬 (skills)
| 유형 | 판정 | 위치 |
|------|------|------|
| 범용 도구 (Jira REST 호출 자체, TDD, 코드리뷰) | **core** | plugin `skills/` — `jira-rest-ops`, `dev-*`, `harness-*` |
| 조직 워크플로 (우리 Jira 주간보고·TASKS 규칙, CRM 보정 절차) | **org** | `domains/{svc}/skills/` 또는 `operations/skills/` + **`.cairn/skills.yaml` 등록** |
- 판별: jira-rest-ops(범용 REST)=core / luppiter-datachange(우리 운영 절차)=org

### 에이전트 (agents)
| 유형 | 판정 | 위치 |
|------|------|------|
| 범용 레이어 (backend-dev, frontend-dev, dba, code-reviewer) | **core** | plugin `agents/` |
| 도메인 페르소나 (luppiter/cmdb/hermes 특화 지식) | **org** | `domains/{svc}/agents/` |

### 훅 (hooks)
| 유형 | 판정 | 위치 |
|------|------|------|
| 범용 가드 (charter, git-commit, skill-create, capture-*, orchestrator-entry) | **core** | plugin `hooks/` |
| 조직 워크플로 가드 (jira-transition, service-orchestration, feature-jira-sync) | **org** | `.cairn/profile/hooks.yaml` (profile-aware, `cairn-hook-router.sh`가 조건부 실행) |

### 룰 (rules)
| 유형 | 판정 | 위치 |
|------|------|------|
| 범용 (coding-style, testing, security, git-workflow, core, agents) | **core** | plugin `rules/`·`rules-on-demand/` |
| 조직 (서비스 매핑, Jira 프로젝트키·필드ID, 도메인 룰) | **org** | `.cairn/profile/` (값) + `domains/{svc}/rules-on-demand/` (도메인 룰) |

---

## 부트스트랩 적용 (포팅 시)

**core는 포팅하지 않는다** (엔진이 always 제공). **org만** 워크스페이스로 가져온다.

판별 자동화 (claude-cairn J6 기법):
```bash
# 엔진 자산과 basename diff → 엔진에 없는 것만 org 후보
comm -23 <(ls ats/agents/knowledge/lessons/common | sort) \
         <(ls cairn/knowledge/lessons/common | sort)
# → 엔진에 없는 lesson = org 특화 → 포팅 대상
```

이 기준이 있으면 "무엇을 안 가져올지"가 기계적으로 결정된다.

---

## 관련 문서
- `docs/WORKSPACE_MODEL.md` — 3계층 구조 (cairn / cairn-<team> / projects)
- `docs/PROFILE_CONTRACT.md` — org 값의 profile 보관 규약
- `schemas/skills.schema.json` — org 스킬 레지스트리(`.cairn/skills.yaml`) 계약
- `skills/harness-orchestrator/SKILL.md` — org 스킬 디스패치 규칙
