---
name: harness-service-bootstrap
description: "새 서비스/프로젝트 bootstrap 오케스트레이터. template repo fork → rename-service.py → workspace/docs/AGENTS → charts/values skeleton 초기화까지를 단계별 GATE로 진행한다."
---

## 스킬 규칙
### ALWAYS
- 서비스명, F/E repo명, B/E repo명, template source를 먼저 확정
- `workspace-*` 스킬을 bootstrap/catalog 보조 스킬로 재사용
- `project-structure.md`, `project-docs.md` 기준으로 docs/AGENTS/service catalog를 보강
- charts/values 변경 전 diff preview를 남김
- 완료 시 `service-ops`로 넘길 bootstrap handoff evidence를 남김
### NEVER
- repo naming 검증 없이 template 생성 금지
- `rename-service.py` 결과 확인 없이 commit/push 금지
- bootstrap 단계에서 Vault/ArgoCD/DB write까지 확장 금지
- bootstrap evidence 없이 `service-ops` 완료로 간주 금지
- [GATE 0] 통과 전 repo 생성/clone/rename 시작 금지
- [GATE 1] 통과 전 charts/values 초기화 commit/push 금지

# Harness Service Bootstrap

새 서비스/프로젝트를 template 기반으로 생성하고, 팀 표준 문서/카탈로그/배포 skeleton을 맞춘다.
운영 반영 단계(Vault, ArgoCD, DB)는 `harness-service-ops`가 담당한다.

## 참조

- `references/bootstrap-sop.md` — Confluence `${CONFLUENCE_PAGE_ID}` 정규화 요약 + 실제 repo 명령
- `rules-on-demand/project-structure.md` — template 구조 및 naming
- `rules-on-demand/project-docs.md` — docs/AGENTS 표준
- `skills/harness-orchestrator/SKILL.md` — 상위 라우터, 본 스킬은 `service-bootstrap` branch owner
- `skills/harness-orchestrator/scripts/service-orchestration.mjs` — `init`/`bootstrap-complete` CLI
- `skills/workspace-create-service/SKILL.md`
- `skills/workspace-add-project/SKILL.md`
- `skills/workspace-setup/SKILL.md`
- `docs/HARNESS_DESIGN_RATIONALE.md` — orchestrator 의무 원칙(모든 변경 수반 요청은 GATE 0 경유). 조직 도입 근거는 워크스페이스 `decisions/`(존재 시) 참조

## 실행 절차

1. `SCAN`
   - 서비스명 / repo명 / template repo / workspace 배치 방식 확인
   - 대상 범위: F/E, B/E, 필요 시 batch/charts/values repo
   - 기존 서비스 허브 존재 여부 확인
   - `node skills/harness-orchestrator/scripts/service-orchestration.mjs init {service}` 로 로컬 상태 파일 생성

#### [GATE 0] bootstrap scope 확정
이 GATE를 통과해야 template repo 생성과 rename을 시작한다.

##### 기본 항목
- [ ] 서비스명과 repo naming rule 확정
- [ ] F/E / B/E template source 확정
- [ ] workspace 연결 방식(`symlink`/`direct`) 확정
- [ ] 기존 서비스 허브 존재 여부 확인 (`없으면 workspace-create-service`)

##### 비전 정합성 (비전 카탈로그 정합 + 자율 repo 존중 원칙 — 조직 도입 근거는 워크스페이스 `decisions/`(존재 시) 참조. 팀 비전 Confluence pageId ${CONFLUENCE_PAGE_ID})
- [ ] **파트 분류**: `<YOUR_PART_A>` / `<YOUR_PART_B>` / `공통` — `services/{파트}/{서비스}/` 위치 결정
- [ ] **카테고리**: 팀 비전 기준 카테고리 선택
- [ ] **계층**: 팀 비전 기준 계층 선택
- [ ] **인증 방식**: `SSO` / `Token` / `Local` / `Certificate` / 기타
- [ ] **배포 환경**: `K8s` / `VM` / `HW` / 기타
- [ ] **Roadmap 단계**: `1차 YYYY.MM` + 상태(`Yellow/Green/Red`)
- [ ] **자율 repo 여부 (자율 repo 존중 원칙)**:
  - 표준 적용 = 영문 commit + Jira 티켓 + review-evidence + Co-Authored-By 강제
  - 자율 (예: 자율 repo 패턴) = repo 자체 룰 보존, 카탈로그 메타만 우리 관리
- [ ] **service-mapping.md 등록**: `rules/service-mapping.md` 매핑 행 추가
- [ ] **frontmatter 표준 적용**: `vision_category` / `vision_layer` / `part` / `roadmap_stage` / `auth_method` / `deployment`
- [ ] **도메인 에이전트 신설 여부**: `domains/<YOUR_SERVICE>/agents/{서비스}.md` — 프로젝트 레포 canonical (자율 repo 필수, 표준 repo 선택)

상세 가이드: `references/bootstrap-charter.md`

2. `SCAFFOLD`
   - GitHub template repo 생성 또는 기존 repo 확인
   - 로컬 clone/link
   - 각 repo에서 `rename-service.py` 수행
   - rename 결과 검토 후 commit 준비

3. `REGISTER`
   - `workspace-setup`으로 workspace 연결
   - `workspace-add-project`로 docs/AGENTS 생성 및 서비스 README 갱신
   - 필요 시 `workspace-create-service` 선행

#### [GATE 1] 초기 skeleton 검증
이 GATE를 통과해야 charts/values 초기화와 후속 commit/push로 진행한다.
- [ ] rename 후 예상 경로/패키지/앱 이름 확인
- [ ] 프로젝트 레포 `docs/`, `AGENTS.md` 생성 확인
- [ ] `AGENTS.md` frontmatter 검증 — `service:` + `role:` 필수값 존재, `service:` 값이 `rules/service-mapping.md`의 `서비스 폴더` 컬럼과 일치 (양식: `templates/project-agents.md`)
- [ ] 서비스 카탈로그(`services/{service}/README.md`) 반영 확인
- [ ] charts/values 대상 repo와 스크립트 경로 확인

4. `APPLY`
   - `service-charts` skeleton 생성
     - 실행 주체: 수동 shell 작업 (`workspace-*` 스킬 아님), 작업 repo는 `workspace/<YOUR_CHARTS_REPO>/`
     - 명령:
       ```bash
       cd workspace/<YOUR_CHARTS_REPO>
       cp -R <YOUR_ORG>-sample <YOUR_ORG>-<service>
       rg -l "<YOUR_ORG>-sample" <YOUR_ORG>-<service> | xargs -I{} sed -i '' 's/<YOUR_ORG>-sample/<YOUR_ORG>-<service>/g' {}
       ```
     - 산출물: `workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-<service>/Chart.yaml`, `templates/deployment-svc.yaml`, `templates/configmap.yaml`, `templates/secrets-provider.yaml`
     - 확인:
       ```bash
       test -f workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-<service>/Chart.yaml
       rg -n "<YOUR_ORG>-sample" workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-<service>
       ```
       `rg` 결과가 없어야 한다.
   - `service-values` skeleton 생성
     - 실행 주체: repo 스크립트 실행, 작업 repo는 `workspace/<YOUR_VALUES_REPO>/`
     - 명령:
       ```bash
       cd workspace/<YOUR_VALUES_REPO>
       ./create-service.sh <YOUR_ORG>-<service> <port>
       ```
     - 산출물: `workspace/<YOUR_VALUES_REPO>/applications/<YOUR_ORG>-<service>.yaml`, `workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-<service>/values.yaml`
     - 확인:
       ```bash
       test -f workspace/<YOUR_VALUES_REPO>/applications/<YOUR_ORG>-<service>.yaml
       test -f workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-<service>/values.yaml
       rg -n "name: <YOUR_ORG>-<service>|port: <port>|targetPort: <port>" \
         workspace/<YOUR_VALUES_REPO>/applications/<YOUR_ORG>-<service>.yaml \
         workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-<service>/values.yaml
       ```
   - F/E → B/E 연결값 skeleton 반영
     - 실행 주체: 수동 values 편집, 작업 repo는 `workspace/<YOUR_VALUES_REPO>/`
     - 명령:
       ```bash
       $EDITOR workspace/<YOUR_VALUES_REPO>/<frontend-service>/values.yaml
       ```
       현재 로컬 표준에서는 `config.bffBaseUrl`, `config.apiBaseUrl` 키를 사용한다. 단일 backend만 있는 UI면 `[TBD - 외부 확인 필요]` 위치에 연결 키를 남기고 handoff evidence에 기록한다.
     - 산출물: `workspace/<YOUR_VALUES_REPO>/<frontend-service>/values.yaml` 내부 `config.*BaseUrl` skeleton
     - 확인:
       ```bash
       rg -n "bffBaseUrl|apiBaseUrl|backendUrl" \
         workspace/<YOUR_VALUES_REPO>/<frontend-service>/values.yaml
       ```
       실제 사용 키는 `references/bootstrap-sop.md`의 "F/E → B/E 연결값" 절과 일치해야 한다.
   - backend configmap / values 초기값 반영
     - 실행 주체: 수동 values 편집, configmap 키는 chart template가 소비
     - 명령:
       ```bash
       $EDITOR workspace/<YOUR_VALUES_REPO>/<backend-service>/values.yaml
       ```
       최소 skeleton은 `config.appBaseUrl` 이고, 현재 로컬 표준에서 공통 `config.profile`은 `<YOUR_ORG>-comm/values.yaml`가 제공한다. API/BFF 계열 추가 키는 `references/bootstrap-sop.md`의 "backend configmap / values 초기값" 절을 따른다.
     - 산출물: `workspace/<YOUR_VALUES_REPO>/<backend-service>/values.yaml` 내부 `config`, `secrets` skeleton
     - 확인:
       ```bash
       rg -n "appBaseUrl|profile|secretProviderClass|kubernetesSecretName" \
         workspace/<YOUR_VALUES_REPO>/<backend-service>/values.yaml \
         workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-comm/values.yaml
       ```
   - HTTPRoute skeleton 파일 준비
     - 실행 주체: 수동 shell 작업, 외부 노출 필요 서비스만 수행. 내부 전용 서비스는 N/A를 handoff evidence에 남긴다.
     - 명령:
       ```bash
       cp \
         workspace/<YOUR_CHARTS_REPO>/<your-bff-service>/templates/httproute.yaml \
         workspace/<YOUR_CHARTS_REPO>/<public-service>/templates/httproute.yaml
       $EDITOR workspace/<YOUR_CHARTS_REPO>/<public-service>/templates/httproute.yaml
       ```
       `<YOUR_ORG>-frontend/templates/httproute.yaml`를 복제해도 되지만, 현재 로컬 repo 기준으로 외부 노출 패턴 확인용 기준 파일은 BFF 서비스와 frontend 서비스 두 개다.
     - 산출물: `workspace/<YOUR_CHARTS_REPO>/<public-service>/templates/httproute.yaml`
     - 확인:
       ```bash
       test -f workspace/<YOUR_CHARTS_REPO>/<public-service>/templates/httproute.yaml
       rg -n "kind: HTTPRoute|name: <public-service>|port:" \
         workspace/<YOUR_CHARTS_REPO>/<public-service>/templates/httproute.yaml
       ```

5. `VERIFY`
   - 생성 repo / workspace / docs / charts / values 경로 점검
   - bootstrap handoff evidence 정리
   - `service-orchestration.mjs bootstrap-complete` 로 bootstrap 완료 기록
   - bootstrap 산출물과 운영 반영 경계 확인
   - 운영 반영이 필요하면 `harness-service-ops`로 위임

## bootstrap handoff evidence

`service-ops` 또는 `cicd-deploy`로 넘어가기 전에 아래 증적이 준비되어 있어야 한다.

- 서비스 허브: `services/{service}/README.md`, `TASKS.md`
- 프로젝트 레포: `docs/`, `AGENTS.md`
- workspace 연결 정보: `workspace.json` 또는 동등한 실제 경로 확인 결과
- 배포 skeleton: `service-charts`, `service-values`, HTTPRoute skeleton
- 미완료 항목과 다음 owner: `service-ops`

이 증적이 비어 있으면 bootstrap은 완료가 아니다.

기록 위치:
- 로컬 상태 파일: `temp/orchestrator/{service}/state.json` (git 미추적)
- 완료 기록 예시:

```bash
node skills/harness-orchestrator/scripts/service-orchestration.mjs bootstrap-complete {service} \
  --project-root workspace/{frontend_repo} \
  --project-root workspace/{backend_repo} \
  --charts workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-{service} \
  --values workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-{service} \
  --httproute workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-{service}/templates/httproute.yaml
```

## 완료 조건 (DONE WHEN)
- [ ] [GATE] GATE 0 통과
- [ ] [GATE] GATE 1 통과
- [ ] [MANUAL] template repo/clone/rename 완료
- [ ] [FILE] 프로젝트 레포 `docs/` 및 `AGENTS.md` 존재
- [ ] [MANUAL] service-charts / service-values skeleton 준비 완료
- [ ] [CONTENT] bootstrap handoff evidence 정리 완료
- [ ] [FILE] `temp/orchestrator/{service}/state.json` 에 bootstrap 완료 기록
