---
tags:
  - type/guide
  - domain/rules
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# Rule System Architecture & Synchronization

## Overview

This document captures the architectural insights from establishing a distributed rule system across multiple locations in the Claude Code workflow.

**Session Date**: 2026-01-30
**Context**: Multi-location rule sync and cross-reference implementation

## Problem Statement

When implementing shared rules across multiple locations:
- **Home Rules** (`~/.claude/rules/`) - Global defaults for all projects
- **Project Rules** (`agents/rules/` in repo) - Project-specific overrides
- **Documentation References** (CLAUDE.md) - Context-dependent rules

The challenge is maintaining consistency while allowing local customization.

## Key Insights

### 1. Layered Rule Architecture

Rules follow a **3-tier hierarchical model**:

```
┌─────────────────────────────────────┐
│  Global Defaults                    │
│  (~/.claude/rules/)                 │
│  - Universal standards              │
│  - Language-agnostic patterns       │
│  - Team-wide policies               │
└──────────────┬──────────────────────┘
               ↓ (override by)
┌─────────────────────────────────────┐
│  Project Overrides                  │
│  (./agents/rules/)                 │
│  - Project-specific customizations  │
│  - Domain-specific standards        │
│  - Team/org preferences             │
└──────────────┬──────────────────────┘
               ↓ (reference via)
┌─────────────────────────────────────┐
│  Runtime Context                    │
│  (CLAUDE.md)                        │
│  - Session-specific guidance        │
│  - Current project priorities       │
│  - Active decision records          │
└─────────────────────────────────────┘
```

**Why This Matters**:
- **Consistency**: Global defaults ensure team standards
- **Flexibility**: Projects can override for specific needs
- **Discoverability**: CLAUDE.md provides project context
- **Maintainability**: Single source of truth per layer

### 2. Cross-Reference Pattern

Each rule file includes a **"Related Rules"** section:

```markdown
## Related Rules

- [rule-name.md](rule-name.md) - What this rule depends on
- [other-rule.md](other-rule.md) - What rule depends on this
```

**Benefits**:
- **Navigation**: Developers discover related guidelines
- **Context**: Understand rule dependencies
- **Completeness**: Ensure all related aspects are covered
- **Maintenance**: Easy to identify impact of changes

**Example Flow**:
```
doc-organization.md
  ├─ Referenced by: git-workflow.md
  ├─ References: hooks.md (doc blocker hook)
  └─ Related: agents.md (doc-updater agent)

git-workflow.md
  ├─ References: testing.md (TDD coverage)
  ├─ References: agents.md (planner, code-reviewer)
  └─ References: security.md (pre-commit checks)
```

### 3. Synchronization Strategy

**Critical Rule**: When changing shared configuration:

1. **Identify Scope**
   - Is this global (team-wide)?
   - Or project-specific?
   - Or temporary/session-specific?

2. **Update All Affected Locations**
   ```
   Global change → ~/.claude/rules/ + agents/rules/ + CLAUDE.md
   Project change → agents/rules/<project>/ only
   Session note → temp/ or docs/projects/<project>/
   ```

3. **Cross-Reference**
   - Add links in affected rules
   - Document dependencies
   - Note when rules conflict

### 4. Document Organization Principle

**Key Distinction**: Separate code from documentation

```
workspace/                    docs/projects/
├── src/                      ├── architecture/
├── tests/                    ├── decisions/
└── config/                   ├── guide/
                              └── sop/
```

**Why Separation Matters**:
- Code lives where it's used (workspace)
- Documentation lives where it's referenced (docs)
- Clear responsibility boundaries
- Easier to find "how do I understand this system?"

### 5. Auto-Classification Workflow

Context-based automatic document placement:

```
if (workingOnProject(luppiter_scheduler))
  → save to docs/projects/luppiter_scheduler/
else if (workingOnSharedPolicy)
  → save to base/guides/decisions/
else if (workingOnLanguagePattern)
  → save to docs/guides/<language>/
else if (workingOnAutomation)
  → save to agents/knowledge/lessons/common/
else
  → save to temp/
```

**Benefit**: Reduces decision fatigue during work

## Implementation Patterns

### Pattern 1: Rule Dependency Mapping

When adding a new rule, create a dependency map:

```markdown
## Depends On
- security.md (input validation requirements)
- patterns.md (common implementation patterns)

## Depended On By
- git-workflow.md (feature workflow uses this rule)
- testing.md (test rules must verify code quality)

## Conflicts With
- performance.md (rule X might be slower, document tradeoff)
```

### Pattern 2: Multi-Location Changes

When syncing a rule across locations:

```bash
# 1. Update home rules
nano ~/.claude/rules/rule-name.md

# 2. Update project rules
nano agents/rules/rule-name.md

# 3. Update CLAUDE.md if referenced
nano CLAUDE.md

# 4. Commit with comprehensive message
git commit -m "docs: sync rule-name changes across all locations

- Updated global rule in ~/.claude/rules/
- Updated project override in agents/rules/
- Updated references in CLAUDE.md
- Added cross-reference links"
```

### Pattern 3: Version Alignment

For rules that exist in multiple locations:

```markdown
# Rule Name

## Latest Version
- Global: 2.1 (last updated 2026-01-30)
- Project: 2.0 (last updated 2026-01-15)
- Status: Project version is 1 iteration behind

## Changes in 2.1
- [Change 1 description]
- [Change 2 description]

## Upgrade Path
To align project with global:
1. [Step 1]
2. [Step 2]
```

## Decision Records

### Why Layered Architecture?

**Alternatives Considered**:
1. **Single Global File** - No flexibility for projects
2. **No Links Between Rules** - Hard to understand dependencies
3. **Duplicate Rules** - Maintenance nightmare with sync issues

**Chosen**: Layered + linked approach
**Rationale**: Balances flexibility with maintainability

### Why Auto-Classification?

**Alternatives Considered**:
1. **Manual placement decisions** - Slow, inconsistent
2. **Single docs/ folder** - Becomes disorganized quickly
3. **Algorithm-based placement** - Can be rigid

**Chosen**: Context-aware auto-placement with override
**Rationale**: Fast during development, organized by default

## Related Concepts

### Similar Patterns in Other Systems
- **Kubernetes**: ConfigMaps (global) + custom resources (specific)
- **Git**: Global config (~/.gitconfig) + repo config (.git/config)
- **npm**: Global packages + local packages per project
- **Docker**: Base images + project Dockerfiles

### Organizational Benefits
- **Clear Ownership**: Who maintains each layer?
- **Change Impact**: Easy to see what breaks with changes
- **Audit Trail**: Cross-references serve as documentation
- **Training**: New team members follow links to understand

## Practical Checklist

When establishing rule synchronization:

- [ ] Identify which rules should be global vs project-specific
- [ ] Document layered architecture clearly
- [ ] Add "Related Rules" section to each rule file
- [ ] Create cross-reference map document
- [ ] Establish sync protocol for shared rules
- [ ] Add version tracking for multi-location rules
- [ ] Document dependency and conflict relationships
- [ ] Create CLAUDE.md reference for project context
- [ ] Test that all links work correctly
- [ ] Document auto-classification rules clearly

## Lessons Learned

1. **Distributed Rules Need Explicit Sync**: Can't rely on "they'll stay in sync naturally"
2. **Cross-References Are Critical**: Without links, developers miss related rules
3. **Layering Prevents Duplication**: Global → Project → Session keeps DRY principle
4. **Clear Scope = Fewer Conflicts**: Knowing what each layer does reduces surprises
5. **Auto-Classification Reduces Friction**: Context-aware placement helps adoption

## Next Steps

1. Create cross-reference map visualizer
2. Add sync validation tool (ensure all locations match)
3. Document conflict resolution strategy
4. Create rule migration guide for team onboarding
5. Monitor for orphaned/unreferenced rules (technical debt)

---

**Created**: 2026-01-30
**Type**: System Architecture Document
**Status**: Active - Used for multi-project rule management
**Related**: doc-organization.md, git-workflow.md, agents.md
