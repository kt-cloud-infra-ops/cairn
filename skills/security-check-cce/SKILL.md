---
name: security-check-cce
description: "컨테이너 이미지·Kubernetes 보안 설정(CCE) 진단 스킬. 매 실행마다 사내 Confluence 진단 가이드와 POD CCE 항목표를 읽기 전용으로 재수집해 최신 기준을 확정하고, Harbor 이미지를 digest로 pull → 일회용 컨테이너에서 CCE 진단 스크립트 실행 → Kubernetes/Helm 매니페스트 점검 → 조치 파일 생성 및 재점검 → Markdown·Excel·예외신청 리포트를 산출할 때 사용한다. 이미지 CVE 조치는 security-check-cve, 소스코드 SAST는 보안전문가 에이전트 담당."
triggers: [CCE, CCE 진단, POD CCE, 컨테이너 보안 설정 점검, Kubernetes 보안 설정 점검, 이미지 CCE 조치, CCE 미조치 사유, 보안 설정 취약점]
---

## 스킬 규칙

### ALWAYS
- **순서**: Confluence READ ONLY 선언 → 기준 페이지 재수집·파싱 → [GATE 0] → 대상 해석·pull → [GATE 1] → 일회용 컨테이너 진단 → 매니페스트 점검 → 조치 파일 생성·재점검 → [GATE 2] → 리포트 산출
- 실행 시작 시 아래 문장을 그대로 출력한다:
  `Confluence mode: READ ONLY. No page, comment, attachment, or metadata changes will be made.`
- 기준 페이지 2개를 **매 실행마다 다시 수집**한다 (계속 갱신되는 문서이므로 캐시·내장 사본을 현재 기준으로 쓰지 않는다)
- 이미지는 digest로 고정해 pull한다 (실행 중 tag가 바뀌는 상황 차단)
- 진단 컨테이너는 고유 이름으로 생성하고, 성공·실패 모두 **반드시 제거**하되 수집한 로그·결과 파일은 보존한다
- 결과는 `Good / Vulnerable / N/A / Blocked / Needs Review` 5분류로 기록한다
- 조치 파일은 `<출력루트>/<run-id>/cce/remediation/` 에 **복사본으로만** 생성한다
- 이미지/파일시스템 항목은 조치된 로컬 이미지에 스크립트를 재실행해 재점검한다. Kubernetes/Helm 항목은 생성된 매니페스트를 파싱해 재점검한다

### NEVER
- **[GATE 0] 통과 전 이미지 pull·컨테이너 실행 금지**
- **[GATE 1] 통과 전 root 권한 진단 컨테이너 실행 금지**
- **[GATE 2] 통과 전 리포트·예외신청서 확정 산출 금지**
- **Confluence 변경 API 사용 절대 금지** — 페이지·댓글·첨부·메타데이터 생성/수정/삭제 일체 금지 (`references/confluence-policy.md` 금지 목록 참조)
- 운영 Kubernetes 리소스 변경 금지 — 진단은 전량 읽기 전용
- 원본 매니페스트·Helm values·Dockerfile 직접 수정 금지 (복사본에만 조치 작성)
- 스크립트 실행을 위해 원본 이미지에 패키지 설치 금지 (shell 없는 distroless는 `Blocked`)
- 권한 거부 결과를 `Good` 또는 `Vulnerable`로 변환 금지 → `Blocked` 또는 `Needs Review`
- 이미지 push 금지
- 기준 페이지를 읽지 못한 상태에서 오래된 사본으로 진단 진행 금지 → 중단하거나 기준선을 `blocked` 처리
- 이미지 스크립트 결과만으로 워크로드(Kubernetes) 항목을 `조치 완료`로 표기 금지

## 디스패치 경계

| 요청 | 담당 |
|------|------|
| 컨테이너/Kubernetes 보안 설정 진단·조치 (사내 CCE 기준) | **이 스킬** |
| 컨테이너 이미지 CVE 분석·패치·재스캔 | `security-check-cve` |
| 소스코드 SAST, 이미지 없는 의존성 CVE, 레포 전반 보안 리뷰 | `보안전문가` 에이전트 |

## 참조 문서

| 파일 | 읽는 시점 |
|------|-----------|
| `docs/SECURITY_CHECK_SETUP.md` | **신규 환경 최초 1회** — 3개 보안 스킬 공통 환경 구성 가이드 |
| `../security-check-cve/references/safety-policy.md` | 시작 시 필수 — 두 스킬 공통 안전 정책 |
| `references/confluence-policy.md` | 시작 시 필수 — 읽기 전용 정책, 허용/금지 도구 목록 |
| `config/cce.env.example` | 신규 환경 — `.cairn/profile/cce.env` 템플릿 (기준 문서 URL) |
| `references/cce-baseline.md` | 1~2단계 — 기준 페이지 식별자, 항목 코드 체계, N/A 규칙, 파싱 결과 구조 |
| `references/container-diagnosis.md` | 4~6단계 — pull·일회용 컨테이너 실행·스크립트 수집·결과 회수·정리 |
| `references/manifest-checks.md` | 7~8단계 — Kubernetes/Helm 점검 항목과 조치 파일 생성 |
| `references/report-format.md` | 9단계 — CCE 리포트 JSON 스키마와 엑셀 워크북 구조 |

## 사전 조건

- Atlassian Confluence **읽기 전용** 접근 (조회/검색 도구만)
- 컨테이너 런타임: `docker` 또는 `nerdctl`
- Harbor 접근: 기존 credential helper 또는 사용자 지정 robot-account 환경변수명
- 엑셀 산출 시: Python 3 + `openpyxl` (미설치 시 차단, 자동 설치 금지)
- 출력 루트: 사용자 인자 우선, 없으면 `<현재 작업 디렉터리>/outputs`

> 신규 환경에서 처음 실행한다면 `docs/SECURITY_CHECK_SETUP.md` 를 먼저 확인한다.

## 실행 절차

1. **READ ONLY 선언 + 기준 수집** — 선언 문장을 출력한 뒤, 진단 가이드 페이지와 POD CCE 항목 페이지를 조회 도구로 다시 읽는다. 페이지 ID·제목·버전 번호·수집 시각을 기록한다. → `references/confluence-policy.md`, `references/cce-baseline.md`

2. **기준 파싱** — 현재 진단 명령, 적용 항목 코드, N/A 규칙, 첨부 스크립트 링크 또는 코드블록 스크립트를 추출해 `evidence/confluence-baseline.json`에 저장한다. 페이지가 읽히지 않으면 진단을 중단하거나 기준선을 `blocked`로 표시한다.

3. **대상 해석** — Harbor 아티팩트 URL / 이미지 참조 / TXT·CSV 목록 / Dockerfile·Helm·Kubernetes 파일에서 발견한 참조를 정규화하고, Harbor API로 repository·tag·digest·아키텍처·스캔 메타데이터를 확인한다.

#### [GATE 0] 기준선·대상 확정
이 GATE를 통과해야 이미지 pull 및 컨테이너 실행으로 진행한다.
- [ ] READ ONLY 선언 출력 완료, 이번 실행에서 사용할 Confluence 도구가 조회 계열뿐임을 확인
- [ ] 기준 페이지 2개의 ID·버전·수집시각 기록 완료 (현재 시점 재수집)
- [ ] 적용 항목 코드와 N/A 항목 목록 확정
- [ ] 진단 대상 이미지의 digest·아키텍처 확정, `run-id`와 출력 경로 확정

WARN 처리:
- 기준 페이지 조회 실패 → 중단. 과거 사본을 현재 기준으로 사용하지 않는다
- 항목표 파싱 실패 → 해당 항목군을 `Blocked`로 두고 매니페스트 점검만 진행

4. **스크립트 확보** — 우선순위: ① 사용자 제공 로컬 스크립트 디렉터리 → ② 조회된 페이지 본문의 첨부 다운로드 링크(읽기 전용 세션) → ③ 페이지 코드블록 내 스크립트. `scriptSource`, 페이지 ID·버전, 첨부 URL 또는 콘텐츠 해시, 로컬 SHA-256을 기록한다. 확보 실패 시 스크립트 기반 항목은 `Blocked`.

5. **이미지 pull** — digest 고정, 명시적 `--platform`.

#### [GATE 1] 진단 실행 컨텍스트 확인
이 GATE를 통과해야 컨테이너 진단을 실행한다.
- [ ] 사용할 런타임과 진단 명령 계획을 사용자에게 제시
- [ ] 스크립트 출처와 SHA-256 기록 완료 (미확보 시 Blocked 범위 합의)
- [ ] 기본 실행 컨텍스트 = 이미지 설정 사용자. root 진단이 필요하면 **사유와 함께 사용자 승인**을 받고 기록
- [ ] 생성될 임시 컨테이너 이름이 고유하고, 정리(cleanup) 방식이 확정됨

WARN 처리:
- shell 없는 distroless 이미지 → `Blocked` 처리. 스크립트 실행을 위해 이미지를 변조하지 않는다
- 아키텍처 에뮬레이션 사용 → 결과에 `emulated / not production-verified` 라벨링

6. **일회용 컨테이너 진단** — keep-alive 명령으로 컨테이너를 띄우고, 스크립트를 복사·실행 권한 부여·실행한 뒤 결과 파일을 호스트로 회수하고 컨테이너를 제거한다. 결과 파일의 **실제 생성 위치를 확인**한다(가이드의 예시 경로와 실제 실행 디렉터리가 다를 수 있다). → `references/container-diagnosis.md`

7. **매니페스트 점검** — 이미지·Dockerfile·Kubernetes 워크로드·Helm values·securityContext 증거를 읽기 전용으로 수집·점검한다. → `references/manifest-checks.md`

8. **매핑·분류·조치 생성** — 스크립트와 매니페스트 증거를 현재 CCE 항목 코드에 매핑하고 5분류로 판정한다. 필요한 경우 가장 작은 안전 조치를 `remediation/` 아래 복사본(`Dockerfile`, `kubernetes-patch.yaml`, `values-cce.yaml`)으로 생성한다. Dockerfile 조치가 필요하면 새 로컬 태그로 빌드한 뒤 **동일 스크립트를 재실행**해 재점검한다.

9. **리포트 산출** — `summary.md`, `exceptions.md`, `container-cce-report.xlsx`, 원본 증거 파일을 생성한다. → `references/report-format.md`

#### [GATE 2] 산출물·외부 공유 최종 승인
이 GATE를 통과해야 리포트를 확정한다.
- [ ] 이번 실행에서 Confluence 변경 호출 0건임을 재확인 (실행 로그·도구 호출 증거 점검)
- [ ] 판정 결과가 실제 증거 파일과 일치하고, `Blocked`/`Needs Review`가 그대로 표기됨
- [ ] 워크로드 항목이 매니페스트 재파싱으로 재점검되었음 (이미지 스크립트 결과로 대체하지 않음)
- [ ] 기준 정보(페이지 ID·버전·수집시각)가 리포트에 기재됨
- [ ] 리포트·로그에 자격증명·kubeconfig·시크릿 노출 0건

WARN 처리:
- root override로 얻은 결과 포함 → 해당 항목에 실행 컨텍스트 override 사실 표기
- 첨부 스크립트 미확보 → 리포트에 누락 사실과 영향 항목 범위를 명시

## 출력 레이아웃

```text
outputs/<run-id>/cce/
  summary.md
  exceptions.md
  container-cce-report.xlsx
  remediation/
    Dockerfile
    kubernetes-patch.yaml
    values-cce.yaml
  evidence/
    confluence-baseline.json
    harbor-artifact.json
    script-manifest.json
    pull-and-container-log.txt
    <normalized-image>/<digest>/
      result_1.txt
      result_2.txt
    raw-command-output/
```

## 완료 조건 (DONE WHEN)
- [ ] [GATE] GATE 0 통과 — 기준선 재수집·대상·READ ONLY 확정
- [ ] [GATE] GATE 1 통과 — 진단 실행 컨텍스트 및 root override 승인
- [ ] [GATE] GATE 2 통과 — 산출물 검증 및 Confluence 무변경 재확인
- [ ] [FILE] `outputs/<run-id>/cce/summary.md` — 요약 존재
- [ ] [FILE] `outputs/<run-id>/cce/evidence/confluence-baseline.json` — 기준선 증거 존재
- [ ] [FILE] `outputs/<run-id>/cce/container-cce-report.xlsx` — 워크북 존재 (엑셀 요청 시)
- [ ] [CONTENT] `summary.md` contains 기준 페이지 ID·버전·수집시각
- [ ] [CONTENT] `summary.md` contains `Confluence mode: READ ONLY`
- [ ] [MANUAL] 임시 진단 컨테이너 잔존 0건 확인
- [ ] [MANUAL] 원본 매니페스트·Helm values 수정 0건 확인
