# CVE 리포트 형식

## 1. `report-input.json` 스키마

엑셀·Markdown 산출물의 단일 입력. 파괴적 작업을 재실행하지 않고 리포트를 재생성할 수 있도록 이 파일을 먼저 확정한다.

```json
{
  "run": {
    "id": "20260917-142500-a1b2",
    "generatedAt": "2026-09-17T14:25:00+09:00",
    "scanner": {"name": "Trivy", "version": "0.74.0", "dbUpdatedAt": "2026-09-17T09:00:00Z"}
  },
  "images": [
    {
      "source": "registry/repository@sha256:...",
      "output": "registry/repository:tag-patched-20260917-142500-a1b2",
      "os": "debian",
      "architecture": "amd64",
      "application": "PostgreSQL",
      "applicationVersionBefore": "16.14",
      "applicationVersionAfter": "16.15",
      "validation": "passed|failed|blocked|emulated",
      "findings": [
        {
          "cveId": "CVE-2026-0001",
          "package": "libxml2",
          "installedVersion": "2.9.14+dfsg-1.3",
          "fixedVersion": "2.9.14+dfsg-1.3+deb12u1",
          "severity": "CRITICAL|HIGH|MEDIUM|LOW",
          "description": "...",
          "status": "remediated|residual|exception|false-positive|blocked",
          "remediation": "...",
          "difficulty": "low|medium|high",
          "impact": "low|medium|high",
          "exceptionReason": "",
          "evidenceUrl": ""
        }
      ]
    }
  ]
}
```

## 2. 엑셀 워크북 구조

시트 5개, 순서 고정.

### `요약`
- 총 이미지 수, 고유 CVE 수
- Critical / High / Medium / Low 건수
- remediated / residual / exception / blocked / false-positive 건수
- 심각도 분포 차트, 조치 상태 차트
- 이미지별 결과 요약 표
- 스캐너명·버전·DB 갱신시각

### `이미지별 결과`
- 이미지 출처, tag/digest, OS, 아키텍처, 애플리케이션 버전
- before/after 심각도 건수
- 빌드 상태, 런타임 검증 상태, 스캔 상태
- 출력 이미지 참조, 산출물 경로

### `CVE 상세`
- 이미지, CVE ID, 패키지, 설치 버전, 수정 버전, 심각도, 설명
- 조치 내용, 난이도, 운영 영향, 상태, 근거 URL
- **CVE 1건 = 1행 원자성 유지.** 이미지 필드는 행마다 반복 기재한다
- 이미지 그룹은 **교차 음영(banding) + 테두리**로 시각 구분한다
- 자동필터 범위 안의 데이터 셀은 **병합 금지**

### `조치 결과`
- 생성된 Dockerfile, 패키지·애플리케이션 변경 내역
- 빌드 결과, 테스트 결과, before/after 건수, 잔존 위험

### `예외 신청`
- 필드 순서 고정: `CVE ID / OS / 패키지 / 심각도`
- 사유 분류 + 비기술 독자용 간결 사유
- 요청 범위 밖 심각도는 제외 (기본: Low 제외)

## 3. 워크북 품질 요건

- [ ] 헤더 고정(freeze panes) + 자동필터
- [ ] 요약 수치는 **표 범위를 참조하는 수식**으로 작성 (하드코딩 금지)
- [ ] 심각도 색상 적용, 열 너비 상한, 설명 셀 줄바꿈
- [ ] 필터 대상 표 내부 병합 0건 — 제목/섹션 헤더 병합은 표 바깥에서만 허용
- [ ] 수식 오류 셀(`#REF!`, `#VALUE!` 등) 0건
- [ ] 시트명이 위 5개와 정확히 일치

## 4. 생성 방식

- Python 3 + `openpyxl` 사용
- `openpyxl` 미설치 시 **차단**하고 설치 안내만 한다 (자동 설치 금지)
- 저장 전에 시트명·필터·freeze pane·수식·병합 범위·오류 셀을 검사한다

## 5. `summary.md`

- 실행 정보: run-id, 생성시각, 스캐너·DB 버전
- 대상 이미지 수와 전체 before/after 요약
- 이미지별 한 줄 결과
- 검증 실패·blocked 항목 별도 섹션 (숨기지 않는다)
- 에뮬레이션 검증 시 최상단 경고 문구
