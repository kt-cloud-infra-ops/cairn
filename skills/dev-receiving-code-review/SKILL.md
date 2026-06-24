---
name: dev-receiving-code-review
description: "코드 리뷰 피드백을 받았을 때 수용 프로토콜. 맹목적 동의 금지, 코드베이스 검증 우선, 필요시 기술 근거로 반박. (origin: superpowers/receiving-code-review)"
---

## 스킬 규칙
### ALWAYS
- 피드백 전체를 **끝까지 읽은 후** 반응 (부분 반응 금지)
- 구현 전 **코드베이스 검증** (grep, 테스트 확인 등)
- 기술적으로 이 저장소에 맞는지 판단
- 불명확한 항목은 **먼저 clarify** 후 진행 (부분 이해로 구현 금지)
- 수정 시 **한 건씩** 테스트하며 적용

### NEVER
- "You're absolutely right!" / "맞습니다!" 류 맹목적 동의 금지
- "Thanks for catching that!" / "좋은 지적입니다!" 류 **감사 표현 금지** — 코드 수정으로 대신
- 검증 전 "바로 구현하겠습니다" 금지
- 일부만 이해한 상태에서 부분 구현 후 나머지 질문 금지 (전부 clarify 먼저)
- 여러 건 일괄 수정 후 통합 테스트 금지 (건별 테스트)

## 실행 절차

1. **READ**: 피드백 전체 반응 없이 읽기
2. **UNDERSTAND**: 요구사항을 자기 언어로 재진술 (불명확하면 질문)
3. **VERIFY**: 코드베이스 현재 상태와 대조 (grep, 테스트, 빌드 타겟 등)
4. **EVALUATE**: 이 저장소에 기술적으로 타당한가? (아니면 push back)
5. **RESPOND**: 기술적 acknowledgement 또는 근거 있는 반박
6. **IMPLEMENT**: 한 건씩 수정 + 테스트

## 반응 패턴 예시

| 리뷰어 의견 | ❌ 나쁜 반응 | ✅ 좋은 반응 |
|-----------|-------------|-------------|
| "legacy 제거" | "맞습니다! 제거하겠습니다" | "확인: 빌드 타겟 10.15+, 이 API는 13+ 필요. backward compat 필요. 현재 bundle ID 오류 수정할지, pre-13 지원 드롭할지?" |
| "proper metrics 구현" | 바로 DB/export 구현 | "grep: 이 endpoint 호출 없음. 제거(YAGNI)? 사용처 있나?" |
| "1~6 수정" (4,5 이해 못함) | 1,2,3,6 먼저 구현 | "1,2,3,6 이해. 4,5는 먼저 확인 필요" |

## Push back 기준

아래 상황에선 기술 근거로 **반박**:
- 제안이 기존 기능 깨뜨림
- 리뷰어가 전체 컨텍스트 모름
- YAGNI 위반 (안 쓰는 기능)
- 이 스택/프로젝트에 기술적 부적합
- 레거시/호환성 이유 존재

반박 방법:
- 방어적 태도 X → 기술 근거
- 구체적 질문
- 작동 중인 테스트/코드 참조
- 아키텍처 영향이면 사용자에게 에스컬레이션

## 올바른 피드백 수용 예시

```
✅ "Fixed. {변경 내용}"
✅ "Good catch — {특정 이슈}. {위치}에서 수정"
✅ [코드만 수정하고 diff로 보여줌]

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ "Thanks for {anything}"
❌ 어떤 형태든 감사 표현
```

**왜 감사 금지**: 행동으로 말한다. 코드 수정 자체가 피드백 수용의 증거. "Thanks" 쓸 것 같으면 삭제하고 fix만 남기기.

## Push back이 틀렸을 때 수정

```
✅ "확인해보니 맞습니다. {X} 검증했고 {Y} 맞음. 구현합니다."
✅ "검증: 당신이 맞음. 제 초기 이해가 {이유}로 틀림. 수정."

❌ 장황한 사과
❌ push back 방어
❌ 과한 설명
```

사실만 말하고 넘어간다.

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 피드백 전체를 끝까지 읽음
- [ ] [MANUAL] 불명확 항목 전부 clarify 완료
- [ ] [MANUAL] 각 수정 건별 코드베이스 검증
- [ ] [MANUAL] 테스트 건별 통과 확인
- [ ] [MANUAL] 감사/performative 표현 0건

## GitHub PR 스레드 회신

인라인 리뷰 코멘트는 **스레드 내 답글**로:
```
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies
```
PR 최상위 코멘트로 답하지 않음.

## Origin (Vendor 흡수)

| 항목 | 값 |
|------|----|
| 원본 | [obra/superpowers — receiving-code-review](https://github.com/obra/superpowers) |
| vendor 사본 | [superpowers--receiving-code-review](../vendor/superpowers--receiving-code-review/SKILL.md) |
| 흡수 결정 | [ADR-006](../../../decisions/006-skill-unification.md) — PR #31 |
| 판정 | SUPPLEMENT (리뷰 피드백 수용 프로토콜) |

## 참조

- 연관: `dev-code-review` (리뷰하는 쪽)
