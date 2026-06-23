---
tags:
  - type/guide
  - domain/java/mybatis
  - domain/db/query
  - audience/claude
---

> 상위: [java](README.md) · [lessons](../README.md)

# MyBatis SQL 패턴 가이드

## 1. resultType=HashMap 시 SQL alias = Map 키

### 규칙

`resultType="java.util.HashMap"` 사용 시, SELECT 절의 **컬럼 alias가 곧 Map의 키 이름**이 된다.

### 함정 사례

```xml
<!-- SQL: alias는 api_token -->
SELECT token as api_token FROM c01_<your_service>_info
```

```java
// Java: "token"으로 접근 → null 반환!
String token = serviceInfo.get("token").toString();  // NPE

// 올바른 접근:
String token = serviceInfo.get("api_token").toString();
```

### 검증 방법

1. Mapper XML의 SELECT 절에서 `as` alias 확인
2. Java 코드에서 `map.get("키")` 호출부와 대조
3. alias 없으면 컬럼명이 키 (PostgreSQL은 소문자 변환)

---

## 2. UNION ALL 시 컬럼 타입/의미 정합성

### 규칙

UNION ALL로 다른 테이블을 합칠 때, **같은 위치의 컬럼이 같은 의미**여야 한다.

### 주의 사항

```sql
-- inventory_master: IP 기반
SELECT zabbix_ip, host_nm, control_area ...

UNION ALL

-- cmon_service_inventory_master: 서비스 기반
SELECT target_name AS zabbix_ip,   -- 키 타입이 다름 (IP vs 서비스명)
       service_nm AS host_nm,
       svc_type AS control_area     -- 값 체계가 다름 (VM/서버 vs Service/Platform)
```

- 하위 쿼리에서 빈 문자열(`''`)이나 NULL로 채운 컬럼은 후속 JOIN/WHERE에서 의도치 않은 매칭 발생 가능
- `WHERE target_ip IN (...)` 조건에 빈 문자열 포함 주의

---

관련: [<YOUR_ORG> 스타일](kt-cloud-style.md) · [디자인 패턴](design-patterns.md) · [SRE 코딩](sre-coding.md) · [코드 리뷰 함정](code-review-traps.md) · [DB 최적화](../db/database-optimization.md)

*최종 업데이트: 2026-02-10*
