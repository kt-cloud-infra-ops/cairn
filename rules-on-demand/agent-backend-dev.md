---
triggers:
  - WebControllerHelper.java
  - ExceptionRestAdvice.java
  - ServletInitializer.java
  - sql-ctl.xml
---

## 준수 규칙
- 기존 프로젝트의 패키지 구조와 네이밍 컨벤션을 따른다.
- 모든 외부 호출에 타임아웃을 설정한다.
- 에러 시 스택트레이스를 로깅한다.
- 응답은 `WebControllerHelper`의 `setResSuccess/setResFail`를 사용한다.
- 동일 목적의 시나리오를 Unit/Integration, Apidog, Playwright에 중복 작성하지 않는다.

## 소스 참조
- `agents/subagents/backend-dev.md`
