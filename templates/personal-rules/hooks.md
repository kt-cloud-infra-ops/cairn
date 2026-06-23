# Hooks System

## Hook Types

- **PreToolUse**: Before tool execution (validation, parameter modification)
- **PostToolUse**: After tool execution (auto-format, checks)
- **Stop**: When Claude stops and waits for user input

## Current Hooks (in ~/.claude/settings.json)

### Stop
- **completion sound**: `Hero.aiff` 사운드 재생 (작업 완료 알림)

## Auto-Accept Permissions

Use with caution:
- Enable for trusted, well-defined plans
- Disable for exploratory work
- Never use dangerously-skip-permissions flag
- Configure `allowedTools` in `~/.claude.json` instead

## TodoWrite Best Practices

Use TodoWrite tool to:
- Track progress on multi-step tasks
- Verify understanding of instructions
- Enable real-time steering
- Show granular implementation steps

Todo list reveals:
- Out of order steps
- Missing items
- Extra unnecessary items
- Wrong granularity
- Misinterpreted requirements

---

## Related Rules

- [git-workflow.md](git-workflow.md) - Commit/push hooks context
- [performance.md](performance.md) - Auto-accept permissions strategy
