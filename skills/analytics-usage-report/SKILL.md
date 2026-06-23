---
name: usage-report
description: "사용 패턴 인사이트 리포트"
model: haiku
---

<!-- personal 모드는 단순 집계라 haiku로 충분. team 모드의 "인사이트 제안"(D항목)이
     필요할 때만 호출자가 sonnet으로 명시 override. -->


## 스킬 규칙
- [ALWAYS] 지정 기간/범위 내 데이터만 분석
- [NEVER] 다른 팀원 사용 데이터 임의 분석 금지

사용 패턴을 분석하여 인사이트 리포트를 생성합니다.

## 실행 절차

## 인자

```
/usage-report [personal|team] [기간: 7d|30d|90d (기본: 30d)]
```

- `personal` (기본): 본인의 사용 패턴
- `team`: 팀 전체 비교 (각 팀원 usage-log 집계)

## 데이터 소스

### 1차: usage-log.jsonl (구조화된 데이터)
```
base/personal/{사번}/usage-log.jsonl
```

각 라인은 `/wrap` 실행 시 자동 생성된 세션 로그:
```json
{
  "date": "2026-03-12",
  "session_id": "abc123",
  "duration_min": 45,
  "commands": ["/work-start", "/work-tasks", "/worklog"],
  "rules_triggered": ["jira-workflow", "daily-workflow"],
  "agents_used": ["code-reviewer", "dba"],
  "commits": 3,
  "files_changed": 8,
  "categories": ["docs", "rules"]
}
```

### 2차: 보조 데이터 (usage-log 없을 때 폴백)
- `git log --author={이메일}` — 커밋 패턴
- `base/personal/{사번}/worklog/` — 작업일지

## 분석 항목

### personal 모드

```bash
# usage-log.jsonl 읽기
LOGFILE="base/personal/$(git config user.name | sed 's/.*//;')/usage-log.jsonl"
# 폴백: 사번 직접 사용
# LOGFILE="base/personal/<YOUR_USER_ID>/usage-log.jsonl"
```

#### A. 커맨드 사용 빈도
usage-log에서 `commands` 배열을 집계:
- Top 10 커맨드 (막대 차트)
- 사용하지 않는 커맨드 목록 (27개 중 미사용)

#### B. 규칙 트리거 빈도
usage-log에서 `rules_triggered` 배열을 집계:
- Top 10 규칙
- 트리거되지 않는 규칙 (16개 중 미사용 → 불필요한 규칙?)

#### C. 에이전트 활용 패턴
usage-log에서 `agents_used` 배열을 집계:
- 어떤 에이전트를 자주 쓰는지
- 사용 안 하는 에이전트 (활용 기회 놓치는 중?)

#### D. 작업 패턴
- 일별 세션 수 (최근 기간)
- 평균 세션 시간
- 커밋 타입 비율 (categories 기반)
- 요일별 활동 분포

#### E. 트렌드
- 주간 비교: 이번 주 vs 지난 주
- 새로 사용하기 시작한 커맨드/규칙
- 사용 빈도가 줄어든 커맨드/규칙

### team 모드

팀원별 usage-log.jsonl을 집계 (base/personal/*/usage-log.jsonl):

#### A. 팀 전체 커맨드 히트맵
```
           <YOUR_NAME>  <YOUR_NAME>  <YOUR_NAME>  <YOUR_NAME>  <YOUR_NAME>
/work-start  12            8            5            3            2
/work-tasks  15           10            3            2            1
/code-review  8            2            0            0            0
/tdd          3            0            0            0            0
```

#### B. 팀원별 활동 요약
- 총 세션 수, 평균 세션 시간, 주력 작업 카테고리

#### C. 채택률
- 전체 커맨드 27개 중 팀에서 실제 사용 비율
- 전체 규칙 16개 중 실제 트리거 비율
- → "팀이 잘 안 쓰는 기능" = 개선 또는 제거 대상

#### D. 인사이트 제안
데이터 기반으로 자동 생성:
- "code-review를 가장 많이 사용하는 <YOUR_NAME>의 설정을 팀에 공유하면?"
- "impact-analysis 규칙이 트리거된 적 없음 → 팀 교육 필요?"
- "/tdd를 사용하는 팀원이 커밋당 버그 수정 비율이 낮음"

## 출력 형식

```
╔══════════════════════════════════════════════════╗
║          USAGE REPORT (personal · 30d)           ║
╠══════════════════════════════════════════════════╣

📊 요약
├─ 기간: 2026-02-11 ~ 2026-03-12
├─ 총 세션: 42회 · 평균 세션: 52분
├─ 총 커밋: 68건 · 변경 파일: 312개
└─ 활성 커맨드: 14/27 (52%)

🔧 커맨드 TOP 10
├─ /worklog       ████████████████ 38회
├─ /work-tasks    ██████████████   32회
├─ /work-start    ████████████     28회
├─ /code-review   ████████         18회
├─ /wrap          ██████           14회
├─ /plan          ████              8회
├─ /tdd           ███               6회
├─ /brainstorm    ██                4회
├─ /e2e           ██                4회
└─ /build-fix     █                 2회

📋 규칙 트리거 TOP 5
├─ daily-workflow   ████████████ 42회
├─ jira-workflow    ██████████   38회
├─ git-workflow     ████████     28회
├─ doc-organization ██████       22회
└─ impact-analysis  ████          8회

⚠️ 미사용 (활용 기회?)
├─ 커맨드: /create-service, /add-project, /update-codemaps
└─ 규칙: apidog-workflow, patterns

📈 트렌드
├─ 이번 주: 12세션 (지난 주 대비 +20%)
├─ 신규 사용: /e2e (이번 주부터)
└─ 감소: /session-insights (3주 미사용)

╚══════════════════════════════════════════════════╝
```

## 주의사항

- usage-log.jsonl이 없거나 데이터 부족 시: git log 기반 간이 분석으로 폴백
- team 모드에서 개인별 세션 시간/빈도는 평가 목적이 아님을 명시
- 리포트 결과를 Confluence에 올릴지 사용자에게 확인

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 리포트 출력 완료
