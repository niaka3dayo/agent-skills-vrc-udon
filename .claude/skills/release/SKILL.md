---
name: release
description: >-
    Release procedure for agent-skills-vrc-udon: sync main into dev, bump the five version fields,
    open and merge the release PR, rewrite the Release Drafter notes, and publish to npm. Use when
    asked to cut, prepare, or publish a release, to bump the version, or to sync main into dev.
    Maintainer-only; not distributed.
metadata:
    internal: true
---

# Release

```
main ──sync PR──> dev (when the ancestry check fails)
dev ──version-bump PR──> dev ──release PR──> main ──Release Drafter draft──> publish ──> npm
```

GitHub Release notes are drafted by Release Drafter, and GitHub Releases are the canonical release history. `CHANGELOG.md` is a historical archive through v1.2.0; later releases are not backfilled.

Version numbers must be bumped by hand on `dev` before the release PR is opened (Step 2). `publish.yml` does run `npm version "$VERSION" --no-git-tag-version` in the CI runner as a safety net, but those edits are not committed back, so the git tree has to be kept current by hand.

## Step 1: Synchronize `main` into `dev` when needed

```bash
bash .claude/skills/release/scripts/sync-main-into-dev.sh
```

The script fetches both branches and checks that `dev` contains the current `main` history. If it does not, it opens a sync PR from a new `chore/sync-main-into-dev-<timestamp>` branch, waits for the seven required checks (Symlink Integrity, Hook Scripts, Documentation Smoke Tests, Markdown Links, npm Pack Test, EditorConfig, Version Sync), merges with a merge commit, and repeats the ancestry check. Do not continue until that final check succeeds.

## Step 2: Bump the version fields on `dev`

Decide the target version vX.Y.Z from the labels on the PRs merged into `dev` since the last release (see [Version resolution](#version-resolution-label-driven)). Then:

```bash
git checkout dev && git pull
git checkout -b chore/release-vX.Y.Z

bash .claude/skills/release/scripts/bump-version.sh X.Y.Z

git commit -am "chore(version): bump to vX.Y.Z"
git push -u origin chore/release-vX.Y.Z
gh pr create --base dev --label "release: maintenance" \
  --title "chore(version): bump to vX.Y.Z" \
  --body "Pre-release version bump for Step 3 of the release flow."
```

The script moves these five fields together and stops unless exactly those five lines changed:

- `package.json` → `.version`
- `.claude-plugin/marketplace.json` → `.metadata.version`
- `skills/unity-vrc-udon-sharp/SKILL.md` → frontmatter `metadata.version`
- `skills/unity-vrc-world-sdk-3/SKILL.md` → frontmatter `metadata.version`
- `.claude/skills/unity-vrc-skills-renovator/SKILL.md` → frontmatter `metadata.version`

Wait for all seven required CI checks. Version Sync verifies that the five fields agree. Merge the bump PR into `dev` (squash is fine here; it is a single-purpose commit). CodeRabbit review is optional on this PR.

## Step 3: Create the release PR from `dev` to `main`

```bash
gh pr create --base main --head dev \
  --title "Release vX.Y.Z" \
  --body "Merge dev into main for release"
```

The title must include the version that matches `package.json#version` on `dev` after Step 2. The body can follow `.github/PULL_REQUEST_TEMPLATE/release.md`. Wait for CI to pass. CodeRabbit approval is not required for release PRs: they are mechanical merges of commits that were already reviewed.

## Step 4: Merge the release PR

Merge with a merge commit. Do NOT squash: Release Drafter needs each underlying PR commit. The merge triggers Release Drafter to update the draft release on `main`.

## Step 5: Publish the GitHub Release draft

```bash
# List draft releases
gh release list --exclude-drafts=false

# Rewrite the auto-generated notes, then publish
gh release edit vX.Y.Z --notes "$(cat <<'NOTES'
## What's New in vX.Y.Z
...

## vX.Y.Z の変更点
...
NOTES
)"

# Publishing triggers publish.yml → npm publish
gh release edit vX.Y.Z --draft=false
```

Always rewrite the notes before publishing:

- Remove the "Release vX.Y.Z (#N)" self-reference line.
- Replace bare PR titles with user-facing prose.
- Use a bilingual structure: English release notes first, then a Japanese version of the same user-facing content.
- Add a contributor acknowledgement section when a bundled PR closed an externally reported Issue. Name the Issue number and the reporter, keep it respectful, and mirror the reporter's language when possible.

The `published` event triggers `publish.yml`, which validates the tag, runs `npm version "$VERSION" --allow-same-version` (a no-op when Step 2 was done), syncs `SKILL.md` and `marketplace.json` again as a safety net, and runs `npm publish --provenance`. It uses the `npm-publish` environment, which holds the `NPM_TOKEN` secret.

Afterwards, `npm view agent-skills-vrc-udon version` should return the new version.

## Version resolution (label-driven)

Count the labels on the PRs merged into `dev` since the last release:

| Label | Bump |
|-------|------|
| `release: breaking` | major |
| `release: feature` | minor |
| `release: fix` | patch |
| `release: docs` | patch |
| `release: maintenance` | patch |

The highest bump wins. If no label matches, default to **patch**. Release Drafter resolves the same labels for the draft body, so the draft and `package.json` agree as long as the manual bump matches.

## What NOT to do

- Do NOT skip Step 2. `publish.yml` changes the version only inside the runner and does not commit it back, so a missed bump leaves the git tree frozen. Version Sync passes when all five fields agree on the wrong value; this drifted for five release cycles before it was caught (PR #169).
- Do NOT create tags manually. Release Drafter creates the tag when the release is published.
- Do NOT delete a release or a tag. Published versions may be referenced by tag (`git clone --branch vX.Y.Z`), and deleting a tag breaks every user who pinned it (Issue #290).
- Do NOT push directly to `dev` or `main`. Branch protection blocks it; use the PR flows above.
- Do NOT merge feature branches directly to `main`. Always go through `dev`.
