---
name: build-fix
description: "빌드/타입 에러 수정. 최소 diff로 빌드 통과만 목표."
---

## 스킬 규칙
### ALWAYS
- 빌드/타입 에러만 수정
- 최소 diff 원칙
- 수정 후 전체 빌드 재실행
### NEVER
- 아키텍처 변경 금지
- e.printStackTrace() 금지
- 추가 기능 변경/리팩토링 금지

## 실행 절차

1. 빌드 실행하여 에러 목록 수집
2. 에러 유형별 분류 (타입, import, 의존성 등)
3. 가장 근본적인 에러부터 수정 (cascade 효과)
4. 수정 후 재빌드 → 에러 0건 확인
5. 추가 기능 변경/리팩토링 하지 않음

## 옵트인: lint/포맷 자동 수정

기본 OFF. 사용자가 **명시적으로** "lint 자동 수정해" / "포맷 정리해" / "prettier 적용해" 등을 요청한 경우에만 적용.

자동 수정 허용 범위:
- 포맷 정리 (`prettier --write`, `gofmt`, `black`)
- import 정리 (`eslint --fix` import 규칙, `isort`)
- 타입 누락 보강 (단순 선언, 분기 변경 없음)
- 단순 lint 규칙 준수 (unused import 제거, var → const 등)

자동 수정 금지 범위:
- 분기/상태 전이/API 계약/데이터 모델 변경 필요한 경우
- 한두 줄을 넘어선 요구사항 해석/설계 선택 필요한 경우
- 파일 전반 품질 문제로 신뢰성 낮은 자동 수정

자동 수정 후:
- 무엇을 수정했는지 `.harness/review-evidence.json`의 `autoFixed` 배열에 기록
- 테스트/lint/정적분석 재실행 → 결과 갱신
- 사용자에게 수정 내역 명시 보고

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 빌드 에러 0건
- [ ] [MANUAL] 회귀 없음 (전체 빌드 재실행 확인)
- [ ] [MANUAL] 자동 수정 사용 시 사용자 명시 요청 확인 + autoFixed 기록
