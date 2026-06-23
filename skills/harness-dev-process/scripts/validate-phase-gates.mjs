#!/usr/bin/env node

import { spawnSync } from "child_process"
import { existsSync, readdirSync, readFileSync, statSync } from "fs"
import path from "path"
import { fileURLToPath } from "url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))

const artifactPatterns = {
  cps: [/^feature-cps\.md$/iu, /^cps\.md$/iu],
  prd: [/^feature-prd\.md$/iu, /^prd\.md$/iu],
  architecture: [/^feature-architecture\.md$/iu, /^architecture\.md$/iu],
  taskPacket: [/^task-packet\.md$/iu, /^task-[\w-]+\.md$/iu],
}

function parseArgs(argv) {
  const options = {
    json: false,
    phase: null,
    projectDir: null,
    level: "standard",
  }

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index]

    if (token === "--json") {
      options.json = true
      continue
    }

    if (token === "--phase") {
      options.phase = normalizePhase(argv[index + 1] ?? "")
      index += 1
      continue
    }

    if (token === "--level") {
      options.level = (argv[index + 1] ?? "standard").toLowerCase()
      index += 1
      continue
    }

    if (options.projectDir == null) {
      options.projectDir = token
    }
  }

  return options
}

function usage() {
  console.error("Usage: validate-phase-gates.mjs <project-dir> [--phase PLAN|IMPL|VERIFY|SHIP|DONE] [--level lite|standard|full] [--json]")
}

function normalizeHeading(text) {
  return text
    .toLowerCase()
    .replace(/\[[^\]]+\]\([^)]+\)/g, "")
    .replace(/[`*_~]/g, "")
    .replace(/[^\p{Letter}\p{Number}]+/gu, "")
}

function normalizePhase(value) {
  const token = value.trim().toUpperCase()
  const aliases = {
    PLAN: "PLAN",
    IMPL: "IMPL",
    IMPLEMENT: "IMPL",
    IMPLEMENTATION: "IMPL",
    VERIFY: "VERIFY",
    SHIP: "SHIP",
    DONE: "DONE",
  }

  return aliases[token] ?? null
}

function walkFiles(rootDir) {
  const entries = readdirSync(rootDir, { withFileTypes: true })
  const files = []

  for (const entry of entries) {
    if ([".git", "node_modules", ".idea", ".next", "dist", "build"].includes(entry.name)) {
      continue
    }

    const fullPath = path.join(rootDir, entry.name)

    if (entry.isDirectory()) {
      files.push(...walkFiles(fullPath))
      continue
    }

    files.push(fullPath)
  }

  return files
}

function findArtifact(projectDir, patterns) {
  const files = walkFiles(projectDir)
  return files.find(filePath => patterns.some(pattern => pattern.test(path.basename(filePath)))) ?? null
}

function extractSections(markdown) {
  const headings = []
  const pattern = /^(#{1,6})\s+(.+?)\s*$/gmu

  for (const match of markdown.matchAll(pattern)) {
    headings.push({
      level: match[1].length,
      text: match[2].trim(),
      index: match.index ?? 0,
    })
  }

  return headings.map((heading, index) => ({
    ...heading,
    content: markdown.slice(heading.index, headings[index + 1]?.index ?? markdown.length),
  }))
}

function findSection(markdown, aliases) {
  const normalizedAliases = aliases.map(alias => normalizeHeading(alias))
  return extractSections(markdown).find(section => normalizedAliases.includes(normalizeHeading(section.text))) ?? null
}

function stripLinkSyntax(text) {
  return text.replace(/\[[^\]]+\]\([^)]+\)/g, "")
}

function hasPlaceholder(text) {
  const sanitized = stripLinkSyntax(text).replace(/-\s+\[[ xX]\]/g, "")
  return /\[[^\]\n]{2,}\]/u.test(sanitized)
}

function extractTableRows(sectionText) {
  return sectionText
    .split("\n")
    .filter(line => line.trim().startsWith("|"))
    .map(line => line.split("|").slice(1, -1).map(cell => cell.trim()))
    .filter(row => row.length > 0 && !row.every(cell => /^-+$/.test(cell.replace(/:/g, ""))))
}

function isFilledValue(value) {
  return value != null && value.trim() !== "" && !hasPlaceholder(value)
}

function countChecklistItems(text) {
  return [...text.matchAll(/^\s*-\s+\[[ xX]\]\s+/gmu)].length
}

function countCheckedItems(text, labelPattern) {
  const pattern = new RegExp(`^\\s*-\\s+\\[x\\]\\s+.*${labelPattern}.*$`, "gimu")
  return [...text.matchAll(pattern)].length
}

function readFileIfExists(filePath) {
  return filePath != null && existsSync(filePath) ? readFileSync(filePath, "utf8") : null
}

function runDocContractValidation(filePath) {
  const validation = spawnSync(
    process.execPath,
    [path.join(scriptDir, "validate-doc-contracts.mjs"), filePath, "--json"],
    { encoding: "utf8" },
  )

  if (validation.error != null) {
    return {
      errors: [`문서 계약 검증 실행 실패: ${validation.error.message}`],
      warnings: [],
    }
  }

  try {
    const [result] = JSON.parse(validation.stdout)
    return {
      errors: result.errors ?? [],
      warnings: result.warnings ?? [],
    }
  } catch (error) {
    return {
      errors: [`문서 계약 검증 결과를 파싱할 수 없습니다: ${error instanceof Error ? error.message : String(error)}`],
      warnings: [],
    }
  }
}

function loadState(projectDir) {
  const candidates = [
    path.join(projectDir, ".harness", "state.json"),
    path.join(projectDir, "state.json"),
  ]

  for (const candidate of candidates) {
    if (!existsSync(candidate)) {
      continue
    }

    try {
      return {
        path: candidate,
        value: JSON.parse(readFileSync(candidate, "utf8")),
      }
    } catch (error) {
      return {
        path: candidate,
        value: {},
        parseError: error instanceof Error ? error.message : String(error),
      }
    }
  }

  return {
    path: null,
    value: {},
  }
}

function getNestedValue(source, dottedPath) {
  return dottedPath
    .split(".")
    .reduce((current, key) => (current != null && typeof current === "object" ? current[key] : undefined), source)
}

function getBooleanEvidence(state, aliases) {
  for (const alias of aliases) {
    const value = getNestedValue(state, alias)
    if (typeof value === "boolean") {
      return value
    }

    // evidence pointer 구조: { status: "pass"|"fail"|null, ... }
    if (value != null && typeof value === "object" && "status" in value) {
      if (value.status === "pass") {
        return true
      }

      if (value.status === "fail") {
        return false
      }
    }

    // 문자열 "pass"/"fail" 직접 비교
    if (value === "pass") {
      return true
    }

    if (value === "fail") {
      return false
    }
  }

  return null
}

function getApprovedStatus(markdown) {
  return /\|\s*상태\s*\|\s*`?approved`?\s*\|/iu.test(markdown)
}

function isNotApplicable(sectionText) {
  return /해당없음|n\/a|없음/iu.test(sectionText)
}

function inferPhase(artifacts) {
  if (artifacts.cps == null) {
    return "PLAN"
  }

  if (artifacts.prd == null || artifacts.architecture == null) {
    return "IMPL"
  }

  if (artifacts.taskPacket == null) {
    return "VERIFY"
  }

  return "SHIP"
}

function buildArtifactMap(projectDir) {
  return {
    cps: findArtifact(projectDir, artifactPatterns.cps),
    prd: findArtifact(projectDir, artifactPatterns.prd),
    architecture: findArtifact(projectDir, artifactPatterns.architecture),
    taskPacket: findArtifact(projectDir, artifactPatterns.taskPacket),
  }
}

function checkPlanGate(artifacts) {
  const unmet = []
  const warnings = []
  const cpsText = readFileIfExists(artifacts.cps)

  if (artifacts.cps == null || cpsText == null) {
    unmet.push("CPS 문서가 없습니다.")
    return { unmet, warnings }
  }

  const docContract = runDocContractValidation(artifacts.cps)
  unmet.push(...docContract.errors.map(error => `feature-cps.md: ${error}`))
  warnings.push(...docContract.warnings.map(warning => `feature-cps.md: ${warning}`))

  const charter = findSection(cpsText, ["Charter"])
  if (charter == null) {
    unmet.push("CPS에 Charter 섹션이 없습니다.")
  } else {
    const requiredFields = ["Goal", "Context", "Constraints", "Done When"]
    for (const field of requiredFields) {
      const pattern = new RegExp(`^\\s*${field}:\\s*([\\s\\S]*?)(?=^\\s*(Goal|Context|Constraints|Done When):|(?![\\s\\S]))`, "imu")
      const match = charter.content.match(pattern)
      const value = match?.[1]?.trim() ?? ""
      if (value === "" || hasPlaceholder(value)) {
        unmet.push(`Charter ${field} 값이 비어 있거나 템플릿 placeholder 상태입니다.`)
      }
    }
  }

  const clarificationMatch = cpsText.match(/Clarification Level:\s*`?([A-Z]+)`?/iu)
  if ((clarificationMatch?.[1] ?? "").toUpperCase() === "HIGH") {
    unmet.push("Clarification Level이 HIGH입니다.")
  }

  const acceptance = findSection(cpsText, ["Acceptance Criteria"])
  if (acceptance == null || countChecklistItems(acceptance.content) < 1) {
    unmet.push("Acceptance Criteria 체크박스가 1개 이상 필요합니다.")
  }

  const impact = findSection(cpsText, ["영향도 분석"])
  const impactRows = impact == null ? [] : extractTableRows(impact.content).filter(row => /^\d+$/.test(row[0] ?? ""))
  if (impact == null) {
    unmet.push("영향도 분석 섹션이 없습니다.")
  } else if (impactRows.length < 8) {
    unmet.push("영향도 분석 8개 항목이 모두 채워지지 않았습니다.")
  } else {
    for (const row of impactRows.slice(0, 8)) {
      if (!isFilledValue(row[2] ?? "")) {
        unmet.push(`영향도 분석 ${row[0]}번 항목의 '해당' 값이 비어 있습니다.`)
      }
    }
  }

  return { unmet, warnings }
}

function checkImplGate(artifacts, state) {
  const unmet = []
  const warnings = []
  const prdText = readFileIfExists(artifacts.prd)
  const architectureText = readFileIfExists(artifacts.architecture)

  if (artifacts.prd == null || prdText == null) {
    unmet.push("PRD 문서가 없습니다.")
  }

  if (artifacts.architecture == null || architectureText == null) {
    unmet.push("Architecture 문서가 없습니다.")
  }

  if (prdText != null) {
    const prdContract = runDocContractValidation(artifacts.prd)
    unmet.push(...prdContract.errors.map(error => `feature-prd.md: ${error}`))
    warnings.push(...prdContract.warnings.map(warning => `feature-prd.md: ${warning}`))

    const fullstack = findSection(prdText, ["풀스택 레이어 설계"])
    const rows = fullstack == null ? [] : extractTableRows(fullstack.content).filter(row => /^\d+$/.test(row[0] ?? ""))
    if (fullstack == null) {
      unmet.push("PRD에 풀스택 레이어 설계 섹션이 없습니다.")
    } else if (rows.length < 8) {
      unmet.push("풀스택 8레이어 판정이 모두 작성되지 않았습니다.")
    } else {
      for (const row of rows.slice(0, 8)) {
        if (!isFilledValue(row[2] ?? "")) {
          unmet.push(`풀스택 레이어 ${row[0]}번의 '해당' 값이 비어 있습니다.`)
        }
      }
    }

    const apiDesign = findSection(prdText, ["API 설계"])
    if (apiDesign == null) {
      unmet.push("PRD에 API 설계 섹션이 없습니다.")
    } else if (!isNotApplicable(apiDesign.content)) {
      const apiReady = /\|\s*Method\s*\|/u.test(apiDesign.content)
        && /\|\s*URL\s*\|/u.test(apiDesign.content)
        && /\*\*Request\*\*/u.test(apiDesign.content)
        && /\*\*Response/u.test(apiDesign.content)
        && !hasPlaceholder(apiDesign.content)
      if (!apiReady) {
        unmet.push("API 설계 섹션이 placeholder 상태이거나 Method/URL/Request/Response가 부족합니다.")
      }
    }

    const ddlSection = findSection(prdText, ["DDL 변경"])
    if (ddlSection == null) {
      unmet.push("PRD에 DDL 변경 섹션이 없습니다.")
    } else if (!isNotApplicable(ddlSection.content)) {
      const hasSql = /```sql[\s\S]*?(alter|create|drop|comment)\b[\s\S]*?```/iu.test(ddlSection.content)
      if (!hasSql && hasPlaceholder(ddlSection.content)) {
        unmet.push("DDL 변경 섹션이 placeholder 상태입니다.")
      }
    }
  }

  if (architectureText != null) {
    const architectureContract = runDocContractValidation(artifacts.architecture)
    unmet.push(...architectureContract.errors.map(error => `feature-architecture.md: ${error}`))
    warnings.push(...architectureContract.warnings.map(warning => `feature-architecture.md: ${warning}`))

    const externalIntegration = findSection(architectureText, ["외부 연동"])
    if (externalIntegration == null) {
      unmet.push("Architecture에 외부 연동 섹션이 없습니다.")
    } else if (!isNotApplicable(externalIntegration.content)) {
      const specReady = /실제 응답 샘플/iu.test(externalIntegration.content) && !hasPlaceholder(externalIntegration.content)
      if (!specReady) {
        unmet.push("외부 연동 스펙이 placeholder 상태이거나 실제 응답 샘플이 없습니다.")
      }
    }
  }

  // UI 목업 검증 (UI 변경이 있는 경우)
  if (prdText != null) {
    const uiSection = findSection(prdText, ["UI 변경"])
    if (uiSection != null) {
      // "변경 화면"이나 "변경 내용"이 채워져 있으면 UI 변경으로 간주
      const hasScreenChange = /변경 화면:\s*\S+/u.test(uiSection.content) && !hasPlaceholder(uiSection.content.replace(/해당\s*없음\s*사유/g, ""))
      if (hasScreenChange) {
        // 목업 파일이 실제 경로/파일명을 갖고 있는지 검증
        const mockupMatch = uiSection.content.match(/목업 파일:\s*(.+)/u)
        const mockupValue = (mockupMatch?.[1] ?? "").trim()
        const hasMockup = mockupValue !== "" && !hasPlaceholder(mockupValue) && !/필수|경로|설명/u.test(mockupValue)
        if (!hasMockup) {
          unmet.push("UI 변경이 있지만 목업 파일이 지정되지 않았습니다.")
        }
      }
    }
  }

  // 사용자 승인 — Harness Level에 따라 분기
  const userApproved = getBooleanEvidence(state, [
    "approvals.user",
    "userApproval",
    "approvedByUser",
  ]) ?? (prdText != null && getApprovedStatus(prdText)) ?? (architectureText != null && getApprovedStatus(architectureText))

  const resolvedLevel = state._resolvedLevel ?? "standard"

  if (resolvedLevel === "lite") {
    // Lite: 승인 불필요 — skip
  } else if (!userApproved) {
    unmet.push("사용자 승인 증거가 없습니다. 상태를 approved로 올리거나 state.json에 approvals.user=true를 기록하세요.")
  }

  return { unmet, warnings }
}

function checkVerifyGate(artifacts, state) {
  const unmet = []
  const warnings = []
  const taskText = readFileIfExists(artifacts.taskPacket)

  if (artifacts.taskPacket == null || taskText == null) {
    unmet.push("Task Packet 문서가 없습니다.")
  }

  if (taskText != null) {
    const taskContract = runDocContractValidation(artifacts.taskPacket)
    unmet.push(...taskContract.errors.map(error => `task-packet.md: ${error}`))
    warnings.push(...taskContract.warnings.map(warning => `task-packet.md: ${warning}`))
  }

  const buildSuccess = getBooleanEvidence(state, [
    "evidence.build",
    "evidence.build.status",
    "checks.buildSuccess",
    "buildSuccess",
  ])
  if (buildSuccess !== true) {
    unmet.push("빌드 성공 증거가 없습니다. evidence.build.status=\"pass\"를 기록하세요.")
  }

  const changedFilesMatch = getBooleanEvidence(state, [
    "checks.changedFilesMatchPrd",
    "changedFilesMatchPrd",
  ])
  if (changedFilesMatch !== true) {
    unmet.push("PRD 변경 파일 목록과 실제 변경 일치 여부가 기록되지 않았습니다.")
  }

  const unitTestsReady = getBooleanEvidence(state, [
    "evidence.unitTest",
    "evidence.unitTest.status",
    "checks.unitTestsWritten",
    "unitTestsWritten",
  ]) ?? (taskText != null && countCheckedItems(taskText, "단위 테스트") > 0)
  if (!unitTestsReady) {
    unmet.push("단위 테스트 작성/통과 증거가 없습니다.")
  }

  const doneWhenMet = getBooleanEvidence(state, [
    "checks.doneWhenMet",
    "doneWhenMet",
  ]) ?? (taskText != null && countCheckedItems(taskText, "Done When 기준 모두 충족") > 0)
  if (!doneWhenMet) {
    unmet.push("Task Packet의 Done When 충족 증거가 없습니다.")
  }

  return { unmet, warnings }
}

function checkShipGate(state, taskText) {
  const unmet = []

  const allTestsPassed = getBooleanEvidence(state, [
    "evidence.unitTest",
    "evidence.unitTest.status",
    "checks.allTestsPassed",
    "allTestsPassed",
  ])
  if (allTestsPassed !== true) {
    unmet.push("모든 테스트 통과 증거가 없습니다.")
  }

  const codeReviewPassed = getBooleanEvidence(state, [
    "evidence.codeReview",
    "evidence.codeReview.status",
    "checks.codeReviewPassed",
    "codeReviewPassed",
  ])
  if (codeReviewPassed !== true) {
    unmet.push("코드 리뷰 CRITICAL/HIGH 없음 증거가 없습니다.")
  }

  const securityPassed = getBooleanEvidence(state, [
    "evidence.securityReview",
    "evidence.securityReview.status",
    "checks.securityPassed",
    "securityPassed",
  ])
  if (securityPassed !== true) {
    unmet.push("보안 체크 통과 증거가 없습니다.")
  }

  const regressionPassed = getBooleanEvidence(state, [
    "evidence.regression",
    "evidence.regression.status",
    "checks.regressionPassed",
    "regressionPassed",
  ]) ?? (taskText != null && countCheckedItems(taskText, "영향받는 기존 테스트 통과") > 0)
  if (!regressionPassed) {
    unmet.push("영향받는 기존 테스트 통과 증거가 없습니다.")
  }

  const localVerification = getBooleanEvidence(state, [
    "evidence.localVerification",
    "evidence.localVerification.status",
    "checks.localVerificationCompleted",
    "localVerificationCompleted",
  ])
  if (localVerification !== true) {
    unmet.push("로컬 검증 완료 증거가 없습니다.")
  }

  return unmet
}

function checkDoneGate(artifacts, state) {
  const unmet = []
  const prdText = readFileIfExists(artifacts.prd)

  if (prdText == null) {
    unmet.push("PRD 문서가 없어 배포 계획을 검증할 수 없습니다.")
  } else {
    const deploySection = findSection(prdText, ["배포 계획"])
    if (deploySection == null) {
      unmet.push("PRD에 배포 계획 섹션이 없습니다.")
    } else {
      const hasRollback = /\|\s*롤백 계획\s*\|/u.test(deploySection.content) && !hasPlaceholder(deploySection.content)
      const hasDeployPlan = /\|\s*배포 순서\s*\|/u.test(deploySection.content) && !hasPlaceholder(deploySection.content)
      if (!hasDeployPlan) {
        unmet.push("배포 계획 섹션이 placeholder 상태입니다.")
      }
      if (!hasRollback) {
        unmet.push("롤백 계획이 명시되지 않았습니다.")
      }
    }
  }

  const jiraDone = getBooleanEvidence(state, [
    "evidence.jiraAcceptance",
    "evidence.jiraAcceptance.status",
    "checks.jiraAcceptanceDone",
    "jiraAcceptanceDone",
  ])
  if (jiraDone !== true) {
    unmet.push("Jira Acceptance Criteria 완료 증거가 없습니다.")
  }

  const worklogUpdated = getBooleanEvidence(state, [
    "evidence.worklog",
    "evidence.worklog.status",
    "checks.worklogUpdated",
    "worklogUpdated",
  ])
  if (worklogUpdated !== true) {
    unmet.push("작업일지 반영 증거가 없습니다.")
  }

  return unmet
}

function validatePhaseGate(projectDir, phase, level) {
  const artifacts = buildArtifactMap(projectDir)
  const stateEntry = loadState(projectDir)
  const state = stateEntry.value
  // Level 우선순위: CLI > state.json > default(standard)
  state._resolvedLevel = level
    ?? getNestedValue(state, "harnessLevel")
    ?? getNestedValue(state, "level")
    ?? "standard"
  const selectedPhase = phase ?? inferPhase(artifacts)
  const taskText = readFileIfExists(artifacts.taskPacket)
  let unmet = []
  let warnings = []

  if (selectedPhase === "PLAN") {
    const planGate = checkPlanGate(artifacts)
    unmet = planGate.unmet
    warnings = planGate.warnings
  } else if (selectedPhase === "IMPL") {
    const planGate = checkPlanGate(artifacts)
    const implGate = checkImplGate(artifacts, state)
    unmet = [
      ...planGate.unmet,
      ...implGate.unmet,
    ]
    warnings = [...planGate.warnings, ...implGate.warnings]
  } else if (selectedPhase === "VERIFY") {
    const planGate = checkPlanGate(artifacts)
    const implGate = checkImplGate(artifacts, state)
    const verifyGate = checkVerifyGate(artifacts, state)
    unmet = [
      ...planGate.unmet,
      ...implGate.unmet,
      ...verifyGate.unmet,
    ]
    warnings = [...planGate.warnings, ...implGate.warnings, ...verifyGate.warnings]
  } else if (selectedPhase === "SHIP") {
    const planGate = checkPlanGate(artifacts)
    const implGate = checkImplGate(artifacts, state)
    const verifyGate = checkVerifyGate(artifacts, state)
    unmet = [
      ...planGate.unmet,
      ...implGate.unmet,
      ...verifyGate.unmet,
      ...checkShipGate(state, taskText),
    ]
    warnings = [...planGate.warnings, ...implGate.warnings, ...verifyGate.warnings]
  } else if (selectedPhase === "DONE") {
    const planGate = checkPlanGate(artifacts)
    const implGate = checkImplGate(artifacts, state)
    const verifyGate = checkVerifyGate(artifacts, state)
    unmet = [
      ...planGate.unmet,
      ...implGate.unmet,
      ...verifyGate.unmet,
      ...checkShipGate(state, taskText),
      ...checkDoneGate(artifacts, state),
    ]
    warnings = [...planGate.warnings, ...implGate.warnings, ...verifyGate.warnings]
  } else {
    unmet = [`Unsupported phase: ${selectedPhase}`]
  }

  return {
    projectDir,
    phase: selectedPhase,
    passed: unmet.length === 0,
    artifacts,
    statePath: stateEntry.path,
    stateParseError: stateEntry.parseError ?? null,
    unmet,
    warnings,
  }
}

function printText(result) {
  const status = result.passed ? "PASS" : "FAIL"
  console.log(`${status} ${result.projectDir} [${result.phase}]`)

  if (result.statePath != null) {
    console.log(`- state: ${result.statePath}`)
  }

  for (const [name, artifactPath] of Object.entries(result.artifacts)) {
    if (artifactPath != null) {
      console.log(`- ${name}: ${artifactPath}`)
    }
  }

  if (result.stateParseError != null) {
    console.log(`- state parse error: ${result.stateParseError}`)
  }

  for (const item of result.unmet) {
    console.log(`- ${item}`)
  }

  for (const warning of result.warnings) {
    console.log(`- WARNING: ${warning}`)
  }
}

function findProjectDirByState(startDir) {
  let current = path.resolve(startDir)
  const root = path.parse(current).root

  while (current !== root) {
    if (existsSync(path.join(current, ".harness", "state.json"))) {
      return current
    }

    if (existsSync(path.join(current, "state.json"))) {
      return current
    }

    current = path.dirname(current)
  }

  return null
}

const options = parseArgs(process.argv.slice(2))

if (options.projectDir == null) {
  // 자동 추론: cwd에서 상위로 올라가며 .harness/state.json 탐색
  const inferred = findProjectDirByState(process.cwd())
  if (inferred != null) {
    options.projectDir = inferred
  } else {
    usage()
    process.exit(1)
  }
}

const projectDir = path.resolve(options.projectDir)
if (!existsSync(projectDir) || !statSync(projectDir).isDirectory()) {
  console.error(`Project directory not found: ${projectDir}`)
  process.exit(1)
}

if (options.phase == null && process.argv.includes("--phase")) {
  console.error("Invalid phase. Use PLAN, IMPL, VERIFY, SHIP, or DONE.")
  process.exit(1)
}

const result = validatePhaseGate(projectDir, options.phase, options.level)

if (options.json) {
  console.log(JSON.stringify(result, null, 2))
} else {
  printText(result)
}

if (!result.passed) {
  process.exit(1)
}
