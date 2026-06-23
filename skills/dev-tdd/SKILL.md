---
name: tdd
description: "TDD 워크플로우 강제. RED→GREEN→REFACTOR 순서로 테스트 먼저 작성 후 구현. 80%+ 커버리지."
---

## 스킬 규칙
### ALWAYS
- RED→GREEN→REFACTOR 순서 필수
- 80%+ 커버리지
- Layered 테스트: Unit + Integration + Apidog 3종 + Playwright
- 불변성 우선, 함수 50줄, 파일 800줄
### NEVER
- 테스트 없이 구현 금지
- 실패 테스트 삭제/수정 금지 (테스트가 틀린 경우 제외)

## 실행 절차

1. **인터페이스 스캐폴딩** — 구현할 기능의 인터페이스/시그니처만 먼저 정의
2. **테스트 작성 (RED)** — 실패하는 테스트 먼저 작성
3. **테스트 실행 → 반드시 FAIL 확인**
4. **최소 구현 (GREEN)** — 테스트를 통과하는 최소 코드
5. **테스트 실행 → PASS 확인**
6. **리팩토링 (IMPROVE)** — 코드 품질 개선 (테스트는 유지)
7. **커버리지 확인** — 80%+ 달성 확인

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 테스트 전체 PASS
- [ ] [MANUAL] 커버리지 80%+ 확인
- [ ] [MANUAL] RED → GREEN → REFACTOR 순서 준수

## 참고

- [references/tdd-examples.md](references/tdd-examples.md) — 언어별 TDD 예시
