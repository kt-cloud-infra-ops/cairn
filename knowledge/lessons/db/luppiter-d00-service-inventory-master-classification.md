---
tags:
  - type/lesson
  - audience/team
  - service/luppiter
  - domain/db
aliases: []
---

> 상위: [lessons](../../README.md) · [db](../README.md)

# Luppiter `d00_service_inventory_master` 적재 경로와 대시보드 분류

## 날짜
2026-05-28

## 세션/프로젝트
luppiter_web — TECHIOPS26-566 종합대시보드 (wall) overview 분류 후속 작업

## 핵심

`d00_service_inventory_master` 는 **STT(svc-inv) 화면을 통해 수동 INSERT/UPDATE 되는 운영 테이블**이다. 외부 자동 동기화/수집 경로가 아니다. 종합대시보드 wall overview 의 group_type 분류 CASE 는 `host_group_nm` 접두사를 KCP-first 로 평가하므로, 잘못된 host_group_nm 으로 등록된 row 1개가 대시보드 표기를 즉시 오염시킨다.

## 적재 owner

| 경로 | 행위 | 코드 위치 |
|------|------|----------|
| STT 화면 INSERT | 신규 서비스 인벤토리 등록 | `sql-stt.xml:1031` |
| STT 화면 UPDATE | 수정 | `sql-stt.xml:1073` |
| Inventory 화면 INSERT | 상위 인벤토리 등록 경로 | `sql-Inventory.xml:421` |

→ **운영 DB 직접 DML 은 비권장**. STT/Inventory 화면이 owner 이므로 화면 경로로 수정한다. 다만 화면이 막혀 있거나 데이터 불일치 사건 정정 시에는 DML 도 허용하되, downstream 영향 (cmon_event_info, 인시던트, 자동갱신 화면) 을 먼저 확인한다.

## 대시보드 분류 규칙 (TECHIOPS26-566 신규 wall overview)

### group_type CASE 평가 순서 (KCP-first)

```
1. host_group_nm LIKE 'KCP\_%'       → group_type = 'KCP'
2. (그 외) ZT 코드 / idc_center_code → CLASSIC / CAPTIVE / ...
3. sub_type 은 별도 평가 (ZT0001 → PUBLIC, ...)
```

→ 접두사가 `NEXT_`, `D00_`, `CMON_` 등 KCP가 아니면 자동으로 `CLASSIC` 으로 분류된다. sub_type 까지 PUBLIC 으로 잡히면 wall overview 의 "클래식 공공" 칸에 SERVICE/PLATFORM 카운트로 잘못 표시된다.

## 사건: stg 운영 종합대시보드 오표기 (2026-05-27~28)

### 증상
운영 stg 종합대시보드 wall overview 의 "클래식 공공" 영역에 SERVICE/PLATFORM 표기가 비정상 노출.

### 원인
`d00_service_inventory_master` 에 다음 row 가 적재되어 있었음.

```
host_group_nm: NEXT_공통_NEXT-observability-admin-dashboard-G_DX-G-GLOBAL_PLATFORM
host_group_nm: NEXT_공통_NEXT-observability-admin-dashboard-G_DX-G-GLOBAL_SERVICE
```

- `NEXT_` 접두사라 KCP 분류에서 빠짐 → CLASSIC
- ZT0001 매핑으로 sub_type=PUBLIC
- 결과: "클래식 공공" SERVICE/PLATFORM 카운트로 잘못 합산

### 로컬과 운영 차이
로컬 K8s 백업 DB (2026-04-28) 에는 해당 row 0건. **stg 전용 유입** — 운영 DB 만 별도 검증해야 보이는 종류.

### 정정 절차
1. **svc-inv 화면에서 `use_yn='N'` 또는 삭제**
2. 운영 DB 직접 DML 은 비권장 (STT 가 INSERT/UPDATE owner)
3. 삭제 전 `cmon_event_info` 의 동일 `host_group_nm` 매칭 이벤트/인시던트 존재 여부 확인 → 미해소 이벤트가 있으면 동시에 정리

## KCP-first 가설 반증 (CAPTIVE)

### 가설
"KCP-first 평가가 `ZT0003 + KCP_` 호스트를 CAPTIVE 에서 가져가서 운영 CAPTIVE 가 누락된다."

### 검증 (로컬 K8s DB, 2026-04-28 백업)

| 항목 | 결과 |
|------|------|
| ZT0003 존 67개 전부 `kcp_hosts_in_zt0003` | **0** |
| 기존 `selectSummaryInventoryList` vs 신규 `selectSummaryOverviewInventoryRaw` CAPTIVE inventory 7종 (CSW/HW/NW/VM_*) | **완전 일치** |
| specific 존 현황 ZT0003 d00 | **0건** |

→ **로컬에서는 가설 반증.** `idc_center_code` null→실제 변경의 CAPTIVE 영향도 없음.

### 결론
분류·집계 로직 차이로는 **로컬 CAPTIVE 가 달라지지 않는다.** 운영 차이가 있다면 다음 중 하나:

- `cmon_group_user` 권한 필터 (`gu.user_id=#{user_id}`) 의 운영 사용자별 그룹 차이
- 운영 데이터량 의존 (KCP-first 의 stealing 이 운영 데이터에서만 발생 가능)

### 잠재 리스크 (유효)
운영 DB 에 `ZT0003 + KCP_` 접두사 호스트가 한 건이라도 존재하면 KCP-first 가 CAPTIVE 에서 빼간다. 필요 시 CASE 에서 `ZT0003 → CAPTIVE` 를 KCP_ 검사보다 **앞에** 두는 정정 검토.

```
검토안 (가능 시):
1. ZT0003 → CAPTIVE 우선
2. host_group_nm LIKE 'KCP\_%' → KCP
3. 나머지 → CLASSIC
```

## AI 에이전트용 점검 순서

1. 종합대시보드 (wall) overview 표기가 이상하면 먼저 `d00_service_inventory_master.host_group_nm` 접두사 확인
2. KCP-first 분류 영향 의심 시 위 SQL 패턴으로 `ZT0003 + KCP_%` 카운트 운영에서 확인
3. d00 row 정정은 svc-inv 화면 경로 우선, DML 은 downstream (cmon_event_info, 인시던트) 영향 확인 후
4. 로컬·dev 에서 분류 변경을 검증하더라도 운영 데이터량 의존 케이스는 stg 실데이터로 재검증

## 회귀 검증 SQL

```sql
-- d00 의 비표준 접두사 host_group_nm 탐지
SELECT host_group_nm, COUNT(*) 
FROM d00_service_inventory_master
WHERE use_yn = 'Y'
  AND host_group_nm NOT LIKE 'KCP\_%' ESCAPE '\'
GROUP BY host_group_nm
ORDER BY 2 DESC;

-- ZT0003 + KCP_ 충돌 탐지 (운영에서 실행)
SELECT COUNT(*)
FROM d00_service_inventory_master d
JOIN inventory_master i ON d.host_group_nm = i.host_group_nm
WHERE d.use_yn = 'Y'
  AND i.zone_code = 'ZT0003'
  AND d.host_group_nm LIKE 'KCP\_%' ESCAPE '\';
```

## 적용 가능한 상황

- 종합대시보드 (wall) / 센터별 대시보드 (specific) overview 표기 오류 분석
- CLASSIC/CAPTIVE/KCP/PUBLIC 분류 변경 영향도 점검
- O11y 인벤토리 (`d00_service_inventory_master`) 적재 경로 추적
- 운영-로컬 데이터 차이로 발생하는 사건의 검증 패턴

## 관련 문서

- [luppiter-inventory-master-sub-rules.md](luppiter-inventory-master-sub-rules.md) — inventory_master + sub 적재 규칙
- [luppiter-system-code-relationship.md](../common/luppiter-system-code-relationship.md) — d00 가 anchor 5개 중 1개
- [luppiter-permission-cte-zero-row.md](luppiter-permission-cte-zero-row.md) — `cmon_group_user` 권한 필터 사례
