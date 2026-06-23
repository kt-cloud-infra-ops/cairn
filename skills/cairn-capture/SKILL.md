---
name: cairn-capture
description: 업무 수행 중·후의 지식을 md로 캡처하여 팀에 공용화. lesson/decision/sop/feature로 자동 분류 제안 → 초안 생성 → (team 모드) git 커밋·푸시 제안. "캡처", "이거 문서화", "남겨둬", "공용화", "/cairn:capture" 키워드 및 세션 종료 시 능동 트리거.
---

# Cairn Capture — 업무 지식 공용화 루프

> Cairn의 차별화 엔진. "내 업무를 AI에게 학습시켜 팀에 공용화한다."
> 흔적(업무) → 돌탑(md) → 이정표(팀 공용화)

## 스킬 규칙

- **ALWAYS**: 캡처 대상을 먼저 `lesson / decision / sop / feature` 중 하나로 분류하고 사용자에게 확인받은 뒤 저장한다.
- **ALWAYS**: 저장 경로는 `.cairn/config.json`의 `capture.targets`를 따른다 (없으면 기본값: knowledge/lessons, docs/decisions, docs/sop, docs/features).
- **ALWAYS**: 생성하는 md에 YAML frontmatter(`type`, `created`, 관련 티켓/링크)와 breadcrumb를 포함한다.
- **NEVER**: [GATE-SHARE] 통과 전에 `git push`(외부 공용화)를 실행하지 않는다. solo 모드에서는 push를 제안하지 않는다.
- **NEVER**: 개인 식별자(자격증명/토큰/사번 실값)를 캡처 md에 포함하지 않는다.

## 캡처 유형 분류

| 유형 | 무엇 | 기본 저장 위치 | 템플릿 |
|------|------|---------------|--------|
| **lesson** | 재사용 가능한 패턴/교훈/함정 | `knowledge/lessons/{java\|db\|common\|...}/` | 배경 → 문제 → 해결 → 재사용 포인트 |
| **decision** | 의사결정(ADR) | `docs/decisions/` | 맥락 → 결정 → 대안 → 영향 |
| **sop** | 반복 운영/작업 절차 | `docs/sop/` | 목적 → 사전조건 → 단계 → 검증 |
| **feature** | 기능 설계/스펙 | `docs/features/{TICKET}-*.md` | 요구 → 설계 → 영향도 → 테스트 |

## 실행 절차

### 1. 캡처 대상 식별
- 수동 호출(`/cairn:capture [주제]`): 사용자가 지정한 주제
- 능동 트리거(hook/오케스트레이터): 직전 세션의 변경(파일 diff, 내린 결정, 수행한 절차)을 요약

### 2. 유형 분류 + 확인 [GATE-CLASSIFY]
- [ ] 대상을 lesson/decision/sop/feature 중 하나로 분류
- [ ] 사용자에게 "이 내용을 {유형}으로 {경로}에 남길까요?" 확인
- 사용자가 거절하면 캡처 중단(노이즈 방지)

### 3. md 초안 생성
- 유형별 템플릿으로 초안 작성, frontmatter + breadcrumb 포함
- 사내 종속값은 ENV_STANDARD 토큰/플레이스홀더로 (공용화 시 재사용 가능하게)

### 4. 저장 + 인덱스 갱신
- `capture.targets` 경로에 저장
- 상위 README/인덱스에 링크 1줄 추가 (탐색 비용 절감)

### 5. 공용화 제안 [GATE-SHARE] (team 모드만)
- [ ] `mode == team` 그리고 `team.autoCommitPrompt == true` 인지 확인
- [ ] 사용자에게 커밋 메시지 초안 제시 + **명시 승인** 요청
- [ ] 승인 후에만 `git add {파일} && git commit` → (요청 시) `git push`
- solo 모드: 로컬 저장까지만, push 제안 안 함

## 완료 조건 (DONE WHEN)

- [FILE] 분류된 유형의 경로에 md 1개 생성됨 (frontmatter + breadcrumb 포함)
- [CONTENT] 캡처 md에 개인 식별자/자격증명 실값 없음
- [FILE] 상위 인덱스/README에 링크 1줄 추가됨
- [GATE] team 모드 공용화는 [GATE-SHARE] 사용자 승인 후에만 커밋/푸시됨
- [MANUAL] solo 모드는 로컬 저장으로 완료 (push 없음)

## 관련 문서

- `config/cairn.config.example.json` — mode/capture/team 설정
- `skills/analytics-learn/` — 패턴 추출 (캡처 엔진 보조)
- `skills/daily-wrap/` — 세션 단위 인사이트 추출
