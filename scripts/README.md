# Cairn Engine Scripts

CLI tooling for Cairn workspaces.

| Script | Purpose |
|--------|---------|
| `validate.mjs` | Validate `.cairn/` config files against the JSON Schemas in `schemas/`. |
| `cairn-init` | Initialize a new Cairn workspace. |
| `cairn-project-add` | Register a project in `.cairn/sources.yaml`. |
| `cairn-project-pull` | Clone / pull managed projects. |
| `lib/cairn-workspace-lib.cjs` | Shared helpers for the `cairn-*` scripts. |

---

## validate.mjs — Schema Validator

Validates a workspace's `.cairn/` configuration against the JSON Schemas in
`schemas/` and reports per-file `PASS` / `FAIL`. Designed for use in git hooks
and CI (non-zero exit on failure).

### What it checks

| File | Schema | Notes |
|------|--------|-------|
| `.cairn/workspace.yaml` | `workspace.schema.json` | |
| `.cairn/sources.yaml` | `sources.schema.json` | + cross-item uniqueness of `name` / `path` (not expressible in JSON Schema) |
| `.cairn/profile/*.yaml` | `profile.schema.json` | dispatched by the file's `schema` field to the matching `oneOf` variant |
| profile file with `schema: cairn.services/v1` | `services.schema.json` | standalone services document |

### Install dependencies

The validator needs `ajv` (JSON Schema 2020-12), `ajv-formats`, and `js-yaml`.
Install once from the engine root:

```bash
cd /path/to/cairn       # the engine repo (where package.json lives)
npm install
```

> `node_modules/` is not committed. Each environment runs `npm install`.

### Usage

```bash
# Validate the workspace containing (or above) the current directory
node scripts/validate.mjs

# Validate a specific workspace
node scripts/validate.mjs /path/to/workspace

# Point directly at a .cairn directory
node scripts/validate.mjs /path/to/workspace/.cairn

# Via npm (from the engine root)
npm run validate -- /path/to/workspace
```

If no path is given, the validator searches the current directory and walks up
until it finds a `.cairn/` directory.

### Exit codes

| Code | Meaning |
|------|---------|
| `0`  | All validated files passed (warnings are non-fatal) |
| `1`  | One or more files failed validation |
| `2`  | Setup error (missing dependencies, no `.cairn/` found, bad schema) |

### Example output

```
Cairn Schema Validator
Workspace : /path/to/workspace
Schemas   : /path/to/cairn/schemas
────────────────────────────────────────────────────────────────────────

Core
  ✔ PASS  workspace.yaml  .cairn/workspace.yaml
  ✔ PASS  sources.yaml    .cairn/sources.yaml

Profile
  ✖ FAIL  profile/org.yaml  .cairn/profile/org.yaml
    • /org: must NOT have additional properties {"additionalProperty":"short_name"}

────────────────────────────────────────────────────────────────────────

✖ 1 file(s) failed  2 pass · 0 warn · 0 skip
```

Set `NO_COLOR=1` (or pipe to a non-TTY) to disable ANSI colors.

### Use in a hook / CI

```bash
# pre-commit hook or CI step — fails the build on schema drift
node scripts/validate.mjs "$WORKSPACE" || exit 1
```

### Notes

- **Profile dispatch.** `profile.schema.json` is a `oneOf` over 7 variants
  keyed on the `schema` field
  (`cairn.profile/v1`, `cairn.profile.org/v1`, `cairn.profile.atlassian/v1`,
  `cairn.profile.git/v1`, `cairn.profile.infra/v1`, `cairn.profile.teams/v1`,
  `cairn.profile.hooks/v1`). The validator reads the declared `schema` and
  reports only the errors from the matching variant.
- **`cairn.profile.services/v1`.** A profile file declaring this schema is
  reported as a **WARN** (non-fatal): that schema id is not defined in
  `profile.schema.json`. Either add it to `profile.schema.json`, or use the
  standalone `cairn.services/v1` schema for that file.
- **Dependency choice.** AJV is used (not a hand-rolled checker) because the
  schemas rely on JSON Schema 2020-12 features — `oneOf`, cross-file `$ref`,
  `additionalProperties: false`, `not`/`pattern` guards, `const` discriminators —
  that are error-prone to reimplement correctly. The one rule AJV cannot express
  (cross-item `name`/`path` uniqueness in `sources.yaml`) is checked separately
  in code.
```
