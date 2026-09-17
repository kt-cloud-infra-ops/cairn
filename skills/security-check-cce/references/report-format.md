# CCE 리포트 형식

## 1. 리포트 입력 JSON

```json
{
  "run": {
    "id": "20260917-142500-a1b2",
    "generatedAt": "2026-09-17T14:25:00+09:00",
    "runtime": {"name": "nerdctl", "version": "2.0.0"}
  },
  "baseline": {
    "guidePageId": "1925678414",
    "guideVersion": 8,
    "itemsPageId": "1925088343",
    "itemsVersion": 5,
    "fetchedAt": "2026-09-17T14:20:00+09:00",
    "applicableItems": ["U-05", "U-06"],
    "naItems": ["U-01", "U-02", "U-03", "U-04", "U-18", "U-35"]
  },
  "targets": [
    {
      "image": {"reference": "registry/repo@sha256:...", "architecture": "amd64", "os": "debian"},
      "containerRun": {"user": "1000", "userOverridden": false, "emulated": false, "cleanup": "ok"},
      "items": [
        {
          "code": "U-05",
          "name": "패스워드 파일 보호",
          "result": "Good|Vulnerable|N/A|Blocked|Needs Review",
          "risk": "Critical|High|Medium|Low|Info",
          "evidence": ["evidence/<image>/<digest>/result_1.txt:42"],
          "source": "script_1|script_2|manifest",
          "remediation": "",
          "difficulty": "low|medium|high",
          "impact": "low|medium|high",
          "recheck": "passed|failed|not-applicable"
        }
      ],
      "remediationFiles": ["remediation/kubernetes-patch.yaml"]
    }
  ]
}
```

판정 규칙:

- 권한 거부·출력 누락 → `Blocked` 또는 `Needs Review` (절대 `Good`/`Vulnerable` 아님)
- 항목명이 기준 페이지와 달라졌으면 `Needs Review`로 두고 차이를 기록

## 2. 엑셀 워크북 구조

시트 5개, 순서 고정.

### `요약`
- 전체 / 적용 / Good / Vulnerable / N/A / Blocked 건수
- 준수율(%) — 분모는 **적용 항목**, N/A·Blocked 처리 기준을 각주로 명시
- 위험도 분포, 이미지·워크로드 요약, 차트

### `진단 결과`
- 대상, CCE 코드, 항목명, 결과, 위험도, 증거, 조치 방안, 난이도, 영향, 참조 링크

### `조치 결과`
- 원래 값, 변경 값, 산출 파일, 재점검 결과, 잔존 위험

### `예외 신청`
- 필드 순서 고정: `CCE 코드 / 대상 / 항목 / 위험도`
- 사유 분류 + 간결한 비기술 사유
- 기본 포함 범위: 사용자가 선택한 `Vulnerable` 및 `Blocked` 항목

### `기준 정보`
- Confluence URL, 페이지 제목, 페이지 버전 번호, 수집 시각
- 적용 항목 목록, N/A 규칙
- 런타임·실행 컨텍스트(override 여부), 스크립트 출처와 SHA-256

## 3. 워크북 품질 요건

- [ ] 헤더 고정 + 자동필터
- [ ] 요약 수치는 표 범위 참조 수식
- [ ] 결과 상태별 색상
- [ ] **필터 대상 표 내부 병합 0건** — 병합은 대시보드/제목 영역에서만
- [ ] 수식 오류 셀 0건
- [ ] 시트명이 위 5개와 정확히 일치
- [ ] `기준 정보` 시트에 페이지 버전 메타데이터 존재

생성은 Python 3 + `openpyxl`. 미설치 시 차단하고 설치 안내만 한다 (자동 설치 금지). 저장 전 시트명·필터·freeze pane·수식·병합 범위·오류 셀을 검사한다.

## 4. `summary.md`

- 최상단: `Confluence mode: READ ONLY. No page, comment, attachment, or metadata changes will be made.`
- 기준 페이지 ID·버전·수집시각
- 대상별 Good/Vulnerable/N/A/Blocked 집계와 준수율
- `Blocked` / `Needs Review` 항목 별도 섹션 (숨기지 않는다)
- root override·에뮬레이션 사용 시 해당 사실 명시
- 조치 파일 목록과 **적용 주체는 사용자**임을 명시

## 5. `exceptions.md`

- 항목별: CCE 코드 / 대상 / 항목 / 위험도 / 사유 분류 / 사유
- 사유는 1~2문장, 비기술 독자 기준
- 근거 없는 "영향 없음" 단정 금지 — 대체 통제 또는 후속 계획을 함께 적는다
- `Blocked`는 조치 예외가 아니라 **후속 과제**로 구분해 표기한다
