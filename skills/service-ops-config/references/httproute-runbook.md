# HTTPRoute / Values Preview Runbook

`service-ops-config` substep C에서 사용하는 HTTPRoute / values / runtime env preview 절차다.
이 substep은 write 전 diff와 rendered output을 고정하는 데 목적이 있다.

## 입력

- service
- env
- namespace
- charts 경로
- values 경로
- hostname

## preview 대상

- `workspace/infraops-service-charts/infraops-<service>/templates/httproute.yaml`
- `workspace/infraops-service-values/infraops-<service>/values.yaml`
- `workspace/infraops-service-values/infraops-comm/values.yaml`

내부 전용 서비스는 HTTPRoute를 만들지 않고 `N/A (internal only)`로 기록한다.

## diff preview

```bash
git diff -- \
  workspace/infraops-service-charts/infraops-<service> \
  workspace/infraops-service-values/infraops-<service>
```

## key preview

```bash
rg -n "HTTPRoute|appBaseUrl|bffBaseUrl|apiBaseUrl|profile|secretProviderClass" \
  workspace/infraops-service-charts/infraops-<service> \
  workspace/infraops-service-values/infraops-<service> \
  workspace/infraops-service-values/infraops-comm/values.yaml
```

## rendered preview

```bash
helm template infraops-<service> \
  workspace/infraops-service-charts/infraops-<service> \
  -f workspace/infraops-service-values/infraops-comm/values.yaml \
  -f workspace/infraops-service-values/infraops-<service>/values.yaml \
  | rg -n "kind: HTTPRoute|kind: ConfigMap|APP_BASE_URL|BFF_BASE_URL|API_BASE_URL|PROFILE"
```

## 확인 포인트

- HTTPRoute가 필요한 서비스인가
- hostnames / backendRefs / port가 target env와 일치하는가
- runtime env key가 values/configmap 간에 일치하는가
- push 전에 남길 diff preview가 충분한가

## 산출물

- chart/value diff preview
- rendered HTTPRoute / ConfigMap preview
- runtime env key checklist
