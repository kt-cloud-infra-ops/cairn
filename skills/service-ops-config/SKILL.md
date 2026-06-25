---
name: service-ops-config
description: "harness-service-ops CONFIG step helper. Vault Secret / Observability / HTTPRoute/values preview의 3 substep을 묶어 단계별 checklist + wrapper를 제공한다."
---

## 스킬 규칙
### ALWAYS
- target env, namespace, service, charts repo, values repo, deployment, hostname을 먼저 확정
- `harness-service-ops` PRECHECK 결과와 bootstrap evidence를 먼저 확인
- 각 substep 종료 시 preview/checklist 산출물을 남기고 다음 단계로 진행
- 실제 write 실행 주체(사람 또는 외부 운영 도구 owner)를 명시한다
### NEVER
- helper 결과만으로 운영 반영 완료로 간주 금지
- bootstrap evidence 없이 시작 금지
- 외부 write CLI를 이 스킬이 직접 확정 실행한 것으로 기록 금지
- [GATE 0] 통과 전 Vault/Observability/HTTPRoute preview 시작 금지

## 외부 컨텍스트 처리 (CRITICAL)
Confluence, 사내 운영 SOP, 실제 cluster/Vault/Grafana 접근 경로는 이 저장소에 자동 동기화되지 않는다.
이 스킬은 확인 가능한 repo 근거와 checklist를 먼저 만들고, 외부 시스템별 실제 write 명령은 `[TBD - 외부 확인 필요]`로 남긴다.

| 순위 | 소스 | 용도 |
|------|------|------|
| PRIMARY | `harness-service-ops` PRECHECK 결과, `temp/orchestrator/{service}/state.json`, project `docs/`, charts/values repo | env/namespace/path 확정, preview 근거 |
| SECONDARY | `skills/harness-service-ops/references/ops-sop.md`, service hub, 사내 SOP/Confluence | 운영 절차 보강 |
| FORBIDDEN | 추정한 secret key, 미확인 hostname, 임의 cluster 경로 | 사용 금지 |

## 참조

- `skills/harness-service-ops/SKILL.md`
- `skills/harness-service-ops/references/ops-sop.md`
- `references/vault-secret-runbook.md`
- `references/observability-runbook.md`
- `references/httproute-runbook.md`

## 실행 절차

1. `INPUT SNAPSHOT`
   - 대상 service / env / namespace / deployment / hostname / charts repo / values repo를 고정
   - bootstrap evidence와 `service-orchestration.mjs validate {service} --require bootstrap` 통과 여부를 재확인
   - 이번 요청에서 필요한 substep만 선택한다
     - A: Vault Secret 등록/검증
     - B: Observability 설정/링크 확인
     - C: HTTPRoute / values / runtime env preview

#### [GATE 0] CONFIG helper 시작 조건
이 GATE를 통과해야 각 substep checklist를 실행한다.
- [ ] bootstrap evidence 확인
- [ ] target env / namespace / deployment / hostname 확정
- [ ] charts/values 경로와 수정 owner 확정
- [ ] 필요한 substep(A/B/C) 선택 완료
- [ ] 실제 write 실행 주체 또는 외부 확인 owner 명시

2. `substep A — Vault Secret 등록/검증`
   - `references/vault-secret-runbook.md`를 따라 values/chart 기준 secret key, `secretProviderClass`, `kubernetesSecretName` preview를 만든다
   - exact Vault write 명령은 확인 가능한 SOP가 없으면 `[TBD - 외부 확인 필요]`로 남긴다
   - 산출물:
     - secret key checklist
     - values/chart preview 근거
     - unresolved `[TBD]` 목록

3. `substep B — Observability 설정/링크 확인`
   - `references/observability-runbook.md`를 따라 dashboard/log/alert 경로와 owner를 정리한다
   - 실제 등록 경로가 없다면 `N/A` 또는 `[TBD - 외부 확인 필요]`로 명시한다
   - 산출물:
     - dashboard/log/alert link evidence
     - observability owner / follow-up route
     - N/A 또는 `[TBD]` 판단 근거

4. `substep C — HTTPRoute / values / runtime env preview`
   - `references/httproute-runbook.md`를 따라 diff preview, `helm template`, runtime env 노출 키를 점검한다
   - 내부 전용 서비스는 HTTPRoute를 만들지 않고 `N/A (internal only)`를 남긴다
   - 산출물:
     - chart/value diff preview
     - rendered HTTPRoute / ConfigMap preview
     - runtime env key checklist

5. `RETURN TO harness-service-ops`
   - 이 스킬은 helper다. GATE owner와 `ops-precheck` 기록 owner는 계속 `harness-service-ops`다
   - substep 산출물을 owner에게 전달하고, owner가 `service-orchestration.mjs ops-precheck ...` 기록 여부를 결정한다

## 완료 조건 (DONE WHEN)
- [ ] [GATE] GATE 0 통과
- [ ] [FILE] `references/vault-secret-runbook.md` 존재
- [ ] [FILE] `references/observability-runbook.md` 존재
- [ ] [FILE] `references/httproute-runbook.md` 존재
- [ ] [MANUAL] 필요한 substep(A/B/C)의 checklist 결과 정리 완료
- [ ] [MANUAL] `harness-service-ops` owner에게 preview/evidence handoff 완료
