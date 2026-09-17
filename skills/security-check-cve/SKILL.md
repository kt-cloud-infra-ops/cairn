---
name: security-check-cve
description: "컨테이너 이미지 CVE 분석·조치·검증·리포트 스킬. Harbor 아티팩트 URL / 이미지 참조 / 이미지 목록 파일 / 매니페스트 디렉터리를 입력받아 Trivy 기준선 수집 → 최소 호환 패치 Dockerfile 생성 → 로컬 빌드 + 런타임 검증 → 재스캔 before/after 비교 → Markdown·Excel 리포트와 예외신청 사유서 생성까지 수행할 때 사용한다. 소스코드 SAST와 이미지 없는 일반 의존성 점검은 보안전문가 에이전트 담당."
triggers: [CVE, 이미지 취약점, Harbor 취약점, 컨테이너 취약점 조치, 패치 Dockerfile, Trivy, CVE 엑셀, CVE 예외 신청, 취약점 리포트]
---

## 스킬 규칙

### ALWAYS
- **순서**: 입력 수집 → preflight → [GATE 0] → 기준선 스캔/분류 → 조치안 설계 → [GATE 1] → 패치 빌드 → 런타임 검증 → 재스캔 비교 → [GATE 2] → 리포트 산출
- 모든 산출물은 `<출력루트>/<run-id>/cve/` 아래에만 쓴다 (`run-id` = `YYYYMMDD-HHMMSS-<4자리난수>`)
- 소스 이미지는 digest로 고정(pin)하고, 빌드는 항상 명시적 `--platform`으로 원본 아키텍처를 지정한다
- 조치 후에는 **애플리케이션 버전 / 실행 UID / entrypoint / 필수 명령·확장 / 제품별 스모크 테스트**를 실제 실행해 검증한다
- 재스캔은 기준선과 **동일 스캐너 + 동일 DB 버전**으로 수행하고, 스캐너·DB 버전과 갱신시각을 리포트에 기록한다
- 조치 결과는 `remediated / residual / exception / false-positive / blocked` 5분류로 구분한다
- 스캐너의 `No fix`는 "수정 불가 확정"이 아니라 **fix 메타데이터 부재**로 취급한다

### NEVER
- **[GATE 0] 통과 전 이미지 pull·빌드 금지**
- **[GATE 1] 통과 전 패치 이미지 빌드 금지**
- **[GATE 2] 통과 전 리포트·예외신청서 확정 산출 금지**
- 레지스트리 push 금지 — 사용자가 명시적으로 요청한 경우에만, 별도 승인을 받고 수행
- 기존 이미지 태그 덮어쓰기 금지 (`--replace-local` 명시 없이 동일 로컬 태그 재사용 금지)
- 운영 Kubernetes 리소스 변경 금지 (진단 중 어떤 워크로드도 수정하지 않는다)
- 스캔 대상 소스 디렉터리에 생성 파일 쓰기 금지
- 검증 증거 없이 "조치 완료 / 빌드 성공 / 스캔 통과" 보고 금지
- 레지스트리 자격증명, kubeconfig 내용, 애플리케이션 시크릿을 리포트·로그에 출력 금지
- 도구 자동 설치 금지, 사용자가 지정한 스캐너·런타임을 무단 교체 금지
- 패키지 저장소 추가 및 TLS 검증 비활성화 금지

## 디스패치 경계

| 요청 | 담당 |
|------|------|
| 컨테이너 이미지 CVE 분석·패치·Trivy 비교·export·엑셀 리포트 | **이 스킬** |
| 컨테이너/Kubernetes 보안 설정 진단 (CCE) | `security-check-cce` |
| 소스코드 SAST, 이미지 없는 의존성 CVE, 레포 전반 보안 리뷰 | `보안전문가` 에이전트 |

## 참조 문서

| 파일 | 읽는 시점 |
|------|-----------|
| `docs/SECURITY_CHECK_SETUP.md` | **신규 환경 최초 1회** — 3개 보안 스킬 공통 환경 구성 가이드 |
| `references/safety-policy.md` | 시작 시 필수 — 공통 안전 정책·차단 조건 |
| `references/inputs-and-preflight.md` | 1~2단계 — 입력 정규화 규칙, preflight 점검, 출력 레이아웃 |
| `references/dockerfile-patterns.md` | 6단계 — OS별 패치 Dockerfile 작성 패턴 |
| `references/product-profiles.md` | 7단계 — PostgreSQL/Redis/Java/generic 검증 항목 |
| `references/report-format.md` | 9단계 — `report-input.json` 스키마와 엑셀 워크북 구조 |
| `references/exception-reasons.md` | 9단계 — 예외신청 사유 분류와 문장 작성 규칙 |

## 사전 조건

- 컨테이너 런타임: `docker` 또는 `nerdctl` 중 하나 (버전 기록)
- 취약점 스캐너: `trivy` 로컬 바이너리 또는 컨테이너 실행 가능. 둘 다 불가 시 Harbor 스캔 결과를 기준선으로 사용하되 리포트에 Harbor 스캐너·DB 메타데이터로 라벨링한다
- 레지스트리 접근: 기존 credential helper 또는 사용자가 지정한 robot-account 환경변수명
- 엑셀 산출 시: Python 3 + `openpyxl`. 미설치 시 차단하고 사용자에게 설치 안내 (자동 설치 금지)
- 출력 루트: 사용자 인자 우선, 없으면 `<현재 작업 디렉터리>/outputs`

사전 조건이 비면 해당 경로를 `blocked`로 표시하고 나머지만 진행한다. 임의 우회하지 않는다.

> 신규 환경에서 처음 실행한다면 `docs/SECURITY_CHECK_SETUP.md` 를 먼저 확인한다.

## 실행 절차

1. **입력 수집·정규화** — Harbor 아티팩트 URL / `registry/repo:tag` / `registry/repo@sha256:...` / TXT·CSV 목록 / Dockerfile·Compose·Helm values·Kubernetes YAML 디렉터리를 받아 registry·repository·tag·digest 기준으로 중복 제거한다. digest가 tag보다 우선한다. 자격증명이 포함된 URL은 거부한다. → `references/inputs-and-preflight.md`

2. **Preflight** — 런타임·스캐너 탐지 및 버전 기록, 호스트 OS/아키텍처, 소스 이미지 아키텍처, 레지스트리 연결성, `run-id` 생성, 출력 디렉터리 생성.

#### [GATE 0] 대상·실행 환경 확정
이 GATE를 통과해야 이미지 pull 및 스캔으로 진행한다.
- [ ] 정규화된 대상 이미지 목록과 개수를 사용자에게 제시하고 동의받음
- [ ] 선택된 런타임·스캐너와 버전, 스캐너 DB 갱신시각 기록 완료
- [ ] 출력 루트와 `run-id` 확정, 소스 디렉터리 외부임을 확인
- [ ] 아키텍처 확정 — 호스트와 이미지 아키텍처가 다르면 에뮬레이션 사용 여부를 사용자에게 확인

WARN 처리:
- 스캐너·레지스트리 접근 불가 → 해당 이미지를 `blocked`로 표시하고 나머지만 진행
- 호스트/이미지 아키텍처 불일치로 에뮬레이션 사용 → 검증 결과를 `emulated / not production-verified`로 라벨링하고 네이티브 검증으로 계산하지 않는다

3. **이미지 메타데이터 수집** — 아키텍처, OS, base image, 실행 사용자, entrypoint, command, 패키지 생태계, 애플리케이션 버전을 `metadata.json`에 기록한다.

4. **기준선 스캔** — Trivy(또는 Harbor 리포트)로 `scan-before.json`을 생성한다.

5. **분류** — 동일 CVE·소스 패키지의 중복 패키지 발생을 묶고, 심각도 / fix 가용성 / 런타임 관련성 / 운영 영향 / 조치 난이도로 분류한다.

6. **최소 호환 조치안 설계** — 아래 우선순위로 가장 작은 변경을 선택한다.
   1. 동일 지원 릴리스 라인의 상위 패치 이미지 사용
   2. Debian/Ubuntu/Alpine 패키지 업데이트
   3. 애플리케이션 의존성 업데이트
   4. 미사용 패키지 제거 — 런타임 점검으로 불필요가 입증된 경우에만
   5. 호환 조치가 없으면 예외 문서화
   설계 결과로 digest 고정 패치 Dockerfile을 생성한다. → `references/dockerfile-patterns.md`

#### [GATE 1] 조치 방침 사용자 승인
이 GATE를 통과해야 패치 이미지 빌드로 진행한다.
- [ ] 이미지별 조치 방침(상위 이미지 / 패키지 업데이트 / 예외)과 근거를 사용자에게 제시
- [ ] 애플리케이션 버전 변경 여부와 호환성 영향 명시
- [ ] 생성될 로컬 태그명이 기존 태그와 충돌하지 않음 확인
- [ ] 예외 처리 범위(기본: 잔존 Critical/High/Medium, Low 제외) 확정

WARN 처리:
- 지원되지 않는 패키지 매니저 / OS → 추측 변경 대신 분석만 제공하고 사용자에게 제품 프로파일 또는 스모크 명령을 요청
- 사용자가 Low까지 예외 범위에 포함하도록 요청 → 범위를 리포트에 명시

7. **빌드 + 런타임 검증** — 원본 아키텍처로 새 로컬 태그를 빌드한다(push 없음). 제품 프로파일에 따라 애플리케이션 버전·실행 UID·entrypoint·필수 명령·확장/모듈·스모크 테스트를 실행하고 `validation.txt`에 남긴다. → `references/product-profiles.md`
   - 빌드 실패 → 로그 보존, 성공 형태 산출물 생성 금지
   - 런타임 회귀 → 해당 패치 이미지 거부, 실패한 검증 항목 보고

8. **재스캔·비교** — 최신 DB로 `scan-after.json`을 만들고 기준선과 비교해 심각도별 증감, 잔존·조치 CVE를 산출한다.

9. **산출물 생성** — `summary.md`, `exceptions.md`, `report-input.json`, `container-cve-report.xlsx`를 만든다. 사용자가 요청하면 `.tar.gz` export와 `SHA256SUMS`를 생성한다. → `references/report-format.md`, `references/exception-reasons.md`

#### [GATE 2] 산출물·외부 공유 최종 승인
이 GATE를 통과해야 리포트를 확정하고 push/export 등 외부 영향 작업을 수행한다.
- [ ] before/after 수치가 실제 스캔 결과와 일치하고, 검증 실패·blocked 항목이 리포트에 그대로 표기됨
- [ ] 예외신청 사유가 비기술 독자에게 이해 가능하고 근거 없는 주장이 없음
- [ ] 리포트·로그에 자격증명·시크릿 노출 0건
- [ ] (push 요청 시) 대상 레지스트리·태그와 push 수행을 사용자가 명시적으로 승인

WARN 처리:
- 스캐너 DB가 stale → 보안 결과를 `unverified`로 표기하고 GATE 통과 보류
- 검증이 에뮬레이션으로만 수행됨 → 요약 최상단에 `emulated / not production-verified` 명시

## 출력 레이아웃

```text
outputs/<run-id>/cve/
  summary.md
  exceptions.md
  report-input.json
  container-cve-report.xlsx
  images/<normalized-image>/
    Dockerfile
    metadata.json
    scan-before.json
    scan-after.json
    validation.txt
  exports/
    <image>.tar.gz
    SHA256SUMS
```

## 완료 조건 (DONE WHEN)
- [ ] [GATE] GATE 0 통과 — 대상·런타임·스캐너·run-id 확정
- [ ] [GATE] GATE 1 통과 — 조치 방침 사용자 승인
- [ ] [GATE] GATE 2 통과 — 산출물 검증 및 외부 영향 작업 승인
- [ ] [FILE] `outputs/<run-id>/cve/summary.md` — 요약 존재
- [ ] [FILE] `outputs/<run-id>/cve/container-cve-report.xlsx` — 워크북 존재 (엑셀 요청 시)
- [ ] [FILE] `outputs/<run-id>/cve/images/<image>/scan-after.json` — 이미지별 재스캔 결과 존재 (조치 대상 한정)
- [ ] [CONTENT] `summary.md` contains 스캐너명·버전·DB 갱신시각
- [ ] [MANUAL] 레지스트리 push 여부 — 기본 미수행, 수행 시 사용자 승인 기록 확인
- [ ] [MANUAL] 검증 실패/blocked 항목이 리포트에 누락 없이 표기되었는지 확인
