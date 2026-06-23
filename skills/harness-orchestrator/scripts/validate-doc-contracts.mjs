#!/usr/bin/env node

import { spawnSync } from "child_process"
import path from "path"
import { fileURLToPath } from "url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const delegated = path.resolve(scriptDir, "../../harness-dev-process/scripts/validate-doc-contracts.mjs")

const result = spawnSync(process.execPath, [delegated, ...process.argv.slice(2)], {
  stdio: "inherit",
})

if (result.error != null) {
  console.error(result.error.message)
  process.exit(1)
}

process.exit(result.status ?? 1)
