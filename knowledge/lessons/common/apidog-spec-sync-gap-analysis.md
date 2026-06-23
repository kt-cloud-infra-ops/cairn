---
tags:
  - type/guide
  - domain/api
  - service/luppiter
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# Luppiter Web ↔ Apidog 스펙 현행화 갭 분석

## 개요

`luppiter_web` 코드 기준 API 매핑과 Apidog export 스펙 간 차이를 빠르게 정량화했다.

분석 일시: 2026-02-25

---

## 분석 기준

- 코드 기준:
  - `workspace/luppiter_web/src/main/java/com/ktc/luppiter/web/controller/*Controller.java`
  - `workspace/luppiter_web/src/main/java/com/ktc/luppiter/external/api/controller/*Controller.java`
- 스펙 기준:
  - Apidog `projectId=992853` export 결과
  - `/tmp/luppiter-openapi.json`
- 추출 방식:
  - 컨트롤러 매핑 어노테이션(`@RequestMapping/@GetMapping/...`)에서 path 문자열 수집
  - OpenAPI `paths` key와 set 비교

---

## 핵심 결과

| 항목 | 수치 |
|------|------|
| 코드 경로 수 (`code_paths`) | 207 |
| 스펙 경로 수 (`spec_paths`) | 103 |
| 코드에는 있고 스펙에 없는 경로 (`missing_in_spec`) | 134 |
| 스펙에는 있고 코드에 없는 경로 (`extra_in_spec`) | 30 |

의미:
- 현행화는 진행 중이나, 전체 기준으로는 아직 큰 갭이 존재한다.
- `api/ctl`, `api/evt`, `api/mng` 계열에서 누락이 집중되는 경향이 있다.

---

## 샘플 갭

### missing_in_spec 예시

- `/api/cmm/controlAreaList`
- `/api/ctl/groupCheck`
- `/api/evt/comm/serviceDeviceList`
- `/api/evt/eventHostInfo`
- `/api/ctl/updateRespDeptConcall/{currentResp}`

### extra_in_spec 예시

- `/api/ctl/insertSmsRule`
- `/api/evt/refine/save`
- `/dashboard/manage`
- `/dashboard/specific`
- `/dashboard/urlMonitoring`

---

## 권장 현행화 전략

### 1단계: 경로/메서드 동기화 (0.5~1일)

- 누락 엔드포인트 우선 반영
- 제거/이관된 경로 여부 확인 후 spec 정리

### 2단계: 요청/응답 스키마 정합화 (2~3일)

- body, query, path 파라미터 필수값 점검
- 대표 응답 예시와 에러 코드 보강

### 3단계: 검증/안정화 (1~2일)

- 코드 ↔ spec diff 재실행
- 실제 호출 테스트 또는 mock 검증
- 운영 반영 전 리뷰 체크리스트 통과

총 공수(1인): 3.5~6일

---

## 바로 실행 가능한 체크리스트

- [ ] `export-openapi` 결과를 기준 스냅샷으로 고정
- [ ] `missing_in_spec` 134개를 도메인별(`evt/ctl/mng`)로 분류
- [ ] 1차 반영 후 diff 재실행
- [ ] 변경 내역을 Apidog 프로젝트 릴리즈 노트로 남김

---

## 참고 파일

- `workspace/luppiter_web/src/main/java/com/ktc/luppiter/web/controller/`
- `workspace/luppiter_web/src/main/java/com/ktc/luppiter/external/api/controller/`
- `/tmp/luppiter-openapi.json`

