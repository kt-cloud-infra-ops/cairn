# ATS → Cairn-PE 마이그레이션 가이드

> 설계 SoT: `cairn-engine-design.md` §7
> 대상 독자: 기존 `ai-team-standards`(ATS) 사용자

---

## 개요

이 가이드는 `ai-team-standards`(ATS)의 공유 자산을 `cairn-pe` workspace로 이관하는 절차를 설명한다.

> **이 가이드는 PE팀의 구체적인 케이스다.**
> 일반 패턴은 `ats → cairn-<your-team>` 이다. PE팀은 `cairn-pe`를 workspace 이름으로 사용하지만,
> 다른 팀은 `cairn-sre`, `cairn-data`, `cairn-acme` 등 자신의 팀 이름으로 workspace를 생성한다.
> `cairn-pe`는 레퍼런스 구현(reference implementation)으로, 다른 팀이 복제할 수 있는 템플릿이다.

이관의 목적:

- 조직값(Jira key, 서비스명, SOP 등)을 `cairn` 엔진에서 분리
- workspace 단위로 팀 자산을 git 관리
- `cairn` core의 marketplace 배포 가능 상태 확보

이관 후 ATS는 **archive/read-only** 상태가 된다. 신규 작업은 `cairn-pe`에서 수행한다.

---

## 이관 매핑표

| ATS 경로 | Cairn-PE 대상 | 비고 |
|---------|--------------|------|
| `base/services/**` | `services/**` | README/TASKS/SOP 보존. 서비스 카탈로그 SoT |
| `base/services/*/*/sop/**` | `runbooks/services/{service}/` | `runbooks/` canonical, `services/`는 인덱스/링크 |
| `base/support-projects/**` | `support-projects/**` | 외부 요청/지원 프로젝트 보존 |
| `base/guides/decisions/**` | `decisions/**` | ADR 이력 보존 |
| `base/guides/ktcloud/atlassian/**` | `runbooks/integrations/atlassian/` | 조직 profile 문서 |
| `base/guides/ktcloud/cmdb/**` | `domains/cmdb/` | domain profile |
| `base/guides/ktcloud/inv/**` | `domains/inventory/` | 사내 inventory domain |
| `base/personal/**` | 공유 이관 금지. user private workspace | 개인 worklog는 opt-in import만 |
| `workspace.json` | `.cairn/sources.yaml` | symlink/direct를 clone/pull source로 변환 |
| `workspace/**` symlink | `.cairn/sources.yaml` + `projects/**` clone | 기본 symlink 폐기. git clone으로 대체 |
| `agents/rules/service-mapping.md` | `.cairn/profile/services.yaml` | 값은 profile로, 규칙은 core docs로 |
| `agents/rules/jira-workflow.md` | `rules/jira-workflow.md` + `.cairn/profile/atlassian.yaml` | 조직 key 분리 |
| `agents/rules-on-demand/luppiter/**` | `domains/luppiter/rules-on-demand/**` | PE domain pack |
| `agents/subagents/common/cmdb.md` | `domains/cmdb/agents/cmdb.md` | domain agent |
| `agents/subagents/infraops/**` | `domains/infraops/**` | PE domain agents |
| `agents/skills/luppiter-*` | `domains/luppiter/skills/**` | domain skill |
| `agents/skills/jira-work-*`, `jira-weekly-report` | `skills/atlassian-reporting/**` 또는 `cairn-pe/skills` | PE workflow |
| `.claude/hooks/guard-jira-transition.sh` | `hooks/profile/guard-jira-transition.sh` | profile toggle |
| `.claude/hooks/guard-service-orchestration.sh` | `hooks/profile/guard-service-orchestration.sh` | profile toggle |
| `.claude/hooks/check-feature-jira-sync.sh` | `hooks/profile/check-feature-jira-sync.sh` | profile toggle |

---

## 이관 단계

### Phase M0: Freeze and Inventory

**목적**: ATS 변경을 동결하고 이관 대상 파일을 분류한다.

**작업**:

1. `ai-team-standards` 신규 구조 변경 freeze
2. 현재 `temp/marketplace/team-coupling-inventory.md`, `cairn-residual-scan.md`를 baseline으로 보존
3. ATS 파일 전체를 `core / profile / domain / private / archive`로 manifest화

**완료 조건**:

- [ ] `migration-manifest.yaml` 생성
- [ ] unmapped 파일 0, 또는 모든 파일이 `archive` / `private`으로 명시적 판정
- [ ] ATS에 신규 구조 변경 없음 (freeze 확인)

---

### Phase M1: Cairn Core Contract 반영

**목적**: `cairn`에 workspace 계약 문서, 스키마, 템플릿을 추가한다.

**작업**:

1. `docs/WORKSPACE_MODEL.md`, `docs/PROFILE_CONTRACT.md`, `docs/MIGRATION_GUIDE.md` 추가 (본 파일 포함)
2. `schemas/workspace.schema.json`, `schemas/sources.schema.json`, `schemas/profile.schema.json`, `schemas/services.schema.json` 추가
3. `templates/workspace/`, `templates/profile/` 추가
4. `skills/cairn-init`, `skills/cairn-project-add`, `skills/cairn-project-pull` 설계/구현
5. README를 plugin-install 중심에서 workspace-init 중심으로 수정

**완료 조건**:

- [ ] 새 빈 workspace 생성 가능 (`cairn init` 동작)
- [ ] `sources.yaml` schema validate 통과
- [ ] cairn core 조직값 scan PASS (조직명/key/URL 0건)

---

### Phase M2: Cairn-PE Scaffold 생성

**목적**: `cairn-pe` workspace repo를 만들고 구조를 초기화한다.

**작업**:

1. `cairn-pe` repo 생성 (private) — 일반 패턴: `cairn-<your-team>` 이름으로 생성
2. `.cairn/profile/*` 작성 (env var placeholder로)
3. `services/`, `runbooks/`, `decisions/`, `support-projects/`, `domains/` 빈 구조 생성
4. `workspace.json`과 현재 `workspace/` symlink를 `.cairn/sources.yaml`로 변환

**완료 조건**:

- [ ] `cairn project pull --dry-run` 성공
- [ ] service catalog schema validate 통과
- [ ] `local.env` 기준 Atlassian/Git 연동 동작 확인

---

### Phase M3: ATS Content Migration

**목적**: ATS 공유 자산을 cairn-pe로 실제 이관한다.

**이관 우선순위**:

1. `base/services/**` → `services/**`
2. `base/guides/decisions/**` → `decisions/**`
3. `base/support-projects/**` → `support-projects/**`
4. `base/guides/ktcloud/**` → `runbooks/`/`domains/`/`profile/docs`
5. `agents/rules-on-demand/luppiter/**`, domain agents, luppiter skills → `domains/luppiter/**`
6. Jira/daily/workspace skills → profile-aware skills 또는 Capture/core 대체
7. personal docs → **이관 금지** (private opt-in만)

**완료 조건**:

- [ ] 링크/경로 rewrite 완료
- [ ] old path reference scan에서 `base/`, `workspace/` direct reference 0 또는 compatibility note 추가
- [ ] profile secret scan PASS (`local.env` 외부 secret 0건)

---

### Phase M4: Dogfood

**목적**: 팀이 실제 업무를 `cairn-pe` workspace에서 수행하며 검증한다.

**작업**:

1. 팀 실제 작업을 `cairn-pe` workspace에서 수행
2. `projects/` clone/pull로 프로젝트 접근
3. Capture Loop가 `knowledge/decisions/runbooks`에 저장하는지 검증
4. Jira/Confluence evidence는 profile/env로 연결

**완료 조건**:

- [ ] 1주 이상 주요 daily/dev/service-ops workflow 수행
- [ ] `ai-team-standards`에서 신규 작업 발생 0 또는 cairn-pe로 redirect
- [ ] Capture 결과물이 workspace storage에 올바르게 저장됨

---

### Phase M5: ATS Archive

**목적**: ATS를 read-only로 전환하고 이관을 완료한다.

**read-only 전환 기준**:

- [ ] `cairn-pe`에 모든 shared 자산 이관 완료
- [ ] 개인/secret/private 자산 분리 완료
- [ ] `cairn` core 조직값 scan PASS
- [ ] `cairn-pe` profile 값이 profile 디렉터리에만 존재
- [ ] 팀 설치/clone/pull/init 가이드 검증 완료
- [ ] ATS README에 archive notice와 cairn-pe 이동 경로 명시

**ATS README archive notice 예시** (PE팀 케이스):

```markdown
> **[ARCHIVED]** 이 저장소는 read-only 상태입니다.
> 신규 작업은 cairn-pe workspace를 사용하세요.
> 이관 완료일: YYYY-MM-DD
```

> 다른 팀은 `cairn-pe` 대신 자신의 `cairn-<your-team>` workspace를 사용한다.

---

## 자주 묻는 질문

### 기존 `workspace/` symlink는 어떻게 됩니까?

`cairn` 기본 연결 방식은 git clone/pull이다. 기존 symlink(`strategy: link`)는 고급 옵션(`cairn project link`)으로 후순위 지원되며 기본값이 아니다. M2 단계에서 `sources.yaml`로 변환한다.

### 개인 worklog는 이관합니까?

`base/personal/**`은 공유 repo에 이관하지 않는다. 개인 private workspace에 opt-in import로만 이전 가능하다.

### `daily-work-start/end` 스킬은 어떻게 됩니까?

`cairn-capture` + session insights + workspace activity로 흡수된다. 단순 삭제가 아니라 workspace 기반으로 통합된다.

### 이관 중 기존 ATS를 계속 쓸 수 있습니까?

M0~M4 단계에서는 ATS를 병행 사용할 수 있다. M5에서 ATS가 read-only가 된 후에는 신규 작업을 cairn-pe에서만 수행한다.

---

## 관련 문서

- [WORKSPACE_MODEL.md](WORKSPACE_MODEL.md) — 3계층 모델, workspace 레이아웃
- [PROFILE_CONTRACT.md](PROFILE_CONTRACT.md) — profile YAML 스키마 상세
- [templates/workspace/](../templates/workspace/) — workspace 초기화 템플릿
- [templates/profile/](../templates/profile/) — profile YAML 파일 템플릿
