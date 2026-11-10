# agent-skills-vrc-udon Development Guide

This repository is an **npm package** that distributes AI agent skills for VRChat UdonSharp development.
It is NOT a VRChat/Unity project. The codebase consists of markdown knowledge files, templates, and CI workflows.

## Repository Structure

```
skills/                          # Skill content (distributed to users)
  unity-vrc-udon-sharp/          # UdonSharp constraints, networking, templates
  unity-vrc-world-sdk-3/         # World SDK components, optimization
.claude/
  rules/                         # Loaded automatically in this repository
    doc-sync.md                  # Documentation sync rule (repo maintenance)
    evidence-gate.md             # Evidence order before changing a verified runtime claim
  hooks/
    doc-sync-reminder.sh         # PostToolUse hook: reminds about doc updates
  skills/                        # Maintainer-only skills (not distributed)
    unity-vrc-skills-renovator/  # Meta-skill for maintaining the distributed skills
    release/                     # Release procedure and its scripts
  audit/                         # SDK coverage-audit tooling + ledger (maintainer-only, not distributed)
    README.md                    # How to run the SDK-bump diff audit
    sdk-coverage-ledger.md       # Decision ledger (candidates, verdicts, skips)
    scripts/                     # census / diff / refine pipeline
evals/                           # Behavioural evals for `claude plugin eval` (see evals/README.md)
templates/                       # AI tool config templates (distributed to users)
  CLAUDE.md                      # Claude Code project instructions
  AGENTS.md                      # Codex CLI / generic agent instructions
  GEMINI.md                      # Gemini CLI instructions
hooks/
  hooks.json                     # Claude Code plugin hook registration (runs validate-udonsharp.sh)
.github/
  workflows/                     # CI (lint, pack test, publish)
  ISSUE_TEMPLATE/                # Bug report, knowledge request
tests/
  run.sh                         # Local entry point: runs every suite CI runs
  docs/                          # Documentation contract tests and fixtures
  hooks/                         # Validator hook tests and fixtures
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
- All seven CI checks are required: Symlink Integrity, Hook Scripts, Documentation Smoke Tests,
  Markdown Links, npm Pack Test, EditorConfig, and Version Sync
- Required checks use `strict: false` on `dev` and `strict: true` on `main`
- PR required for all changes

### Branch Naming

`feature/*`, `fix/*`, `docs/*`, `refactor/*`, `security/*`, `chore/*`

## Key Files

| File | Purpose |
|------|---------|
| `package.json` | npm metadata, `files` array controls what gets published |
| `.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json` | Claude Code marketplace entry and plugin manifest |
| `hooks/hooks.json` | Registers the validator hook for Claude Code plugin installs |
| `skills/*/SKILL.md` | Skill definitions with YAML frontmatter |
| `skills/*/rules/*.md` | Constraint rules for AI code generation |
| `templates/*.md` | AI tool config files distributed to end users |

## Testing

```bash
# Run every suite CI runs. Needs bash, python3 and jq; on Windows run it inside WSL.
npm test                        # same as: bash tests/run.sh
bash tests/run.sh layers        # only suites whose path contains "layers"

# Verify npm pack includes correct files
npm pack --dry-run
```

The BusyBox and PowerShell hook suites are skipped locally when `busybox` or `pwsh` is missing; CI always runs them.

Those suites are static. To check what an agent does with the skills loaded, run the evals in [`evals/README.md`](evals/README.md) before and after a change to a `SKILL.md`, a description, or a rule. They cost real usage, so they are not part of CI.

## CI Checks

| Check | What it verifies |
|-------|-----------------|
| Symlink Integrity | No symlinks in repo (breaks npm pack) |
| Hook Scripts | validate-udonsharp.sh is executable and valid bash |
| Documentation Smoke Tests | Required documentation reference coverage is present |
| Markdown Links | No broken links in documentation |
| npm Pack Test | Package includes all required files |
| EditorConfig | File formatting matches .editorconfig rules (indent_size check disabled; see below) |
| Version Sync | All five package version fields agree |

One more job, Hook Scripts (Windows PowerShell 5.1), runs the PowerShell hook suite under Windows PowerShell 5.1 on a Windows runner. It is not a required check.

### EditorConfig Notes

- **IndentSize check is intentionally disabled** in `.editorconfig-checker.json` (`Disable.IndentSize: true`).
  C# uses 4-space indentation while JS/MJS uses 2-space; continuation lines and alignment patterns
  in C# templates cause false positives. The `indent_style` check (tabs vs spaces) remains active.
- **Editor setup**: Install an [EditorConfig plugin](https://editorconfig.org/#pre-installed) for your IDE
  to automatically apply formatting rules from `.editorconfig`.
- **Per-line exceptions**: Use `// editorconfig-checker-disable-line` for intentional deviations.

## Releases

Follow the `release` skill ([`.claude/skills/release/SKILL.md`](.claude/skills/release/SKILL.md)) step by step. Do not improvise a release. These rules hold whatever else happens:

- Bump the five version fields on `dev` before opening the release PR (`.claude/skills/release/scripts/bump-version.sh`). `publish.yml` changes them only inside the CI runner and does not commit them back.
- Merge the release PR with a merge commit, never squash, so that Release Drafter sees each underlying PR.
- Do not create tags by hand. Release Drafter creates the tag when the release is published.
- Never delete a release or a tag. Users pin versions by tag (Issue #290).
- GitHub Release notes are drafted by Release Drafter, and GitHub Releases are the canonical release history. `CHANGELOG.md` is a historical archive through v1.2.0; later releases are not backfilled.

## SDK Verification

Public VRChat creator docs and the `vrchat-community/UdonSharp` API page sometimes lag behind the actual SDK binary. When triaging a knowledge-request Issue that hinges on whether a specific API exists, the authoritative source is the SDK DLL itself.

This repo uses a gitignored local workspace pattern at `unity-project-for-sdk-search/` for that verification. The directory is intentionally not packed into the npm tarball — only its `README.md` is tracked so the convention is discoverable on clone. See [`unity-project-for-sdk-search/README.md`](unity-project-for-sdk-search/README.md) for one-time setup steps, the canonical `strings | grep` command, and the Udon wrapper symbol legend.

Use this verification path before documenting any API that you cannot confirm against the official public docs.

### Coverage audit (SDK bumps)

Beyond point verification of a single API, the same workspace backs a repeatable **coverage audit** that diffs the full Udon-callable surface against current skill coverage to surface undocumented-but-shipped gaps — the structural problem behind #190 (`VRCObjectPool.Shuffle()`) and #213/#214 (missing events). Run it on each SDK bump and triage only what changed. The procedure and tooling are in [`.claude/audit/README.md`](.claude/audit/README.md); the inclusion policy it feeds — binary presence is a discovery signal only, never grounds for inclusion — is in [`CONTRIBUTING.md`](CONTRIBUTING.md) ("Content Scope").

## Editing Skills

When modifying skill content in `skills/`:
- Always verify against [official VRChat documentation](https://creators.vrchat.com/)
- Update SDK version tables if adding new API coverage
- Run the validate-udonsharp hook against any `.cs` code examples
- Keep `templates/` in sync if skills table or rules paths change
- After adding, renaming, or removing a `##` section in a reference, run `python3 tests/docs/reference-toc.py --write` to refresh its table of contents
- The active SDK target is declared once per skill, in the `## SDK Versions` section of each `SKILL.md`. Other files under `skills/` link to it instead of repeating the number

### Documentation Sync

A PostToolUse hook (`.claude/hooks/doc-sync-reminder.sh`) automatically reminds you to update documentation when editing files under `skills/` or `templates/`. See `.claude/rules/doc-sync.md` for the full sync checklist and trigger conditions.
