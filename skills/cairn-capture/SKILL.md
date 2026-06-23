---
name: cairn-capture
description: 업무 수행 중·후의 지식을 md로 캡처하여 팀에 공용화. AI가 문맥을 추론해 위치+유형을 자율 제안 → 초안 생성 → (team 모드) git 커밋·푸시 제안. "캡처", "이거 문서화", "남겨둬", "공용화", "/cairn:capture" 키워드 및 세션 종료 시 능동 트리거.
---

# Cairn Capture — 업무 지식 공용화 루프

> Cairn의 차별화 엔진. "내 업무를 AI에게 학습시켜 팀에 공용화한다."
> 흔적(업무) → 돌탑(md) → 이정표(팀 공용화)

---

## 스킬 규칙

### ALWAYS

- **ALWAYS**: 캡처 트리거 시 AI가 **문맥 전체를 분석**(무슨 작업·어떤 프로젝트/서비스·영향범위)한 뒤 위치+유형을 **자율 추론·제안**한다. 분기표를 기계적으로 따르지 않는다.
- **ALWAYS**: 제안이 명백하면 바로 "이 내용을 {유형}으로 {경로}에 남길까요?" 1문항으로 확인. 영향범위가 애매할 때만 추가 1문항 질문한다 (질문은 최대 1개).
- **ALWAYS**: **영향범위(blast radius)가 저장 위치를 결정**한다 (아래 "위치 결정 원칙" 참조).
- **ALWAYS**: 생성하는 md에 YAML frontmatter(`type`, `created`, 관련 티켓/링크)와 breadcrumb를 포함한다.
- **ALWAYS**: 저장 후 상위 README/인덱스에 링크 1줄 추가한다 (탐색 비용 절감).

### NEVER (불변 3원칙)

- **NEVER**: 같은 결정·교훈을 2개 이상의 스코프에 중복 저장하지 않는다. SoT는 1곳, 상위 스코프는 링크 참조만 한다.
- **NEVER**: secret·token·API key·개인정보·사번 실값을 캡처 md에 포함하지 않는다. ENV_STANDARD 토큰/플레이스홀더로 대체한다.
- **NEVER**: 영향범위와 저장위치가 불일치하는 캡처를 실행하지 않는다 (예: 팀 전체 결정을 단일 프로젝트 docs/에 저장하거나, 단일 프로젝트 feature를 workspace decisions/에 올리는 것).
- **NEVER**: [GATE-SHARE] 통과 전에 `git push`(외부 공용화)를 실행하지 않는다. solo 모드에서는 push를 제안하지 않는다.

---

## 위치 결정 원칙 (영향범위 기반)

분기표를 외우지 말고, **"이 지식이 영향을 미치는 범위가 어디인가?"** 로 추론한다.

| 영향범위 | 저장 위치 | 예시 |
|---------|----------|------|
| **1개 프로젝트만** | `projects/{proj}/docs/features/` 또는 `projects/{proj}/docs/decisions/` | 특정 서비스 기능 스펙, 단일 레포 ADR |
| **1개 서비스(여러 프로젝트)** | `cairn-<team>/services/{svc}/decisions/` 또는 `cairn-<team>/services/{svc}/` | 서비스 아키텍처 결정, 서비스 운영 SOP |
| **여러 서비스 / 팀 전체** | `cairn-<team>/decisions/` | 플랫폼 표준, 팀 공통 ADR |
| **재사용 패턴·교훈** | `cairn-<team>/knowledge/lessons/{domain}/` | DB 쿼리 패턴, API 설계 교훈 |
| **운영 절차 (runbook)** | `cairn-<team>/runbooks/` | 배포 체크리스트, 장애 대응 절차 |
| **일상 공통업무** | `cairn-<team>/operations/` | 점검 이력, 표준화 작업, 내재화 기록 |
| **개인 작업일지·메모** | `.cairn/personal/` (gitignore, 공유 안 함) | 개인 세션 기록, 임시 메모 |

> **SoT 단일성 강제**: 프로젝트 레포 `docs/`에 이미 있으면 workspace `decisions/`에 복사하지 않고 링크만 추가한다. 반대도 동일.

---

## 캡처 유형

| 유형 | 무엇 | 템플릿 구조 |
|------|------|------------|
| **feature** | 기능 설계/스펙 | 요구 → 설계 → 영향도 → 테스트 |
| **decision** | 의사결정 (ADR) | 맥락 → 결정 → 대안 → 영향 |
| **lesson** | 재사용 패턴/교훈/함정 | 배경 → 문제 → 해결 → 재사용 포인트 |
| **runbook** | 반복 운영/절차 | 목적 → 사전조건 → 단계 → 검증 |
| **operations** | 일상 공통업무 기록 | 날짜 → 작업 → 결과 → 후속조치 |

유형 선택도 AI가 추론한다. 명백하면 제안에 포함, 애매하면 1문항으로 확인.

---

## 실행 절차

### 1. 캡처 대상 식별

- 수동 호출(`/cairn:capture [주제]`): 사용자가 지정한 주제를 기반으로 분석
- 능동 트리거(hook/오케스트레이터): 직전 세션의 변경(파일 diff, 내린 결정, 수행한 절차)을 요약

### 2. 자율 문맥 분석

AI가 아래를 추론한다 (사용자 인터럽트 최소화):

1. **무슨 작업인가** — 기능 구현·결정·운영절차·교훈 중 무엇
2. **어떤 프로젝트/서비스인가** — 단일 프로젝트인지, 서비스 범위인지, 팀 전체인지
3. **영향범위(blast radius)** — 1개 프로젝트 / 1개 서비스 / 팀 전체 / 개인
4. **저장 위치 + 유형** — 위 "위치 결정 원칙"에서 자동 도출

결론이 명백하면 → 제안 1문항으로 바로 확인 [GATE-CLASSIFY]
애매하면 → 영향범위를 묻는 1문항 추가 후 제안

### 3. 확인 [GATE-CLASSIFY]

- [ ] "이 내용을 **{유형}**으로 **{경로}**에 남길까요?" 확인
- 사용자가 거절하면 캡처 중단 (노이즈 방지)
- 사용자가 경로를 수정 제안하면 수정안으로 진행

### 4. md 초안 생성

- 유형별 템플릿으로 초안 작성
- YAML frontmatter: `type`, `created`, 관련 티켓/링크 포함
- Breadcrumb: `> 상위: [폴더명](../README.md)` 포함
- 사내/조직 종속값은 ENV_STANDARD 토큰/플레이스홀더로 작성 (공용화 시 재사용 가능하게)

### 5. 저장 + 인덱스 갱신

- 결정된 경로에 md 저장
- 상위 README/인덱스에 링크 1줄 추가

### 6. 공용화 제안 [GATE-SHARE] (team 모드만)

- [ ] `mode == team` 확인
- [ ] 사용자에게 커밋 메시지 초안 제시 + **명시 승인** 요청
- [ ] 승인 후에만 `git add {파일} && git commit` → (요청 시) `git push`
- solo 모드: 로컬 저장까지만, push 제안 안 함

---

## 완료 조건 (DONE WHEN)

- [FILE] 결정된 유형·경로에 md 1개 생성됨 (frontmatter + breadcrumb 포함)
- [CONTENT] 캡처 md에 secret/token/개인정보 실값 없음
- [CONTENT] 저장 위치가 영향범위와 일치함 (불변 원칙 3 준수)
- [FILE] 상위 인덱스/README에 링크 1줄 추가됨
- [GATE] team 모드 공용화는 [GATE-SHARE] 사용자 승인 후에만 커밋/푸시됨
- [MANUAL] solo 모드는 로컬 저장으로 완료 (push 없음)

---

## 관련 문서

- `config/cairn.config.example.json` — mode/capture/team 설정
- `skills/analytics-learn/` — 패턴 추출 (캡처 엔진 보조)
- `skills/daily-wrap/` — 세션 단위 인사이트 추출
