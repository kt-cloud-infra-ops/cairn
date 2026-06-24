---
name: learn
description: "재사용 가능한 패턴 추출"
---

## 스킬 규칙
- [ALWAYS] 기존 lessons/ 중복 확인 후 생성
- [ALWAYS] 카테고리별 배치 (db/, java/, common/)
- [NEVER] 기존 스킬과 중복 패턴 생성 금지

# /learn - Extract Reusable Patterns

Analyze the current session and extract any patterns worth saving as skills.

## Trigger

Run `/learn` at any point during a session when you've solved a non-trivial problem.

## What to Extract

Look for:

1. **Error Resolution Patterns**
   - What error occurred?
   - What was the root cause?
   - What fixed it?
   - Is this reusable for similar errors?

2. **Debugging Techniques**
   - Non-obvious debugging steps
   - Tool combinations that worked
   - Diagnostic patterns

3. **Workarounds**
   - Library quirks
   - API limitations
   - Version-specific fixes

4. **Project-Specific Patterns**
   - Codebase conventions discovered
   - Architecture decisions made
   - Integration patterns

## Output Format

Create a skill file at `agents/skills/learned/[pattern-name].md`:

```markdown
# [Descriptive Pattern Name]

**Extracted:** [Date]
**Context:** [Brief description of when this applies]

## Problem
[What problem this solves - be specific]

## Solution
[The pattern/technique/workaround]

## Example
[Code example if applicable]

## When to Use
[Trigger conditions - what should activate this skill]
```

## Process

1. Review the session for extractable patterns
2. Identify the most valuable/reusable insight
3. Draft the skill file
4. Ask user to confirm before saving
5. Save to `agents/skills/learned/`

## Notes

- Don't extract trivial fixes (typos, simple syntax errors)
- Don't extract one-time issues (specific API outages, etc.)
- Focus on patterns that will save time in future sessions
- Keep skills focused - one pattern per skill

## 완료 조건 (DONE WHEN)
- [ ] [FILE] knowledge/lessons/ 하위에 새 패턴 문서 생성
- [ ] [MANUAL] 기존 스킬과 중복 아님 확인

## 실행 절차

1. 현재 세션에서 비자명한 해결 패턴 식별
2. 기존 lessons/ 중복 확인
3. 새 패턴 문서 생성 (lessons/{카테고리}/)
4. 기존 스킬에 반영 가치 있으면 제안
