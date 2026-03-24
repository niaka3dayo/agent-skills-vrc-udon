# agent-skills-vrc-udon Development Guide

This repository is an **npm package** that distributes AI agent skills for VRChat UdonSharp development.
It is NOT a VRChat/Unity project. The codebase consists of markdown knowledge files, a Node.js installer, and CI workflows.

## Repository Structure

```
skills/                          # Skill content (distributed to users)
  unity-vrc-udon-sharp/          # UdonSharp constraints, networking, templates
  unity-vrc-world-sdk-3/         # World SDK components, optimization
.claude/
  rules/
    doc-sync.md                  # Documentation sync rule (repo maintenance)
  hooks/
    doc-sync-reminder.sh         # PostToolUse hook: reminds about doc updates
  skills/
    unity-vrc-skills-renovator/  # Meta-skill for maintaining skills (dev only, not distributed)
templates/                       # AI tool config templates (distributed to users)
  CLAUDE.md                      # Claude Code project instructions
  AGENTS.md                      # Codex CLI / generic agent instructions
  GEMINI.md                      # Gemini CLI instructions
bin/
  install.mjs                    # npx installer script
.github/
  workflows/                     # CI (lint, pack test, publish)
  ISSUE_TEMPLATE/                # Bug report, knowledge request
package.json                     # npm package config
```

## Development Workflow

```
feature/* ──PR──> dev ──release PR──> main ──tag──> npm publish
```

- Default branch: **`dev`** (integration)
- Release branch: **`main`** (triggers npm publish via GitHub Release)
- **All PRs must target `dev`** (never `main` directly)
- `main` is updated only via release PRs from `dev`

### Branch Protection

Both `dev` and `main` are protected:
- No direct push (`enforce_admins: true`, applies to admin too)
- CI must pass: Symlink Integrity, Hook Scripts, npm Pack Test
- PR required for all changes

### Branch Naming

`feature/*`, `fix/*`, `docs/*`, `refactor/*`, `security/*`, `chore/*`

## Key Files

| File | Purpose |
|------|---------|
| `bin/install.mjs` | npx installer (copies skills + templates to user project) |
| `package.json` | npm metadata, `files` array controls what gets published |
| `skills/*/SKILL.md` | Skill definitions with YAML frontmatter |
| `skills/*/rules/*.md` | Constraint rules for AI code generation |
| `templates/*.md` | AI tool config files distributed to end users |

## Testing

```bash
# Verify npm pack includes correct files
npm pack --dry-run

# Test installer
node bin/install.mjs --list
node bin/install.mjs --help
```

## CI Checks

| Check | What it verifies |
|-------|-----------------|
| Symlink Integrity | No symlinks in repo (breaks npm pack) |
| Hook Scripts | validate-udonsharp.sh is executable and valid bash |
| EditorConfig | File formatting matches .editorconfig rules (indent_size check disabled; see below) |
| npm Pack Test | Package includes all required files, installer works |
| Markdown Links | No broken links in documentation |

### EditorConfig Notes

- **IndentSize check is intentionally disabled** in `.editorconfig-checker.json` (`Disable.IndentSize: true`).
  C# uses 4-space indentation while JS/MJS uses 2-space; continuation lines and alignment patterns
  in C# templates cause false positives. The `indent_style` check (tabs vs spaces) remains active.
- **Editor setup**: Install an [EditorConfig plugin](https://editorconfig.org/#pre-installed) for your IDE
  to automatically apply formatting rules from `.editorconfig`.
- **Per-line exceptions**: Use `// editorconfig-checker-disable-line` for intentional deviations.

## Release Guide

### Overview

```
dev ──release PR──> main ──Release Drafter draft──> publish ──> npm
```

Version numbers and changelogs are **fully automated** by Release Drafter.
Do NOT manually edit `package.json` version — `publish.yml` sets it from the release tag.

### Step-by-step

1. **Create a release PR from `dev` to `main`**
   ```bash
   gh pr create --base main --head dev \
     --title "Release vX.Y.Z" \
     --body "Merge dev into main for release"
   ```
   - Title should include the expected version (check the draft release for the resolved version)
   - Wait for CI to pass and CodeRabbit approval

2. **Merge the release PR**
   - Merge (do NOT squash — preserve commit history)
   - This triggers Release Drafter to update the draft release on `main`

3. **Publish the GitHub Release draft**
   ```bash
   # List draft releases
   gh release list --exclude-drafts=false

   # Review and publish the draft (edit title/notes if needed)
   gh release edit vX.Y.Z --draft=false
   ```
   - The `published` event triggers `publish.yml`
   - `publish.yml` reads the tag, sets `npm version`, and runs `npm publish --provenance`
   - Uses the `npm-publish` environment (requires `NPM_TOKEN` secret)

### Version resolution (automatic)

Release Drafter resolves the version bump from PR labels:

| Label | Bump |
|-------|------|
| `release: breaking` | major |
| `release: feature` | minor |
| `release: fix` | patch |
| `release: docs` | patch |
| `release: maintenance` | patch |

If no label matches, defaults to **patch**.

### What NOT to do

- Do NOT manually bump `package.json` version (publish.yml handles it)
- Do NOT create tags manually (Release Drafter creates them)
- Do NOT push directly to `main` (branch protection blocks it)
- Do NOT merge feature branches directly to `main` (always go through `dev`)

## Editing Skills

When modifying skill content in `skills/`:
- Always verify against [official VRChat documentation](https://creators.vrchat.com/)
- Update SDK version tables if adding new API coverage
- Run the validate-udonsharp hook against any `.cs` code examples
- Keep `templates/` in sync if skills table or rules paths change

### Documentation Sync

A PostToolUse hook (`.claude/hooks/doc-sync-reminder.sh`) automatically reminds you to update documentation when editing files under `skills/` or `templates/`. See `.claude/rules/doc-sync.md` for the full sync checklist and trigger conditions.
