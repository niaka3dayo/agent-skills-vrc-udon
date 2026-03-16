# agent-skills-vrc-udon Development Guide

This repository is an **npm package** that distributes AI agent skills for VRChat UdonSharp development.
It is NOT a VRChat/Unity project. The codebase consists of markdown knowledge files, a Node.js installer, and CI workflows.

## Repository Structure

```
skills/                          # Skill content (distributed to users)
  unity-vrc-udon-sharp/          # UdonSharp constraints, networking, templates
  unity-vrc-world-sdk-3/         # World SDK components, optimization
.claude/
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
| npm Pack Test | Package includes all required files, installer works |
| Markdown Links | No broken links in documentation |

## Publishing

1. Merge dev -> main via PR
2. Create GitHub Release with `v*` tag
3. `publish.yml` auto-publishes to npm with provenance

## Editing Skills

When modifying skill content in `skills/`:
- Always verify against [official VRChat documentation](https://creators.vrchat.com/)
- Update SDK version tables if adding new API coverage
- Run the validate-udonsharp hook against any `.cs` code examples
- Keep `templates/` in sync if skills table or rules paths change
