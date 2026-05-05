#!/usr/bin/env node

/**
 * agent-skills-vrc-udon — deprecation shim (v1.9.0+).
 *
 * As of v1.9.0, this entrypoint no longer installs files. It prints a
 * deprecation banner pointing at the canonical install command and exits 0.
 * Full removal (along with the package.json `bin` field, the bin/ directory,
 * and this file) is scheduled for v2.0.0.
 *
 * Rationale and migration: https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/180
 */

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PKG_ROOT = resolve(__dirname, '..');
const pkg = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8'));

const noColor = process.env.NO_COLOR !== undefined;
const bold = (s) => (noColor ? s : `\x1b[1m${s}\x1b[0m`);
const yellow = (s) => (noColor ? s : `\x1b[33m${s}\x1b[0m`);
const cyan = (s) => (noColor ? s : `\x1b[36m${s}\x1b[0m`);
const dim = (s) => (noColor ? s : `\x1b[2m${s}\x1b[0m`);

const CANONICAL = 'npx skills add niaka3dayo/agent-skills-vrc-udon --yes';
const ISSUE_URL = 'https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/180';

console.log('');
console.log(bold('agent-skills-vrc-udon') + ` v${pkg.version}`);
console.log('');
console.log(yellow('  DEPRECATED') + dim(': the npx installer no longer copies files.'));
console.log('');
console.log('  Starting with v1.9.0 this command is a no-op shim. It will be');
console.log('  removed entirely in v2.0.0. Please switch to the canonical');
console.log('  install path:');
console.log('');
console.log('    ' + cyan(CANONICAL));
console.log('');
console.log('  Alternative (Claude Code users):');
console.log('');
console.log('    ' + cyan('claude plugin add niaka3dayo/agent-skills-vrc-udon'));
console.log('');
console.log(dim(`  Background and migration notes: ${ISSUE_URL}`));
console.log('');

process.exit(0);
