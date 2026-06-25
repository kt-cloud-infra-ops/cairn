---
tags:
  - type/guide
  - domain/rules
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# Rule Synchronization Patterns

## Quick Reference

When you need to maintain rules across multiple locations, use these patterns.

**Session Date**: 2026-01-30
**Focus**: Practical patterns for distributed rule systems

## Pattern 1: Global-to-Project Sync

Use when updating a global rule that must propagate to projects.

### Scenario
You're updating `~/.claude/rules/security.md` and this rule affects all projects.

### Steps

```bash
# 1. Update global rule
vim ~/.claude/rules/security.md
# Update content, ensure clarity

# 2. Check which projects override this rule
grep -r "security" rules/ 2>/dev/null

# 3. For each project that has local version:
#    - Review if override is still needed
#    - Merge important changes
#    - Or remove local version if no longer needed

# 4. Document in git commit
git commit -m "docs: update security rules globally

Changes:
- Added new authentication requirement
- Updated rate limiting guidance
- Aligned with team-wide policy

Affects:
- ~/.claude/rules/security.md (global)
- rules/security.md (project override - merged)
- CLAUDE.md (updated reference section)"
```

## Pattern 2: Project-Specific Override

Use when you need project-specific behavior without affecting global rules.

### Scenario
`<your_service>` has stricter performance requirements than the global rule allows.

### Structure

```
~/.claude/rules/performance.md
  └─ Global: "Aim for <5s response time"

rules/performance.md
  └─ Project: "MUST be <2s for event processing"

CLAUDE.md
  └─ Context: "<your_service> has different SLA"
```

### Implementation

```markdown
# performance.md (project-specific override)

## Team Standard
See [global performance rule](~/.claude/rules/performance.md)

## Project Override: <your_service>

This project has stricter requirements due to real-time event processing:

- Response time: <2s (vs. global 5s)
- Throughput: 10k events/min minimum
- Backpressure handling: Required

### Why Different?
- Events must be processed in near real-time
- Customer SLA: 99.9% uptime
- Critical alerting system

### When to Use Global vs Local
- Performance optimization: Use this rule
- General code quality: Use global rule
```

## Pattern 3: Cross-Reference Web

Use to maintain aware-ness of dependencies between rules.

### Setup

```markdown
# doc-organization.md

## Related Rules (Incoming Dependencies)
Rules that depend on this one:
- git-workflow.md - Specifies where to commit docs
- agents.md - doc-updater agent uses these rules

## Related Rules (Outgoing Dependencies)
Rules this one depends on:
- hooks.md - References doc blocker hook
- security.md - Pre-commit validation

## Conflicts With
- performance.md - Rule X trades off against rule Y
  (See conflict resolution section below)
```

### Benefits
- New developers see full picture of how rules connect
- Easy to find impact when changing a rule
- Prevents orphaned/unused rules
- Reveals missing documentation

## Pattern 4: Multi-Location Update Protocol

Use when making changes that affect multiple rule files.

### Pre-Change Checklist

```markdown
□ Identify all affected rule files
  - Home: ~/.claude/rules/
  - Project: rules/
  - References: CLAUDE.md

□ Map dependencies
  - What rules reference this one?
  - What rules does this reference?
  - Are there conflicts?

□ Plan order of changes
  1. Start with base/foundational rules
  2. Update dependent rules
  3. Update CLAUDE.md references
  4. Update cross-reference links

□ Prepare commit message template
  - What changed and why
  - Which files affected
  - Any breaking changes?
```

### Execution

```bash
# 1. Make changes to primary rule file
vim ~/.claude/rules/primary-rule.md

# 2. Update all references
grep -r "primary-rule" rules CLAUDE.md

# 3. Update cross-reference links in each file
vim ~/.claude/rules/rule-a.md  # Update "Related Rules"
vim ~/.claude/rules/rule-b.md  # Update "Related Rules"
vim rules/rule-a.md    # Update "Related Rules"

# 4. Test links work (if possible)
# 5. Commit all at once
git add -A
git commit -m "docs: sync primary-rule changes across system

Files changed:
  - ~/.claude/rules/primary-rule.md (core change)
  - ~/.claude/rules/rule-a.md (updated reference)
  - ~/.claude/rules/rule-b.md (updated reference)
  - rules/rule-a.md (project override)
  - CLAUDE.md (context section)

What changed:
  - [specific change]
  - [specific change]

Impact:
  - Affects feature development workflow
  - Requires agent: planner, code-reviewer"
```

## Pattern 5: Conflict Resolution

Use when global and project rules conflict.

### Decision Framework

```
Is the conflict:

1. Temporary (this sprint only)?
   → Document in temp/conflict-resolution.md
   → Add deadline for resolution

2. Permanent (project specific)?
   → Create project-specific override
   → Document why in CLAUDE.md
   → Add to project rules/

3. Systemic (reveals bad rule)?
   → Global rule needs updating
   → Update both global and all projects
   → Document lesson learned
```

### Example Resolution

```markdown
# Conflict: Code Size vs Readability

## Global Rule
- coding-style.md: Max 800 lines per file

## Project Rule
- <your_service>: Entity classes often 1200+ lines for complex objects

## Decision
- KEEP both rules as stated
- Add exception category: "Compound Entity"
- Define criteria for exception:
  - Multiple business entities in one class
  - Explicit PR review required
  - Document architectural reason in class comment
```

## Pattern 6: Rule Evolution Tracking

Use to maintain rule versions and changes.

### Version Format

```markdown
# Rule Name

## Version History

### v2.1 (2026-01-30)
- Added section on reactive patterns
- Clarified async/await requirements
- **Breaking**: Removed deprecated synchronous APIs
- Migration: [link to migration guide]

### v2.0 (2026-01-15)
- Major refactor of error handling section
- Added performance benchmarks
- New pattern: Circuit breaker

### v1.0 (2025-12-01)
- Initial version
```

### Migration Guide Template

```markdown
## Migrating from v1.0 to v2.0

### Changes Affecting You

1. **Error Handling** (BREAKING)
   ```
   Before: catch (e) { logger.log(e) }
   After: catch (error) {
     log.error('context', error)
     throw new AppError('message', error)
   }
   ```

2. **New Pattern Available** (Optional)
   - Circuit breaker pattern now available
   - Recommended for external API calls

### Timeline
- Jan 30: Global rule updated
- Feb 6: All projects must update
- Feb 13: Deprecated syntax will be flagged in code review
```

## Pattern 7: Auto-Synced Rule Areas

Use for high-change rules that need frequent sync.

### Setup Automation Hints

```markdown
# Rule Name

## Sync Status: AUTO-SYNC REQUIRED
This rule changes frequently and must be manually synced.

### Sync Checklist
- [ ] Updated ~/.claude/rules/rule-name.md?
- [ ] Updated rules/rule-name.md (if override)?
- [ ] Updated CLAUDE.md references?
- [ ] Updated cross-reference links?
- [ ] Tested all markdown links?

### Last Synced
- Global: 2026-01-30 by claude
- Project: 2026-01-28 by claude
- Status: Project is 2 days behind (non-critical)
```

### Tool Integration Ideas

```bash
# Sync checker (pseudocode)
function checkRuleSyncStatus() {
  globalMD5 = md5(~/.claude/rules/rule.md)
  projectMD5 = md5(./rules/rule.md)

  if (globalMD5 != projectMD5)
    warn("Rule out of sync")
    suggest("Review differences")
}
```

## Pattern 8: Documentation Comment in Code

Use to link code to relevant rules.

### Example

```java
// See: ~/.claude/rules/coding-style.md - File Organization
// This class is intentionally 1200 lines (Compound Entity exception)
// PR review required: @architect
@Entity
public class ComplexOrderEntity {
  // ... complex implementation
}
```

```typescript
// See: ~/.claude/rules/security.md - Input Validation
// All user inputs MUST be validated with zod schema
export function validateUserInput(input: unknown) {
  return userSchema.parse(input)
}
```

## Practical Workflow

### Daily Development

```
1. Start work on task
   ↓
2. Check relevant rules (via cross-references)
   ├─ Is there a global rule?
   ├─ Is there a project override?
   └─ What's the current status?
   ↓
3. Code following latest rule version
   ↓
4. If you find rule gap or ambiguity
   ├─ Document in temp/
   ├─ Raise for next review
   └─ Note in PR description
```

### Weekly Review

```
- [ ] Check rule sync status
- [ ] Review any new conflicts added
- [ ] Validate all links still work
- [ ] Promote temp docs to permanent location if needed
```

### Monthly Sync

```
- [ ] Full audit of rule consistency
- [ ] Review version history
- [ ] Archive obsolete rules
- [ ] Update cross-reference map
```

## Common Mistakes & How to Avoid

| Mistake | Problem | Solution |
|---------|---------|----------|
| Updating global but not project | Confusion about what applies | Use multi-location update protocol |
| Broken cross-reference links | Developers can't find info | Test links regularly |
| Duplicate rules in multiple places | Sync nightmare | Use layered approach (global/project/session) |
| No version tracking | Don't know when rules changed | Add version history section |
| Rules become stale | Old guidance followed incorrectly | Mark deprecation date clearly |

## Checklists

### When Creating New Rule

```markdown
□ Choose appropriate location (global vs project)
□ Write clear title and overview
□ Add "Related Rules" section with links
□ Include practical examples
□ Add decision record if non-obvious
□ Test all markdown links
□ Add version number (v1.0)
□ Commit with clear message
□ Announce in team channels if global
```

### When Updating Existing Rule

```markdown
□ Check all cross-references first
□ Identify affected files/projects
□ Make changes to primary location
□ Update all references
□ Update cross-reference links
□ Increment version number
□ Add change to version history
□ Test all links
□ Commit with comprehensive message
```

### Before Syncing Rules

```markdown
□ Identify scope (global/project/session)
□ Map all affected files
□ Review for conflicts
□ Plan change order
□ Execute multi-location protocol
□ Validate all links
□ Test with actual workflow
□ Document in CLAUDE.md if needed
```

---

**Created**: 2026-01-30
**Type**: Pattern Reference
**Complexity**: Intermediate - assumes understanding of rule layers
**Related**: rule-system-architecture.md, doc-organization.md
