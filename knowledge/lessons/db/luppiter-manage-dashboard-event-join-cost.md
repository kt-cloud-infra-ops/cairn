---
tags:
  - type/lesson
  - audience/team
  - service/luppiter
  - domain/db
aliases: []
---

> 상위: [lessons](../../README.md) · [db](../README.md)

# Luppiter manage(관제) 대시보드 — `cmon_event_info` 이중 조인 비용

## 날짜
2026-05-28

## 세션/프로젝트
luppiter_web — TECHIOPS26-566 관제대시보드 성능 진단 (참고 측정)

## 측정값 (로컬 K8s DB)

| 항목 | 값 |
|------|---|
| 엔드포인트 | `/dashboard/manage/service/info` |
| 쿼리 | `selectManageStandardServiceList` |
| EXPLAIN ANALYZE 총 실행시간 | **59ms** |
| `cmon_event_info` 로컬 행 수 | 약 57만 |

로컬 기준 비용은 낮음 (신규 이벤트 1건, 조치중 인시던트 0건 → 거의 0).

## 구조적 부하

`selectManageStandardServiceList` 는 `cmon_event_info` 를 **2회** 참조한다.

1. **icd 서브쿼리** — 조치중 인시던트 매칭
2. **마지막 LEFT JOIN** — 최신 이벤트 결합

조인 키는 `(target_ip, host_group_nm)` 복합 텍스트 조인.

→ 로컬은 데이터 분포상 비용 0 에 가깝지만, **stg/운영처럼 데이터량이 많고 이벤트/인시던트 분포가 넓어지면 양쪽 모두 비용 급증 가능.**

## 위험 신호 (stg/운영에서 발생 시)

| 신호 | 해석 |
|------|------|
| stg 관제대시보드 지연 보고 | 로컬 동일 EXPLAIN 으로는 재현 안 됨 — stg DB 에서 직접 측정 필요 |
| `cmon_event_info` Seq Scan | (target_ip, host_group_nm) 인덱스 없음/누락 가능 |
| 조치중 인시던트 N건 이상 분포 | icd 서브쿼리 비용 증가 |

## AI 에이전트용 점검 순서

1. 관제대시보드 지연 보고가 들어오면 **로컬 EXPLAIN ANALYZE 만으로 판단하지 말 것** — 로컬은 거의 항상 빠름
2. stg/운영 직접 측정 필요 시 `selectManageStandardServiceList` 의 동일 쿼리를 사용자 권한으로 EXPLAIN ANALYZE
3. 조인 키 `(target_ip, host_group_nm)` 인덱스 존재 여부 확인
4. icd 서브쿼리와 마지막 LEFT JOIN 각각의 비용 분리 측정

## 회귀 검증 / 측정 SQL

```sql
-- 운영/STG 측정 시
EXPLAIN (ANALYZE, BUFFERS)
SELECT /* selectManageStandardServiceList 실제 본문 */
FROM ...
WHERE ...
;

-- 조인 키 인덱스 확인
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'cmon_event_info'
  AND (indexdef LIKE '%target_ip%' OR indexdef LIKE '%host_group_nm%');
```

## 적용 가능한 상황

- 관제대시보드 (manage) 지연 진단
- `cmon_event_info` 이중 참조 쿼리 일반 비용 분석
- 로컬·운영 데이터 분포 차이로 발생하는 성능 이슈 패턴

## 관련 문서

- [database-optimization.md](database-optimization.md)
- [luppiter-permission-cte-zero-row.md](luppiter-permission-cte-zero-row.md) — `cmon_event_info` 관련 회귀 패턴 사례
