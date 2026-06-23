#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs"
import path from "path"
import { fileURLToPath } from "url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, "../../../..")
const orchestratorRoot = path.join(repoRoot, "temp", "orchestrator")

function usage() {
  console.error("Usage:")
  console.error("  service-orchestration.mjs init <service>")
  console.error("  service-orchestration.mjs bootstrap-complete <service> [--service-readme path] [--tasks path] [--project-root path ...] [--workspace-mode symlink|direct] [--charts path] [--values path] [--httproute path]")
  console.error("  service-orchestration.mjs ops-precheck <service> --env <env> --namespace <namespace> [--deployment name] [--db name] [--hostname host]")
  console.error("  service-orchestration.mjs ops-complete <service>")
  console.error("  service-orchestration.mjs status <service> [--json]")
  console.error("  service-orchestration.mjs validate <service> --require bootstrap|ops-precheck|deploy-ready|ops [--json]")
}

function fail(message, details = []) {
  console.error(message)
  for (const detail of details) {
    console.error(`- ${detail}`)
  }
  process.exit(1)
}

function normalizeServiceName(value) {
  const trimmed = value.trim().toLowerCase()
  if (!/^[a-z0-9][a-z0-9_-]*$/u.test(trimmed)) {
    fail(`Invalid service name: ${value}`)
  }
  return trimmed
}

function parseArgs(argv) {
  if (argv.length < 2) {
    usage()
    process.exit(1)
  }

  const [command, rawService, ...rest] = argv
  const options = {
    command,
    service: normalizeServiceName(rawService),
    json: false,
    projectRoots: [],
  }

  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index]

    switch (token) {
      case "--json":
        options.json = true
        break
      case "--require":
        options.requirement = rest[index + 1] ?? null
        index += 1
        break
      case "--service-readme":
        options.serviceReadme = rest[index + 1] ?? null
        index += 1
        break
      case "--tasks":
        options.tasks = rest[index + 1] ?? null
        index += 1
        break
      case "--project-root":
        options.projectRoots.push(rest[index + 1] ?? "")
        index += 1
        break
      case "--workspace-mode":
        options.workspaceMode = rest[index + 1] ?? null
        index += 1
        break
      case "--charts":
        options.charts = rest[index + 1] ?? null
        index += 1
        break
      case "--values":
        options.values = rest[index + 1] ?? null
        index += 1
        break
      case "--httproute":
        options.httproute = rest[index + 1] ?? null
        index += 1
        break
      case "--env":
        options.env = rest[index + 1] ?? null
        index += 1
        break
      case "--namespace":
        options.namespace = rest[index + 1] ?? null
        index += 1
        break
      case "--deployment":
        options.deployment = rest[index + 1] ?? null
        index += 1
        break
      case "--db":
        options.db = rest[index + 1] ?? null
        index += 1
        break
      case "--hostname":
        options.hostname = rest[index + 1] ?? null
        index += 1
        break
      default:
        fail(`Unknown option: ${token}`)
    }
  }

  return options
}

function nowIso() {
  return new Date().toISOString()
}

function resolveRepoPath(value) {
  if (value == null || value.trim() === "") {
    return null
  }

  return path.isAbsolute(value)
    ? path.normalize(value)
    : path.normalize(path.join(repoRoot, value))
}

function toRepoRelative(value) {
  if (value == null) {
    return null
  }

  const relative = path.relative(repoRoot, value)
  return relative.startsWith("..") ? value : relative || "."
}

function ensureDir(dirPath) {
  mkdirSync(dirPath, { recursive: true })
}

function stateDirFor(service) {
  return path.join(orchestratorRoot, service)
}

function statePathFor(service) {
  return path.join(stateDirFor(service), "state.json")
}

function defaultState(service) {
  return {
    service,
    createdAt: nowIso(),
    updatedAt: nowIso(),
    bootstrap: {
      status: "pending",
      completedAt: null,
      workspaceMode: null,
      serviceReadme: null,
      tasks: null,
      projectRoots: [],
      artifacts: {
        serviceReadme: false,
        tasks: false,
        projects: [],
        charts: false,
        values: false,
        httproute: false,
      },
    },
    ops: {
      status: "blocked",
      precheck: {
        status: "pending",
        at: null,
        env: null,
        namespace: null,
        deployment: null,
        db: null,
        hostname: null,
      },
      completedAt: null,
    },
  }
}

function loadState(service) {
  const statePath = statePathFor(service)
  if (!existsSync(statePath)) {
    return {
      path: statePath,
      value: defaultState(service),
      existed: false,
    }
  }

  return {
    path: statePath,
    value: JSON.parse(readFileSync(statePath, "utf8")),
    existed: true,
  }
}

function saveState(service, state) {
  state.updatedAt = nowIso()
  ensureDir(stateDirFor(service))
  writeFileSync(statePathFor(service), `${JSON.stringify(state, null, 2)}\n`)
}

function assertExists(label, filePath) {
  if (filePath == null || !existsSync(filePath)) {
    fail(`${label} not found`, [filePath == null ? "path is missing" : toRepoRelative(filePath)])
  }
}

function bootstrapArtifactSummary(projectRoots) {
  return projectRoots.map(projectRoot => ({
    root: toRepoRelative(projectRoot),
    docs: existsSync(path.join(projectRoot, "docs")),
    agents: existsSync(path.join(projectRoot, "AGENTS.md")),
  }))
}

function validateBootstrapOptions(options) {
  const serviceReadme = resolveRepoPath(options.serviceReadme ?? `base/services/${options.service}/README.md`)
  const tasks = resolveRepoPath(options.tasks ?? `base/services/${options.service}/TASKS.md`)
  const charts = resolveRepoPath(options.charts)
  const values = resolveRepoPath(options.values)
  const httproute = resolveRepoPath(options.httproute)
  const projectRoots = options.projectRoots.map(resolveRepoPath).filter(Boolean)

  assertExists("Service README", serviceReadme)
  assertExists("Service TASKS", tasks)

  if (projectRoots.length === 0) {
    fail("At least one --project-root is required for bootstrap completion")
  }

  for (const projectRoot of projectRoots) {
    assertExists("Project root", projectRoot)
    assertExists("Project docs", path.join(projectRoot, "docs"))
    assertExists("Project AGENTS.md", path.join(projectRoot, "AGENTS.md"))
  }

  assertExists("service-charts path", charts)
  assertExists("service-values path", values)
  assertExists("HTTPRoute path", httproute)

  return {
    serviceReadme,
    tasks,
    projectRoots,
    charts,
    values,
    httproute,
  }
}

function validateState(state, requirement) {
  const errors = []
  const bootstrap = state.bootstrap ?? {}
  const artifacts = bootstrap.artifacts ?? {}
  const ops = state.ops ?? {}
  const precheck = ops.precheck ?? {}

  const bootstrapComplete = bootstrap.status === "complete"
  const projects = Array.isArray(artifacts.projects) ? artifacts.projects : []
  const bootstrapArtifactsOk = Boolean(
    artifacts.serviceReadme
    && artifacts.tasks
    && artifacts.charts
    && artifacts.values
    && artifacts.httproute
    && projects.length > 0
    && projects.every(project => project.docs && project.agents),
  )

  const precheckComplete = precheck.status === "complete"
  const opsComplete = ops.status === "complete"

  if (["bootstrap", "ops-precheck", "deploy-ready", "ops"].includes(requirement)) {
    if (!bootstrapComplete) {
      errors.push("bootstrap.status=complete 가 아닙니다.")
    }

    if (!bootstrapArtifactsOk) {
      errors.push("bootstrap evidence(service README/TASKS/projects/charts/values/httproute)가 완전하지 않습니다.")
    }
  }

  if (["ops-precheck", "deploy-ready", "ops"].includes(requirement)) {
    if (!precheckComplete) {
      errors.push("ops.precheck.status=complete 가 아닙니다.")
    }
    if (!precheck.env || !precheck.namespace) {
      errors.push("ops PRECHECK env/namespace 증적이 없습니다.")
    }
  }

  if (requirement === "ops" && !opsComplete) {
    errors.push("ops.status=complete 가 아닙니다.")
  }

  return {
    ok: errors.length === 0,
    errors,
  }
}

function printStatus(state, asJson) {
  if (asJson) {
    console.log(JSON.stringify(state, null, 2))
    return
  }

  const bootstrap = state.bootstrap ?? {}
  const ops = state.ops ?? {}
  const precheck = ops.precheck ?? {}

  console.log(`service: ${state.service}`)
  console.log(`state: ${statePathFor(state.service)}`)
  console.log(`bootstrap.status: ${bootstrap.status ?? "unknown"}`)
  console.log(`bootstrap.completedAt: ${bootstrap.completedAt ?? "-"}`)
  console.log(`ops.precheck.status: ${precheck.status ?? "unknown"}`)
  console.log(`ops.status: ${ops.status ?? "unknown"}`)
  console.log(`updatedAt: ${state.updatedAt ?? "-"}`)
}

function main() {
  const options = parseArgs(process.argv.slice(2))
  const loaded = loadState(options.service)
  const state = loaded.value

  switch (options.command) {
    case "init":
      if (!loaded.existed) {
        saveState(options.service, state)
      }
      printStatus(state, options.json)
      return

    case "bootstrap-complete": {
      const validated = validateBootstrapOptions(options)
      state.bootstrap = {
        status: "complete",
        completedAt: nowIso(),
        workspaceMode: options.workspaceMode ?? state.bootstrap?.workspaceMode ?? null,
        serviceReadme: toRepoRelative(validated.serviceReadme),
        tasks: toRepoRelative(validated.tasks),
        projectRoots: validated.projectRoots.map(toRepoRelative),
        artifacts: {
          serviceReadme: true,
          tasks: true,
          projects: bootstrapArtifactSummary(validated.projectRoots),
          charts: true,
          values: true,
          httproute: true,
        },
      }
      state.ops = state.ops ?? defaultState(options.service).ops
      if (state.ops.status === "blocked") {
        state.ops.status = "pending"
      }
      saveState(options.service, state)
      printStatus(state, options.json)
      return
    }

    case "ops-precheck": {
      const bootstrapValidation = validateState(state, "bootstrap")
      if (!bootstrapValidation.ok) {
        fail("bootstrap 선행조건이 충족되지 않았습니다.", bootstrapValidation.errors)
      }
      if (!options.env || !options.namespace) {
        fail("--env 와 --namespace 는 필수입니다.")
      }
      state.ops = state.ops ?? defaultState(options.service).ops
      state.ops.status = "prechecked"
      state.ops.precheck = {
        status: "complete",
        at: nowIso(),
        env: options.env,
        namespace: options.namespace,
        deployment: options.deployment ?? null,
        db: options.db ?? null,
        hostname: options.hostname ?? null,
      }
      saveState(options.service, state)
      printStatus(state, options.json)
      return
    }

    case "ops-complete": {
      const deployValidation = validateState(state, "deploy-ready")
      if (!deployValidation.ok) {
        fail("deploy-ready 선행조건이 충족되지 않았습니다.", deployValidation.errors)
      }
      state.ops = state.ops ?? defaultState(options.service).ops
      state.ops.status = "complete"
      state.ops.completedAt = nowIso()
      saveState(options.service, state)
      printStatus(state, options.json)
      return
    }

    case "status":
      printStatus(state, options.json)
      return

    case "validate": {
      const requirement = (options.requirement ?? "").toLowerCase()
      if (!["bootstrap", "ops-precheck", "deploy-ready", "ops"].includes(requirement)) {
        fail("validate requires --require bootstrap|ops-precheck|deploy-ready|ops")
      }

      const validation = validateState(state, requirement)
      if (options.json) {
        console.log(JSON.stringify({
          service: options.service,
          requirement,
          ok: validation.ok,
          errors: validation.errors,
          statePath: toRepoRelative(statePathFor(options.service)),
        }, null, 2))
      } else if (!validation.ok) {
        console.error(`service: ${options.service}`)
        console.error(`state: ${toRepoRelative(statePathFor(options.service))}`)
        for (const error of validation.errors) {
          console.error(`- ${error}`)
        }
      }

      process.exit(validation.ok ? 0 : 1)
    }

    default:
      usage()
      process.exit(1)
  }
}

main()
