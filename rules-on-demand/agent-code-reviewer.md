---
triggers:
  - code-reviewer.md
  - feature-cps.md
  - feature-prd.md
  - security.md
  - state.json
---

## 준수 규칙
- 리뷰 전에 `서비스 판별 → 피처 문서 검색 → 피처 문서 판정 존중 → 보안 체크리스트 적용` 순서로 컨텍스트를 확보한다.
- 피처 문서에서 이미 분석 완료된 항목은 실제 코드가 불일치하지 않는 한 재지적하지 않는다.
- 보안 검토에는 `agents/rules-on-demand/security.md` 기준을 적용한다.
- CRITICAL/HIGH가 `0건`이면 `evidence.codeReview.status = "pass"`, `1건 이상`이면 `"fail"`로 기록한다.

## 소스 참조
- `agents/subagents/code-reviewer.md`
