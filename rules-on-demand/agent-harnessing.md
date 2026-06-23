---
triggers:
  - AGENTS.md
  - core.md
  - doc-organization.md
  - harnessing.md
  - SKILL.md
---

## 준수 규칙
- 같은 정책은 한 곳만 canonical로 두고 여러 파일에 복붙하지 않는다.
- `base/`와 프로젝트 레포 `docs/`, `agents/subagents/`와 하네스 문서의 경계를 섞지 않는다.
- 항상 읽어야 하는 정보와 필요할 때만 읽는 정보를 분리한다.
- 도메인 에이전트의 `## 요구사항 이력`은 핵심 자산으로 취급한다.
- 구조 변경은 `정책 중복 제거 → 카탈로그 정리 → 본문 슬림화` 순서로 진행한다.
- `harnessing`은 기본적으로 제안/판단 역할을 맡고, 수정은 명시적 handoff 후 실행자가 수행한다.
- `weekly-report`처럼 오탐 비용이 큰 command는 auto-trigger보다 helper script/skill을 우선 검토한다.

## 소스 참조
- `agents/subagents/harnessing.md`
