import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, '..');
const INSTALLER = join(REPO_ROOT, 'bin/install.mjs');
const PKG_VERSION = JSON.parse(readFileSync(join(REPO_ROOT, 'package.json'), 'utf8')).version;

/** A file that exists in the source skills/ tree; used as a sentinel to detect overwrite. */
const SENTINEL_PATH = join('skills', 'unity-vrc-udon-sharp', 'SKILL.md');
const STALE_MARKER = '__INSTALLER_TEST_STALE__\n';

function setupTempProject(t) {
  const dir = mkdtempSync(join(tmpdir(), 'agent-skills-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function runInstaller(cwd, args = []) {
  return execFileSync('node', [INSTALLER, ...args], {
    cwd,
    env: { ...process.env, NO_COLOR: '1' },
    encoding: 'utf8',
  });
}

test('fresh install: copies skills and writes current package version', (t) => {
  const dir = setupTempProject(t);

  runInstaller(dir);

  assert.ok(
    existsSync(join(dir, '.agent-skills', 'skills', 'unity-vrc-udon-sharp')),
    'skills/ should be copied on fresh install',
  );
  assert.equal(
    readFileSync(join(dir, '.agent-skills', '.version'), 'utf8').trim(),
    PKG_VERSION,
    '.version should match current package version',
  );
});

test('same-version re-run without --force: preserves existing files (current SKIP behavior)', (t) => {
  const dir = setupTempProject(t);

  runInstaller(dir);
  const sentinel = join(dir, '.agent-skills', SENTINEL_PATH);
  writeFileSync(sentinel, STALE_MARKER, 'utf8');

  // .version already equals PKG_VERSION → not an upgrade → SKIP path is correct here
  runInstaller(dir);

  assert.equal(
    readFileSync(sentinel, 'utf8'),
    STALE_MARKER,
    'same-version re-run should not overwrite (use --force for that)',
  );
});

test('upgrade re-run without --force: overwrites stale skills (Issue #164)', (t) => {
  const dir = setupTempProject(t);

  runInstaller(dir);
  // Simulate "user installed an older version" by downgrading .version
  // and corrupting a sentinel file as if it were stale content.
  writeFileSync(join(dir, '.agent-skills', '.version'), '0.0.0', 'utf8');
  const sentinel = join(dir, '.agent-skills', SENTINEL_PATH);
  writeFileSync(sentinel, STALE_MARKER, 'utf8');

  // Re-run without --force; installer should detect the version mismatch
  // and overwrite stale skills/ content.
  runInstaller(dir);

  assert.notEqual(
    readFileSync(sentinel, 'utf8'),
    STALE_MARKER,
    'Issue #164: skills/ was SKIPped during upgrade; content stayed stale',
  );
  assert.equal(
    readFileSync(join(dir, '.agent-skills', '.version'), 'utf8').trim(),
    PKG_VERSION,
    '.version should be updated to current package version after upgrade',
  );
});

test('upgrade re-run without --force: overwrites stale config reference files (Issue #164)', (t) => {
  const dir = setupTempProject(t);

  runInstaller(dir);
  const claudeMd = join(dir, '.agent-skills', 'CLAUDE.md');
  writeFileSync(claudeMd, STALE_MARKER, 'utf8');
  writeFileSync(join(dir, '.agent-skills', '.version'), '0.0.0', 'utf8');

  runInstaller(dir);

  assert.notEqual(
    readFileSync(claudeMd, 'utf8'),
    STALE_MARKER,
    'Issue #164: config files were SKIPped during upgrade; content stayed stale',
  );
});

test('--force overwrites regardless of version state', (t) => {
  const dir = setupTempProject(t);

  runInstaller(dir);
  const sentinel = join(dir, '.agent-skills', SENTINEL_PATH);
  writeFileSync(sentinel, STALE_MARKER, 'utf8');

  // .version still equals PKG_VERSION (no upgrade), but --force overrides
  runInstaller(dir, ['--force']);

  assert.notEqual(
    readFileSync(sentinel, 'utf8'),
    STALE_MARKER,
    '--force must always overwrite, even on same-version re-run',
  );
});
