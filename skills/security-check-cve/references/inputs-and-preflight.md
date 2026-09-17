# 입력 정규화와 Preflight

## 1. 지원 입력

| 입력 형태 | 예시 | sourceType |
|-----------|------|------------|
| Harbor 아티팩트 UI URL | `https://<harbor>/harbor/projects/1/repositories/app/artifacts-tab/artifacts/sha256:...` | `harbor-url` |
| 태그 이미지 참조 | `registry/repository:tag` | `image-ref` |
| digest 이미지 참조 | `registry/repository@sha256:<64 hex>` | `image-ref` |
| 목록 파일 | TXT/CSV, 한 줄에 하나 | `list` |
| 매니페스트 디렉터리 | Dockerfile `FROM`, Compose `image:`, Helm values의 repository/tag/digest, Kubernetes `image:` | `discovered` |

## 2. 정규화 규칙

1. registry / repository / tag / digest 4필드로 분해한다
2. 동일 registry+repository에서 **digest 참조가 tag 참조보다 우선**한다 (tag는 가변)
3. 중복은 제거하되 원본 입력 문자열(`input`)을 함께 보존한다
4. 자격증명이 포함된 URL(`user:pass@`, 토큰 쿼리스트링)은 **거부**하고 경고에 사유만 기록한다 (값 에코 금지)
5. 파싱 불가 항목은 버리지 않고 `warnings`에 남긴다

정규화 결과 구조:

```json
{
  "schemaVersion": 1,
  "images": [
    {
      "input": "...",
      "registry": "...",
      "repository": "...",
      "tag": "...",
      "digest": "sha256:...",
      "sourceType": "harbor-url|image-ref|list|discovered"
    }
  ],
  "warnings": []
}
```

## 3. Harbor 해석

- Harbor 호스트와 API base는 아티팩트 URL에서 파싱한다
- Harbor API로 tag·digest·아키텍처·스캔 메타데이터를 확인한다
- repository 경로는 URL 인코딩을 고려한다 (`/` → `%2F`)
- 인증은 기존 Docker/nerdctl credential helper 또는 사용자가 알려준 robot-account 환경변수명을 사용한다
- 로컬 Trivy가 없으면 Harbor 스캔 결과를 기준선으로 쓸 수 있으나, **동일 DB before/after 비교를 주장하지 않고** Harbor 스캐너·DB 메타데이터로 라벨링한다

## 4. Preflight 체크리스트

- [ ] `docker` / `nerdctl` 탐지, 버전 기록, 하나 선택
- [ ] 호스트 OS·아키텍처 기록
- [ ] 소스 이미지 아키텍처 확인 → 이후 모든 pull/build에 명시적 `--platform` 사용
- [ ] Trivy 탐지, 엔진 버전 + 취약점 DB 버전·갱신시각 기록
- [ ] 레지스트리 연결성과 credential helper 확인
- [ ] 출력 루트 결정: 사용자 인자 > `<현재 작업 디렉터리>/outputs`
- [ ] `run-id` 생성: `YYYYMMDD-HHMMSS-<4자리난수>`
- [ ] 출력 경로가 스캔 대상 소스 디렉터리 내부가 **아님**을 확인

필수 도구가 없으면 해당 작업만 차단한다. 도구를 설치하거나 다른 스캐너로 무단 대체하지 않는다.

## 5. 출력 루트 규칙

```text
<출력루트>/<run-id>/cve/...   # security-check-cve
<출력루트>/<run-id>/cce/...   # security-check-cce
```

같은 세션에서 두 스킬을 연속 실행하면 `run-id`를 공유해 하나의 run 디렉터리 아래 `cve/`, `cce/`로 나란히 둘 수 있다.
