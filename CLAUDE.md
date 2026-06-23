# Project Instructions → AGENTS.md

This project's unified instructions are in `AGENTS.md`.
All AI tools (Claude Code, Codex, Cursor, Copilot, etc.) follow the same rules.

## Instruction Sources

| File | Role |
|------|------|
| `AGENTS.md` | Plugin entry point (structure, Phase Gates, workflow) |
| `rules/*.md` | Detailed rules (auto-loaded) |
| `skills/*.md` | Workflow skill commands |

## Claude Code Notes

- `.claude/rules/` → symlink to `rules/` for auto-loading
- For project structure, skill list, and full context see `AGENTS.md`
- When working in a sub-project: check that project's CLAUDE.md first
