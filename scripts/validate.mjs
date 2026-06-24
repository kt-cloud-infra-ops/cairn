#!/usr/bin/env node
/**
 * Cairn Schema Validator
 *
 * Usage:
 *   node scripts/validate.mjs [workspace-path]
 *
 * Validates a workspace's .cairn/ config against the JSON Schemas in schemas/:
 *   .cairn/workspace.yaml      → workspace.schema.json
 *   .cairn/sources.yaml        → sources.schema.json   (+ cross-item uniqueness)
 *   .cairn/profile/*.yaml      → profile.schema.json   (oneOf variant dispatch)
 *   .cairn/skills.yaml         → skills.schema.json    (optional registry)
 *   profile services document  → services.schema.json
 *
 * Default workspace-path: current working directory (searches up for .cairn/).
 *
 * Exit codes:
 *   0 — all validated files PASS (warnings are non-fatal)
 *   1 — one or more files FAIL
 *   2 — setup error (missing deps, no .cairn/, bad args)
 *
 * Dependencies: ajv (^8, JSON Schema 2020-12), ajv-formats, js-yaml (^4)
 * Install:  npm install   (from the cairn engine root)
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { resolve, join, dirname, basename } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

// ─── paths ───────────────────────────────────────────────────────────────────

const CAIRN_ROOT = resolve(fileURLToPath(new URL('.', import.meta.url)), '..');
const SCHEMA_DIR = join(CAIRN_ROOT, 'schemas');

// ─── load dependencies (from cairn engine's own node_modules first) ───────────

const require = createRequire(import.meta.url);

function tryRequire(id) {
  // Prefer the engine's local node_modules (canonical install location)
  try { return require(resolve(CAIRN_ROOT, 'node_modules', ...id.split('/'))); } catch {}
  // Fallback to normal Node resolution
  try { return require(id); } catch {}
  return null;
}

const AjvRaw  = tryRequire('ajv/dist/2020.js');
const fmtRaw  = tryRequire('ajv-formats');
const yamlRaw = tryRequire('js-yaml');

if (!AjvRaw || !yamlRaw) {
  console.error('');
  console.error('ERROR: Required dependencies not found.');
  console.error(`  cd ${CAIRN_ROOT} && npm install`);
  console.error('  Then retry: node scripts/validate.mjs [workspace-path]');
  console.error('');
  process.exit(2);
}

const Ajv        = AjvRaw.default ?? AjvRaw;
const addFormats = fmtRaw ? (fmtRaw.default ?? fmtRaw) : null;
const yaml       = yamlRaw;

// ─── AJV (JSON Schema 2020-12) ─────────────────────────────────────────────────

const ajv = new Ajv({ strict: false, allErrors: true, verbose: true });
if (addFormats) addFormats(ajv);

// ─── load + register schemas (cross-file $ref) ─────────────────────────────────

function loadSchema(filename) {
  const path = join(SCHEMA_DIR, filename);
  if (!existsSync(path)) throw new Error(`Schema not found: ${path}`);
  return JSON.parse(readFileSync(path, 'utf8'));
}

function loadOptionalSchema(filename) {
  const path = join(SCHEMA_DIR, filename);
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, 'utf8'));
}

let schemas, validate;
try {
  schemas = {
    workspace: loadSchema('workspace.schema.json'),
    sources:   loadSchema('sources.schema.json'),
    profile:   loadSchema('profile.schema.json'),
    services:  loadSchema('services.schema.json'),
    skills:    loadOptionalSchema('skills.schema.json'),
  };
  // Register all so profile.schema.json's "$ref": "./services.schema.json" resolves.
  for (const s of Object.values(schemas).filter(Boolean)) {
    try { ajv.addSchema(s); } catch { /* already registered */ }
  }
  validate = {
    workspace: ajv.compile(schemas.workspace),
    sources:   ajv.compile(schemas.sources),
    profile:   ajv.compile(schemas.profile),
    services:  ajv.compile(schemas.services),
    skills:    schemas.skills ? ajv.compile(schemas.skills) : null,
  };
} catch (e) {
  console.error(`\nERROR loading/compiling schemas: ${e.message}\n`);
  process.exit(2);
}

// ─── YAML helper ───────────────────────────────────────────────────────────────

function parseYaml(filePath) {
  try {
    return yaml.load(readFileSync(filePath, 'utf8'));
  } catch (e) {
    throw new Error(`YAML parse error: ${e.message}`);
  }
}

// ─── profile schema dispatch ───────────────────────────────────────────────────
//
// profile.schema.json declares 7 known variants via oneOf, keyed on `schema`:
//   cairn.profile/v1             profileBundle (all sections in one file)
//   cairn.profile.org/v1         orgProfile
//   cairn.profile.atlassian/v1   atlassianProfile
//   cairn.profile.git/v1         gitProfile
//   cairn.profile.infra/v1       infraProfile
//   cairn.profile.teams/v1       teamsProfile
//   cairn.profile.hooks/v1       hooksProfile
//
// cairn.services/v1 is the standalone services schema document.
// cairn.profile.services/v1 is an org extension NOT defined in profile.schema.json
//   → reported as a schema gap (WARN), not a hard fail.

const KNOWN_PROFILE_SCHEMAS = new Set([
  'cairn.profile/v1',
  'cairn.profile.org/v1',
  'cairn.profile.atlassian/v1',
  'cairn.profile.git/v1',
  'cairn.profile.infra/v1',
  'cairn.profile.teams/v1',
  'cairn.profile.hooks/v1',
]);

// ─── cross-item uniqueness for sources.yaml (schema can't express this) ─────────

function checkSourcesUniqueness(data) {
  const errors = [];
  if (!Array.isArray(data?.sources)) return errors;
  const names = new Map(), paths = new Map();
  data.sources.forEach((src, i) => {
    if (src && typeof src.name === 'string') {
      if (names.has(src.name)) errors.push(`sources[${i}].name "${src.name}" duplicates index ${names.get(src.name)}`);
      else names.set(src.name, i);
    }
    if (src && typeof src.path === 'string') {
      if (paths.has(src.path)) errors.push(`sources[${i}].path "${src.path}" duplicates index ${paths.get(src.path)}`);
      else paths.set(src.path, i);
    }
  });
  return errors;
}

// ─── formatting ─────────────────────────────────────────────────────────────────

const useColor = process.stdout.isTTY && !process.env.NO_COLOR;
const c = (code, s) => (useColor ? `\x1b[${code}m${s}\x1b[0m` : s);
const C = {
  green:  s => c('32', s),
  red:    s => c('31', s),
  yellow: s => c('33', s),
  bold:   s => c('1', s),
  dim:    s => c('2', s),
};

function fmtAjvErrors(errors) {
  if (!errors?.length) return [];
  return errors.map(e => {
    const path   = e.instancePath || '(root)';
    const params = e.params && Object.keys(e.params).length ? ' ' + JSON.stringify(e.params) : '';
    return `    ${C.red('•')} ${path}: ${e.message}${C.dim(params)}`;
  });
}

// oneOf failures emit a deep error tree (one branch per variant). Since the file
// declares its own `schema`, the only relevant errors are from the variant whose
// `schema` const matched — drop the "must be equal to constant" noise from the
// other 6 variants, plus the top-level oneOf wrapper.
function fmtOneOfErrors(errors) {
  if (!errors?.length) return [];
  const leaves = errors.filter(e =>
    e.keyword !== 'oneOf' &&
    e.instancePath !== '' &&
    // drop variant-discriminator misses: `/schema must be equal to constant`
    !(e.keyword === 'const' && e.instancePath === '/schema')
  );
  // De-duplicate identical (path, keyword, param) errors arising from multiple
  // oneOf branches reporting the same underlying problem.
  const seen = new Set();
  const unique = leaves.filter(e => {
    const k = `${e.instancePath}|${e.keyword}|${JSON.stringify(e.params)}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  const chosen = unique.length ? unique.slice(0, 12) : errors.slice(0, 6);
  return fmtAjvErrors(chosen);
}

// ─── result tracking + reporters ────────────────────────────────────────────────

const tally = { pass: 0, fail: 0, warn: 0, skip: 0 };

function pass(label, rel)        { console.log(`  ${C.green('✔ PASS')}  ${C.bold(label)}  ${C.dim(rel)}`); tally.pass++; return true; }
function fail(label, rel, lines) { console.log(`  ${C.red('✖ FAIL')}  ${C.bold(label)}  ${C.dim(rel)}`); lines.forEach(l => console.log(l)); tally.fail++; return false; }
function warn(label, rel, lines) { console.log(`  ${C.yellow('⚠ WARN')}  ${C.bold(label)}  ${C.dim(rel)}`); lines.forEach(l => console.log(`    ${C.yellow(l)}`)); tally.warn++; return null; }
function skip(label, rel, why)   { console.log(`  ${C.dim(`– SKIP  ${label}  ${rel}  (${why})`)}`); tally.skip++; return null; }

const relTo = (base, abs) => (abs.startsWith(base + '/') ? abs.slice(base.length + 1) : abs);

// ─── individual validators ───────────────────────────────────────────────────────

function validateWorkspace(cairnDir, base) {
  const fp = join(cairnDir, 'workspace.yaml');
  const r  = relTo(base, fp);
  if (!existsSync(fp)) return skip('workspace.yaml', r, 'not found');
  let data;
  try { data = parseYaml(fp); } catch (e) { return fail('workspace.yaml', r, [`    ${C.red('• ' + e.message)}`]); }
  return validate.workspace(data)
    ? pass('workspace.yaml', r)
    : fail('workspace.yaml', r, fmtAjvErrors(validate.workspace.errors));
}

function validateSources(cairnDir, base) {
  const fp = join(cairnDir, 'sources.yaml');
  const r  = relTo(base, fp);
  if (!existsSync(fp)) return skip('sources.yaml', r, 'not found');
  let data;
  try { data = parseYaml(fp); } catch (e) { return fail('sources.yaml', r, [`    ${C.red('• ' + e.message)}`]); }

  const schemaOk     = validate.sources(data);
  const uniqueErrors = checkSourcesUniqueness(data);
  if (schemaOk && !uniqueErrors.length) return pass('sources.yaml', r);

  const lines = [];
  if (!schemaOk)           lines.push(...fmtAjvErrors(validate.sources.errors));
  if (uniqueErrors.length) lines.push(...uniqueErrors.map(e => `    ${C.red('• ' + e)}`));
  return fail('sources.yaml', r, lines);
}

function validateSkills(cairnDir, base) {
  const fp = join(cairnDir, 'skills.yaml');
  const r  = relTo(base, fp);
  if (!existsSync(fp)) return skip('skills.yaml', r, 'not found');
  if (!validate.skills) {
    return fail('skills.yaml', r, [
      `    ${C.red('• schemas/skills.schema.json not found; cannot validate existing registry')}`,
    ]);
  }

  let data;
  try { data = parseYaml(fp); } catch (e) { return fail('skills.yaml', r, [`    ${C.red('• ' + e.message)}`]); }
  return validate.skills(data)
    ? pass('skills.yaml', r)
    : fail('skills.yaml', r, fmtAjvErrors(validate.skills.errors));
}

function validateProfileFile(fp, base) {
  const name = basename(fp);
  const r    = relTo(base, fp);
  const label = `profile/${name}`;

  let data;
  try { data = parseYaml(fp); } catch (e) { return fail(label, r, [`    ${C.red('• ' + e.message)}`]); }

  const schemaId = data?.schema;
  if (!schemaId) return fail(label, r, [`    ${C.red("• (root): missing required field 'schema'")}`]);

  // Standalone services document
  if (schemaId === 'cairn.services/v1') {
    return validate.services(data)
      ? pass(label, r)
      : fail(label, r, fmtAjvErrors(validate.services.errors));
  }

  // Org-specific extension not modeled in profile.schema.json
  if (schemaId === 'cairn.profile.services/v1') {
    return warn(label, r, [
      `schema "${schemaId}" is not defined in profile.schema.json (oneOf).`,
      `Schema gap: add cairn.profile.services/v1 to profile.schema.json,`,
      `or change this file to use cairn.services/v1 (standalone services schema).`,
      `Structural validation skipped for this file.`,
    ]);
  }

  // Known profile variant
  if (KNOWN_PROFILE_SCHEMAS.has(schemaId)) {
    return validate.profile(data)
      ? pass(label, r)
      : fail(label, r, fmtOneOfErrors(validate.profile.errors));
  }

  // Unknown schema id
  return fail(label, r, [
    `    ${C.red(`• (root): unknown profile schema "${schemaId}"`)}`,
    `    ${C.dim('  Known: ' + [...KNOWN_PROFILE_SCHEMAS].join(', '))}`,
  ]);
}

function validateProfileDir(cairnDir, base) {
  const dir = join(cairnDir, 'profile');
  if (!existsSync(dir)) { skip('profile/', relTo(base, dir), 'directory not found'); return; }
  const files = readdirSync(dir).filter(f => /\.(ya?ml)$/.test(f)).sort();
  if (!files.length) { skip('profile/', relTo(base, dir), 'no YAML files'); return; }
  for (const f of files) validateProfileFile(join(dir, f), base);
}

// ─── locate .cairn/ (search current dir, then walk up) ─────────────────────────

function findCairnDir(startPath) {
  // explicit .cairn path
  if (basename(startPath) === '.cairn' && existsSync(startPath)) {
    return { cairnDir: startPath, workspace: dirname(startPath) };
  }
  // direct child
  let dir = startPath;
  while (true) {
    const candidate = join(dir, '.cairn');
    if (existsSync(candidate)) return { cairnDir: candidate, workspace: dir };
    const parent = dirname(dir);
    if (parent === dir) return null; // reached filesystem root
    dir = parent;
  }
}

// ─── main ──────────────────────────────────────────────────────────────────────

function main() {
  const startPath = resolve(process.argv[2] ?? '.');
  const found = findCairnDir(startPath);

  if (!found) {
    console.error(`\n${C.red(`ERROR: No .cairn/ directory found at or above: ${startPath}`)}`);
    console.error('Usage: node scripts/validate.mjs [workspace-path]\n');
    process.exit(2);
  }

  const { cairnDir, workspace } = found;

  console.log('');
  console.log(C.bold('Cairn Schema Validator'));
  console.log(C.dim(`Workspace : ${workspace}`));
  console.log(C.dim(`Schemas   : ${SCHEMA_DIR}`));
  console.log('─'.repeat(72));

  console.log('\n' + C.bold('Core'));
  validateWorkspace(cairnDir, workspace);
  validateSources(cairnDir, workspace);

  console.log('\n' + C.bold('Profile'));
  validateProfileDir(cairnDir, workspace);

  console.log('\n' + C.bold('Skills'));
  validateSkills(cairnDir, workspace);

  console.log('\n' + '─'.repeat(72));
  const { pass: p, fail: f, warn: w, skip: s } = tally;
  const summary = `${p} pass · ${w} warn · ${s} skip`;
  if (f === 0) console.log('\n' + C.green(C.bold('✔ All checks passed')) + '  ' + summary + '\n');
  else         console.log('\n' + C.red(C.bold(`✖ ${f} file(s) failed`)) + '  ' + summary + '\n');

  process.exit(f > 0 ? 1 : 0);
}

main();
