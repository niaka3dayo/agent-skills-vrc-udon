# Documentation Sync Rule

When modifying files under `skills/` or `templates/`, you MUST check and update related documentation to prevent documentation drift.

## Trigger Conditions

Any change to these paths requires a documentation sync check:

| Changed Path | Check These Docs |
|---|---|
| `skills/*/SKILL.md` | README.md Skills section, README.ja.md Skills section |
| `skills/*/rules/*.md` | README.md Rules section, `templates/CLAUDE.md`, `templates/AGENTS.md`, `templates/GEMINI.md` |
| `skills/*/hooks/*` | README.md Hooks section |
| `skills/*/references/*.md` | README.md Skills section (reference count/list) |
| `skills/*/assets/templates/*.cs` | README.md Skills section (template count) |
| `templates/*.md` | README.md Install/Structure section |
| `bin/install.mjs` | README.md Install section, CLAUDE.md Testing section |

## What to Check

1. **Skill tables**: Do README.md and README.ja.md list all skills with correct rule/reference/template counts?
2. **Rule paths**: Do `templates/*.md` reference valid rule file paths under `skills/*/rules/`?
3. **Hook references**: If hooks were added/removed/renamed, are they listed in README.md Hooks section?
4. **SDK version table**: If SDK version support changed, update the SDK Versions section
5. **Structure tree**: If directories were added/removed, update the Structure section in README.md and CLAUDE.md

## What NOT to Update

- `CHANGELOG.md` — managed by Release Drafter, not manual edits
- `package.json` version — managed by publish workflow
- `SKILL.md` version fields — managed by publish workflow

## Checklist (run mentally before committing)

- [ ] README.md skill/rule/hook tables match the actual `skills/` directory contents
- [ ] README.ja.md is in sync with README.md (same structure, translated content)
- [ ] All other README translations (README.zh-CN.md, etc.) are flagged for update if they exist
- [ ] `templates/*.md` rule paths are valid (no broken references)
- [ ] CLAUDE.md Structure section reflects current directory layout
