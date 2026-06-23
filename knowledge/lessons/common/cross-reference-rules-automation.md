---
tags:
  - type/automation
  - domain/rules
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 규칙 파일 교차참조 자동화

**작성일**: 2026-01-30
**대상**: Claude Code 규칙 관리 시스템

## 세션 요약

2026-01-30 세션에서 8개의 규칙 파일(`~/.claude/rules/`)에 "## Related Rules" 섹션을 수동으로 추가했습니다.

**수정된 파일**:
- `agents.md`
- `coding-style.md`
- `security.md`
- `testing.md`
- `git-workflow.md`
- `performance.md`
- `patterns.md`
- `hooks.md`
- `doc-organization.md`

## 발견된 반복 패턴

### 1. 동일 구조의 섹션 추가
각 파일의 마지막에 동일한 구조로 추가:
```markdown
---

## Related Rules

- [filename.md](filename.md) - Description
- [other-file.md](other-file.md) - Context
```

### 2. 수동 관계 매핑 작업
- 각 파일마다 관련 규칙을 수동으로 식별
- 파일 간의 상호 참조 정의
- 링크 및 설명 작성
- 프로젝트 repo와 홈 디렉토리 간 동기화

### 3. 두 위치의 파일 동기화
- `~/.claude/rules/` (개인 홈)
- `<YOUR_PLUGIN_ROOT>/agents/rules/` (프로젝트 repo)
- 동일한 변경을 양쪽에 모두 반영

## 자동화 가능한 작업

### A. 규칙 파일 관계 그래프 생성
**현재 수동 작업**: 각 파일의 내용을 읽고 수동으로 관련성 판단

**자동화 방안**:
1. 모든 규칙 파일의 제목과 주요 키워드 추출
2. 키워드 기반 자동 관계 매핑
3. `related-rules-map.json` 생성

```json
{
  "agents.md": {
    "keywords": ["agent", "workflow", "execution", "planner", "tdd-guide"],
    "relatedFiles": [
      { "file": "testing.md", "reason": "tdd-guide agent usage" },
      { "file": "security.md", "reason": "security-reviewer agent" },
      { "file": "git-workflow.md", "reason": "agent-driven workflow" }
    ]
  },
  "testing.md": {
    "keywords": ["test", "coverage", "TDD", "unit", "integration", "e2e"],
    "relatedFiles": [
      { "file": "agents.md", "reason": "tdd-guide, e2e-runner agents" },
      { "file": "git-workflow.md", "reason": "TDD in feature workflow" }
    ]
  }
}
```

### B. 관계 맵에서 자동 문서 생성
**목표**: `related-rules-map.json` → 각 파일의 "## Related Rules" 섹션 자동 생성

**스크립트**:
```bash
#!/bin/bash
# update-related-rules.sh

# 1. 관계 맵 로드
# 2. 각 파일 읽기
# 3. "## Related Rules" 섹션 생성 또는 업데이트
# 4. 두 위치(홈 + 프로젝트) 자동 동기화
```

### C. 파일 동기화 자동화
**현재 수동 작업**: `cp ~/.claude/rules/doc-organization.md /path/to/project/`

**자동화 방안**:
1. 홈 디렉토리 변경 감지 (watchman, inotify)
2. 자동 양방향 동기화
3. 충돌 감지 및 경고

```bash
# .claude/hooks/sync-rules.sh
SYNC_PAIRS=(
  "~/.claude/rules/doc-organization.md:${PROJECT}/agents/rules/doc-organization.md"
  "~/.claude/rules/agents.md:${PROJECT}/agents/rules/agents.md"
)
```

## 구현 전략

### Phase 1: 관계 맵 생성
1. 수동으로 `related-rules-map.json` 작성
2. 각 파일의 핵심 개념과 키워드 정의
3. 파일 간 의존성/참조 관계 명확화

### Phase 2: 자동 생성 스크립트
1. Python/Node.js 스크립트 작성
2. 템플릿 기반 "Related Rules" 섹션 생성
3. 두 위치 자동 동기화

### Phase 3: 후킹 시스템 통합
1. Pre-commit 훅: 관계 맵 검증
2. Post-edit 훅: 자동 동기화
3. Stop 훅: 양쪽 파일 검증

## 예상 효과

| 항목 | 현재 | 자동화 후 |
|------|------|---------|
| 규칙 파일 업데이트 시간 | 10분/파일 | 10초/전체 |
| 동기화 오류 | 수동 실수 가능 | 자동 검증 |
| 관계 맵 유지보수 | 수동 | 반자동 (키워드 기반) |
| 새 규칙 추가 | 수동으로 전체 재작성 | 추가만 필요 |

## 구현 복잡도

### 낮음 (즉시 가능)
- `related-rules-map.json` 수동 작성
- Bash 스크립트로 간단한 동기화

### 중간 (1-2시간)
- Python으로 자동 생성 스크립트
- 템플릿 기반 문서 생성

### 높음 (고급)
- Watchman 기반 실시간 동기화
- 규칙 파일 변경 감지 및 의존성 자동 업데이트

## 다음 단계

1. **`related-rules-map.json` 설계**: 자동화 기반이 될 메타데이터
2. **동기화 스크립트 작성**: 양방향 동기화 로직
3. **테스트**: 홈/프로젝트 디렉토리 간 일관성 검증
4. **CI/CD 통합**: Pre-commit 훅으로 자동 검증

## 참고

- 기존 규칙 관계: `<YOUR_PLUGIN_ROOT>/agents/rules/` 참조
- 동기화 규칙: `doc-organization.md` - "공통 설정 변경 시 동기화 필수" 섹션
- 관련 자동화: `agents/knowledge/lessons/common/` 폴더의 다른 자동화 패턴들
