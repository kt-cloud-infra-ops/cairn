---
triggers:
  - CommonDashboard.js
  - ManageDashboard.js
  - SpecificMainDashboard.js
  - WallMainDashboard.js
---

## 준수 규칙
- 기존 화면의 패턴을 먼저 파악하고 동일한 패턴으로 구현한다.
- `commonGrid`, `commonPopup` 등 기존 공통 JS 함수를 먼저 파악하고 재사용한다.
- 새 라이브러리 도입 전 기존 공통 함수로 해결 가능한지 먼저 확인한다.
- 레퍼런스 화면 지정 요청이 있으면 같은 패턴으로 맞춘다.

## 소스 참조
- `agents/frontend-dev.md` (엔진 plugin 레이어 에이전트)
