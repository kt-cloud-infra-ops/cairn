---
name: e2e
description: "Playwright E2E 테스트 생성/실행. 스크린샷/비디오/trace 아티팩트."
---

## 스킬 규칙
### ALWAYS
- Critical flow 3~5개부터, 안정화 후 확장
- 스크린샷/비디오/trace 아티팩트 저장
- 임시 데이터 e2e_ 접두사
### NEVER
- 운영환경 기존 데이터 변경 금지

## 실행 절차

1. 테스트 대상 user journey 정의
2. Page Object 또는 직접 셀렉터로 테스트 작성
3. `npx playwright test` 실행
4. 실패 시 스크린샷/trace로 디버깅
5. 아티팩트 업로드 (CI 환경)

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] Playwright 테스트 PASS
- [ ] [MANUAL] 아티팩트 (스크린샷/비디오/trace) 저장
