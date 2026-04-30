# Release PR Template

> Open a release PR with this template by appending `?template=release.md` to the new-PR URL,
> or by editing the body after creation. See `CLAUDE.md` "Release Guide" for the full flow.

## Pre-flight checklist (Step 1 must be done BEFORE this PR is opened)

- [ ] **Version bumped on `dev`** via a separate `chore(version): bump to vX.Y.Z` PR, already merged.
  Verify with `node -p "require('./package.json').version"` on `dev` — it must equal the target version.
- [ ] All 5 version fields are in sync (Version Sync CI checks this; verify locally too):
  - `package.json` → `.version`
  - `.claude-plugin/marketplace.json` → `.metadata.version`
  - `skills/unity-vrc-udon-sharp/SKILL.md` → frontmatter `metadata.version`
  - `skills/unity-vrc-world-sdk-3/SKILL.md` → frontmatter `metadata.version`
  - `.claude/skills/unity-vrc-skills-renovator/SKILL.md` → frontmatter `metadata.version`

## Summary

Release vX.Y.Z — short one-line punchline.

**N PRs since vPREVIOUS:**

- #NNN — `<type>`: `one-sentence summary`
- ...

**Version bump driver**: `release: <highest-label>` → `<bump-type>`.

## What changed

### `Skill or Area` (#NNN)

- ...

## Reporter acknowledgement (if applicable)

If any of the bundled PRs closed an externally-reported Issue, list reporters here. The release notes
themselves should also include a thank-you (in the reporter's language).

## Merge instructions

**DO NOT SQUASH** — use a plain merge commit so Release Drafter sees each underlying PR.

## Post-merge

1. Release Drafter creates/updates a draft release on `main`.
2. Rewrite the draft notes (`gh release edit vX.Y.Z --notes "$(cat <<'NOTES' ... NOTES)"`):
   - Remove the auto-generated "Release vX.Y.Z (#N)" self-reference line.
   - Convert bare PR titles to user-facing prose.
   - Add reporter thank-you if applicable, in the reporter's language.
3. `gh release edit vX.Y.Z --draft=false` to publish — triggers `publish.yml` → `npm publish`.

## Test plan

- [ ] CI green (Symlinks / Hooks / Markdown / npm Pack / Installer Tests / EditorConfig / Version Sync)
- [ ] Release Drafter draft body reflects the merged PRs
- [ ] After publish: `npm view agent-skills-vrc-udon version` returns vX.Y.Z

## Release impact

`release: <label>` → `<bump-type>` bump per Release Drafter.
