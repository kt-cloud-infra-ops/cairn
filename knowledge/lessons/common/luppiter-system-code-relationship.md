---
tags:
  - type/guide
  - service/luppiter
  - audience/ai
---

> 상위: [common](README.md) · [lessons](../README.md)

# 학습: Luppiter system_code 값 기반 관계

## 날짜
2026-04-01

## 세션/프로젝트
Luppiter web + scheduler

## 배운 것

`system_code`는 ERD에 FK로 잘 드러나지 않지만, 실제로는 Luppiter에서 다음 역할을 동시에 수행한다.

- 배치 Job 식별자
- 이벤트 소스 시스템 식별자
- Zabbix/OBS API 연결정보 선택키
- 인벤토리/서비스 인벤토리 분기 키
- 삭제/메인터넌스/상세 팝업의 라우팅 키

즉 `system_code`는 표시용 코드가 아니라, **값 기반 관계 키**로 취급해야 한다.

### 현재 확인된 시스템별 차이

- **O11y infra**
  - `inventory_master(system_code + zabbix_ip)` 매칭이 맞아야 scheduler 취합이 된다.
  - `resolved`는 단독 INSERT가 아니라 기존 `firing` 이벤트 UPDATE 경로다.
- **Zenius infra**
  - scheduler 이벤트 취합 프로시저는 주로 `zabbix_ip` 기준으로 인벤토리를 찾는다.
  - 하지만 web 삭제/메인터넌스 경로에서는 `system_code=ES0006` 분기가 중요하다.
- **Zabbix infra**
  - scheduler 취합은 `zabbix_ip` 중심이다.
  - web 수용/삭제/메인터넌스는 `system_code`로 API 서버/프록시/템플릿을 선택한다.

### AI 에이전트용 점검 순서

1. 변경 대상이 infra인지 service/platform인지 먼저 구분
2. `system_code`가 display인지 routing key인지 판정
3. 아래 5개 앵커 테이블을 함께 본다
   - `c01_batch_event`
   - `c01_zabbix_info`
   - `inventory_master`
   - `d00_service_inventory_master`
   - `cmon_event_info`
4. 화면/쿼리/프로시저/배치에서 같은 `system_code`를 어떻게 해석하는지 비교
5. O11y는 `system_code + 추가 조건(IP 또는 svc_type/l3/zone)` 조합까지 확인

## 적용 가능한 상황

- O11y/zenius/zabbix 기능 개선 시 영향도 분석
- 이벤트 누락, 상세 팝업 분기 오류, 메인터넌스 대상 누락 원인 분석
- 인벤토리 보정/마이그레이션 시 어떤 downstream 기능이 깨지는지 점검할 때

## 참고 자료

- `workspace/luppiter_web/docs/specs/system-code-relationship-map.md`
- `workspace/luppiter_web/docs/features/o11y-infra-inventory-fields.md`
- `workspace/luppiter_web/docs/features/zenius-delete-support.md`
