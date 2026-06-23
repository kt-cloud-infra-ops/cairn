---
tags:
  - type/guide
  - domain/java
  - audience/claude
---

> 상위: [java](README.md) · [lessons](../README.md)

# Java 코드 리뷰 함정 패턴

## 1. List.of / Map.of 괄호 위치 함정

### 문제 코드

```java
// 버그: List에 3개 원소 (Map, String, Long)
List.of(Map.of("active_since", startEpoch), "active_till", endEpoch)
// 결과: [{active_since=12345}, "active_till", 67890]
```

### 올바른 코드

```java
// 정상: List에 1개 원소 (2키 Map)
List.of(Map.of("active_since", startEpoch, "active_till", endEpoch))
// 결과: [{active_since=12345, active_till=67890}]
```

### 감지 방법

- `Map.of()` 닫는 괄호 `)` 뒤에 바로 `,`가 오면 의심
- Map 키-값 쌍 개수가 홀수면 의심 (Map.of는 짝수 인자)
- IDE에서 `List.of` 인자 수 확인

### 발견 사례

- LUPR-701: MaintenanceAlarmServiceJob.getObservabilityInfo() — ClassCastException 유발

---

## 2. 설계 문서 라인번호 불일치

### 문제

설계 문서에 기재된 소스 파일 라인번호가 실제와 다른 경우.

### 사례

- MaintenanceAlarmServiceMapper.xml: 설계 문서에 L431, L696, L857 기재 → 실제 파일 203줄
- 원인: 다른 버전/브랜치 기준으로 작성, 또는 다른 파일과 혼동

### 대응

- 설계 문서의 라인번호를 그대로 신뢰하지 말고 **반드시 grep으로 실제 파일 검증**
- 검증 후 설계 문서에 검증일자와 실제 라인번호 갱신

---

관련: [KT Cloud 스타일](kt-cloud-style.md) · [디자인 패턴](design-patterns.md) · [SRE 코딩](sre-coding.md) · [MyBatis](mybatis-sql-patterns.md)

*최종 업데이트: 2026-02-10*
