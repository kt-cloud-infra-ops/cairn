# Service Knowledge Scaffold (유지가능성 표준 그릇)

owner 부재(휴직·이직·담당 이동)에도 **팀 + AI가 서비스를 같은 수준으로 유지**하기 위한 "결정층(Why)" 표준 그릇.

## 왜 필요한가

운영 지식은 3층으로 나뉜다. 우리 자산은 절차(How)는 충실하나 **결정(Why)이 owner 개인에게 묶여 있다.**

| 층 | 담는 곳 | 부재 시 |
|----|--------|---------|
| 절차 How | SOP (`base/services/{svc}/sop/`) | 따라할 수 있음 |
| 규칙 What | 도메인 준수 규칙 | 따라하되 새 상황 막힘 |
| **결정 Why** | **이 스캐폴드** | **재현 불가 = bus factor 리스크** |

"왜 이 구조인가 / 바꾸면 왜 터지나 / 새 요청을 어떻게 판단하나"가 코드 밖에 남아야, AI가 그걸 읽고 owner를 대리 판단한다. → 누가 빠져도 AI+하네스로 **유지 하한선 보장**.

## 구성

| 파일 | 역할 |
|------|------|
| `agents/domain/_TEMPLATE.md` | 도메인 에이전트 — 준수규칙(What) + **결정 이력(Why)** + **판단 시나리오(How to decide)** + 요구사항 이력 |
| `docs/decisions/_TEMPLATE.md` | 서비스 ADR — 비가역·위험 결정의 Why + **되돌리면 안 되는 이유** |
| `AGENTS-knowledge-section.md` | 서비스 `AGENTS.md`에 병합할 "결정층 적립 의무 + 유지가능성 체크리스트" |
| `maintainability.md` | drift 방지 / 건강 측정 기준 (stale·충실도·커버리지) |

## 적용 방법

1. **신규 서비스**: demo 템플릿(`demo-backend-kt`)에 이 그릇이 포함됨 → `rename-service.py`가 `os.walk` 전수 복제·치환하므로 **파생 시 자동 상속**.
2. **기존 파생 서비스**: 이 폴더를 레포에 복사 + `AGENTS-knowledge-section.md`를 해당 `AGENTS.md`에 병합.
3. **적립**: 한 번에 몰아 쓰지 않는다. **평소 작업의 부산물로** 도메인 에이전트·ADR에 한 줄씩 누적 (하네스 Phase가 강제).

## 강제 메커니즘 (하네스 연계)

- `code-reviewer`가 코드 변경 시 도메인 에이전트 선참조 의무 (`agents/rules/agents.md`)
- Phase Gate 영향도 분석이 "결정 이력" 참조를 유도
- `/analytics-maintainability` — 주기 스캔으로 stale·빈 문서·메타 누락 감지 (drift 방지, maintainer별 리포트)
- 적립 누락 시 경고 hook 강화 가능

> drift 방지 상세: [maintainability.md](maintainability.md)

## 검증 (유지가능성 리허설)

> **owner 개입 없이, 팀원 + AI가 이 문서들만으로 운영 태스크 1건을 완수할 수 있는가?**

막히는 지점 = 다음에 채울 갭. 주기적으로 측정한다(도메인 에이전트 충실도 · ADR 커버리지 · 리허설 통과).
