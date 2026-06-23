---
tags:
  - type/guide
  - domain/rules
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# 문서 아키텍처 가이드

## 개요

Claude 메인 프로젝트의 계층적 문서 구조 설계 가이드입니다.

## 문서 계층 구조

```
┌─────────────────────────────────────────────────────┐
│                  CLAUDE.md (메인)                    │
│         전체 구조, 공통 원칙, 프로젝트 목록            │
│                    ~100줄                           │
└─────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ CLAUDE.md   │  │ CLAUDE.md   │  │ CLAUDE.md   │
│ (프로젝트A)  │  │ (프로젝트B)  │  │ (프로젝트C)  │
│  20-300줄   │  │  20-300줄   │  │  20-300줄   │
└─────────────┘  └─────────────┘  └─────────────┘
         │               │               │
         └───────────────┼───────────────┘
                         ▼
         ┌─────────────────────────────────┐
         │       docs/learnings/           │
         │    상세 기술 문서, 코딩 룰북      │
         │      프로젝트 횡단 지식          │
         └─────────────────────────────────┘
```

## 각 문서의 역할

### 메인 CLAUDE.md
- **위치**: `/claude/CLAUDE.md`
- **역할**: 진입점, 전체 구조 파악
- **내용**:
  - 프로젝트 구조 설명
  - 핵심 원칙 (3가지)
  - 슬래시 커맨드 목록
  - 하위 프로젝트 인덱스
  - 공통 코딩 가이드 (개념만)
  - 주간 리마인더
- **크기**: 100-150줄

### 프로젝트별 CLAUDE.md
- **위치**: `/{project}/CLAUDE.md`
- **역할**: 해당 프로젝트 컨텍스트 정의
- **내용**:
  - 프로젝트 개요
  - 기술 스택
  - 프로젝트 특화 가이드 (상세)
  - 관련 문서 링크
- **크기**: 20-300줄 (프로젝트 복잡도에 따라)

### docs/learnings/
- **위치**: `/claude/docs/learnings/`
- **역할**: 상세 기술 지식, 학습 기록
- **내용**:
  - 코딩 표준 상세
  - 디자인 패턴 가이드
  - SRE 가이드
  - 프로젝트별 기술 문서
- **명명 규칙**: `{번호}-{주제}.md` (예: `005-sre-coding-guide.md`)

### base/guides/decisions/
- **위치**: `/claude/base/guides/decisions/`
- **역할**: 아키텍처 의사결정 기록 (ADR)
- **내용**:
  - 결정 배경 (컨텍스트)
  - 대안 검토
  - 채택 이유
  - 예상 결과
- **명명 규칙**: `{번호}-{주제}.md`

### agents/knowledge/lessons/common/
- **위치**: `/claude/agents/knowledge/lessons/common/`
- **역할**: 자동화 패턴 기록
- **내용**:
  - 반복 작업 패턴
  - 자동화 방법
  - 스크립트/훅 정의

## 심볼릭 링크 구조

```
/claude/projects/
├── luppiter-web -> /develop/workspace/luppiter-web
├── morning_report -> /develop/workspace/morning_report
├── zabbix_api -> /develop/workspace/zabbix_api
└── luppiter_inv -> /develop/workspace/luppiter_inv
```

**특징**:
- 메인 프로젝트에서 하위 프로젝트 접근 가능
- 각 프로젝트는 별도 git repo
- 심볼릭 링크는 .gitkeep으로만 추적

## 새 프로젝트 추가 시 체크리스트

1. [ ] 심볼릭 링크 생성 (`projects/` 폴더)
2. [ ] 메인 CLAUDE.md 프로젝트 목록 업데이트
3. [ ] 프로젝트 CLAUDE.md 작성 여부 결정
4. [ ] 필요시 해당 프로젝트에 CLAUDE.md 생성
5. [ ] 관련 learnings 문서 링크 추가

## 프로젝트 CLAUDE.md 템플릿

```markdown
# {프로젝트명} 프로젝트

{한 줄 설명}

## 프로젝트 개요

- **기술 스택**: {기술 스택}
- **주요 기능**: {기능 설명}
- **포트/서버**: {해당시}

## {프로젝트 특화 섹션}

{필요한 가이드, 규칙, API 등}

## 참고 문서

- `/claude/docs/learnings/{관련 문서}.md`
```

## 관련 ADR

- `base/guides/decisions/002-claude-md-distributed-structure.md`
