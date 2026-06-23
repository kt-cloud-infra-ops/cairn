---
tags:
  - type/lesson
  - audience/team
  - service/luppiter
  - domain/db
aliases: []
---

> 상위: [lessons](../../README.md) · [db](../README.md)

# Luppiter 권한 CTE 0건 케이스 결함 패턴

## 핵심

**Luppiter 의 화면이 메타시각(`now_date_time`/`add_thirty_time`)을 SQL row 컬럼으로 SELECT 하는 패턴은 0건 응답 시 화면이 죽은 것처럼 보이는 결함을 유발한다.**

## 결함 체인

```
[1] SQL: now_date_time / add_thirty_time 을 row 컬럼으로 SELECT
        ↓ 결과 0 row
[2] WebControllerHelper.setList: if(0 < listSize) 안에서만 메타 추출 → 빈 문자열로 응답
        ↓ JSON: { now_date_time:"", add_thirty_time:"" }
[3] JSP: $("#refreshCount").text("") + $("#addThirtyTime").val("")
        ↓ 화면 시간표시 빈 칸, 자동갱신 임계 빈값
[4] fnAutoReload: if(("" != fnNullChangeBlank(addThirtyTime)) && ...) → silent skip
        ↓
[5] 자동갱신 영구 정지 (manual F5 만 가능)
```

## 권한 CTE 흐름 (참고)

`selectEventList` 등의 화면 SQL 표준 패턴:

```sql
WITH match_event AS (
  WITH find_host_group_cd AS (
    SELECT DISTINCT layer_cd FROM cmon_group_layer
    WHERE group_id IN (
      SELECT group_id FROM cmon_group
      WHERE group_id IN (
        SELECT group_id FROM cmon_group_user 
        WHERE user_id = #{loginUserId} AND delete_yn = 'N'
      ) AND delete_yn = 'N'
    ) AND layer = 5
  )
  SELECT A.layer_nm
  FROM cmon_layer_code_info A, find_host_group_cd B
  WHERE A.layer_cd = B.layer_cd AND A.delete_yn = 'N'
)
SELECT COUNT(*) OVER() AS total_count
     , TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS') AS now_date_time      -- ← row 컬럼
     , TO_CHAR(NOW() + '10 seconds', 'YYYYMMDDHH24MISS') AS add_thirty_time  -- ← row 컬럼
     , /* event 데이터 ... */
FROM cmon_event_info A
WHERE host_group_nm IN (SELECT layer_nm FROM match_event)
  AND event_state IN ('신규', '인지', '조치중')
```

→ **사용자별 권한 host_group_nm 매핑이 빈 결과를 만들거나, 미해소 이벤트가 0건이면 SELECT 결과 0 row → 메타시각도 같이 사라진다.**

## 영향 범위 (luppiter_web)

### 동일 SQL 패턴 매퍼 4개

- `sql-evt.xml` (이벤트)
- `sql-icd.xml` (인시던트)
- `sql-zab.xml` (Zabbix maintenance)
- `sql-mkt.xml` (M-Kate)

### 자동갱신 사용 화면 (직접 영향)

- `evt/subEventState.jsp`
- `evt/subEventStateWindowPopup.jsp`
- `icd/subIncidentState.jsp`
- `zab/subMaintenanceInfo.jsp`

### 시간표시 사용 화면 (간접 영향)

- `evt/subEventHistory.jsp`
- `mng/deleteHosts.jsp`
- `zab/subMaintenanceUpdatePop.jsp` (`openTime` 시간 비교 오동작 가능)
- `zab/obsMaintenanceUpdatePop.jsp` (동일)

## 정공 fix (TECHIOPS26-543, 2026-04-28 적용)

### 단일 진입점 패치 — `WebControllerHelper.setList`

```java
public void setList(...) throws Exception {
    int nListSize = (list != null) ? list.size() : 0;
    int totalCount = 0;
    String nowDateTime;
    String addThirtyTime;
    
    if (0 < nListSize) {
        totalCount    = StringUtil.zeroConvert(StringUtil.isNullToString(list.get(0).get("total_count")));
        nowDateTime   = StringUtil.isNullToString(list.get(0).get("now_date_time"));
        addThirtyTime = StringUtil.isNullToString(list.get(0).get("add_thirty_time"));
    } else {
        // list 가 비어있어도 메타시각이 빈 문자열로 응답되지 않도록 서버 NOW 로 채운다.
        // JSP fnAutoReload 가 addThirtyTime 빈값을 silent skip 하여 자동갱신이 영구 정지되는 회귀 방지.
        LocalDateTime now = LocalDateTime.now();
        nowDateTime   = now.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        addThirtyTime = now.plusSeconds(10).format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
    }
    
    map.put(addObjectName, list);
    map.put("total_count", totalCount);
    map.put("now_date_time", nowDateTime);
    map.put("add_thirty_time", addThirtyTime);
    setResSuccess(map, request);
}
```

### 효과

- 응답 스키마 차원에서 메타시각이 빈 문자열로 가지 않음을 보장
- list size > 0 응답은 그대로 (회귀 0)
- 자동갱신 4개 화면 + 시간표시 4개 화면 = **단일 진입점 fix 로 8개 화면 일괄 보호**
- prd 영향 0 (prd 의 모든 list 응답에서 메타시각이 NOW 로 채워질 뿐 — 빈 문자열에 의존하는 코드 없음, 회귀 위험 0)

## 예방 원칙

1. **메타데이터를 row 데이터에 묶지 마라** — 응답 단위 메타(시각, 페이징 정보 등)는 row 와 분리해서 응답에 채워야 한다
2. **0 row 시나리오를 정상 케이스로 다뤄라** — list 비었다고 server NOW / pagination 등 메타데이터까지 비우면 안 됨
3. **새 화면이 자동갱신을 추가하면 0건 시나리오를 시뮬레이션해서 검증** — 권한 그룹 일부에 미해소 이벤트가 0건이 가능한 케이스 포함

## 회귀 검증 SQL (재발 방지)

```sql
-- 0건 케이스 시뮬레이션: 특정 user_id 의 권한 그룹이 host_group 매핑은 있지만 해당 그룹의 미해소 이벤트가 0건
WITH find_host_group_cd AS (
  SELECT DISTINCT layer_cd FROM cmon_group_layer
  WHERE group_id IN ('G0029','G0031') AND layer = 5  -- NW 권한
), match_event AS (
  SELECT A.layer_nm FROM cmon_layer_code_info A, find_host_group_cd B
  WHERE A.layer_cd = B.layer_cd AND A.delete_yn='N'
)
SELECT COUNT(*) FROM cmon_event_info
WHERE event_state IN ('신규','인지','조치중')
  AND host_group_nm IN (SELECT layer_nm FROM match_event);
-- 0 이면 자동갱신 정지 회귀 시나리오. fix 후 setList 가 메타시각을 NOW 로 채워주면 회복.
```

## 참고

- 임시조치(`CATR-KD05R-MG-14R08` 메모리 임계 90%→80%로 미해소 이벤트 1건 유지)는 fix 배포 전 회피책. 배포 후 임계 90% 원복
- 배포 시퀀스: feature → develop → stage → production → main (TECHIOPS26-543 의 경우 5.6 배포에 동봉)

## 관련 문서

- [database-optimization.md](database-optimization.md)
- [luppiter-inventory-master-sub-rules.md](luppiter-inventory-master-sub-rules.md)
- [slack-payload-curl-validation.md](../common/slack-payload-curl-validation.md) — 동일 세션의 발송 검증 SOP
