---
tags:
  - type/guide
  - domain/db
  - service/luppiter
  - audience/claude
---

> 상위: [db](README.md) · [lessons](../README.md)

# 학습: Luppiter inventory_master + sub 테이블 연동 규칙

## 날짜
2026-04-23

## 배경
inventory_master DB 직접 SQL 작업 시 inventory_master_sub 처리 누락으로 데이터 불일치 발생.
DB 오류가 발생하지 않아 무음으로 통과된 사례.

---

## 핵심 규칙

### control_area `_` 포함 여부가 판단 기준

| 조건 | master.control_area | sub 필요 여부 |
|------|---------------------|---------------|
| `_` 없음 (예: `NW`, `CSW`) | 원본 그대로 | 불필요 |
| `_` 있음 (예: `VM_OS`, `VM_DB`) | `_` 앞부분만 (`VM`) | **필수** |

- `inventory_master.control_area` = `_` 앞부분 (예: `VM`)
- `inventory_master_sub.control_area` = 원본 전체 (예: `VM_OS`)
- `inventory_master_sub` 복합 PK: `(zabbix_ip, control_area)`

### 처리 순서

**INSERT**
```
1. inventory_master_sub INSERT  ← 반드시 먼저
2. inventory_master INSERT
3. inventory_master_history INSERT (master+sub JOIN 스냅샷)
```

**UPDATE**
```
1. inventory_master_sub UPSERT (ON CONFLICT (zabbix_ip, control_area) DO UPDATE)
2. inventory_master UPDATE
3. inventory_master_history INSERT
```

**DELETE**
```
1. inventory_master_history INSERT (선행 이력 보존)
2. inventory_master_sub DELETE (zabbix_ip + control_area 단위)
3. inventory_master DELETE ← sub가 전부 삭제된 IP만
```

### host_group_nm 패턴

```
{L1코드명}_{L3코드명}_{zone}_{control_area}
```

예: `ETC_Cloud통합관제_ECLS-M1-COREMGMT_VM_OS`

### inventory_master_history 컬럼 주의

| 잘못된 컬럼 | 올바른 컬럼 |
|------------|------------|
| `created_dt` | `cret_dt` |
| `created_id` | `cretr_id` |
| `idc_center_code` | **없음** (master에만 있음) |

flag: `'I'`(등록), `'U'`(수정), `'D'`(삭제) — VARCHAR(2) 제약

---

## 체크리스트 (DB 직접 작업 시)

- [ ] control_area에 `_` 포함 여부 확인
- [ ] `_` 포함 시 inventory_master_sub 처리 포함했는가
- [ ] INSERT: sub → master → history 순서인가
- [ ] DELETE: history → sub → master 순서인가
- [ ] history INSERT 시 sub JOIN 후 스냅샷인가
- [ ] master.control_area = `_` 앞부분만인가
- [ ] sub.control_area = 원본 전체인가

---

## 정합성 검증 쿼리

```sql
-- sub가 있어야 하는데 없는 행 탐지
SELECT im.zabbix_ip, im.host_nm, im.control_area
FROM inventory_master im
WHERE im.control_area LIKE '%\_%' ESCAPE '\'
  AND NOT EXISTS (
      SELECT 1 FROM inventory_master_sub ims
      WHERE ims.zabbix_ip = im.zabbix_ip
  );

-- 고아 sub 탐지 (master 없는 sub)
SELECT ims.zabbix_ip, ims.control_area
FROM inventory_master_sub ims
WHERE NOT EXISTS (
    SELECT 1 FROM inventory_master im
    WHERE im.zabbix_ip = ims.zabbix_ip
);
```

---

## 관련 코드
- `SttServiceImpl.insertInventory` / `updateInventory` / `deleteInventory`
- `sql-stt.xml`: insertInventorySub, updateInventorySub, deleteInventorySub
- `sql-Inventory.xml`: insertInventoryMasterSub (MNG 수용 경로)
