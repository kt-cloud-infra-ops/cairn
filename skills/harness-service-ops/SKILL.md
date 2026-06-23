---
name: harness-service-ops
description: "서비스 운영 반영 오케스트레이터. Vault/Observability/Actions/ArgoCD/DB/DDL/DML/접속 검증을 read-only와 write 경로로 분리해 단계별 GATE로 진행한다."
---

## 스킬 규칙
### ALWAYS
- 시작 시 read-only 점검과 write 경로를 분리
- env, namespace, repo, deployment, DB target을 먼저 확정
- write 직전 payload/diff/대상 경로 preview를 남김
- bootstrap 산출물 준비 여부를 먼저 확인하고 부족하면 `harness-service-bootstrap`로 되돌림
- `cicd-deploy`는 bootstrap 완료 이후 deploy helper로만 사용
### NEVER
- target env/namespace/DB 확인 없이 write 금지
- dev Phase(`INIT → PLAN → IMPL → VERIFY → SHIP`)를 운영 반영에 재사용 금지
- bootstrap evidence 없이 `cicd-deploy`, ArgoCD, DB write 시작 금지
- [GATE 0] 통과 전 Vault/ArgoCD/DB write 금지
- [GATE 1] 통과 전 chart/value push 및 sync 금지
- [GATE 2] 통과 전 DDL/DML 및 관리자 권한 변경 금지

# Harness Service Ops

서비스 bootstrap 이후 운영 환경 반영과 활성화를 담당한다.
read-only 점검은 가볍게 처리하고, write path만 명시적 GATE를 적용한다.

## 참조

- `references/ops-sop.md` — Confluence `2000455370` 운영 반영 요약
- `agents/skills/service-ops-config/SKILL.md`
- `agents/skills/harness-orchestrator/SKILL.md` — 상위 라우터, 본 스킬은 `service-ops` branch owner
- `agents/skills/harness-orchestrator/scripts/service-orchestration.mjs` — `validate`/`ops-precheck` CLI
- `agents/skills/cicd-deploy/SKILL.md`
- `agents/skills/jira-rest-ops/SKILL.md`
- `agents/rules/skill-governance.md`
- `base/guides/decisions/008-orchestrator-mandatory.md` — 모든 변경 수반 요청은 orchestrator 의무 통과

## 실행 절차

1. `PRECHECK`
   - 요청이 read-only인지 write인지 판정
   - **비계획 장애(incident) 식별**: 요청이 정상 운영 반영(Vault/배포/DDL)인지, 비계획 장애 대응(장애·적재 실패·알람 미적재·CINM 등)인지 1차 분기
     - 비계획 장애면 → `ops-incident` sub-owner로 위임 (Phase 0 인지·분류부터). 이때 **bootstrap/deploy-ready 검증 면제** (운영 중 서비스 = 이미 bootstrap 완료 전제, 장애 시급성 우선)
     - 정상 운영 반영이면 → 아래 GATE 0 흐름 진행
   - 대상 env / namespace / chart repo / values repo / deployment / DB / hostname 확인
   - bootstrap handoff evidence 또는 동등 증적 존재 여부 확인
   - `service-orchestration.mjs validate {service} --require bootstrap` 통과 확인

#### [GATE 0] 운영 write 사전 조건 확인
이 GATE를 통과해야 운영 반영 write로 진행한다. (단 **incident sub-path는 면제** — `ops-incident` GATE 1 승인으로 장애 임시 회피 write 진행)
- [ ] bootstrap evidence 확인 (`base/services/{service}/README.md`, 프로젝트 `docs/`/`AGENTS.md`, charts/values skeleton)
- [ ] target env / namespace / deployment / DB 확정
- [ ] chart/value repo 및 권한 확인
- [ ] Vault / cluster / DB 접근 경로 확인
- [ ] rollback 또는 재시도 경로 확인

2. `CONFIG`
   - `service-ops-config` helper로 위임
     - substep A — Vault Secret 등록/검증
     - substep B — Observability 설정/링크 확인
     - substep C — HTTPRoute / values / runtime env 변경 preview
   - 본 스킬은 GATE 0/1/2 owner를 유지한다
   - helper 결과(Secret checklist, dashboard/link evidence, chart/value preview)를 확정한 뒤 `service-orchestration.mjs ops-precheck {service} --env ... --namespace ...` 기록

#### [GATE 1] 배포 반영 전 검증
이 GATE를 통과해야 chart/value push와 ArgoCD sync로 진행한다.
- [ ] chart/value diff preview 확인
- [ ] 필요한 secret / config key 존재 확인
- [ ] GitHub Actions 또는 rollout 확인 경로 확정
- [ ] write 대상 repo/branch 확인

3. `DEPLOY`
   - chart/value push
   - 필요 시 `cicd-deploy`로 develop merge, GitHub Actions, ArgoCD helper flow 실행
   - GitHub Actions build 확인
   - ArgoCD sync
   - rollout / env 반영 여부 확인

4. `DATA`
   - DB 생성
   - DDL / DML 적용
   - 관리자 권한 부여 등 후속 데이터 반영

#### [GATE 2] 데이터 반영 전 검증
이 GATE를 통과해야 DB write로 진행한다.
- [ ] target DB와 접속 계정 확인
- [ ] 적용할 DDL/DML 파일 경로 확인
- [ ] 데이터 변경 대상 사용자/권한 확인
- [ ] 실패 시 복구 또는 재적용 경로 확인

5. `VERIFY`
   - pod/env/secret 반영 여부 확인
   - Observability 대시보드 확인
   - hostname 접속 검증
   - 정상 기동 + 기능 검증 결과 사용자 보고

6. `RELEASE-CLOSE` (VERIFY 통과 후 사용자 명시 승인 필요)
   - **luppiter 계열** (`TECHIOPS26-*`, fixVersion = `LUPPITER_*`):
     - `luppiter-release-e2e-sync` 스킬의 `[GATE RELEASED]` 진입 → `--mark-released --confirmed-release-date YYYY-MM-DD` 실행으로 fixVersion `released=true` 마킹
     - 미실행 시 release report 페이지가 미릴리즈 상태로 노출되어 추적 누락 (TECHIOPS26-643 사례)
   - **다른 서비스**: 해당 서비스의 release 스킬로 위임 (없으면 Jira UI 수동 처리 + 후속 신설 검토)
   - 완료 조건: `[MANUAL] fixVersion released=true 마킹 완료`

## bootstrap prerequisite

아래 중 하나라도 없으면 `service-ops`를 진행하지 않고 `harness-service-bootstrap`로 되돌린다.

- 서비스 허브가 없다
- 프로젝트 레포 `docs/` 또는 `AGENTS.md`가 없다
- `service-charts` / `service-values` skeleton이 없다
- HTTPRoute / values 대상 경로가 해석되지 않는다

즉, 사용자가 "CI/CD부터 해달라"고 요청해도 bootstrap 증적이 없으면 운영 반영을 시작하지 않는다.

로컬 validator 예시:

```bash
node agents/skills/harness-orchestrator/scripts/service-orchestration.mjs validate {service} --require bootstrap
node agents/skills/harness-orchestrator/scripts/service-orchestration.mjs ops-precheck {service} \
  --env dev \
  --namespace {namespace} \
  --deployment {deployment}
```

## 완료 조건 (DONE WHEN)
- [ ] [GATE] GATE 0 통과
- [ ] [GATE] GATE 1 통과
- [ ] [GATE] GATE 2 통과
- [ ] [CONTENT] bootstrap evidence 확인 완료
- [ ] [MANUAL] 운영 반영 write와 검증 경로 보고 완료
- [ ] [MANUAL] 웹/대시보드/rollout 검증 완료
- [ ] [FILE] `temp/orchestrator/{service}/state.json` 에 ops precheck/complete 기록
