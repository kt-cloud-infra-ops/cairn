# 패치 Dockerfile 작성 패턴

## 공통 규칙

- `FROM`은 **digest 고정** — `FROM registry/repo@sha256:<64 hex>`
- `latest` 등 부동 태그 사용 금지
- 원본 이미지의 `USER` / `ENTRYPOINT` / `CMD` / `WORKDIR` / 환경변수를 보존한다
- 패키지 매니저 메타데이터를 정리해 이미지 증가를 최소화한다
- 패키지 저장소 추가·교체 금지, TLS 검증 비활성화 금지
- 라벨로 출처와 조치 시점을 남긴다

```dockerfile
LABEL cairn.source-digest="sha256:..." \
      cairn.patch-date="2026-09-17" \
      cairn.run-id="20260917-142500-a1b2"
```

## Debian / Ubuntu

```dockerfile
FROM <registry>/<repo>@sha256:<digest>
USER root
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
USER <원본 USER>
```

- 특정 패키지만 올릴 때는 `apt-get install -y --only-upgrade <pkg>=<version>` 형태로 버전을 고정한다
- 원본 `USER`가 비어 있으면(=root) `USER` 복원 행을 넣지 않는다

## Alpine

```dockerfile
FROM <registry>/<repo>@sha256:<digest>
USER root
RUN apk upgrade --no-cache
USER <원본 USER>
```

- 특정 패키지만: `apk add --no-cache --upgrade <pkg>=<version>`
- 원본 base 이미지에 비root 사용자가 설정된 경우에만 `USER` 복원

## CloudNativePG PostgreSQL

- 조치 후 **UID 26** 복원이 필수다

```dockerfile
FROM <registry>/<repo>@sha256:<digest>
USER root
RUN apt-get update && apt-get upgrade -y --no-install-recommends \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
USER 26
```

- base OS 메이저 변경은 collation 변경 위험이 있어 기본 금지. 불가피하면 GATE 1에서 별도 고지한다

## 지원되지 않는 패키지 매니저

`apt` / `apk` 외 매니저(예: `microdnf`, `zypper`)나 distroless 이미지는 **추측으로 명령을 만들지 않는다**. 분석 결과만 제공하고 사용자에게 다음을 요청한다.

- 사용할 제품 프로파일
- 스모크 검증 명령
- 또는 상위 패치 이미지 태그

## 로컬 태그 규칙

```text
<원본 repository>:<원본 tag>-patched-<run-id>
```

- 동일 태그가 이미 존재하면 중단한다. 사용자가 `--replace-local`에 해당하는 의도를 명시한 경우에만 재사용한다
- 빌드는 항상 `--platform <원본 아키텍처>`를 명시한다
- 어떤 경우에도 Dockerfile 또는 빌드 명령에 push 단계를 포함하지 않는다
