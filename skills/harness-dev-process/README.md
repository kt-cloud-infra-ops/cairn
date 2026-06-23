---
tags:
  - type/reference
  - audience/team
---

# 하네스 오케스트레이터

기능 개발할 때 이 순서로 진행됩니다.

## 산출물 (무엇을 만드나)

```
📋 templates/feature-cps.md          요구사항 정의서
│  배경 → 문제 → 해결 방향 → 영향도    (왜, 뭘 만드나)
│
📐 templates/feature-prd.md          상세 설계서
│  기능 요구사항 + 풀스택 8레이어       (어떻게 만드나)
│
🏗️ templates/feature-architecture.md  기술 설계서
│  컴포넌트 + 데이터모델 + 보안         (어떤 구조로)
│
📦 templates/task-packet.md           구현 작업 지시서
   입력 → 수행 → 출력 → 검증           (실행 단위)
```

## 검증 (제대로 만들었나)

```
🚪 references/phase-gates.md          단계별 통과 조건
   INIT → PLAN → IMPL → VERIFY → SHIP  (못 넘기면 차단)

✈️ references/charter-preflight.md     착수 전 점검표
   Goal / Context / Constraints / Done When

✅ references/output-schema.md         산출물 검증 규칙
   필수 섹션 + 금지 패턴 (추정 표현 등)
```

## 도구 (자동으로 돌리는 것)

```
🔍 scripts/validate-doc-contracts.mjs  문서 검증기
   필수 섹션 있나? 추정 표현 없나? → PASS/FAIL

🔍 scripts/validate-phase-gates.mjs    Gate 검증기
   통과 조건 충족? Level별 승인? → PASS/FAIL

🚀 scripts/init-harness-run.sh         하네스 시작
   state.json + 템플릿 자동 생성
```

## 규모별 적용 (Harness Level)

| 작업 | Level | 만들 것 |
|------|-------|--------|
| 버그 수정 1줄 | **Lite** | Charter 확인만 |
| 기능 추가 | **Standard** | CPS + PRD + Architecture |
| 테이블 추가 + 외부 연동 | **Full** | 전부 + 매 단계 승인 |

## 시작하려면

```bash
# 하네스 초기화
./agents/skills/harness-dev-process/scripts/init-harness-run.sh /path/to/project --level standard --ticket TECHIOPS26-XXX

# 문서 검증
node agents/skills/harness-dev-process/scripts/validate-doc-contracts.mjs feature-cps.md --type cps

# Gate 검증
node agents/skills/harness-dev-process/scripts/validate-phase-gates.mjs /path/to/project --phase PLAN
```
