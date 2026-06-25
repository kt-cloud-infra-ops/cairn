---
tags:
  - type/guide
  - domain/rules
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# Rule Design Principles for Distributed Systems

## Executive Summary

Effective rule systems for distributed teams require deliberate design choices that balance consistency with flexibility. This document captures principles learned from implementing multi-layer rule architecture across global, project, and session contexts.

**Session Date**: 2026-01-30
**Audience**: Team leads, architects, tool builders

## Core Principles

### Principle 1: Layered Authority

**Statement**: Rules exist at multiple layers, each with distinct authority.

```
┌─────────────────────────────────────────┐
│ Authority Level: HIGHEST                │
│ Layer: Global (~/.claude/rules/)        │
│ Scope: All projects, all engineers      │
│ Change: Team consensus required         │
│ Examples: Security, testing, git format │
└─────────────────────────────────────────┘
            ↓ can override
┌─────────────────────────────────────────┐
│ Authority Level: MEDIUM                 │
│ Layer: Project (./rules/)       │
│ Scope: Single project only              │
│ Change: Project lead approval           │
│ Examples: Performance targets, patterns │
└─────────────────────────────────────────┘
            ↓ references
┌─────────────────────────────────────────┐
│ Authority Level: LOWEST                 │
│ Layer: Session (CLAUDE.md)              │
│ Scope: Current work context             │
│ Change: Individual decision             │
│ Examples: Current sprint focus, notes   │
└─────────────────────────────────────────┘
```

**Why This Matters**:
- **Clarity**: Everyone knows who can change what
- **Consistency**: Global rules prevent chaos
- **Autonomy**: Projects can solve local problems
- **Efficiency**: Not everything requires team-wide discussion

**Anti-Pattern**: Flat rule system where nothing overrides anything
- Result: Endless conflicts and ambiguity

### Principle 2: Explicit Scope Declaration

**Statement**: Every rule MUST explicitly declare its scope.

```markdown
# Rule Title

## Scope
- Applies to: All Java projects (or specific project)
- Does NOT apply to: Python projects (or exceptions)
- Supersedes: [previous rule, if any]
- Can be overridden by: Project-specific rules

## Layer
- Location: ~/.claude/rules/ (Global)
- Authority: Team-wide decision
- Change process: Requires consensus
```

**Why This Matters**:
- **No Ambiguity**: Developer knows immediately if rule applies
- **Override Clarity**: Clear when exceptions are allowed
- **Audit Trail**: Easy to track which rule supersedes which
- **Onboarding**: New developers understand hierarchy

**Anti-Pattern**: Rule that says "applies everywhere" or has unclear boundaries
- Result: Inconsistent application, arguments about applicability

### Principle 3: Dependency Transparency

**Statement**: All rule dependencies must be explicitly documented.

```markdown
## This Rule Depends On
- security.md - Input validation is a security prerequisite
- patterns.md - Repository pattern used here
- testing.md - Code must meet coverage requirements

## Rules That Depend On This
- git-workflow.md - Feature workflow uses this
- coding-style.md - Code quality checklist references this

## Conflicts With
- performance.md - Rule X might conflict on high-throughput systems
  (Resolution: Use performance.md guidance for latency-critical code)
```

**Why This Matters**:
- **Navigation**: Developer can follow chain of rules
- **Impact Analysis**: See what breaks if rule changes
- **Redundancy Prevention**: Avoid duplicating guidance across rules
- **Conflict Management**: Know what to do when rules clash

**Anti-Pattern**: Isolated rules with no links
- Result: Rules contradict each other, developers confused

### Principle 4: Versioning by Default

**Statement**: Track rule versions; document all changes.

```markdown
## Version

**Current**: v2.1 (2026-01-30)
**Status**: Stable - in use by 3 projects

## Version History

### v2.1 - 2026-01-30
- Added: Async/await patterns
- Changed: Error handling structure
- Removed: (deprecated) Promise.then() pattern
- **Breaking**: Project must upgrade within 2 weeks

### v2.0 - 2026-01-15
- Refactored error handling section
- Added performance benchmarks

### v1.0 - 2025-12-01
- Initial version
```

**Why This Matters**:
- **Audit Trail**: Track when rules change and why
- **Migration Path**: Projects know how to upgrade
- **Stability**: Breaking changes are flagged clearly
- **History**: Look back to understand evolution

**Anti-Pattern**: Rules that silently change
- Result: Developers follow old guidance, inconsistency

### Principle 5: Explicitness Over Implicitness

**Statement**: Assume nothing about the reader's context.

```markdown
GOOD:
"All API responses MUST include an X-Request-ID header.
This is for tracing and debugging. See examples/api-response.ts"

BAD:
"Include request ID in responses."
(What format? Why? Is it mandatory?)

GOOD:
"Tests must have 80% line coverage and include:
  □ Unit tests (individual functions)
  □ Integration tests (API + database)
  □ E2E tests (critical user flows)"

BAD:
"Tests must be comprehensive."
(What does comprehensive mean?)
```

**Why This Matters**:
- **Reduces Questions**: Developers don't need to ask for clarification
- **Consistency**: Everyone interprets rule the same way
- **Self-Service**: Can learn without asking colleagues
- **Enforcement**: Can validate automatically

**Anti-Pattern**: Vague rules open to interpretation
- Result: Inconsistent implementation, endless debate

### Principle 6: Context-Aware Defaults

**Statement**: Provide different guidance for different contexts.

```markdown
## When to Apply This Rule

### Always (Required)
- Security-related decisions
- Public API changes
- Data model changes

### Usually (Recommended)
- New features
- Bug fixes affecting multiple components

### Sometimes (Optional)
- Internal refactoring
- Infrastructure changes
- Documentation updates

### Never (Exception)
- Emergency hotfixes (emergency SOP overrides)
```

**Why This Matters**:
- **Appropriate Enforcement**: Rules scale to context
- **Flexibility**: Handles edge cases without creating exceptions
- **Pragmatism**: "Required" vs "recommended" vs "optional"
- **Respect**: Acknowledges that not all situations are equal

**Anti-Pattern**: One-size-fits-all rules
- Result: Rules feel arbitrary, team ignores them

### Principle 7: Migration Pathways

**Statement**: When rules change, provide clear upgrade path.

```markdown
## Upgrading from v1.0 to v2.0

### What Changed
- Error handling structure (breaking)
- New async patterns available (optional)
- Performance benchmarks added

### Do I Need to Upgrade?
- ✅ YES if: Your service handles sensitive data
- ✅ YES if: Service has >10k daily requests
- ⚠️ MAYBE if: Service is experimental/temporary
- ❌ NO if: Service is in maintenance mode

### How to Upgrade
1. Read [new error handling section](#error-handling)
2. Find all error handling code: `grep -r "catch"`
3. Apply new pattern (see examples below)
4. Run tests: `npm test`
5. PR review required: Error handling specialist

### Timeline
- By 2026-02-01: Review required (non-blocking)
- By 2026-02-15: All services must upgrade (blocking)
- After 2026-02-15: v1.0 no longer supported
```

**Why This Matters**:
- **Adoption**: Clear incentive and path to upgrade
- **Planning**: Teams can schedule upgrade work
- **Support**: Know when to stop supporting old version
- **Fairness**: Not blindsiding teams with sudden changes

**Anti-Pattern**: Hard cutoff with no migration path
- Result: Teams work around rule, create inconsistency

### Principle 8: Observable Compliance

**Statement**: Provide ways to verify rule compliance.

```markdown
## How to Verify Compliance

### Automated
```bash
# Check error handling pattern compliance
npm run lint -- --rule=error-handling-v2

# Check security requirements
npm run security-audit

# Check test coverage
npm run coverage --threshold=80
```

### Manual Checklist
- [ ] All public methods documented
- [ ] All errors wrapped with context
- [ ] All external calls have timeout
- [ ] No console.log statements

### Code Review Focus
- Security-related changes: require architect review
- Performance-related: benchmark before/after
```

**Why This Matters**:
- **Trust**: Can verify rule is actually followed
- **Automation**: Reduces manual review burden
- **Evidence**: PR shows compliance before review
- **Objectively**: No arguing about interpretation

**Anti-Pattern**: Rules that can't be verified
- Result: Compliance unknown, hard to enforce

## Structural Guidelines

### Rule File Structure

```markdown
# Title (Single Concept)

## Overview (1-2 sentences)

## Scope
- Applies to: ...
- Does not apply to: ...
- Layer: (Global/Project/Session)

## The Rule (Core content)
- Use headings for clear structure
- Provide before/after examples
- Explain the "why" not just "what"

## When This Rule Applies
- Always/Usually/Sometimes/Never contexts

## How to Verify
- Automated checks (if any)
- Manual checklist
- Code review focus areas

## Examples
```code
// Good
// Bad
```

## Common Questions
Q: What if X happens?
A: Then Y. See related rule Z.

## Version
- Current: v1.0 (YYYY-MM-DD)
- Deprecation: (if applicable)

## Related Rules
- rule-a.md - Depends on
- rule-b.md - Depended by
- rule-c.md - Conflicts with (see resolution)
```

### Related Rules Section Format

```markdown
## Related Rules

**This rule depends on:**
- [security.md](security.md) - Input validation prerequisite
- [testing.md](testing.md) - Coverage requirements

**These rules depend on this:**
- [git-workflow.md](git-workflow.md) - Feature workflow
- [coding-style.md](coding-style.md) - Code quality

**Coordinates with:**
- [performance.md](performance.md) - Performance vs safety tradeoff

**Conflicts with:**
- [agility.md](agility.md) - Speed vs safety (resolution: context-dependent)
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Vague Motivation

```
BAD: "We need good error handling"
GOOD: "When errors occur without context, debugging takes 10x longer
and production incidents get misclassified. Always wrap errors with:
- Operation being attempted
- User context
- Timestamp and request ID"
```

### Anti-Pattern 2: Scope Creep

```
BAD: Rule tries to cover: security, performance, AND documentation
GOOD: Focused rule on ONE concern. Cross-reference related rules.
```

### Anti-Pattern 3: No Examples

```
BAD: "Use immutable patterns"
GOOD: "Use immutable patterns:
  const newUser = { ...user, name: 'John' }  // GOOD
  user.name = 'John'  // BAD - mutation!"
```

### Anti-Pattern 4: Invisible Enforcement

```
BAD: Rule exists but no way to verify
GOOD: Include: automated checks, manual checklist, review focus
```

### Anti-Pattern 5: Silent Obsolescence

```
BAD: Old rule still referenced but no longer applies
GOOD: Mark deprecated: "This rule superseded by v2.0 as of 2026-01-30"
```

## Implementation Checklist

### Before Publishing Rule

- [ ] **Single Concept**: Rule covers ONE thing (if multiple, split)
- [ ] **Clear Scope**: Who does this apply to?
- [ ] **Explicit Boundary**: What's in scope, what's out?
- [ ] **Why Matters**: Explain the motivation
- [ ] **How To**: Clear steps or patterns
- [ ] **Examples**: Both good and bad examples
- [ ] **Verification**: How to know if you're following it
- [ ] **Dependencies**: What other rules does this need?
- [ ] **Conflicts**: What other rules might conflict?
- [ ] **Version**: v1.0 with date
- [ ] **Related Rules**: Links to dependencies
- [ ] **Tested**: Verify all links work

### Before Updating Rule

- [ ] **Impact Analysis**: Who's affected?
- [ ] **Migration Path**: How do teams upgrade?
- [ ] **Timeline**: When is it required?
- [ ] **Breaking Changes**: Clearly marked if any
- [ ] **All References**: Updated all dependent rules?
- [ ] **Version Bump**: Incremented correctly?
- [ ] **Backward Compat**: How long do we support v1.0?

## Governance Model

### Global Rules
- **Who Decides**: Team consensus (lead + core contributors)
- **Approval**: Must pass discussion, documented decision
- **Change Frequency**: Quarterly review minimum
- **Deprecation**: 4-week notice minimum

### Project Rules
- **Who Decides**: Project lead + team
- **Approval**: Project lead authority
- **Change Frequency**: As needed
- **Communication**: Update CLAUDE.md

### Session Rules
- **Who Decides**: Individual developer
- **Approval**: None (informational only)
- **Change Frequency**: Per session
- **Communication**: In CLAUDE.md context

## Metrics & Observability

Track rule effectiveness:

```markdown
## Rule Health Dashboard

**Coverage**: X% of projects following this rule
**Compliance**: Y% of relevant code passes verification
**Age**: Z days since last update
**Stability**: A% no changes (if stable) or B% changelog items (if changing)

**Alert Conditions**:
- Coverage drops below 80%: Rule needs clarification?
- No updates for 6 months: Rule obsolete?
- Contradicts other rules: Conflict needs resolution
```

---

**Created**: 2026-01-30
**Type**: System Design Principles
**Audience**: Architects, Team Leads
**Status**: Active - Used for rule design decisions
**Related**: rule-system-architecture.md, rule-synchronization-patterns.md, doc-organization.md
