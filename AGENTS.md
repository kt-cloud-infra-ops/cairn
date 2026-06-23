# Cairn — AI Development Harness Plugin

Cairn is a generic, team-portable harness for AI-assisted software development.
It provides a **workspace engine** (init / project-add / project-pull), structured Phase Gates, skill-based workflows, Atlassian evidence integration, and cross-tool rule sharing.
All AI tools (Claude Code, Codex, Cursor, Copilot, etc.) follow the same rules from this repository.

---

## Core Idea — Learn your work, share it with your team

> Like stacking a **cairn** (a trail marker of stones) on a mountain path,
> Cairn lets the AI stack your work — lessons, decisions, procedures — into markdown,
> and a single `git commit` turns it into a guidepost for your whole team.
>
> **trace (your work) → stones (markdown) → guidepost (shared with the team)**

Cairn is not a tool attached to a single project. It is a **workspace-level harness** that manages multiple projects via clone/pull. The asset you carry is not the plugin install directory — it is your **Cairn workspace**.

**Two modes**

| Mode | Behavior |
|------|----------|
| **Solo** | Build your own knowledge library locally. Next session starts already "trained". |
| **Team** | `git commit/push` to share. Teammates clone the same workspace and use the same harness + accumulated knowledge. |

**Capture Loop** — the orchestrator proactively offers to capture knowledge as you work:

```
do work (dev / ops / analysis)
  → orchestrator detects a capture moment → offers:
     "save this as a lesson?", "record this decision as an ADR?", "make this a runbook?"
  → you approve → markdown generated → saved to workspace storage
                   (knowledge/lessons / decisions / runbooks)
  → git commit (share)
  → next session: that markdown loads as context → you start already trained
```

Run manually with `/cairn:capture`, or let the Stop hook suggest it at session end.
Tune via `.cairn/config.json` (`mode`, `capture.frequency`). See `skills/cairn-capture/`.

---

## 3-Layer Architecture

```
cairn              = generic engine plugin. zero org-specific values.
                     creates, validates, reads, and executes workspaces.

cairn-<your-team>  = team/org workspace instance.
                     holds org values, service catalog, team Jira/Confluence mapping,
                     internal SOPs, domain rules, runbooks.
                     Examples: cairn-pe (PE team reference implementation),
                               cairn-sre, cairn-data, cairn-acme, ...
```

| Layer | Role | Contains | Must NOT Contain |
|-------|------|----------|-----------------|
| `cairn` | Generic engine | Orchestrator, Phase Gates, Capture Loop, workspace contract, profile schema, clone/pull skills, generic hooks | Org names, Jira project keys, Confluence space IDs, service names, internal URLs |
| `cairn-<your-team>` | Team workspace instance | `.cairn/profile/*`, service catalog, team Atlassian mapping, SOPs, domain rules, runbooks | Personal secrets/tokens, personal local paths, core engine code forks |

> **`cairn-pe` is the PE team's reference implementation** — a concrete example other teams can clone as a starting point.
> Other teams create their own `cairn-<name>` workspace via `cairn init --profile <name>`.
> Org-specific values live only in `cairn-<name>/.cairn/profile/`; the engine (`cairn`) stays at zero.

---

## What Cairn Provides

| Component | Purpose |
|-----------|---------|
| **Workspace Engine** | `cairn-init` creates/detects workspace; `cairn-project-add` registers sources; `cairn-project-pull` clones/updates |
| **Profile system** | `.cairn/profile/` holds org values (org, atlassian, git, infra, services, teams, hooks). Core stays at zero org-specific values |
| **Capture Loop** (`skills/cairn-capture/`) | Turn your work into shareable markdown saved to workspace storage; git-commit to make it a team asset ★ |
| **Phase Gate system** | Structured INIT → PLAN → IMPL → VERIFY → SHIP workflow with hard gates |
| **Skills** (`skills/`) | Executable workflow commands (`/cairn:skill-name`) |
| **Rules** (`rules/`) | Auto-loaded team standards (coding, testing, security, git, Jira) |
| **Rules on-demand** (`rules-on-demand/`) | Supplemental domain/project rules loaded only when needed |
| **Hooks** (`hooks/`) | PreToolUse/PostToolUse guards (charter, git-commit, skill-create, build-fail, evidence) |
| **Templates** (`templates/`) | CPS / PRD / Architecture / Task Packet / Skill scaffold |
| **Knowledge** (`knowledge/lessons/`) | Reusable lessons and patterns extracted from past sessions |
| **Config** (`config/`) | ENV_STANDARD and placeholder conventions |

---

## Directory Structure

```
cairn/
├── AGENTS.md               ← This file (plugin entry point)
├── CLAUDE.md               ← Claude Code pointer
├── CODEX.md                ← Codex pointer
├── config/
│   ├── cairn.config.example.json  ← Config template (workspace-based paths)
│   └── ENV_STANDARD.md            ← Placeholder / env-var naming standard
├── rules/                  ← Auto-loaded rules (core, git, jira, agents, skill-governance ...)
├── rules-on-demand/        ← Project/domain rules (load explicitly when needed)
├── skills/                 ← Skill definitions (SKILL.md per skill)
│   ├── cairn-init/           ← Workspace creation / detection
│   ├── cairn-project-add/    ← Register + clone a source into workspace
│   ├── cairn-project-pull/   ← Clone/update sources from sources.yaml
│   ├── cairn-capture/        ← Capture Loop engine (workspace storage target)
│   ├── harness-dev-process/  ← Phase Gate orchestrator (canonical dev workflow)
│   ├── harness-brainstorm/
│   ├── harness-plan/
│   ├── dev-code-review/
│   ├── dev-tdd/
│   └── ...
├── agents/                 ← Subagent definitions (domain + layer experts)
├── hooks/                  ← Shell hooks for Claude Code / Codex
│   ├── keyword-detector.sh   ← UserPromptSubmit: phase hint injection
│   ├── guard-charter.sh      ← PreToolUse(Edit/Write): Phase Gate enforcement
│   ├── guard-git-commit.sh   ← PreToolUse(Bash): commit / push guard
│   ├── guard-skill-create.sh ← PreToolUse(Write): skill duplication check
│   ├── collect-evidence.sh   ← Phase 4 SHIP: evidence generation helper
│   ├── detect-harness-change.sh ← PostToolUse: harness config change alert
│   ├── detect-build-fail.sh  ← PostToolUse(Bash): build/test failure detection
│   ├── validate-harness-doc.sh ← PostToolUse: template contract validation
│   └── triggers.json         ← Keyword → phase mapping
├── templates/              ← Document templates
└── knowledge/
    └── lessons/            ← Captured patterns (common/, db/, java/)
```

---

## Workspace Contract

Cairn operates on a **workspace**, not individual project directories.

### `.cairn/workspace.yaml` — workspace identity

```yaml
schema: "cairn.workspace/v1"
workspace:
  name: "my-workspace"
  mode: "team"              # multi-project | solo | project-local
  default_project_root: "projects"

profile:
  name: "cairn-pe"
  path: ".cairn/profile"
  schema: "cairn.profile/v1"

storage:
  knowledge: "knowledge"
  decisions: "decisions"
  runbooks: "runbooks"
  services: "services"
  support_projects: "support-projects"
```

### `.cairn/sources.yaml` — project clone/pull registry

```yaml
schema: "cairn.sources/v1"
defaults:
  root: "projects"
  pull_policy: "manual"     # manual | auto | on-start | scheduled
  dirty_policy: "skip"      # skip | stash | fail
  clone_depth: 1

sources:
  - name: "service-a"
    role: "service"         # service | domain | docs | wiki | support | platform
    repo: "git@github.com:<YOUR_ORG>/service-a.git"
    ref:
      type: "branch"
      name: "develop"
    path: "projects/service-a"
    profile_service_key: "service-a"
```

### `.cairn/profile/` — org values

```
.cairn/profile/
├── org.yaml          # org/team display name, timezone, language
├── atlassian.yaml    # baseUrl, project keys, confluence spaces, field IDs
├── git.yaml          # git orgs, default branch, wiki conventions
├── infra.yaml        # Vault/ArgoCD/Harbor/Jenkins naming rules
├── services.yaml     # service catalog and Jira prefix mapping
├── teams.yaml        # roles, team aliases (personal accountId → local/env)
└── hooks.yaml        # profile-aware hooks enable/disable
```

All values in profile use `${ENV_VAR}` references for secrets. Never commit tokens to profile.

---

## Core Skills: Workspace Lifecycle

### `cairn-init`

Creates or detects a workspace.

```bash
/cairn:cairn-init [--path <dir>] [--profile <name|path>] [--mode solo|team] [--from <git-url>]
# --profile <name> sets the workspace instance name: cairn-<name>
# e.g., --profile pe → cairn-pe (PE team reference), --profile sre → cairn-sre
```

Gates:
- `[GATE-WORKSPACE]` — if current dir is a single project repo, user chooses: create new workspace / use existing / project-local limited mode
- `[GATE-PROFILE]` — choose empty profile or scaffold from a reference implementation (e.g., `cairn-pe`)

### `cairn-project-add`

Registers a source in `.cairn/sources.yaml` and optionally clones it.

```bash
/cairn:cairn-project-add <repo-url> --name <name> --branch <branch> --role service
```

Gate: `[GATE-SOURCE-ADD]` — preview repo URL, ref, local path before writing.

### `cairn-project-pull`

Clones or updates sources from `sources.yaml`.

```bash
/cairn:cairn-project-pull --all
/cairn:cairn-project-pull --source <name>
/cairn:cairn-project-pull --dry-run
```

Gate: `[GATE-PULL-DIRTY]` — dirty worktree stash/rebase/reset requires explicit user approval. Destructive reset is prohibited without approval.

---

## Rule Loading

Rules in `rules/` are auto-loaded by Claude Code via `.claude/rules/` symlink:

```
.claude/rules/ → cairn/rules/   (symlink, auto-read each session)
```

Rules in `rules-on-demand/` must be explicitly read when needed (token-efficient).

**Profile-aware loading**: when a workspace `.cairn/workspace.yaml` is present, profile values
from `.cairn/profile/` supplement the core rules. Profile-specific hooks (e.g., `guard-jira-transition.sh`)
are enabled/disabled via `.cairn/profile/hooks.yaml`.

---

## Skill Invocation

Invoke skills with the `/cairn:` prefix (or your team's configured prefix):

```
/cairn:cairn-init               ← Create or connect to a workspace
/cairn:cairn-project-add        ← Register + clone a project source
/cairn:cairn-project-pull       ← Update all/selected sources
/cairn:capture                  ← Capture knowledge to workspace storage
/cairn:harness-dev-process      ← Start Phase Gate dev workflow
/cairn:harness-brainstorm       ← Requirements clarification
/cairn:dev-code-review          ← Code review + evidence generation
/cairn:dev-tdd                  ← TDD workflow
/cairn:jira-rest-ops            ← Jira REST API operations (profile/env for org values)
```

Each skill lives at `skills/<skill-name>/SKILL.md` and follows the template at `templates/skill-template.md`.

---

## Phase Gate System

The `harness-dev-process` skill enforces 5 phases:

| Phase | Name | Key Output |
|-------|------|-----------|
| 0 | INIT | CPS (Charter Preflight Summary) — Goal / Context / Constraints / Done When |
| 1 | PLAN | PRD + Architecture document + user approval |
| 2 | IMPL | Implementation guided by Charter & PRD |
| 3 | VERIFY | Build + tests + code-review evidence + security review |
| 4 | SHIP | Deployment + Jira A.C. DONE (5-step) + worklog |

State is tracked in `.harness/state.json` per project.
`hooks/guard-charter.sh` physically blocks Edit/Write if Phase Gate is not met.

---

## Hook Registration

Register hooks in your tool's settings (e.g., `~/.claude/settings.json`).
With a workspace, the `cairn-hook-router.sh` approach is preferred — it reads `.cairn/profile/hooks.yaml`
and only runs enabled hooks, so core and profile hooks are wired from one place.

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command", "command": "/path/to/cairn/hooks/guard-charter.sh" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "/path/to/cairn/hooks/guard-git-commit.sh" }] },
      { "matcher": "Write", "hooks": [{ "type": "command", "command": "/path/to/cairn/hooks/guard-skill-create.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "/path/to/cairn/hooks/detect-harness-change.sh" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "/path/to/cairn/hooks/detect-build-fail.sh" }] }
    ]
  }
}
```

---

## Atlassian / Jira Integration

Cairn includes Jira REST ops skill and lessons for Atlassian toolchains.
Configure via `${JIRA_CREDENTIALS_FILE}` (default: `~/.jira-credentials.json`):

```json
{ "email": "<YOUR_USER_ID>@<YOUR_ORG>", "apiToken": "...", "baseUrl": "${ATLASSIAN_BASE_URL}" }
```

Or set org values in `.cairn/profile/atlassian.yaml` (no secrets in profile — use env refs).

See `rules-on-demand/jira-workflow.md` and `skills/jira-rest-ops/SKILL.md` for usage.

---

## Adapting for Your Team

1. Install plugin: `/plugin install cairn@cairn-marketplace`
2. Create your team workspace: `/cairn:cairn-init --profile <your-team> --mode team`
   - This creates a `cairn-<your-team>` workspace (e.g., `cairn-sre`, `cairn-data`, `cairn-acme`).
   - Use `cairn-pe` as a reference implementation to copy profile structure from.
3. Fill in `.cairn/profile/` with your org values
4. Add project sources: `/cairn:cairn-project-add <repo> --name <name> --role service`
5. Set env vars in `~/.zshrc` (see `config/ENV_STANDARD.md`)
6. Register hooks in your tool settings (see Hook Registration above)

---

## Key Rules (Quick Reference)

| Rule File | Topic |
|-----------|-------|
| `rules/core.md` | Core principles, daily routine, no-assumption policy |
| `rules/git-workflow.md` | Commit format, branch strategy, runtime/non-runtime split |
| `rules-on-demand/jira-workflow.md` | Jira issue lifecycle, A.C. format, 5-step completion |
| `rules/agents.md` | Agent orchestration, Phase Gate routing, advisor pattern |
| `rules/skill-governance.md` | Skill creation/duplication check, GATE requirements |
| `rules/doc-organization.md` | Document storage rules, Confluence workflow |
