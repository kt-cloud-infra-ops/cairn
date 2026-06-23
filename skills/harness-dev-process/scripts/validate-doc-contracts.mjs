#!/usr/bin/env node

import { existsSync, readFileSync } from "fs"
import path from "path"
import { fileURLToPath } from "url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const outputSchemaPath = path.resolve(scriptDir, "..", "references", "output-schema.md")

const templateByType = {
  cps: "feature-cps.md",
  prd: "feature-prd.md",
  architecture: "feature-architecture.md",
  task: "task-packet.md",
}

function parseArgs(argv) {
  const options = {
    files: [],
    json: false,
    template: null,
    type: null,
  }

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index]

    if (token === "--json") {
      options.json = true
      continue
    }

    if (token === "--template") {
      options.template = argv[index + 1] ?? null
      index += 1
      continue
    }

    if (token === "--type") {
      options.type = (argv[index + 1] ?? "").toLowerCase()
      index += 1
      continue
    }

    options.files.push(token)
  }

  return options
}

function usage() {
  console.error("Usage: validate-doc-contracts.mjs <markdown-file> [more files...] [--type cps|prd|architecture|task] [--template path] [--json]")
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

function normalizeHeading(text) {
  return text
    .replace(/^#+\s*/u, "")
    .replace(/\([^)]*\)/g, "")
    .toLowerCase()
    .replace(/\[[^\]]+\]\([^)]+\)/g, "")
    .replace(/[`*_~]/g, "")
    .replace(/[^\p{Letter}\p{Number}]+/gu, "")
}

function extractHeadings(markdown) {
  const headings = []
  const pattern = /^(#{1,6})\s+(.+?)\s*$/gmu

  for (const match of markdown.matchAll(pattern)) {
    headings.push({
      level: match[1].length,
      text: match[2].trim(),
      index: match.index ?? 0,
    })
  }

  return headings
}

function extractSections(markdown) {
  const headings = extractHeadings(markdown)
  return headings.map((heading, index) => ({
    ...heading,
    content: markdown.slice(heading.index, headings[index + 1]?.index ?? markdown.length),
  }))
}

function inferType(filePath, markdown) {
  const basename = path.basename(filePath).toLowerCase()
  const heading = extractHeadings(markdown)[0]?.text.toLowerCase() ?? ""

  if (basename.includes("cps") || heading.includes("cps")) {
    return "cps"
  }

  if (basename.includes("prd") || heading.includes("prd")) {
    return "prd"
  }

  if (basename.includes("arch") || heading.includes("architecture")) {
    return "architecture"
  }

  if (basename.includes("task")) {
    return "task"
  }

  return null
}

function resolveTemplateName(filePath, markdown, options) {
  if (options.template != null) {
    return path.basename(options.template)
  }

  const type = options.type ?? inferType(filePath, markdown)
  return type == null ? null : templateByType[type]
}

function extractHeadingBlock(markdown, headingText, level) {
  const fence = "#".repeat(level)
  const pattern = new RegExp(`^${escapeRegExp(fence)}\\s+${escapeRegExp(headingText)}\\s*$([\\s\\S]*?)(?=^${escapeRegExp(fence)}\\s+|^#{1,${level - 1}}\\s+|(?![\\s\\S]))`, "mu")
  return markdown.match(pattern)?.[1] ?? ""
}

function extractYamlFence(text) {
  return text.match(/```yaml\s*([\s\S]*?)```/u)?.[1] ?? ""
}

function extractYamlSegment(yamlText, key) {
  const lines = yamlText.split("\n")
  const startIndex = lines.findIndex(line => line.trim() === `${key}:`)
  if (startIndex === -1) {
    return ""
  }

  const collected = []
  for (let index = startIndex + 1; index < lines.length; index += 1) {
    const line = lines[index]
    if (line.trim() === "") {
      collected.push(line)
      continue
    }

    if (/^[A-Za-z_]+:/u.test(line.trim())) {
      break
    }

    collected.push(line)
  }

  return collected.join("\n")
}

function parsePatternObjects(segment) {
  const blocks = segment.match(/^\s*-\s+pattern:[\s\S]*?(?=^\s*-\s+pattern:|(?![\s\S]))/gmu) ?? []
  return blocks.map(block => ({
    pattern: block.match(/pattern:\s*"([^"]+)"/u)?.[1] ?? "",
    count: Number(block.match(/count:\s*(\d+)/u)?.[1] ?? "1"),
    level: block.match(/level:\s*"([^"]+)"/u)?.[1] ?? "ERROR",
    inSection: block.match(/in_section:\s*"([^"]+)"/u)?.[1] ?? null,
    message: block.match(/message:\s*"([^"]+)"/u)?.[1] ?? "Pattern validation failed",
  }))
}

function parseConditionalSections(segment) {
  const blocks = segment.match(/^\s*-\s+condition:[\s\S]*?(?=^\s*-\s+condition:|(?![\s\S]))/gmu) ?? []
  return blocks.map(block => ({
    condition: block.match(/condition:\s*"([^"]+)"/u)?.[1] ?? "",
    section: block.match(/section:\s*"([^"]+)"/u)?.[1] ?? "",
    requiredPatterns: [...block.matchAll(/^\s*-\s*"([^"]+)"\s*$/gmu)].map(match => match[1]),
  }))
}

function parseRules() {
  const markdown = readFileSync(outputSchemaPath, "utf8")
  const documentHeadings = [
    ["feature-cps.md", "CPS (feature-cps.md)"],
    ["feature-prd.md", "PRD (feature-prd.md)"],
    ["feature-architecture.md", "Architecture (feature-architecture.md)"],
    ["task-packet.md", "Task Packet (task-packet.md)"],
  ]

  const documents = Object.fromEntries(documentHeadings.map(([templateName, heading]) => {
    const sectionText = extractHeadingBlock(markdown, heading, 3)
    const yamlText = extractYamlFence(sectionText)
    const requiredSections = [...extractYamlSegment(yamlText, "required_sections").matchAll(/^\s*-\s*"([^"]+)"\s*$/gmu)]
      .map(match => match[1])
    const requiredPatterns = parsePatternObjects(extractYamlSegment(yamlText, "required_patterns"))
    const conditionalSections = parseConditionalSections(extractYamlSegment(yamlText, "conditional_sections"))

    return [templateName, {
      requiredSections,
      requiredPatterns,
      conditionalSections,
    }]
  }))

  const forbiddenSection = extractHeadingBlock(markdown, "금지 패턴", 2)
  const forbiddenPatterns = parsePatternObjects(extractYamlFence(forbiddenSection))

  return {
    documents,
    forbiddenPatterns,
  }
}

function findSectionByName(sections, name) {
  const expected = normalizeHeading(name)
  return sections.find(section => {
    const actual = normalizeHeading(section.text)
    return actual === expected || actual.startsWith(expected) || expected.startsWith(actual)
  }) ?? null
}

function extractNamedBlock(markdown, sections, name) {
  const section = findSectionByName(sections, name)
  if (section != null) {
    return section.content
  }

  const pattern = new RegExp(`^\\s*${escapeRegExp(name)}:\\s*([\\s\\S]*?)(?=^\\s*[A-Za-z][A-Za-z ]+:|(?![\\s\\S]))`, "imu")
  return markdown.match(pattern)?.[1] ?? ""
}

function runPatternChecks(patterns, markdown, sections) {
  const errors = []
  const warnings = []

  for (const rule of patterns) {
    const targetText = rule.inSection == null
      ? markdown
      : extractNamedBlock(markdown, sections, rule.inSection)
    const count = [...targetText.matchAll(new RegExp(rule.pattern, "gmu"))].length
    if (count >= rule.count) {
      continue
    }

    if (rule.level === "WARNING") {
      warnings.push(rule.message)
      continue
    }

    errors.push(rule.message)
  }

  return { errors, warnings }
}

function runForbiddenPatternChecks(patterns, markdown, sections) {
  const errors = []
  const warnings = []

  for (const rule of patterns) {
    const targetText = rule.inSection == null
      ? markdown
      : extractNamedBlock(markdown, sections, rule.inSection)
    const count = [...targetText.matchAll(new RegExp(rule.pattern, "gmu"))].length
    if (count === 0) {
      continue
    }

    if (rule.level === "WARNING") {
      warnings.push(rule.message)
      continue
    }

    errors.push(rule.message)
  }

  return { errors, warnings }
}

function runConditionalChecks(conditionalSections, markdown, sections) {
  const errors = []

  for (const rule of conditionalSections) {
    const section = findSectionByName(sections, rule.section)
    if (section == null || /해당없음|n\/a|없음/iu.test(section.content)) {
      continue
    }

    for (const pattern of rule.requiredPatterns) {
      if (new RegExp(pattern, "gmu").test(markdown)) {
        continue
      }

      errors.push(`${rule.section} 조건 충족 실패: ${pattern}`)
    }
  }

  return errors
}

function validateDocument(filePath, options, rules) {
  if (!existsSync(filePath)) {
    return {
      file: filePath,
      template: null,
      passed: false,
      errors: ["File not found"],
      warnings: [],
    }
  }

  const markdown = readFileSync(filePath, "utf8")
  const templateName = resolveTemplateName(filePath, markdown, options)
  const schema = templateName == null ? null : rules.documents[templateName]
  const sections = extractSections(markdown)
  const errors = []
  const warnings = []

  if (schema == null) {
    errors.push(`No output-schema rule found for ${templateName ?? "unknown template"}`)
  } else {
    const actualLevel2Sections = sections.filter(section => section.level === 2)
    for (const requiredSection of schema.requiredSections) {
      const expected = normalizeHeading(requiredSection)
      const matched = actualLevel2Sections.some(section => {
        const actual = normalizeHeading(section.text)
        return actual === expected || actual.startsWith(expected) || expected.startsWith(actual)
      })

      if (!matched) {
        errors.push(`Missing required section: ${requiredSection}`)
      }
    }

    const requiredPatternResult = runPatternChecks(schema.requiredPatterns, markdown, sections)
    errors.push(...requiredPatternResult.errors)
    warnings.push(...requiredPatternResult.warnings)
    errors.push(...runConditionalChecks(schema.conditionalSections, markdown, sections))
  }

  const forbiddenPatternResult = runForbiddenPatternChecks(rules.forbiddenPatterns, markdown, sections)
  errors.push(...forbiddenPatternResult.errors)
  warnings.push(...forbiddenPatternResult.warnings)

  return {
    file: filePath,
    template: templateName,
    passed: errors.length === 0,
    errors,
    warnings,
  }
}

function printText(results) {
  for (const result of results) {
    const status = result.passed ? "PASS" : "FAIL"
    const templateInfo = result.template == null ? "" : ` (${result.template})`
    console.log(`${status} ${result.file}${templateInfo}`)

    for (const error of result.errors) {
      console.log(`- ERROR: ${error}`)
    }

    for (const warning of result.warnings) {
      console.log(`- WARNING: ${warning}`)
    }
  }
}

const options = parseArgs(process.argv.slice(2))

if (options.files.length === 0) {
  usage()
  process.exit(1)
}

const rules = parseRules()
const results = options.files.map(file => validateDocument(path.resolve(file), options, rules))

if (options.json) {
  console.log(JSON.stringify(results, null, 2))
} else {
  printText(results)
}

if (results.some(result => !result.passed)) {
  process.exit(1)
}
