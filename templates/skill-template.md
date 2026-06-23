---
name: {skill-name}
description: "{한 줄 설명}"
---

## 스킬 규칙
### ALWAYS
- 해야 할 것 1
- 해야 할 것 2
### NEVER
- 하지 말아야 할 것 1
- 하지 말아야 할 것 2

> 한 가지만 있을 때는 서브헤더 없이:
> - [ALWAYS] 해야 할 것
> - [NEVER] 하지 말 것

## 실행 절차
1. 단계 1
2. 단계 2
3. ...

## (선택) GATE 패턴

> **언제 GATE를 추가하는가**: 외부 시스템(Jira/DB/배포)에 돌이킬 수 없는 변경을 일으키거나 사용자 신뢰에 영향을 주는 산출물을 생성할 때. 단순 도구성/분석성 스킬은 GATE 불필요 — DONE WHEN으로 충분. 단, 도구형 스킬이라도 write 경로(create/update/comment/transition)가 있으면 GATE를 둔다.
> 상세 기준: `agents/rules/skill-governance.md` "GATE 필수 영역" 섹션.

GATE가 필요하다면 절차 단계 끝에 아래 형식 블록을 삽입한다.

```markdown
#### [GATE {번호}] {통과 의미}
이 GATE를 통과해야 다음 단계로 진행한다.
- [ ] {조건 1}
- [ ] {조건 2}
- [ ] {조건 3}

WARN 처리:
- {예외 조건} → {처리 방침: 스킵 / 사용자 확인 / 중단}
```

### GATE 번호 부여 규칙
- GATE 0: 데이터 수집/사전 조건 확인
- GATE 1: 설계/분류 사용자 확인
- GATE 2: 실행 전 검증 통과
- GATE 3 이상: 단계별 완료 확인
- DONE 직전 GATE: 최종 사용자 승인

### NEVER 룰 병행 (우회 차단)
GATE 추가 시 NEVER 섹션에 같이 명시:
```markdown
### NEVER
- [GATE N] 통과 전 {다음 단계 행위} 금지
```

### 데이터 소스 우선순위 (해당 시)
다중 소스 사용 스킬은 ALWAYS 또는 절차 시작에 우선순위표 명시:
```markdown
| 순위 | 소스 | 용도 |
|------|------|------|
| PRIMARY | {소스 A} | {용도} |
| SECONDARY | {소스 B} | {보조 용도} |
| FORBIDDEN | {소스 C} | 절대 금지 |
```

### 외부 컨텍스트 처리 (해당 시)
다른 세션/대화 결정사항이 스킬에 자동 반영 안 되는 경우 명시:
```markdown
## 외부 컨텍스트 처리 (CRITICAL)
다른 세션/대화 결정사항은 본 스킬로 자동 반영 불가.
해결 경로: {1. 선행 데이터 갱신 / 2. GATE에서 사용자 명시 추가}
```

### 권장 한도
- 스킬당 GATE는 최대 3개 이내 (예외: harness-dev-process Phase Gate 5개)
- 형식적 GATE 금지 — 실제 우회 가능 지점에만 배치

## 완료 조건 (DONE WHEN)
- [ ] [GATE] {GATE 번호} 통과 — 외부 변경 직전 사용자 확인 (해당 시)
- [ ] [FILE] {경로} — 파일 존재 확인
- [ ] [CONTENT] {경로} contains {패턴} — 파일 내용 확인
- [ ] [GIT] no-uncommitted — 미커밋 변경 0건
- [ ] [GIT] branch-exists {패턴} — 브랜치 존재
- [ ] [MANUAL] {설명} — 자동 불가, 사용자 리마인더
