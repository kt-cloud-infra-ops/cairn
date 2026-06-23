---
name: session-insights
description: "세션 인사이트 대시보드 생성"
model: haiku
---

<!-- 전체 흐름이 bash 집계 + jq 통계 + 대시보드 출력 (read-only). 토큰 절약 목적 haiku. -->


## 스킬 규칙
- [ALWAYS] 세션 데이터 기반 분석 (추정 아닌 관찰)
- [NEVER] 개인 세션 데이터를 팀 공유 문서에 저장 금지

세션 데이터를 분석하여 인사이트 대시보드를 생성합니다.

## 데이터 소스
다음 경로를 순서대로 확인해 존재하는 경로만 사용:
- `.claude/projects/` 또는 `${CLAUDE_HOME:-~/.claude}/projects/` - 프로젝트별 세션 기록 (*.jsonl)
- `.claude/todos/` 또는 `${CLAUDE_HOME:-~/.claude}/todos/` - TODO 기록

## 분석 항목

### 1. 전체 통계
다음 bash 명령어로 세션 데이터를 수집하세요:

```bash
# 데이터 경로 자동 탐색
PROJECT_DIR=".claude/projects"
TODO_DIR=".claude/todos"
[ -d "$PROJECT_DIR" ] || PROJECT_DIR="$HOME/.claude/projects"
[ -d "$TODO_DIR" ] || TODO_DIR="$HOME/.claude/todos"

# 모든 프로젝트의 세션 파일 목록
find "$PROJECT_DIR" -name "*.jsonl" -type f 2>/dev/null

# 각 세션 파일에서 timestamp 추출하여 분석
for f in "$PROJECT_DIR"/*/*.jsonl; do
  [ -e "$f" ] || continue
  echo "=== $f ==="
  cat "$f" 2>/dev/null | jq -r 'select(.type=="user") | .timestamp' 2>/dev/null | head -5
done
```

### 2. 날짜별 세션 수
각 프로젝트의 jsonl 파일에서 timestamp를 추출하여 날짜별로 그룹핑:
- 최근 7일간 일별 세션 수
- 가장 활발했던 날

### 3. 시간대별 활동 패턴
timestamp의 시간대를 분석하여:
- 주로 작업하는 시간대 (아침/오후/저녁/심야)
- 시간대별 세션 분포

### 4. 프로젝트별 활동량
`$PROJECT_DIR` 하위 폴더별로:
- 세션 파일 크기 (대략적인 활동량)
- 마지막 세션 시간
- 총 세션 수

### 5. 최근 세션 요약
가장 최근 세션들의:
- 첫 메시지 내용 (무슨 작업을 했는지)
- 세션 지속 시간 (첫 timestamp ~ 마지막 timestamp)

---

## 출력 형식

```
╔══════════════════════════════════════════════════════════════╗
║                    SESSION INSIGHTS                          ║
╠══════════════════════════════════════════════════════════════╣

📊 전체 통계
├─ 총 프로젝트 수: X개
├─ 총 세션 수: X개
└─ 분석 기간: YYYY-MM-DD ~ YYYY-MM-DD

📅 최근 7일 활동
├─ 01/19 (일): ████████ 8 sessions
├─ 01/18 (토): ████ 4 sessions
├─ ...
└─ 가장 활발한 날: 01/19 (8 sessions)

⏰ 시간대별 패턴
├─ 오전 (06-12): ██████ 30%
├─ 오후 (12-18): ████████████ 50%
├─ 저녁 (18-24): ████ 15%
└─ 심야 (00-06): █ 5%

📁 프로젝트별 활동 (Top 5)
├─ <your_service>: 25 sessions (마지막: 2시간 전)
├─ <your_other_service>: 10 sessions (마지막: 1일 전)
└─ ...

🕐 최근 세션
├─ [01/19 09:00] claude - "메인 프로젝트 설정..."
├─ [01/18 15:30] <your_service> - "테스트 코드 작성..."
└─ ...

╚══════════════════════════════════════════════════════════════╝
```

위 분석을 수행하고 대시보드 형태로 출력하세요.

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 인사이트 대시보드 출력 완료

## 실행 절차

1. 세션 데이터 수집 (todo, memory, 도구 호출 패턴)
2. 5가지 분석 수행 (생산성/패턴/병목/학습/제안)
3. 대시보드 포맷으로 출력
