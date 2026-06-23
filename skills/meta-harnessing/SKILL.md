---
name: harnessing
description: "하네스 검토 및 개선. 스코프 지정 가능 — /harnessing hooks, /harnessing rules, /harnessing skills, /harnessing vendor, /harnessing memory. 미지정 시 전체 검토."
---

## 스킬 규칙
### ALWAYS
- 전체 구조 스캔 후 판단 (부분 스캔 금지)
- 발견 사항 심각도 분류 (HIGH/MEDIUM/LOW)
- SoT 경계 (rules/ vs skills/ vs rules-on-demand/) 준수
- **ADR 신설/수정/폐기 전 사용자 의도 1회 확인 의무** (GATE 0: ADR-INTENT)
### NEVER
- 확인 없이 공통룰 직접 수정 금지
- 임의로 폴더 구조 변경 금지
- **사용자 의도 확인 없이 ADR 신설/수정/폐기 금지** — ADR-007 사고(당일 폐기, PR 4건 정정) 재발 방지

## [GATE 0: ADR-INTENT] ADR 작성 전 사용자 의도 확인 (CRITICAL)

`base/guides/decisions/` 하위에 신규 ADR 작성 / 기존 ADR 수정 / ADR 폐기 표기 시 본 GATE 통과 필수.

### 통과 조건

- [ ] 사용자가 본 의사결정에 대해 **명시적으로 발화한 의도** 확인 (인용 가능한 사용자 원문 존재)
- [ ] 발화가 모호하면 1회 확인 질문 ("이런 방향 맞나요?" 또는 객관식 선택지)
- [ ] 추정 기반 ADR 작성 금지

### 트리거

- `base/guides/decisions/{N}-*.md` 신설
- 기존 ADR 상태를 "폐기 (Superseded)" 또는 "수정"으로 변경
- ADR README 인덱스에 신규 행 추가

### 위반 시 처리

- ADR 작성 중단 → 사용자 의도 확인 질문 발생
- 발화 인용 없이 진행하면 폐기 비용 발생 (ADR-007 = PR 4건 소비 사례)

### 사례

| 패턴 | 통과 |
|------|------|
| 사용자 원문: "모든 요청은 오케스트레이터를 탄다" → ADR-008 (orchestrator 의무) | ✅ |
| 사용자 발화 없이 "owner skill 직접 호출이 합리적"이라고 추정 → ADR-007 | ❌ (당일 폐기) |

# /harnessing — 하네스 깎기

하네스 구성 요소 전체 또는 특정 범위만 검토하고 개선점을 찾는 스킬.

## 언제 사용하는가

- 하네스 구조를 점검/개선하고 싶을 때
- Hook이 의도대로 동작하는지 확인하고 싶을 때
- 규칙/커맨드/스킬 간 정합성을 검토하고 싶을 때
- 새로운 규칙이나 Hook을 추가한 후 전체 영향 확인
- 메모리, cmux, vendor, commands처럼 특정 축만 부분 검토하고 싶을 때
- 하네싱 전담 에이전트와 대화하며 구조 개선안/마이그레이션 순서를 잡고 싶을 때
- `weekly-report` 같은 고비용 수동 command를 auto-trigger 없이 반자동화하고 싶을 때

## 입력 스코프

기본값은 전체 검토다. 필요하면 아래처럼 범위를 줄여 실행한다:

| 호출 | 의미 |
|------|------|
| `/harnessing` | 전체 검토 |
| `/harnessing hooks` | Hook/validator/설정만 검토 |
| `/harnessing rules` | rules + rules-on-demand만 검토 |
| `/harnessing commands` | commands만 검토 |
| `/harnessing vendor` | vendor skill import만 검토 |
| `/harnessing memory` | 로컬 메모리/feedback 문서만 검토 (최근 변경 우선) |

scope가 주어지면 관련 자산만 읽고, 전체 검토 절차를 그 범위 안에서 축소 적용한다.

## 실행 절차

### 1단계: 현황 스캔

아래 자산을 읽고 현재 상태를 파악한다:

| 자산 | 위치 | 확인 항목 |
|------|------|----------|
| Rules | `agents/rules/*.md` | 총 개수, 최근 변경, 충돌 |
| Rules on-demand | `agents/rules-on-demand/*.md` | 트리거 키워드 동작 여부 |
| Commands | `agents/skills/*.md` | 총 개수, 규칙 참조 여부 |
| Hooks | `.claude/hooks/*.sh` | 맥락 판별 정상, 로그 확인 |
| **Hook 등록** | `.claude/settings.json` | Hook 파일이 settings.json에 등록되어 있는지 |
| Skills | `agents/skills/*/SKILL.md` | 템플릿/validator 정합성 |
| Orchestrators | `agents/skills/harness-*/SKILL.md` | 상위 라우터 ↔ 하위 owner 경계 |
| Vendor | `agents/skills/vendor/manifest.json` | 최신 여부, self-contained |
| 도메인 에이전트 | `agents/subagents/` | 서비스 커버리지 |

### 2단계: 맥락 판별 검증

각 Hook이 아래 시나리오에서 올바르게 동작하는지 시뮬레이션:

| 시나리오 | 기대 동작 |
|---------|----------|
| 개발 코드 커밋 (workspace/) | 차단 (사용자 요청 시만) |
| 개발 코드 push | 차단 (upstream diff 기준) |
| 개발 코드 PR create | 차단 (origin/main diff 기준) |
| 문서/작업일지 커밋 (base/) | 허용 |
| 설정 파일 커밋 (.claude/) | 허용 |
| 하네스 INIT 상태에서 코드 수정 (Edit/Write) | 차단 |
| 하네스 INIT 상태에서 Bash로 코드 수정 | 현재 미차단 (알려진 제한) |
| 하네스 미적용 프로젝트 코드 수정 | 허용 |
| 빌드 실패 후 | 메시지 주입 |

### 3단계: 정합성 검토

| 검토 항목 | 방법 |
|----------|------|
| 규칙 ↔ Hook 매핑 | 모든 CRITICAL 규칙에 대응하는 Hook이 있는지 |
| 커맨드 ↔ 규칙 참조 | 커맨드가 관련 규칙을 참조하는지 |
| 상위 라우터 ↔ 하위 owner | `harness-orchestrator`가 owner를 침범하지 않는지, branch dispatch만 수행하는지 |
| branch consistency | `dev / service-bootstrap / service-ops / harnessing` 경계가 문서와 trigger에 일치하는지 |
| 고비용 수동 command | auto-trigger 제외가 맞는지, helper script/skill로 반자동화 가능한지 |
| 템플릿 ↔ Validator | 템플릿 필수 섹션이 Validator에 반영되어 있는지 |
| 레이어 배치 | 각 자산이 맞는 레이어에 있는지 (invariant / demo / legacy / 특화) |
| 문서 경로 | 참조 경로가 실제 파일과 일치하는지 |

### Memory 스코프 체크리스트

`/harnessing memory` 실행 시:

1. **변경 파일 감지** (혼합 방식):
```bash
# git tracked 자산 (rules, commands, hooks, AGENTS.md)
git diff --name-only HEAD~5 -- agents/ .claude/ AGENTS.md

# git untracked 자산 (메모리 — gitignore)
MEMDIR="$HOME/.claude/projects/-Users-$(whoami)-Documents-ai-team-standards/memory"
find "$MEMDIR" -name "*.md" -mtime -1 -exec ls -lt {} +

# 아직 커밋 안 된 변경
git diff --name-only -- agents/ .claude/
```

2. **변경된 파일 읽고 검토**:
   - 내용이 현재 프로젝트 상태와 맞는지
   - 다른 메모리/규칙 파일과 충돌/중복이 없는지
   - MEMORY.md 인덱스에 반영되어 있는지 (메모리 파일)
   - MEMORY.md가 200줄 한도를 넘지 않는지

3. **정합성 확인**:
   - 메모리에 적힌 파일 경로가 실제 존재하는지
   - 메모리의 규칙이 agents/rules/와 충돌하지 않는지
   - 오래된 메모리(30일+)가 아직 유효한지

4. **검토 결과 기록**:
```
.claude/harnessing/
└── YYYY-MM-DD-{scope}-review.md
    ├── 검토 범위
    ├── 변경 파일 목록
    ├── 각 파일 판정 (✅ 정상 / ⚠️ 주의 / ❌ 수정 필요)
    └── 조치 필요 항목
```
검토할 때마다 결과 파일을 남긴다. 이력이 쌓이면 어떤 항목이 자주 깨지는지 패턴이 보인다.

### CMUX 통신 체크 (전체 검토 시 포함)

세션 간 통신이 필요한 경우 아래를 확인:

| 검토 항목 | 기준 |
|----------|------|
| live screen 읽기 | 스크린샷 대신 `cmux read-screen --workspace ... --surface ... --lines ...` 사용 |
| surface 탐색 | `cmux tree --workspace ... --all` 또는 `cmux list-pane-surfaces --workspace ... --pane ...` 선행 |
| cross-workspace 재현성 | 다른 워크스페이스를 읽을 때 `--workspace`를 명시 |
| 메시지 전송 | **반드시** `cmux send -- "..."` + `cmux send-key ... enter` 분리 실행 (`\n` 방식 금지) |
| key 전송 대상 | `send-key`는 `pane`가 아니라 `surface` 대상 |
| 에러 처리 | `Surface is not a terminal`이면 terminal surface를 다시 찾도록 문서화 |
| 기준 문서 정합성 | 로컬 메모리(`${CLAUDE_HOME:-~/.claude}/projects/.../memory/*.md`)와 `agents/skills/session-monitor.md`가 충돌하지 않는지 확인 |

### 4단계: 개선 제안

발견된 GAP을 아래 형식으로 정리:

``` 
## 발견 항목

### [Priority] 제목
- 현재: ...
- 문제: ...
- 제안: ...
- 영향 범위: ...
```

기본 출력 형식:

```markdown
## Findings
## Options
## Recommendation
## Handoff
```

표준 템플릿: `agents/templates/harnessing-review.md`

### 5단계: 사용량 스냅샷

모든 하네스 자산의 사용 빈도를 측정한다. 월별 비교로 안 쓰이는 자산을 정리.

```bash
echo "=== Rules ==="
for rule in agents/rules/*.md; do
  name=$(basename "$rule" .md)
  commits=$(git log --oneline -30 --all --grep="$name" 2>/dev/null | wc -l | tr -d ' ')
  refs=$(grep -rl "$name" agents/skills/ agents/subagents/ 2>/dev/null | wc -l | tr -d ' ')
  printf "  %-25s commits:%-3s refs:%-3s\n" "$name" "$commits" "$refs"
done

echo "=== Commands ==="
for cmd in agents/skills/*.md; do
  name=$(basename "$cmd" .md)
  commits=$(git log --oneline -30 --all --grep="$name" 2>/dev/null | wc -l | tr -d ' ')
  printf "  %-25s commits:%-3s\n" "$name" "$commits"
done

echo "=== Memory ==="
MEMDIR="$HOME/.claude/projects/-Users-$(whoami)-Documents-ai-team-standards/memory"
if stat --version >/dev/null 2>&1; then
  # GNU/Linux
  find "$MEMDIR" -name "*.md" ! -name "MEMORY.md" -exec stat -c "%Y %n" {} \; | sort -rn | while read ts f; do
    days=$(( ($(date +%s) - ts) / 86400 ))
    printf "  %-40s %s일 전\n" "$(basename $f)" "$days"
  done
else
  # macOS/BSD
  find "$MEMDIR" -name "*.md" ! -name "MEMORY.md" -exec stat -f "%m %N" {} \; | sort -rn | while read ts f; do
    days=$(( ($(date +%s) - ts) / 86400 ))
    printf "  %-40s %s일 전\n" "$(basename $f)" "$days"
  done
fi

echo "=== Hooks ==="
if [ -f /tmp/claude-hook-hits.log ]; then
  echo "  총 hit: $(wc -l < /tmp/claude-hook-hits.log)"
  echo "  BLOCKED: $(grep -c BLOCKED /tmp/claude-hook-hits.log)"
  echo "  ALLOWED: $(grep -c ALLOWED /tmp/claude-hook-hits.log)"
fi

echo "=== Domain Agents ==="
for agent in agents/subagents/*.md agents/subagents/*/*.md agents/subagents/*/*/*.md; do
  name=$(basename "$agent" .md)
  refs=$(grep -rl "$name" agents/skills/ agents/rules/ 2>/dev/null | wc -l | tr -d ' ')
  printf "  %-25s refs:%-3s\n" "$name" "$refs"
done
```

판정 기준:
- commits:0 + refs:0 → **정리 후보** (사용 증거 없음)
- 메모리 30일+ 미변경 → **유효성 재확인** 필요
- Hook hit 0건 → **트리거 조건 점검** 필요

검토 결과 파일에 사용량 섹션을 포함한다:
```
## 사용량 스냅샷 (YYYY-MM-DD)
| 자산 | 이름 | commits | refs | 판정 |
|------|------|---------|------|------|
| rule | performance | 0 | 1 | ⚠️ 정리 후보 |
```

### 6단계: 적용 (사용자 확인 후)

- 경미한 수정 → 바로 적용
- 규칙/Hook 변경 → `/review-rules` 프로세스
- 구조 변경 → Codex 검토 요청
- 구조 변경 검토는 기본적으로 **제안 우선**이며, 수정은 `Handoff` 확정 후 실행한다.

## 병렬 실행 권장

가능하면 아래 에이전트를 병렬로 투입:

| 에이전트 | 검토 관점 |
|---------|----------|
| harnessing | 전체 구조 총괄, SoT 경계, 중복/드리프트 조정 |
| code-reviewer | Hook 스크립트 품질 |
| security-reviewer | Hook bypass 가능성 |
| architect | 레이어 구조 정합성 |

## 참고 문서

- `base/guides/decisions/harness-engineering/` — 의사결정 이력
- `base/guides/decisions/harness-engineering/11-layered-harness-design.md` — 레이어 설계
- `agents/skills/harness-dev-process/SKILL.md` — 오케스트레이터
- `agents/rules-on-demand/` — 도메인·레이어별 준수 규칙 (workflow-guard.sh 소스)
- `.claude/hooks/workflow-guard.sh` — 편집 파일 → 준수 규칙 자동 주입 훅
- `.claude/hooks/keyword-detector.sh` — 키워드 → Phase 유도 + GATE 1→2 blocking
- `.claude/hooks/triggers.json` — keyword→command 매핑

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] 검토 대상 전체 스캔 완료
- [ ] [MANUAL] 발견 사항 보고 (HIGH/MEDIUM/LOW)
- [ ] [MANUAL] 수정 필요 항목 명시
