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
dev ──version-bump PR──> dev ──release PR──> main ──Release Drafter draft──> publish ──> npm
```

Changelogs are automated by Release Drafter. **Version numbers must be bumped manually on `dev` before opening the release PR** (see Step 1 below). `publish.yml` does run `npm version "$VERSION" --no-git-tag-version` in the CI runner as a safety net, but those edits are not committed back, so the git tree's source-of-truth must be kept current by hand.

### Step-by-step

1. **Bump version fields on `dev`**
   - Decide the target version vX.Y.Z (consult labels on merged PRs since the last release — see "Version resolution" below).
   - Branch off `dev`, run the bump, open a PR back to `dev`:

     ```bash
     set -e
     git checkout dev && git pull
     git checkout -b chore/release-vX.Y.Z

     # OLD: read from local package.json. If your local is stale, prefer:
     #   OLD=$(npm view agent-skills-vrc-udon version)
     OLD=$(node -p "require('./package.json').version")
     NEW=X.Y.Z

     # 5 fields must move together — Version Sync CI verifies parity.
     # The SKILL.md sed is anchored to the 4-space-indented frontmatter line
     # so body-text occurrences (e.g. SDK version mentions) are not rewritten.
     sed -i "s/\"version\": \"$OLD\"/\"version\": \"$NEW\"/" package.json .claude-plugin/marketplace.json
     sed -i "s/^    version: \"$OLD\"$/    version: \"$NEW\"/" \
       skills/unity-vrc-udon-sharp/SKILL.md \
       skills/unity-vrc-world-sdk-3/SKILL.md \
       .claude/skills/unity-vrc-skills-renovator/SKILL.md

     # Sanity check before commit — only the 5 expected fields should diff.
     git diff --stat

     git commit -am "chore(version): bump to vX.Y.Z"
     git push -u origin chore/release-vX.Y.Z
     gh pr create --base dev --label "release: maintenance" \
       --title "chore(version): bump to vX.Y.Z" \
       --body "Pre-release version bump for Step 2 of the release flow."
     ```

   - Wait for **all** CI jobs green — specifically Version Sync, which verifies all 5 fields agree on `vX.Y.Z`. (Branch protection currently enforces only `Symlink Integrity / Hook Scripts / npm Pack Test` as required contexts; do not merge if Version Sync is red even though GitHub allows it.) Merge the bump PR into `dev` (squash is fine here — single-purpose commit). CodeRabbit review is optional on this PR — it's mechanical and Version Sync is the substantive check.

2. **Create a release PR from `dev` to `main`**

   ```bash
   gh pr create --base main --head dev \
     --title "Release vX.Y.Z" \
     --body "Merge dev into main for release"
   ```

   - Title must include the version that matches `package.json#version` on `dev` after Step 1.
   - Wait for CI to pass. CodeRabbit approval is **not required for release PRs** (per repo convention — release PRs are mechanical merges of already-reviewed commits).

3. **Merge the release PR**
   - Merge (do NOT squash — preserve commit history so Release Drafter sees each underlying PR commit).
   - This triggers Release Drafter to update the draft release on `main`.

4. **Publish the GitHub Release draft**

   ```bash
   # List draft releases
   gh release list --exclude-drafts=false

   # Always rewrite the auto-generated notes before publishing:
   #   - Remove the "Release vX.Y.Z (#N)" self-reference line
   #   - Replace bare PR titles with user-facing prose
   #   - Add a reporter acknowledgement section if any bundled PR closed an
   #     externally-reported Issue. Mirror the reporter's language for the
   #     release-notes acknowledgement (Japanese reporter → Japanese; English
   #     reporter → English). Issue/PR titles and bodies remain English-first
   #     per repo convention; the reporter-language rule applies only to
   #     user-facing release notes.
   gh release edit vX.Y.Z --notes "$(cat <<'NOTES'
   ## What's New in vX.Y.Z
   ...
   NOTES
   )"

   # Publish (this triggers publish.yml → npm publish)
   gh release edit vX.Y.Z --draft=false
   ```

   - The `published` event triggers `publish.yml`.
   - `publish.yml` reads the tag, runs `npm version "$VERSION" --allow-same-version` (no-op if Step 1 was done correctly), syncs to SKILL.md / marketplace.json again as a safety net, and runs `npm publish --provenance`.
   - Uses the `npm-publish` environment (requires `NPM_TOKEN` secret).

### Version resolution (label-driven)

When deciding the target version in Step 1, count the labels on PRs merged into `dev` since the last release:

| Label | Bump |
|-------|------|
| `release: breaking` | major |
| `release: feature` | minor |
| `release: fix` | patch |
| `release: docs` | patch |
| `release: maintenance` | patch |

The highest bump wins. If no label matches, default to **patch**. Release Drafter independently resolves the same labels for the draft body, so as long as the manual bump in Step 1 matches Release Drafter's resolution, the draft and `package.json` will agree.

### What NOT to do

- Do NOT skip Step 1 (the manual version bump). `publish.yml`'s runner-side mutation does **not** commit back, so a missed bump leaves the git tree frozen. The Version Sync CI check trivially passes when all 5 fields agree on the wrong value — this drifted for 5 release cycles before being caught (PR #169).
- Do NOT create tags manually (Release Drafter creates them when the release is published).
- Do NOT push directly to `main` (branch protection blocks it; use the release PR flow).
- Do NOT merge feature branches directly to `main` (always go through `dev`).

## Editing Skills

When modifying skill content in `skills/`:
- Always verify against [official VRChat documentation](https://creators.vrchat.com/)
- Update SDK version tables if adding new API coverage
- Run the validate-udonsharp hook against any `.cs` code examples
- Keep `templates/` in sync if skills table or rules paths change

### Documentation Sync

A PostToolUse hook (`.claude/hooks/doc-sync-reminder.sh`) automatically reminds you to update documentation when editing files under `skills/` or `templates/`. See `.claude/rules/doc-sync.md` for the full sync checklist and trigger conditions.
