# Observability Runbook

`service-ops-config` substep B에서 사용하는 Observability checklist다.
서비스별 도구(Grafana, Loki, Prometheus, APM, alert route)가 다를 수 있으므로, 확정 가능한 링크와 owner를 먼저 정리한다.

## 입력

- service
- env
- namespace
- deployment
- hostname
- write owner

## 확인 포인트

1. 이 서비스에 observability 설정이 실제로 필요한지 판단한다.
   - metrics/log/alert를 새로 등록해야 하는가
   - 기존 플랫폼에 서비스만 연결하면 되는가
   - internal-only 서비스라서 별도 외부 링크가 불필요한가

2. 아래 결과를 최소 1세트 확보한다.
   - dashboard URL
   - log query 또는 탐색 경로
   - alert ownership / 알림 채널

3. 근거 repo 또는 문서가 있으면 함께 남긴다.
   - project `docs/`
   - service hub
   - `base/support-projects/<YOUR_PROJECT>/`

## read-only 점검 예시

```bash
rg -n "prometheus|grafana|loki|otel|actuator|dashboard_url|alert" \
  workspace/<backend-repo> \
  base/services/<service> \
  base/support-projects/<YOUR_PROJECT>
```

실제 repo 경로가 없거나 서비스가 observability 연동 대상이 아니면 `N/A`로 판정하고 이유를 남긴다.

## 실제 등록/변경

- dashboard 생성/수정 명령: `[TBD - 외부 확인 필요]`
- alert rule 등록 경로: `[TBD - 외부 확인 필요]`
- log/metrics onboarding 절차: `[TBD - 외부 확인 필요]`

이 단계에서 중요한 것은 "지금 당장 write를 실행했다"가 아니라, 어떤 외부 시스템을 누가 어떻게 건드려야 하는지 명시적으로 정리하는 것이다.

## 검증

- 확보한 dashboard URL / log query / alert owner를 handoff evidence에 기록
- URL 또는 owner가 없으면 `N/A` 또는 `[TBD - 외부 확인 필요]`를 명시

## 산출물

- dashboard/log/alert link evidence
- observability owner 메모
- `N/A` 또는 `[TBD]` 판단 근거
