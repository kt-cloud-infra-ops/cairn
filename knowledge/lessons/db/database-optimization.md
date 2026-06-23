---
tags:
  - type/guide
  - domain/db
  - audience/claude
---

> 상위: [db](README.md) · [lessons](../README.md)

# 학습: 데이터베이스 최적화 패턴 (PostgreSQL/MySQL)

## 날짜
2026-01-28

## 세션/프로젝트
Observability 연동 프로젝트 - 데이터베이스 성능 최적화

## 배운 것

### 1. TRUNCATE vs DELETE: 성능 비교

대용량 테이블 초기화 시 선택해야 할 전략

**DELETE 사용 시**:
```sql
-- 각 행을 하나씩 삭제 (트랜잭션 로그 기록)
DELETE FROM cmon_event_info_tmp WHERE processed_yn = 'Y';

-- 특징:
-- - WHERE 절로 조건부 삭제 가능
-- - 개별 행 이벤트 트리거 발동
-- - 트랜잭션 로그 생성 (느림)
-- - 롤백 가능
```

**TRUNCATE 사용 시**:
```sql
-- 전체 테이블 초기화 (구조만 유지)
TRUNCATE TABLE cmon_event_info_tmp;

-- 특징:
-- - 전체 테이블만 초기화 가능 (WHERE 불가)
-- - 트리거 미발동
-- - 트랜잭션 로그 최소화 (매우 빠름)
-- - 롤백 가능 (트랜잭션 내에서)
-- - AUTO_INCREMENT 초기화
```

**성능 비교**:
```
DELETE (1M 행):     ~5-10초
TRUNCATE (1M 행):   ~100ms

성능 차이: 50-100배
```

**선택 기준**:

| 상황 | 추천 | 이유 |
|------|------|------|
| 임시 테이블 전체 초기화 | TRUNCATE | 매우 빠르고 구조 유지 |
| 조건부 삭제 필요 | DELETE | WHERE 절 사용 가능 |
| 트리거 실행 필요 | DELETE | 각 행마다 트리거 발동 |
| 대용량 배치 초기화 | TRUNCATE | 성능 우선 |
| 감사/로깅 필요 | DELETE | 트랜잭션 로그 생성 |

**구현 예시**:
```java
@Transactional
public void cleanupTempTable() {
    // 임시 테이블 전체 초기화 (매 Job마다)
    // TRUNCATE이 DELETE보다 100배 빠름
    jdbcTemplate.execute("TRUNCATE TABLE cmon_event_info_tmp");
}

@Transactional
public void deleteProcessedEvents() {
    // 특정 조건의 이벤트만 삭제
    // WHERE 절이 필요하므로 DELETE 사용
    jdbcTemplate.update(
        "DELETE FROM cmon_event_info_tmp WHERE processed_yn = 'Y' " +
        "AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)"
    );
}
```

### 2. 테이블 파티션 전략: Range 파티션

대용량 이벤트 테이블(cmon_event_info)의 성능 향상을 위한 파티셔닝

**파티션 개요**:
- **목표**: 수년치 이벤트 데이터를 관리하면서 쿼리 성능 유지
- **전략**: 월(Month) 기반 Range 파티션
- **효과**: 테이블 스캔 시 필요한 파티션만 접근

**DDL 예시** (MySQL):
```sql
CREATE TABLE cmon_event_info (
    event_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    event_type VARCHAR(50),
    last_occu_time VARCHAR(12),  -- YYYYMMDDHH24MI
    created_at DATETIME,
    processed_yn CHAR(1)
) PARTITION BY RANGE (YEAR_MONTH(created_at)) (
    PARTITION p202401 VALUES LESS THAN (202402),
    PARTITION p202402 VALUES LESS THAN (202403),
    PARTITION p202403 VALUES LESS THAN (202404),
    -- ...
    PARTITION p202412 VALUES LESS THAN (202501),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

**PostgreSQL 버전**:
```sql
CREATE TABLE cmon_event_info (
    event_id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50),
    last_occu_time VARCHAR(12),
    created_at TIMESTAMP,
    processed_yn CHAR(1)
) PARTITION BY RANGE (DATE_TRUNC('month', created_at));

CREATE TABLE cmon_event_info_202401 PARTITION OF cmon_event_info
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE cmon_event_info_202402 PARTITION OF cmon_event_info
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

**파티션의 이점**:

| 이점 | 설명 | 효과 |
|------|------|------|
| 빠른 쿼리 | Partition Pruning | WHERE created_at >= '2024-01' 조건 시 해당 파티션만 스캔 |
| 빠른 삭제 | Partition Drop | 오래된 데이터는 파티션 통째로 DROP (매우 빠름) |
| 인덱스 축소 | 작은 인덱스 | 각 파티션별 인덱스 생성 → 캐시 효율 향상 |
| 유지보수 | 병렬 작업 | 각 파티션 독립적으로 관리 가능 |

**고려사항**:
- JOIN 성능: 파티션 컬럼이 다르면 성능 저하 가능
- 인덱스: 파티션 컬럼이 인덱스에 포함되어야 함
- 자동화: 매월/분기마다 새 파티션 추가 자동화 필요

**자동 파티션 추가 프로시저**:
```sql
-- MySQL
DELIMITER //
CREATE PROCEDURE add_monthly_partition()
BEGIN
    DECLARE next_month INT;
    SET next_month = DATE_FORMAT(DATE_ADD(NOW(), INTERVAL 1 MONTH), '%Y%m%d');

    ALTER TABLE cmon_event_info
    ADD PARTITION (
        PARTITION CONCAT('p', next_month)
        VALUES LESS THAN (next_month + 100)
    );
END//
DELIMITER ;

-- 매달 첫날 실행
-- 0 0 1 * * root mysql -e "CALL add_monthly_partition();"
```

### 3. 인덱스 최적화

시간 범위 쿼리(매분 실행)에 최적화된 인덱스

**쿼리 패턴**:
```java
// NotificationJob에서 매분 실행
List<CmonEventInfo> eventsToNotify = repository.findByLastOccuTimeAndNotifiedYn(
    getCurrentMinute(),  // YYYYMMDDHH24MI 형식
    'N'
);
```

**최적 인덱스**:
```sql
-- MySQL
CREATE INDEX idx_notification ON cmon_event_info
    (last_occu_time, notified_yn, created_at DESC);

-- 또는 파티션 키와 함께
CREATE INDEX idx_notification ON cmon_event_info
    (notified_yn, created_at DESC)
    PARTITION BY RANGE (YEAR_MONTH(created_at));
```

**쿼리 최적화**:
```sql
-- 좋은 쿼리 (인덱스 활용)
SELECT * FROM cmon_event_info
WHERE notified_yn = 'N'
  AND created_at >= NOW() - INTERVAL 5 MINUTE
ORDER BY created_at DESC
LIMIT 1000;

-- 피할 쿼리 (인덱스 못 탐)
SELECT * FROM cmon_event_info
WHERE last_occu_time = DATE_FORMAT(NOW(), '%Y%m%d%H%i');
-- → 문자열 비교, 매분 달라짐, Range 불가
```

### 4. PostgreSQL DDL 리뷰 체크포인트 (2026-02-23 O11y 배포 리뷰)

#### 인덱스 이름 고유성
```sql
-- 잘못된 예: 같은 이름으로 두 인덱스 생성 → 두 번째가 실패
CREATE INDEX IF NOT EXISTS idx_event_info_type ON cmon_event_info(type);
CREATE INDEX IF NOT EXISTS idx_event_info_type ON cmon_event_info(system_code);
-- → 두 번째 인덱스는 이미 존재한다고 판단하여 생성 안 됨!

-- 올바른 예: 고유한 이름 사용
CREATE INDEX IF NOT EXISTS idx_event_info_type ON cmon_event_info(type);
CREATE INDEX IF NOT EXISTS idx_event_info_system_code ON cmon_event_info(system_code);
```

#### EXCEPTION 블록과 savepoint
```sql
-- PostgreSQL 프로시저의 EXCEPTION 블록은 암묵적 savepoint 사용
-- 블록 안에서 rollback을 명시하면 의도와 다르게 동작할 수 있음
BEGIN
    -- 작업 수행
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'error: %', SQLERRM;
        rollback;  -- ← 이미 savepoint로 롤백됨, 이 줄은 실행 안 됨
                   -- (RAISE EXCEPTION이 먼저 제어 이전)
END;
```

#### 테이블명 일관성 검증
DDL과 애플리케이션 SQL(MyBatis 등) 간 테이블명 불일치 주의:
- DDL: `d00_service_inventory_master`
- Mapper XML: `cmon_service_inventory_master`
- 프로시저: `d00_service_inventory_master`
→ **배포 전 반드시 grep으로 전체 참조 확인**

## 적용 가능한 상황

1. **임시 테이블 초기화**: TRUNCATE 사용 (100배 빠름)
2. **대용량 이벤트 테이블**: Range 파티션 (파티션 프루닝)
3. **시계열 데이터**: 월/분기 기반 파티셔닝
4. **오래된 데이터 삭제**: DROP PARTITION (INSERT/DELETE보다 매우 빠름)
5. **조건부 삭제**: DELETE 사용 (WHERE 절 필요)

## 핵심 체크리스트

데이터베이스 최적화 작업 시:

- [ ] 임시 테이블은 TRUNCATE 사용 (DELETE 제거)
- [ ] 대용량 테이블(100M+ 행)에 Range 파티션 계획
- [ ] 파티션 컬럼에 인덱스 생성
- [ ] 자동 파티션 추가 프로시저 작성
- [ ] 시간 범위 쿼리에 적절한 인덱스 생성
- [ ] 문자열 기반 시간 비교는 범위 조건 사용
- [ ] 파티션별 retention 정책 수립 (예: 3년 유지)

## 관련 최적화 기법

### EXPLAIN으로 쿼리 분석
```sql
EXPLAIN FORMAT=JSON SELECT * FROM cmon_event_info
WHERE notified_yn = 'N'
  AND created_at >= NOW() - INTERVAL 5 MINUTE;

-- 확인 사항:
-- 1. type: ALL이면 위험 (Full Table Scan)
-- 2. rows: 예상 행 수 (적을수록 좋음)
-- 3. Extra: "Using index" 있으면 좋음
```

### 통계 업데이트
```sql
-- MySQL
ANALYZE TABLE cmon_event_info;

-- PostgreSQL
ANALYZE cmon_event_info;

-- 쿼리 플래너가 최적화된 실행 계획 생성
```

## 참고 자료

- MySQL 파티셔닝: https://dev.mysql.com/doc/refman/8.0/en/partitioning.html
- PostgreSQL 파티셔닝: https://www.postgresql.org/docs/current/ddl-partitioning.html
- Observability DDL: `docs/o11y/02-ddl.sql`
- SRE 코딩 가이드: `docs/learnings/005-sre-coding-guide.md`
