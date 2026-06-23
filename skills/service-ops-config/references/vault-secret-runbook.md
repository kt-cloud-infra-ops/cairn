# Vault Secret Runbook

`service-ops-config` substep A에서 사용하는 Vault Secret checklist다.
실제 Vault write 명령은 환경별로 다를 수 있으므로, 이 문서는 repo 근거와 preview를 먼저 고정한다.

## 입력

- service
- env
- namespace
- charts 경로
- values 경로
- write owner

## repo 기준 확인 포인트

- `workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-<service>/values.yaml`
  - `secrets.enabled`
  - `secrets.secretProviderClass`
  - `secrets.secretObjects`
  - `secrets.kubernetesSecretName`
- `workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-comm/values.yaml` (`<YOUR_ORG>-comm` 공통 values)
  - 공통 Vault 설정 존재 여부
- `workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-<service>/templates/secrets-provider.yaml`

## preview 절차

1. values 파일에서 필요한 secret key와 target path를 확인한다.

```bash
rg -n "secrets:|secretProviderClass|secretObjects|kubernetesSecretName|secretPath|secretKey" \
  workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-<service>/values.yaml \
  workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-comm/values.yaml
```

2. chart가 `SecretProviderClass`를 렌더링하는지 확인한다.

```bash
test -f workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-<service>/templates/secrets-provider.yaml
helm template <YOUR_ORG>-<service> \
  workspace/<YOUR_CHARTS_REPO>/<YOUR_ORG>-<service> \
  -f workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-comm/values.yaml \
  -f workspace/<YOUR_VALUES_REPO>/<YOUR_ORG>-<service>/values.yaml \
  | rg -n "SecretProviderClass|secretProviderClass|secretObjects|kubernetesSecretName"
```

3. secret key checklist를 정리한다.

- 어떤 key를 누가 준비하는가
- 어떤 secret path를 사용하는가
- 어떤 namespace에 반영되는가
- `kubernetesSecretName`이 무엇인가

## 실제 write

- Vault UI/CLI 등록 명령: `[TBD - 외부 확인 필요]`
- cluster 반영 owner: `[TBD - 외부 확인 필요]`

추정 금지. 실제 명령을 모르면 runbook에 그대로 `[TBD - 외부 확인 필요]`를 남기고 `harness-service-ops` owner에게 escalation 한다.

## 검증

- repo preview 근거는 위 `rg`/`helm template` 결과로 남긴다
- cluster/Vault post-check command: `[TBD - 외부 확인 필요]`

## 산출물

- secret key checklist
- `secretProviderClass` preview 근거
- unresolved `[TBD]` 목록
- write owner 메모
