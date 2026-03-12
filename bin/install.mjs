#!/usr/bin/env node

/**
 * agent-skills-vrc-udon installer
 *
 * Usage:
 *   npx agent-skills-vrc-udon              Install skills to current directory
 *   npx agent-skills-vrc-udon --symlink    Install with symlinks for AI tools
 *   npx agent-skills-vrc-udon --list       List files that will be installed
 *   npx agent-skills-vrc-udon --help       Show help
 *   npx agent-skills-vrc-udon --version    Show version
 */

import { existsSync, cpSync, mkdirSync, symlinkSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve, dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PKG_ROOT = resolve(__dirname, '..');
const TARGET = process.cwd();

const noColor = process.env.NO_COLOR !== undefined;
const bold = (s) => noColor ? s : `\x1b[1m${s}\x1b[0m`;
const green = (s) => noColor ? s : `\x1b[32m${s}\x1b[0m`;
const yellow = (s) => noColor ? s : `\x1b[33m${s}\x1b[0m`;
const cyan = (s) => noColor ? s : `\x1b[36m${s}\x1b[0m`;
const dim = (s) => noColor ? s : `\x1b[2m${s}\x1b[0m`;

const pkg = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8'));

const HELP = `
${bold('agent-skills-vrc-udon')} v${pkg.version}

  AI Agent Skills for VRChat UdonSharp development.
  Installs skills, rules, and validation hooks for AI coding agents.

${bold('Usage:')}
  npx agent-skills-vrc-udon [options]

${bold('Options:')}
  --symlink    Create symlinks for AI tool directories (.claude/, .agents/, etc.)
  --force      Overwrite existing files
  --list       List files that will be installed (dry run)
  --help       Show this help message
  --version    Show version

${bold('Examples:')}
  ${dim('# Install to current project')}
  npx agent-skills-vrc-udon

  ${dim('# Install with AI tool symlinks')}
  npx agent-skills-vrc-udon --symlink

  ${dim('# Force overwrite existing files')}
  npx agent-skills-vrc-udon --force
`;

const args = process.argv.slice(2);

if (args.includes('--help') || args.includes('-h')) {
  console.log(HELP);
  process.exit(0);
}

if (args.includes('--version') || args.includes('-v')) {
  console.log(pkg.version);
  process.exit(0);
}

const useSymlinks = args.includes('--symlink');
const force = args.includes('--force');
const listOnly = args.includes('--list');

/** Count files recursively */
function countFiles(dir) {
  let count = 0;
  if (!existsSync(dir)) return count;
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isDirectory()) {
      count += countFiles(join(dir, entry.name));
    } else {
      count++;
    }
  }
  return count;
}

/** List files recursively */
function listFiles(dir, base) {
  const files = [];
  if (!existsSync(dir)) return files;
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFiles(fullPath, base));
    } else {
      files.push(relative(base, fullPath));
    }
  }
  return files;
}

const AGENT_DOCS_SRC = join(PKG_ROOT, 'agent-docs');
const DEST_DIR = join(TARGET, '.agent-skills');
const AGENT_DOCS_DEST = join(DEST_DIR, 'agent-docs');

const CONFIG_FILES = ['CLAUDE.md', 'AGENTS.md', 'GEMINI.md'];
const AI_TOOL_DIRS = ['.claude', '.agents', '.codex', '.gemini'];

// --list: dry run
if (listOnly) {
  console.log(bold('\nFiles to install:\n'));

  const files = listFiles(AGENT_DOCS_SRC, PKG_ROOT);
  for (const f of files) {
    console.log(`  ${dim('.agent-skills/')}${f}`);
  }

  console.log('');
  for (const cf of CONFIG_FILES) {
    console.log(`  ${dim('.agent-skills/')}${cf} ${dim('(reference)')}`);
  }

  if (useSymlinks) {
    console.log('');
    for (const dir of AI_TOOL_DIRS) {
      console.log(`  ${dir}/skills/ ${dim('-> .agent-skills/agent-docs/skills/')}`);
      console.log(`  ${dir}/rules/  ${dim('-> .agent-skills/agent-docs/skills/unity-vrc-udon-sharp/rules/')}`);
    }
  }

  const totalFiles = files.length + CONFIG_FILES.length;
  console.log(`\n  ${bold(`${totalFiles} files`)} will be installed.\n`);
  process.exit(0);
}

// Main install
console.log('');
console.log(bold('agent-skills-vrc-udon') + ` v${pkg.version}`);
console.log(dim('Installing VRChat UdonSharp skills for AI agents...\n'));

let copied = 0;
let skipped = 0;

// 1. Copy agent-docs/
if (existsSync(AGENT_DOCS_DEST) && !force) {
  console.log(yellow('  SKIP') + ` .agent-skills/agent-docs/ ${dim('(already exists, use --force to overwrite)')}`);
  skipped += countFiles(AGENT_DOCS_SRC);
} else {
  mkdirSync(AGENT_DOCS_DEST, { recursive: true });
  cpSync(AGENT_DOCS_SRC, AGENT_DOCS_DEST, { recursive: true, force: true });
  const count = countFiles(AGENT_DOCS_SRC);
  copied += count;
  console.log(green('  COPY') + ` agent-docs/ -> .agent-skills/agent-docs/ ${dim(`(${count} files)`)}`);
}

// 2. Copy config reference files
for (const cf of CONFIG_FILES) {
  const src = join(PKG_ROOT, cf);
  const dest = join(DEST_DIR, cf);

  if (!existsSync(src)) continue;

  if (existsSync(dest) && !force) {
    console.log(yellow('  SKIP') + ` .agent-skills/${cf} ${dim('(already exists)')}`);
    skipped++;
  } else {
    mkdirSync(dirname(dest), { recursive: true });
    cpSync(src, dest);
    copied++;
    console.log(green('  COPY') + ` ${cf} -> .agent-skills/${cf} ${dim('(reference)')}`);
  }
}

// 3. Create symlinks if requested
if (useSymlinks) {
  console.log('');

  const skillsTarget = join(DEST_DIR, 'agent-docs', 'skills');
  const rulesTarget = join(DEST_DIR, 'agent-docs', 'skills', 'unity-vrc-udon-sharp', 'rules');

  for (const dir of AI_TOOL_DIRS) {
    const toolDir = join(TARGET, dir);
    const skillsLink = join(toolDir, 'skills');
    const rulesLink = join(toolDir, 'rules');

    mkdirSync(toolDir, { recursive: true });

    // skills symlink
    if (existsSync(skillsLink) && !force) {
      console.log(yellow('  SKIP') + ` ${dir}/skills/ ${dim('(already exists)')}`);
    } else {
      const relTarget = relative(toolDir, skillsTarget);
      try {
        symlinkSync(relTarget, skillsLink);
        console.log(green('  LINK') + ` ${dir}/skills/ -> ${dim(relTarget)}`);
      } catch {
        console.log(yellow('  SKIP') + ` ${dir}/skills/ ${dim('(symlink creation failed)')}`);
      }
    }

    // rules symlink
    if (existsSync(rulesLink) && !force) {
      console.log(yellow('  SKIP') + ` ${dir}/rules/ ${dim('(already exists)')}`);
    } else {
      const relTarget = relative(toolDir, rulesTarget);
      try {
        symlinkSync(relTarget, rulesLink);
        console.log(green('  LINK') + ` ${dir}/rules/ -> ${dim(relTarget)}`);
      } catch {
        console.log(yellow('  SKIP') + ` ${dir}/rules/ ${dim('(symlink creation failed)')}`);
      }
    }
  }
}

// Summary
console.log('');
console.log(bold('Done!'));
console.log(`  ${green(`${copied} copied`)}, ${skipped > 0 ? yellow(`${skipped} skipped`) : `${skipped} skipped`}`);
console.log('');

// Next steps
console.log(bold('Next steps:'));
console.log('');
console.log(`  ${cyan('1.')} AI tool config files are in ${bold('.agent-skills/')} as reference.`);
console.log(`     Copy relevant sections to your project's CLAUDE.md / AGENTS.md / GEMINI.md.`);
console.log('');

if (!useSymlinks) {
  console.log(`  ${cyan('2.')} To auto-link skills to AI tool directories, run:`);
  console.log(`     ${dim('npx agent-skills-vrc-udon --symlink')}`);
  console.log('');
}

console.log(`  ${cyan(useSymlinks ? '2.' : '3.')} For validation hooks, add to your AI tool settings:`);
console.log(`     ${dim('PostToolUse: .agent-skills/agent-docs/skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh')}`);
console.log('');
console.log(`  ${dim('Documentation: https://github.com/niaka3dayo/agent-skills-vrc-udon')}`);
console.log('');
