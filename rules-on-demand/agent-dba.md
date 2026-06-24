---
triggers:
  - sql-<YOUR_DOMAIN>.xml
  - sql-<YOUR_DOMAIN_2>.xml
---

## 준수 규칙
- DDL 확정본 기반으로만 작업한다.
- 쿼리 변경 시 `EXPLAIN ANALYZE`로 성능을 검증한다.
- Soft Delete 컬럼(`del_yn`, `delete_yn`, `use_yn` 등 팀 컨벤션 기준)은 WHERE 조건에 포함한다.
- UNION ALL에서 `''` 또는 `NULL AS 컬럼명` 패딩이 보이면 소비측까지 데이터 흐름을 추적한다.
- 텍스트 컬럼 일괄 변경 시 `information_schema` 전수 조회와 데이터 값 탐색을 함께 수행한다.
- 검색 필터에서는 비활성/삭제 대상을 제외한다.

## 소스 참조
- `agents/dba.md` (엔진 plugin 레이어 에이전트)
