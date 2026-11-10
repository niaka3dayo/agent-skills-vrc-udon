#!/usr/bin/env bash
# Release step 2: move the five version fields to a new version.
#
# Run it on a branch cut from dev. It edits the files and checks that exactly
# the five expected fields changed; committing and opening the PR stay manual.
#
# Usage: bash .claude/skills/release/scripts/bump-version.sh X.Y.Z

set -euo pipefail

NEW="${1:-}"
# Plain SemVer X.Y.Z: numeric parts without leading zeros, no pre-release suffix.
SEMVER='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
if [[ ! "$NEW" =~ $SEMVER ]]; then
    echo "usage: bump-version.sh X.Y.Z" >&2
    exit 2
fi

cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: the working tree has changes; commit or stash them first" >&2
    exit 1
fi

# If the local checkout is stale, compare with: npm view agent-skills-vrc-udon version
OLD="$(node -p "require('./package.json').version")"
if [[ ! "$OLD" =~ $SEMVER ]]; then
    echo "ERROR: package.json version '$OLD' is not X.Y.Z, so it cannot be compared" >&2
    exit 1
fi
NEWEST="$(printf '%s\n' "$OLD" "$NEW" | sort -V | tail -n 1)"
if [ "$OLD" = "$NEW" ] || [ "$NEWEST" != "$NEW" ]; then
    echo "ERROR: $NEW is not newer than the current version $OLD" >&2
    exit 1
fi

sed -i "s/\"version\": \"$OLD\"/\"version\": \"$NEW\"/" package.json .claude-plugin/marketplace.json
# Anchored to the 4-space-indented frontmatter line so that version numbers in
# the body text (SDK versions, for example) are never rewritten.
sed -i "s/^    version: \"$OLD\"$/    version: \"$NEW\"/" \
    skills/unity-vrc-udon-sharp/SKILL.md \
    skills/unity-vrc-world-sdk-3/SKILL.md \
    .claude/skills/unity-vrc-skills-renovator/SKILL.md

EXPECTED="$(printf '1\t1\t%s\n' \
    .claude-plugin/marketplace.json \
    .claude/skills/unity-vrc-skills-renovator/SKILL.md \
    package.json \
    skills/unity-vrc-udon-sharp/SKILL.md \
    skills/unity-vrc-world-sdk-3/SKILL.md | LC_ALL=C sort)"
ACTUAL="$(git diff --numstat | LC_ALL=C sort)"
if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "ERROR: expected exactly one changed line in each of the five version files, got:" >&2
    git diff --stat >&2
    exit 1
fi

git diff --stat
echo "OK: $OLD -> $NEW in five fields. Review the diff, then commit: chore(version): bump to v$NEW"
