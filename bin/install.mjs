#!/usr/bin/env node

/**
 * agent-skills-vrc-udon installer
 *
 * Usage:
 *   npx agent-skills-vrc-udon              Install skills to current directory
 *   npx agent-skills-vrc-udon --symlink    Install with symlinks for AI tools
 *   npx agent-skills-vrc-udon --list       List files that will be installed
 *   npx agent-skills-vrc-udon --uninstall  Remove installed files
 *   npx agent-skills-vrc-udon --help       Show help
 *   npx agent-skills-vrc-udon --version    Show version
 */

import { existsSync, cpSync, mkdirSync, symlinkSync, readFileSync, writeFileSync, readdirSync, rmSync, statSync } from 'node:fs';
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
const red = (s) => noColor ? s : `\x1b[31m${s}\x1b[0m`;

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
  --uninstall  Remove all files installed by this package
  --help       Show this help message
  --version    Show version

${bold('Examples:')}
  ${dim('# Install to current project')}
  npx agent-skills-vrc-udon

  ${dim('# Install with AI tool symlinks')}
  npx agent-skills-vrc-udon --symlink

  ${dim('# Force overwrite existing files')}
  npx agent-skills-vrc-udon --force

  ${dim('# Remove installed files')}
  npx agent-skills-vrc-udon --uninstall
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
const uninstall = args.includes('--uninstall');

const AGENT_DOCS_SRC = join(PKG_ROOT, 'skills');
const DEST_DIR = join(TARGET, '.agent-skills');
const AGENT_DOCS_DEST = join(DEST_DIR, 'skills');
const VERSION_FILE = join(DEST_DIR, '.version');

const TEMPLATES_DIR = join(PKG_ROOT, 'templates');
const CONFIG_FILES = ['CLAUDE.md', 'AGENTS.md', 'GEMINI.md'];
const AI_TOOL_DIRS = ['.claude', '.agents', '.codex', '.gemini'];

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

/** Check if a directory is empty */
function isDirEmpty(dir) {
  if (!existsSync(dir)) return true;
  const entries = readdirSync(dir);
  return entries.length === 0;
}

/** Read installed version from .agent-skills/.version, or null if not present */
function readInstalledVersion() {
  if (!existsSync(VERSION_FILE)) return null;
  try {
    return readFileSync(VERSION_FILE, 'utf8').trim();
  } catch {
    return null;
  }
}

/** Write current package version to .agent-skills/.version */
function writeVersionFile() {
  writeFileSync(VERSION_FILE, pkg.version, 'utf8');
}

// --uninstall: remove all installed files
if (uninstall) {
  console.log('');
  console.log(bold('agent-skills-vrc-udon') + ` v${pkg.version}`);
  console.log(dim('Uninstalling VRChat UdonSharp skills...\n'));

  if (!existsSync(DEST_DIR)) {
    console.log(yellow('  Nothing to uninstall.') + ` ${dim('.agent-skills/ does not exist.')}`);
    console.log('');
    process.exit(0);
  }

  let removed = 0;

  // Remove skills/ subdirectory
  if (existsSync(AGENT_DOCS_DEST)) {
    const count = countFiles(AGENT_DOCS_DEST);
    rmSync(AGENT_DOCS_DEST, { recursive: true, force: true });
    removed += count;
    console.log(red('  REMOVE') + ` .agent-skills/skills/ ${dim(`(${count} files)`)}`);
  }

  // Remove config reference files
  for (const cf of CONFIG_FILES) {
    const dest = join(DEST_DIR, cf);
    if (existsSync(dest)) {
      rmSync(dest, { force: true });
      removed++;
      console.log(red('  REMOVE') + ` .agent-skills/${cf}`);
    }
  }

  // Remove version file
  if (existsSync(VERSION_FILE)) {
    rmSync(VERSION_FILE, { force: true });
    console.log(red('  REMOVE') + ` .agent-skills/.version`);
  }

  // Remove .agent-skills/ itself if now empty
  if (isDirEmpty(DEST_DIR)) {
    rmSync(DEST_DIR, { recursive: true, force: true });
    console.log(red('  REMOVE') + ` .agent-skills/ ${dim('(directory empty, removed)')}`);
  } else {
    console.log(yellow('  KEEP') + ` .agent-skills/ ${dim('(directory not empty, keeping)')}`);
  }

  console.log('');
  console.log(bold('Done!'));
  console.log(`  ${red(`${removed} files removed`)}`);
  console.log('');
  process.exit(0);
}

// --list: dry run
if (listOnly) {
  console.log(bold('\nFiles to install:\n'));

  const files = listFiles(AGENT_DOCS_SRC, PKG_ROOT);
  for (const f of files) {
    console.log(`  ${dim('.agent-skills/')}${f}`);
  }

  console.log('');
  for (const cf of CONFIG_FILES) {
    const src = join(TEMPLATES_DIR, cf);
    if (!existsSync(src)) continue;
    console.log(`  ${dim('.agent-skills/')}${cf} ${dim('(reference)')}`);
  }

  if (useSymlinks) {
    console.log('');
    for (const dir of AI_TOOL_DIRS) {
      console.log(`  ${dir}/skills/ ${dim('-> .agent-skills/skills/')}`);
      console.log(`  ${dir}/rules/  ${dim('-> .agent-skills/skills/unity-vrc-udon-sharp/rules/')}`);
    }
  }

  const totalFiles = files.length + CONFIG_FILES.length;
  console.log(`\n  ${bold(`${totalFiles} files`)} will be installed.\n`);
  process.exit(0);
}

// Main install
console.log('');
console.log(bold('agent-skills-vrc-udon') + ` v${pkg.version}`);

// Version detection: show upgrade/already-up-to-date message
const installedVersion = readInstalledVersion();
if (installedVersion !== null) {
  if (installedVersion === pkg.version) {
    console.log(dim(`Already up to date (v${pkg.version}).`));
  } else {
    console.log(cyan(`Upgrading from v${installedVersion} to v${pkg.version}...`));
  }
} else {
  console.log(dim('Installing VRChat UdonSharp skills for AI agents...'));
}
console.log('');

let copied = 0;
let skipped = 0;

// 1. Copy skills/
if (existsSync(AGENT_DOCS_DEST) && !force) {
  console.log(yellow('  SKIP') + ` .agent-skills/skills/ ${dim('(already exists, use --force to overwrite)')}`);
  skipped += countFiles(AGENT_DOCS_SRC);
} else {
  mkdirSync(AGENT_DOCS_DEST, { recursive: true });
  cpSync(AGENT_DOCS_SRC, AGENT_DOCS_DEST, { recursive: true, force: true });
  const count = countFiles(AGENT_DOCS_SRC);
  copied += count;
  console.log(green('  COPY') + ` skills/ -> .agent-skills/skills/ ${dim(`(${count} files)`)}`);
}

// 2. Copy config reference files
for (const cf of CONFIG_FILES) {
  const src = join(TEMPLATES_DIR, cf);
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

// 3. Write version file
writeVersionFile();

// 4. Create symlinks if requested
if (useSymlinks) {
  console.log('');

  const skillsTarget = join(DEST_DIR, 'skills');
  const rulesTarget = join(DEST_DIR, 'skills', 'unity-vrc-udon-sharp', 'rules');

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
console.log(`     ${dim('PostToolUse: .agent-skills/skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh')}`);
console.log('');
console.log(`  ${dim('Documentation: https://github.com/niaka3dayo/agent-skills-vrc-udon')}`);
console.log('');
