---
tags:
  - type/reference
  - domain/rules
  - audience/claude
---

> 상위: [lessons](../README.md) · [knowledge](../../README.md)

# Common Guides & Learning Resources

Cross-language and cross-project guides.

## Documents

### System & Process

#### [Apidog Token Security Playbook](apidog-token-security-playbook.md)
**Type**: Security Guide | **Complexity**: Beginner
**When to Read**: Operating Apidog tokens in scripts and incident response

Covers:
- Immediate response flow for token exposure
- Storage policy (env first, local file fallback)
- Local verification commands
- Post-incident validation checklist

**Key Insight**: Fast token rotation and explicit storage rules are more important than ad-hoc masking.

---

#### [Rule System Architecture](rule-system-architecture.md)
**Type**: System Architecture | **Complexity**: Beginner
**When to Read**: Understanding how global, project, and session rules work together

Explains:
- Layered rule architecture (global → project → session)
- Why cross-references are critical
- Synchronization strategies for distributed rules
- How auto-classification helps organize documents
- Decision records for architectural choices

**Key Insight**: Distributed rule systems need explicit synchronization and visible dependencies to avoid chaos.

---

#### [Rule Synchronization Patterns](rule-synchronization-patterns.md)
**Type**: Pattern Reference | **Complexity**: Intermediate
**When to Read**: Actually implementing rule changes across multiple locations

Practical patterns:
- Pattern 1: Global-to-Project Sync
- Pattern 2: Project-Specific Overrides
- Pattern 3: Cross-Reference Web
- Pattern 4: Multi-Location Update Protocol
- Pattern 5: Conflict Resolution
- Pattern 6: Rule Evolution Tracking
- Pattern 7: Auto-Synced Rule Areas
- Pattern 8: Documentation Comments in Code

Includes ready-to-use checklists and bash scripts.

**Key Insight**: Following a consistent protocol prevents sync errors and makes changes auditable.

---

#### [Rule Design Principles](rule-design-principles.md)
**Type**: Design Principles | **Complexity**: Advanced
**When to Read**: Before creating or significantly updating shared rules

Core principles:
1. Layered Authority - Different layers, different authority levels
2. Explicit Scope Declaration - No ambiguous boundaries
3. Dependency Transparency - Show what depends on what
4. Versioning by Default - Track changes and migrations
5. Explicitness Over Implicitness - Assume nothing about reader context
6. Context-Aware Defaults - Different guidance for different situations
7. Migration Pathways - Clear upgrade paths when rules change
8. Observable Compliance - Ways to verify rule is followed

Includes structural guidelines, anti-patterns, governance model, and metrics.

**Key Insight**: Good rules scale when they're explicit, versioned, and observable.

---

## 추가 문서 목록

| 문서 | 설명 |
|------|------|
| [cross-reference-rules-automation.md](cross-reference-rules-automation.md) | 규칙 파일 교차참조 자동화 |
| [documentation-architecture.md](documentation-architecture.md) | 문서 아키텍처 가이드 |
| [implementation-guide.md](implementation-guide.md) | 규칙 파일 자동화 구현 가이드 |
| [jira-management-rules.md](jira-management-rules.md) | Jira 관리 규칙 |
| [jira-mcp-limitations.md](jira-mcp-limitations.md) | Jira MCP 도구 한계와 해결책 |
| [jira-task-completion-rules.md](jira-task-completion-rules.md) | Jira 태스크 완료 처리 규칙 |
| [k8s-cluster-migration-crosscheck-ops.md](k8s-cluster-migration-crosscheck-ops.md) | K8s 클러스터 이관 — 크로스체크 명령어 사례집 |
| [mcp-tools-guide.md](mcp-tools-guide.md) | MCP Tools Integration Guide |
| [performance-issue-doc.md](performance-issue-doc.md) | 성능 이슈 분석 문서 템플릿 |
| [playwright-e2e-patterns.md](playwright-e2e-patterns.md) | Playwright E2E 테스트 패턴 및 베스트 프랙티스 |
| [playwright-e2e-test-workflow.md](playwright-e2e-test-workflow.md) | Playwright E2E 테스트 워크플로우 |
| [template.md](template.md) | 학습 문서 템플릿 |
| [brew-postgresql-dyld-fix.md](brew-postgresql-dyld-fix.md) | brew postgresql dyld 에러 해결 (Apple Silicon) |

---

## Learning Session Context

**Session Focus**: Analyzing and documenting rule system architecture

### What This Session Revealed

#### Problem Discovered
When implementing rules across multiple locations (~/.claude/rules, agents/rules/, CLAUDE.md), consistency breaks down without explicit synchronization strategy.

#### Solution Emerged
A layered architecture with:
- **Global defaults** for team-wide standards
- **Project overrides** for specific constraints
- **Session context** for current work guidance
- **Cross-references** to show dependencies
- **Synchronization protocol** to keep in sync

#### Why It Matters
- Rules are team knowledge artifacts
- Distributed rules require explicit governance
- Without clear structure, contradictions emerge
- Cross-references enable navigation and discovery

### Key Takeaways for Teams

1. **Rules are Architecture Decisions**: Treat them like code ADRs
2. **Explicit Beats Implicit**: Make scope, dependencies, authority clear
3. **Layers Prevent Chaos**: Global → Project → Session hierarchy works
4. **Sync is Mandatory**: Passive "natural sync" doesn't work
5. **Dependencies Matter**: Rules aren't isolated; show the web
6. **Verification is Key**: If you can't verify it, it won't be followed

## Related Documents

### In This Repository
- **Java Guides**: `knowledge/lessons/java/`
- **Database Guides**: `knowledge/lessons/db/`

### Team Rules (canonical)
팀 규칙은 `rules/`(매 세션 자동 로드)와 `rules-on-demand/`(키워드/파일 트리거 로드)에 있다. 진입점은 `AGENTS.md`.

## How to Use These Documents

### For Individual Contributors
1. Start with [Rule System Architecture](rule-system-architecture.md) to understand the overall structure
2. Reference [Rule Synchronization Patterns](rule-synchronization-patterns.md) when making changes
3. Consult [Rule Design Principles](rule-design-principles.md) to understand "why" behind rules

### For Team Leads
1. Review [Rule Design Principles](rule-design-principles.md) before creating team-wide rules
2. Use [Rule Synchronization Patterns](rule-synchronization-patterns.md) to update shared rules
3. Reference [Rule System Architecture](rule-system-architecture.md) when onboarding new teams

## Implementation Checklist

When establishing rule systems in your team:

```markdown
- [ ] Choose appropriate layers (global/project/session)
- [ ] Create CLAUDE.md for project context
- [ ] Establish cross-reference convention
- [ ] Define synchronization protocol
- [ ] Communicate layers and authority to team
- [ ] Set up verification mechanisms (automated or manual)
- [ ] Document migration path for rule changes
- [ ] Add version tracking to rules
- [ ] Create related rules section template
- [ ] Establish governance (who approves what)
```

---

**Type**: Guide Index
**Status**: Active
