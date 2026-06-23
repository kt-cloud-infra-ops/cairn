const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const VALID_ROLES = new Set(['service', 'domain', 'docs', 'wiki', 'support', 'platform']);
const VALID_PULL_POLICIES = new Set(['manual', 'auto', 'on-start', 'scheduled']);
const VALID_DIRTY_POLICIES = new Set(['skip', 'stash', 'fail']);

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--') {
      args._.push(...argv.slice(i + 1));
      break;
    }
    if (!token.startsWith('--')) {
      args._.push(token);
      continue;
    }
    const eq = token.indexOf('=');
    if (eq !== -1) {
      args[token.slice(2, eq)] = token.slice(eq + 1);
      continue;
    }
    const key = token.slice(2);
    if (key.startsWith('no-')) {
      args[key.slice(3)] = false;
      continue;
    }
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      i += 1;
    } else {
      args[key] = true;
    }
  }
  return args;
}

function fail(message, code = 1) {
  console.error(`ERROR: ${message}`);
  process.exit(code);
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function fileExists(file) {
  try {
    return fs.existsSync(file);
  } catch (_) {
    return false;
  }
}

function isDirectory(dir) {
  try {
    return fs.statSync(dir).isDirectory();
  } catch (_) {
    return false;
  }
}

function listDirSafe(dir) {
  try {
    return fs.readdirSync(dir);
  } catch (_) {
    return [];
  }
}

function findUp(startDir, relativeFile) {
  let dir = path.resolve(startDir);
  while (true) {
    const candidate = path.join(dir, relativeFile);
    if (fileExists(candidate)) {
      return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) {
      return null;
    }
    dir = parent;
  }
}

function findWorkspaceRoot(startDir = process.cwd()) {
  return findUp(startDir, path.join('.cairn', 'workspace.yaml'));
}

function workspaceRootFromArgs(args) {
  if (args.workspace) {
    const root = path.resolve(String(args.workspace));
    const workspaceFile = path.join(root, '.cairn', 'workspace.yaml');
    if (!fileExists(workspaceFile)) {
      fail(`workspace file not found: ${workspaceFile}`);
    }
    return root;
  }
  const found = findWorkspaceRoot(process.cwd());
  if (!found) {
    fail('Cairn workspace not found. Run cairn-init first or pass --workspace <dir>.');
  }
  return found;
}

function assertSafeRelativePath(value, label = 'path') {
  if (!value || typeof value !== 'string') {
    fail(`${label} is required`);
  }
  if (path.isAbsolute(value)) {
    fail(`${label} must be workspace-relative: ${value}`);
  }
  const parts = value.split(/[\\/]+/);
  if (parts.includes('..') || parts.includes('')) {
    fail(`${label} must stay inside the workspace: ${value}`);
  }
  if (value.includes('\0')) {
    fail(`${label} contains an invalid null byte`);
  }
}

function resolveWorkspacePath(root, relativePath) {
  assertSafeRelativePath(relativePath);
  const resolved = path.resolve(root, relativePath);
  const rootWithSep = path.resolve(root) + path.sep;
  if (resolved !== path.resolve(root) && !resolved.startsWith(rootWithSep)) {
    fail(`path escapes workspace: ${relativePath}`);
  }
  return resolved;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd || process.cwd(),
    encoding: 'utf8',
    stdio: options.stdio || 'pipe',
  });
  if (result.error) {
    return {
      ok: false,
      status: 127,
      stdout: '',
      stderr: result.error.message,
    };
  }
  return {
    ok: result.status === 0,
    status: result.status,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function git(args, options = {}) {
  return run('git', args, options);
}

function requireGit() {
  const result = git(['--version']);
  if (!result.ok) {
    fail('git command not found');
  }
}

function gitOutput(args, cwd) {
  const result = git(args, { cwd });
  return result.ok ? result.stdout.trim() : '';
}

function isGitRepo(dir) {
  return git(['rev-parse', '--is-inside-work-tree'], { cwd: dir }).ok;
}

function gitTopLevel(dir) {
  return gitOutput(['rev-parse', '--show-toplevel'], dir);
}

function gitRemote(dir) {
  return gitOutput(['remote', 'get-url', 'origin'], dir);
}

function gitCurrentBranch(dir) {
  return gitOutput(['branch', '--show-current'], dir);
}

function gitHead(dir) {
  return gitOutput(['rev-parse', 'HEAD'], dir);
}

function gitIsDirty(dir) {
  return gitOutput(['status', '--porcelain'], dir).length > 0;
}

function gitDirtySummary(dir) {
  return gitOutput(['status', '--short'], dir);
}

function hasSecretInRepoUrl(repo) {
  return /:\/\/[^/@\s]+:[^/@\s]+@/.test(repo)
    || /(?:token|password|passwd|secret)=/i.test(repo);
}

function inferNameFromRepo(repo) {
  const trimmed = repo.replace(/\/+$/, '');
  const last = trimmed.split(/[/:]/).pop() || 'project';
  return last.replace(/\.git$/, '') || 'project';
}

function assertKey(value, label) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value)) {
    fail(`${label} must match ^[A-Za-z0-9][A-Za-z0-9._-]*$: ${value}`);
  }
}

function stripInlineComment(line) {
  let inSingle = false;
  let inDouble = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === "'" && !inDouble) {
      inSingle = !inSingle;
    } else if (ch === '"' && !inSingle && line[i - 1] !== '\\') {
      inDouble = !inDouble;
    } else if (ch === '#' && !inSingle && !inDouble && (i === 0 || /\s/.test(line[i - 1]))) {
      return line.slice(0, i).trimEnd();
    }
  }
  return line;
}

function parseScalar(value) {
  const raw = value.trim();
  if (raw === '') {
    return '';
  }
  if ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'"))) {
    return raw.slice(1, -1);
  }
  if (raw === 'true') {
    return true;
  }
  if (raw === 'false') {
    return false;
  }
  if (/^-?\d+$/.test(raw)) {
    return Number(raw);
  }
  if (raw.startsWith('[') && raw.endsWith(']')) {
    const inner = raw.slice(1, -1).trim();
    if (!inner) {
      return [];
    }
    return inner.split(',').map((part) => parseScalar(part.trim()));
  }
  return raw;
}

function parseKeyValue(str) {
  const index = str.indexOf(':');
  if (index === -1) {
    return null;
  }
  return [str.slice(0, index).trim(), parseScalar(str.slice(index + 1))];
}

function parseSourcesYaml(text) {
  const parsed = {
    schema: '',
    defaults: {},
    sources: [],
  };
  let section = null;
  let current = null;
  let currentNested = null;

  for (const rawLine of text.split(/\r?\n/)) {
    const line = stripInlineComment(rawLine);
    if (!line.trim()) {
      continue;
    }
    const indent = line.length - line.trimStart().length;
    const trimmed = line.trim();

    if (indent === 0) {
      current = null;
      currentNested = null;
      if (trimmed === 'defaults:' || trimmed === 'sources:') {
        section = trimmed.slice(0, -1);
        continue;
      }
      const kv = parseKeyValue(trimmed);
      if (kv && kv[0] === 'schema') {
        parsed.schema = kv[1];
      }
      section = null;
      continue;
    }

    if (section === 'defaults' && indent === 2) {
      const kv = parseKeyValue(trimmed);
      if (kv) {
        parsed.defaults[kv[0]] = kv[1];
      }
      continue;
    }

    if (section !== 'sources') {
      continue;
    }

    if (indent === 2 && trimmed.startsWith('- ')) {
      current = {};
      parsed.sources.push(current);
      currentNested = null;
      const rest = trimmed.slice(2).trim();
      if (rest) {
        const kv = parseKeyValue(rest);
        if (kv) {
          current[kv[0]] = kv[1];
        }
      }
      continue;
    }

    if (!current) {
      continue;
    }

    if (indent === 4) {
      if (trimmed.endsWith(':')) {
        currentNested = trimmed.slice(0, -1);
        current[currentNested] = current[currentNested] || {};
        continue;
      }
      const kv = parseKeyValue(trimmed);
      if (kv) {
        current[kv[0]] = kv[1];
        currentNested = null;
      }
      continue;
    }

    if (indent === 6 && currentNested) {
      const kv = parseKeyValue(trimmed);
      if (kv) {
        current[currentNested][kv[0]] = kv[1];
      }
    }
  }

  return parsed;
}

function quoteYaml(value) {
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }
  if (typeof value === 'number') {
    return String(value);
  }
  return JSON.stringify(String(value));
}

function yamlArray(values) {
  return `[${values.map((value) => quoteYaml(value)).join(', ')}]`;
}

function serializeSourcesYaml(doc) {
  const defaults = {
    root: doc.defaults?.root || 'projects',
    pull_policy: doc.defaults?.pull_policy || 'manual',
    dirty_policy: doc.defaults?.dirty_policy || 'skip',
    clone_depth: doc.defaults?.clone_depth ?? 1,
  };
  const lines = [
    'schema: "cairn.sources/v1"',
    'defaults:',
    `  root: ${quoteYaml(defaults.root)}`,
    `  pull_policy: ${quoteYaml(defaults.pull_policy)}`,
    `  dirty_policy: ${quoteYaml(defaults.dirty_policy)}`,
    `  clone_depth: ${quoteYaml(defaults.clone_depth)}`,
    '',
    'sources:',
  ];

  for (const source of doc.sources || []) {
    lines.push(`  - name: ${quoteYaml(source.name)}`);
    lines.push(`    role: ${quoteYaml(source.role)}`);
    if (source.strategy && source.strategy !== 'clone') {
      lines.push(`    strategy: ${quoteYaml(source.strategy)}`);
    }
    lines.push(`    repo: ${quoteYaml(source.repo)}`);
    lines.push('    ref:');
    lines.push(`      type: ${quoteYaml(source.ref?.type || 'branch')}`);
    lines.push(`      name: ${quoteYaml(source.ref?.name || 'main')}`);
    lines.push(`    path: ${quoteYaml(source.path)}`);
    if (source.profile_service_key) {
      lines.push(`    profile_service_key: ${quoteYaml(source.profile_service_key)}`);
    }
    const pull = source.pull || {};
    if (Object.keys(pull).length > 0) {
      lines.push('    pull:');
      if (pull.policy) {
        lines.push(`      policy: ${quoteYaml(pull.policy)}`);
      }
      if (pull.dirty_policy) {
        lines.push(`      dirty_policy: ${quoteYaml(pull.dirty_policy)}`);
      }
      if (typeof pull.rebase === 'boolean') {
        lines.push(`      rebase: ${quoteYaml(pull.rebase)}`);
      }
      if (typeof pull.prune === 'boolean') {
        lines.push(`      prune: ${quoteYaml(pull.prune)}`);
      }
    }
    if (source.docs && Object.keys(source.docs).length > 0) {
      lines.push('    docs:');
      if (source.docs.project_docs) {
        lines.push(`      project_docs: ${quoteYaml(source.docs.project_docs)}`);
      }
      if (source.docs.wiki_repo) {
        lines.push(`      wiki_repo: ${quoteYaml(source.docs.wiki_repo)}`);
      }
    }
    if (Array.isArray(source.tags) && source.tags.length > 0) {
      lines.push(`    tags: ${yamlArray(source.tags)}`);
    }
    lines.push('');
  }
  return `${lines.join('\n').trimEnd()}\n`;
}

function readSources(root) {
  const file = path.join(root, '.cairn', 'sources.yaml');
  if (!fileExists(file)) {
    return {
      schema: 'cairn.sources/v1',
      defaults: {
        root: 'projects',
        pull_policy: 'manual',
        dirty_policy: 'skip',
        clone_depth: 1,
      },
      sources: [],
    };
  }
  const doc = parseSourcesYaml(fs.readFileSync(file, 'utf8'));
  if (doc.schema !== 'cairn.sources/v1') {
    fail(`unsupported sources schema: ${doc.schema || '(missing)'}`);
  }
  doc.defaults = {
    root: doc.defaults.root || 'projects',
    pull_policy: doc.defaults.pull_policy || 'manual',
    dirty_policy: doc.defaults.dirty_policy || 'skip',
    clone_depth: doc.defaults.clone_depth ?? 1,
  };
  doc.sources = doc.sources || [];
  return doc;
}

function writeSources(root, doc) {
  const file = path.join(root, '.cairn', 'sources.yaml');
  fs.writeFileSync(file, serializeSourcesYaml(doc), 'utf8');
}

function validateSource(source) {
  assertKey(source.name, 'source name');
  if (!VALID_ROLES.has(source.role)) {
    fail(`invalid source role: ${source.role}`);
  }
  if (hasSecretInRepoUrl(source.repo)) {
    fail(`repo URL appears to contain credentials: ${source.name}`);
  }
  assertSafeRelativePath(source.path, 'source path');
  const refType = source.ref?.type;
  if (!['branch', 'tag', 'commit'].includes(refType)) {
    fail(`invalid ref type for ${source.name}: ${refType}`);
  }
  if (!source.ref?.name) {
    fail(`ref name is required for ${source.name}`);
  }
  const policy = source.pull?.policy;
  if (policy && !VALID_PULL_POLICIES.has(policy)) {
    fail(`invalid pull policy for ${source.name}: ${policy}`);
  }
  const dirtyPolicy = source.pull?.dirty_policy;
  if (dirtyPolicy && !VALID_DIRTY_POLICIES.has(dirtyPolicy)) {
    fail(`invalid dirty policy for ${source.name}: ${dirtyPolicy}`);
  }
}

function sourceRefFromArgs(args) {
  const refs = ['branch', 'tag', 'commit'].filter((key) => args[key]);
  if (refs.length > 1) {
    fail('choose only one ref option: --branch, --tag, or --commit');
  }
  if (args.tag) {
    return { type: 'tag', name: String(args.tag) };
  }
  if (args.commit) {
    return { type: 'commit', name: String(args.commit) };
  }
  return { type: 'branch', name: String(args.branch || 'main') };
}

function printPlan(title, rows) {
  console.log(`\n${title}`);
  console.log('-'.repeat(title.length));
  for (const [key, value] of rows) {
    console.log(`${key.padEnd(18)} ${value}`);
  }
}

function ensureNoDuplicateSource(doc, candidate) {
  const existingName = doc.sources.find((source) => source.name === candidate.name);
  if (existingName) {
    fail(`source name already exists: ${candidate.name}`);
  }
  const existingPath = doc.sources.find((source) => source.path === candidate.path);
  if (existingPath) {
    fail(`source path already exists: ${candidate.path}`);
  }
}

function readLock(root) {
  const file = path.join(root, '.cairn', 'state', 'sources.lock.json');
  if (!fileExists(file)) {
    return { schema: 'cairn.sources.lock/v1', sources: {} };
  }
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return { schema: 'cairn.sources.lock/v1', sources: {} };
  }
}

function writeLock(root, lock) {
  const file = path.join(root, '.cairn', 'state', 'sources.lock.json');
  ensureDir(path.dirname(file));
  lock.schema = 'cairn.sources.lock/v1';
  lock.updatedAt = new Date().toISOString();
  lock.sources = lock.sources || {};
  fs.writeFileSync(file, `${JSON.stringify(lock, null, 2)}\n`, 'utf8');
}

function updateLock(root, source, status, details = {}) {
  const lock = readLock(root);
  lock.sources[source.name] = {
    repo: source.repo,
    path: source.path,
    ref: source.ref,
    status,
    commit: details.commit || '',
    message: details.message || '',
    updatedAt: new Date().toISOString(),
  };
  writeLock(root, lock);
}

function remoteMatches(existing, expected) {
  return existing === expected || existing.replace(/\.git$/, '') === expected.replace(/\.git$/, '');
}

function cloneSource(root, source, defaults = {}) {
  const target = resolveWorkspacePath(root, source.path);
  ensureDir(path.dirname(target));
  const depth = Number(defaults.clone_depth ?? 1);
  const ref = source.ref || { type: 'branch', name: 'main' };
  const args = ['clone'];
  if (depth > 0 && ref.type !== 'commit') {
    args.push('--depth', String(depth));
  }
  if (ref.type !== 'commit') {
    args.push('--branch', ref.name);
  }
  args.push(source.repo, target);
  const result = git(args, { cwd: root, stdio: 'inherit' });
  if (!result.ok) {
    return { ok: false, message: `git clone failed with status ${result.status}` };
  }
  if (ref.type === 'commit') {
    const checkout = git(['checkout', ref.name], { cwd: target, stdio: 'inherit' });
    if (!checkout.ok) {
      return { ok: false, message: `git checkout ${ref.name} failed` };
    }
  }
  return { ok: true, commit: gitHead(target) };
}

function checkExistingPath(root, source) {
  const target = resolveWorkspacePath(root, source.path);
  if (!fileExists(target)) {
    return { exists: false, target };
  }
  if (!isDirectory(target)) {
    return { exists: true, target, ok: false, message: 'target exists and is not a directory' };
  }
  if (!isGitRepo(target)) {
    return { exists: true, target, ok: false, message: 'target exists and is not a git repository' };
  }
  const remote = gitRemote(target);
  if (remote && !remoteMatches(remote, source.repo)) {
    return { exists: true, target, ok: false, message: `remote mismatch: ${remote}` };
  }
  if (gitIsDirty(target)) {
    return {
      exists: true,
      target,
      ok: false,
      dirty: true,
      message: `dirty worktree:\n${gitDirtySummary(target)}`,
    };
  }
  return { exists: true, target, ok: true, remote };
}

function remoteCheck(repo, ref, skip) {
  if (skip) {
    return { ok: true, skipped: true };
  }
  const result = git(['ls-remote', '--exit-code', repo, ref.type === 'branch' ? `refs/heads/${ref.name}` : ref.type === 'tag' ? `refs/tags/${ref.name}` : ref.name]);
  if (result.ok) {
    return { ok: true };
  }
  const fallback = git(['ls-remote', '--exit-code', repo]);
  if (fallback.ok && ref.type === 'commit') {
    return { ok: true };
  }
  return {
    ok: false,
    message: (result.stderr || fallback.stderr || 'git ls-remote failed').trim(),
  };
}

function copyDir(src, dest) {
  ensureDir(dest);
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(from, to);
    } else if (entry.isFile()) {
      ensureDir(path.dirname(to));
      fs.copyFileSync(from, to);
    }
  }
}

module.exports = {
  VALID_DIRTY_POLICIES,
  VALID_PULL_POLICIES,
  VALID_ROLES,
  assertKey,
  assertSafeRelativePath,
  checkExistingPath,
  cloneSource,
  copyDir,
  ensureDir,
  ensureNoDuplicateSource,
  fail,
  fileExists,
  findWorkspaceRoot,
  git,
  gitCurrentBranch,
  gitDirtySummary,
  gitHead,
  gitIsDirty,
  gitOutput,
  gitRemote,
  gitTopLevel,
  hasSecretInRepoUrl,
  inferNameFromRepo,
  isDirectory,
  isGitRepo,
  listDirSafe,
  parseArgs,
  printPlan,
  readSources,
  remoteCheck,
  remoteMatches,
  requireGit,
  resolveWorkspacePath,
  serializeSourcesYaml,
  sourceRefFromArgs,
  updateLock,
  validateSource,
  workspaceRootFromArgs,
  writeLock,
  writeSources,
};
