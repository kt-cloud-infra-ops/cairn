---
name: analytics-maintainability
description: 결정층 문서(도메인 에이전트·ADR) 건강 스캔. 전 서비스의 stale(신선도)·충실도·커버리지를 측정해 maintainer별 조치 리포트를 낸다. owner 부재에도 팀+AI가 서비스를 유지하는 "유지가능성"을 정량 점검. "유지가능성", "결정층", "문서 stale", "drift", "maintainability" 키워드에 반응.
---

## 스킬 규칙
### ALWAYS
- 읽기 전용 — 문서/코드를 수정하지 않는다 (측정·리포트만)
- maintainer별로 그룹핑해 리포트 (분산 소유 — "내 그릇만" 챙기게)
- stale 판정 기준 명시 (last_verified 나이 + 기준일)

### NEVER
- 스캔 결과로 문서를 자동 수정 금지 (조치는 owner/후속 작업)
- 결정층 문서 0건을 "건강"으로 보고 금지 (스캐폴드 미적용 신호로 구분)

## 실행 절차

1. 스캔 실행:
   ```bash
   python3 agents/skills/analytics-maintainability/scripts/scan.py [workspace-root] [stale-days]
   ```
2. 리포트 해석:
   - `STALE(Nd)` — last_verified 90일 초과 → 코드와 재대조 필요
   - `WHY-EMPTY` — 결정 이력/판단 시나리오 비어있음 → 적립 필요
   - `NO-last_verified` / `NO-maintainer` — 메타 누락 → 스캐폴드 정합 보정
3. maintainer별 조치 안내 (자동 수정 X, owner에게 위임)

## 측정 신호 (기준)

| 신호 | 의미 | 조치 |
|------|------|------|
| stale | 신선도 — 코드 변경 후 미검증 / 90일 초과 | 코드 대조 후 `last_verified` 갱신 |
| 충실도 | 결정 이력·판단 시나리오 실내용 유무 | 평소 작업 부산물로 적립 |
| 커버리지 | 모듈 대비 도메인 에이전트 존재 | 누락 모듈에 그릇 생성 |

> 기준 정의: `base/templates/service-knowledge-scaffold/maintainability.md`

## 적용 주기

- 주 1회 (work-start 또는 weekly-report에 편입 가능)
- 분기 1회 유지가능성 리허설("owner 없이 AI+팀원이 운영 1건 완수")과 병행

## 완료 조건 (DONE WHEN)
- [ ] [CONTENT] 도메인 에이전트·ADR 건수 + 건강/조치필요 집계 출력
- [ ] [CONTENT] maintainer별 조치 리스트 출력
- [ ] [MANUAL] 결정층 0건 시 "스캐폴드 미적용" 명시

## 관련 문서

- [service-knowledge-scaffold](../../../base/templates/service-knowledge-scaffold/README.md) — 결정층 표준 그릇
- [maintainability.md](../../../base/templates/service-knowledge-scaffold/maintainability.md) — 측정 기준 정의
