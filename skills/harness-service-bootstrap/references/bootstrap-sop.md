# Service Bootstrap SOP

Confluence page `CL23 / 2000455370 / demo 를 이용한 개발 환경 만들기`에서
bootstrap 단계에 해당하는 절차만 정규화한 요약이다.

이 문서는 Confluence 원문을 그대로 복제하지 않고, 현재 로컬에서 확인된 template repo와
실행 명령만 추려서 `harness-service-bootstrap` APPLY step이 바로 참조할 수 있게 정리한다.

## 범위

- OKTA 연동 신청 여부 판정
- GitHub template repo 생성
- 로컬 clone
- `rename-service.py`
- `service-charts` / `service-values` 초기 생성
- F/E → B/E 연결값 초기화
- backend configmap / values skeleton
- HTTPRoute skeleton 준비

## 확인한 근거

- `workspace/demo-backend-kt/README.md`
- `workspace/demo-backend-kt/rename-service.py`
- `workspace/infraops-service-charts/README.md`
- `workspace/infraops-service-charts/infraops-bff/templates/httproute.yaml`
- `workspace/infraops-service-charts/infraops-frontend/templates/httproute.yaml`
- `workspace/infraops-service-charts/infraops-message-bridge/README.md`
- `workspace/infraops-service-values/README.md`
- `workspace/infraops-service-values/create-service.sh`
- `workspace/infraops-service-values/infraops-comm/values.yaml`
- `workspace/infraops-service-values/infraops-api/values.yaml`
- `workspace/infraops-service-values/infraops-bff/values.yaml`
- `workspace/infraops-service-values/infraops-frontend/values.yaml`

## 정규화 메모

- 페이지 본문에는 `rename.py`로 적힌 부분이 있으나 실제 템플릿은 `rename-service.py`를 사용한다.
- 페이지는 Windows 경로와 `.\create-service.sh` 표기를 포함한다. 현재 로컬 repo의 실제 명령은 `./create-service.sh`다.
- 페이지 예시에는 `appBaseUrl` 또는 `backendUrl` 계열 표현이 섞여 있으나, 현재 로컬 values repo에서 확인된 F/E 키는 `bffBaseUrl`, `apiBaseUrl`이다.
- backend 공통 `PROFILE` 값은 개별 서비스 `values.yaml`이 아니라 `infraops-comm/values.yaml`의 `config.profile`에서 공급된다.
- HTTPRoute는 모든 서비스에 공통 강제가 아니다. `infraops-message-bridge`처럼 내부 전용 서비스는 의도적으로 `templates/httproute.yaml`를 두지 않는다.

## 상세 절차

### 1. Template repo 생성 + clone + rename

backend template은 현재 `workspace/demo-backend-kt`에서 확인됐다.

```bash
git clone <new-backend-repo-url>
cd <new-backend-repo-dir>
python3 rename-service.py <service-name>
```

확인 방법:

```bash
rg -n "demo-backend-kt|demo-api|demo-batch|com.ktc.infraops.demo" .
```

결과가 없어야 한다.

frontend template의 rename 스크립트 경로는 이 세션에서 확인하지 못했다.

- frontend rename command: `[TBD - 외부 확인 필요]`

### 2. `service-charts` create-service

현재 로컬 기준으로 `infraops-service-charts`에는 `create-service.sh`가 없고,
`README.md`가 수동 복사 + 문자열 치환 절차를 canonical로 설명한다.

실행 repo:

```bash
cd workspace/infraops-service-charts
```

실제 명령:

```bash
cp -R infraops-sample infraops-<service>
rg -l "infraops-sample" infraops-<service> | xargs -I{} sed -i '' 's/infraops-sample/infraops-<service>/g' {}
```

산출물:

- `workspace/infraops-service-charts/infraops-<service>/Chart.yaml`
- `workspace/infraops-service-charts/infraops-<service>/templates/deployment-svc.yaml`
- `workspace/infraops-service-charts/infraops-<service>/templates/configmap.yaml`
- `workspace/infraops-service-charts/infraops-<service>/templates/secrets-provider.yaml`

검증:

```bash
test -f workspace/infraops-service-charts/infraops-<service>/Chart.yaml
rg -n "infraops-sample" workspace/infraops-service-charts/infraops-<service>
```

`rg` 결과가 없어야 한다.

### 3. `service-values` create-service

현재 로컬 기준으로 `infraops-service-values`는 스크립트 기반이다.

실행 repo:

```bash
cd workspace/infraops-service-values
```

실제 명령:

```bash
./create-service.sh infraops-<service> <port>
```

스크립트가 수행하는 일:

- `applications/infraops-sample.yaml` 복사
- `infraops-sample/values.yaml` 복사
- 서비스명 / `port` / `targetPort` 치환

산출물:

- `workspace/infraops-service-values/applications/infraops-<service>.yaml`
- `workspace/infraops-service-values/infraops-<service>/values.yaml`

검증:

```bash
test -f workspace/infraops-service-values/applications/infraops-<service>.yaml
test -f workspace/infraops-service-values/infraops-<service>/values.yaml
rg -n "name: infraops-<service>|port: <port>|targetPort: <port>" \
  workspace/infraops-service-values/applications/infraops-<service>.yaml \
  workspace/infraops-service-values/infraops-<service>/values.yaml
```

### 4. F/E → B/E 연결값 skeleton

현재 로컬 values repo에서 확인된 frontend 연결 키는 아래 두 개다.

- `config.bffBaseUrl`
- `config.apiBaseUrl`

실제 편집 대상:

```bash
$EDITOR workspace/infraops-service-values/infraops-<frontend-service>/values.yaml
```

예시 block:

```yaml
config:
  bffBaseUrl: http://infraops-bff:8081
  apiBaseUrl: http://infraops-api:8082
```

검증:

```bash
rg -n "bffBaseUrl|apiBaseUrl" \
  workspace/infraops-service-values/infraops-<frontend-service>/values.yaml
```

단일 backend 연결 구조에서 `config.backendUrl`을 실제로 쓰는 템플릿은 이 세션에서 확인하지 못했다.

- `config.backendUrl`: `[TBD - 외부 확인 필요]`

### 5. backend configmap / values 초기값

현재 로컬 chart template가 읽는 backend configmap 키는 아래와 같다.

공통:

- `config.profile` (`infraops-comm/values.yaml`에서 공급)
- `config.appBaseUrl`

API 계열 예시 (`infraops-api/templates/configmap.yaml` 기준):

- `config.bffBaseUrl`
- `config.jwtIssuer`
- `config.jwtCookieName`

BFF 계열 예시 (`infraops-bff/templates/configmap.yaml` 기준):

- `config.bffBaseUrl`
- `config.jwtIssuer`
- `config.jwtTtl`
- `config.jwtCookieName`
- `config.cookieDomain`
- `config.cookieSecure`
- `config.oktaIssuer`
- `config.oktaClientId`

Secret skeleton:

- `secrets.enabled`
- `secrets.secretProviderClass`
- `secrets.secretObjects`
- `secrets.kubernetesSecretName`

실제 편집 대상:

```bash
$EDITOR workspace/infraops-service-values/infraops-<backend-service>/values.yaml
```

초기 skeleton 예시:

```yaml
secrets:
  enabled: true
  secretProviderClass: vault-secrets-infraops-<service>
  secretObjects: []
  kubernetesSecretName: infraops-secrets

config:
  appBaseUrl: https://infraops-frontend.svc-dev.14-63-204-35.nip.io
```

검증:

```bash
rg -n "appBaseUrl|secretProviderClass|kubernetesSecretName" \
  workspace/infraops-service-values/infraops-<backend-service>/values.yaml
rg -n "profile:" workspace/infraops-service-values/infraops-comm/values.yaml
```

서비스 유형별 추가 config key는 template별로 달라질 수 있다.

- 추가 runtime key set: `[TBD - 외부 확인 필요]`

### 6. HTTPRoute skeleton

HTTPRoute가 필요한 경우 현재 로컬 기준 참고본은 아래 둘이다.

- `workspace/infraops-service-charts/infraops-bff/templates/httproute.yaml`
- `workspace/infraops-service-charts/infraops-frontend/templates/httproute.yaml`

실제 명령:

```bash
cp \
  workspace/infraops-service-charts/infraops-bff/templates/httproute.yaml \
  workspace/infraops-service-charts/infraops-<public-service>/templates/httproute.yaml
$EDITOR workspace/infraops-service-charts/infraops-<public-service>/templates/httproute.yaml
```

최소 수정 포인트:

- `metadata.name`
- `spec.hostnames[]`
- `spec.parentRefs[].name`
- `spec.parentRefs[].namespace`
- `spec.parentRefs[].sectionName`
- `spec.rules[].backendRefs[].name`
- `spec.rules[].backendRefs[].port`

검증:

```bash
test -f workspace/infraops-service-charts/infraops-<public-service>/templates/httproute.yaml
rg -n "kind: HTTPRoute|name: infraops-<public-service>|port:" \
  workspace/infraops-service-charts/infraops-<public-service>/templates/httproute.yaml
```

내부 전용 서비스는 `infraops-message-bridge`처럼 HTTPRoute를 만들지 않고,
handoff evidence에 `N/A (internal only)`를 명시한다.

## out of scope

아래는 bootstrap가 아니라 운영 반영 단계다.

- Vault Secret 등록
- Observability 연동 확인
- GitHub Actions build 확인
- ArgoCD sync
- DB 생성 / DDL / DML
- 관리자 권한 부여
- 웹 접속 검증
