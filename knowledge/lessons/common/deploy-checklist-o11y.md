---
tags:
  - type/guide/troubleshooting
  - service/luppiter
  - domain/sre
  - audience/ai
---

# 배포 시 o11y 연동 확인 체크리스트

## 배경

2026-03-24 TECHIOPS26-355 배포 시 o11y(ES0007 SE리전) 연동이 09:52부터 Connection timeout 상태였으나, 배포 시점(14:00)까지 미인지. 원인은 방화벽 정책 문제.

## 레슨런

관제 채널(luppiter(ext)) 알림만으로는 배포 전 연동 상태를 파악하기 어려움.
**DB 연동 로그를 직접 확인**하는 절차가 필요.

## 배포 전 점검 쿼리

```sql
-- 1. 배치 이벤트 마지막 동기화 시간 확인
SELECT system_code, sync_dt, use_yn
FROM c01_batch_event
WHERE use_yn = 'Y'
ORDER BY sync_dt DESC;
-- sync_dt가 현재 시간 대비 비정상적으로 오래되었으면 연동 중단 상태

-- 2. 최근 이벤트 수신 확인
SELECT system_code, MAX(occu_time) as last_event
FROM cmon_event_info
WHERE create_time > NOW() - INTERVAL '1 hour'
GROUP BY system_code;
-- ES0007/ES0008(o11y)에서 최근 1시간 이벤트 없으면 연동 확인

-- 3. 인터페이스 테이블 잔존 확인
SELECT system_code, COUNT(*) FROM x01_if_event_obs GROUP BY system_code;
-- 데이터가 쌓여있으면 스케줄러 미처리 상태
```

## 배포 후 점검

1. 스케줄러 로그 확인: `tail -f /app_log/luppiter_scheduler/debug.log | grep ERROR`
2. 위 쿼리 재실행하여 sync_dt 갱신 확인
3. 관제 채널 알림 해소 확인

## 적용 대상

- luppiter_web 배포
- luppiter_scheduler 배포
- message_bridge 배포
- DB DML 작업 (이벤트 데이터 변경 시)
