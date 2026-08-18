# Documentation Sync Rule

When modifying files under `skills/` or `templates/`, you MUST check and update related documentation to prevent documentation drift.

## Trigger Conditions

Any change to these paths requires a documentation sync check:

| Changed Path | Check These Docs |
|---|---|
| `skills/*/SKILL.md` | All five README Skills/support/contributor sections |
| `skills/*/rules/*.md` | README.md Rules section, `templates/CLAUDE.md`, `templates/AGENTS.md`, `templates/GEMINI.md` |
| `skills/*/hooks/*` | README.md Hooks section |
| `skills/*/references/*.md` | README.md Skills section (reference count/list) |
| `skills/*/assets/templates/*.cs` | README.md Skills section (template count) |
| `templates/*.md` | README.md Install/Structure section |

## What to Check

1. **Skill tables**: Do all five README files list all skills with correct rule/reference/template counts?
2. **Rule paths**: Do `templates/*.md` reference valid rule file paths under `skills/*/rules/`?
3. **Hook references**: If hooks were added/removed/renamed, are they listed in README.md Hooks section?
4. **SDK support policy**: If the active target changes, synchronize the stable-only verification gate, historical boundary, and SDK Versions section across all five READMEs.
5. **Community contributors**: Keep the contributor handles, Issue links, and descriptions synchronized across all five READMEs; include only external GitHub Issue reporters whose contributions were accepted, confirmed, or implemented. Exclude maintainer and bot accounts, invalid/duplicate/wontfix/spam Issues, and PR-only contributors. When the census changes, refresh `tests/docs/fixtures/community-contributor-census.json` and the contract-test expectations from a new all-Issue query.
6. **Structure tree**: If directories were added/removed, update the Structure section in README.md and CLAUDE.md

## What NOT to Update

- `CHANGELOG.md` — GitHub Releases are the canonical release history. Keep this file as a historical archive through v1.2.0; later releases are not backfilled.

## What to Update Together (Release Flow)

These fields must be bumped together on `dev` via a `chore(version): bump to vX.Y.Z` PR
**before** opening the release PR. See CLAUDE.md "Release Guide" Step 2 for the exact procedure.
`publish.yml` does mutate them in the CI runner as a safety net, but those edits are not
committed back, so the source-of-truth must be kept current by hand:

- `package.json` → `.version`
- `.claude-plugin/marketplace.json` → `.metadata.version`
- `skills/unity-vrc-udon-sharp/SKILL.md` → frontmatter `metadata.version`
- `skills/unity-vrc-world-sdk-3/SKILL.md` → frontmatter `metadata.version`
- `.claude/skills/unity-vrc-skills-renovator/SKILL.md` → frontmatter `metadata.version`

## Checklist (run mentally before committing)

- [ ] README.md skill/rule/hook tables match the actual `skills/` directory contents
- [ ] All README translations are in sync with README.md (same structure, translated content)
- [ ] Stable-only SDK policy and Community Contributors census are synchronized across all five READMEs
- [ ] `templates/*.md` rule paths are valid (no broken references)
- [ ] CLAUDE.md Structure section reflects current directory layout
