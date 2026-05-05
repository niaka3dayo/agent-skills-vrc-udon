import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, '..');
const INSTALLER = join(REPO_ROOT, 'bin/install.mjs');
const PKG_VERSION = JSON.parse(readFileSync(join(REPO_ROOT, 'package.json'), 'utf8')).version;

const CANONICAL_CMD = 'npx skills add niaka3dayo/agent-skills-vrc-udon';
const ISSUE_URL = 'https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/180';

function setupTempProject(t) {
  const dir = mkdtempSync(join(tmpdir(), 'agent-skills-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function runShim(cwd, args = []) {
  return execFileSync('node', [INSTALLER, ...args], {
    cwd,
    env: { ...process.env, NO_COLOR: '1' },
    encoding: 'utf8',
  });
}

test('no-args: prints deprecation banner, exits 0, writes nothing', (t) => {
  const dir = setupTempProject(t);

  const out = runShim(dir);

  assert.ok(out.includes(CANONICAL_CMD),
    'banner must include the canonical skills CLI command');
  assert.ok(out.includes(ISSUE_URL),
    'banner must include the link to Issue #180');
  assert.ok(out.includes(PKG_VERSION),
    `banner must include the current package version (${PKG_VERSION})`);
  assert.equal(existsSync(join(dir, '.agent-skills')), false,
    'shim must NOT create .agent-skills/ on the user filesystem');
});

test('legacy flags are no-ops: each prints the same banner and exits 0', (t) => {
  const dir = setupTempProject(t);

  const flags = [
    ['--help'], ['-h'],
    ['--version'], ['-v'],
    ['--list'],
    ['--symlink'],
    ['--force'],
    ['--uninstall'],
    ['--unknown-flag'],
    ['--symlink', '--force'],
  ];

  for (const argv of flags) {
    const out = runShim(dir, argv);
    assert.ok(out.includes(CANONICAL_CMD),
      `flag ${JSON.stringify(argv)} should still print the canonical command`);
    assert.equal(existsSync(join(dir, '.agent-skills')), false,
      `flag ${JSON.stringify(argv)} must not create .agent-skills/`);
  }
});

test('non-zero exit is never used (every invocation returns 0)', (t) => {
  const dir = setupTempProject(t);

  // execFileSync throws if exit code != 0; the absence of a throw is the assertion.
  runShim(dir);
  runShim(dir, ['--uninstall']);
  runShim(dir, ['--definitely-not-a-flag']);
});
