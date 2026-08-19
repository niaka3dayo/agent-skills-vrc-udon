#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECURITY="$ROOT_DIR/SECURITY.md"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
DOC_SYNC="$ROOT_DIR/.claude/rules/doc-sync.md"
CONTRIBUTING="$ROOT_DIR/CONTRIBUTING.md"
CLAUDE="$ROOT_DIR/CLAUDE.md"
LABELS="$ROOT_DIR/.github/labels.yml"
LABEL_SYNC="$ROOT_DIR/.github/workflows/label-sync.yml"

require_text() {
    local path="$1" needle="$2"
    grep -Fq "$needle" "$path" || {
        echo "ERROR: $path does not contain expected text: $needle" >&2
        exit 1
    }
}

forbid_text() {
    local path="$1" needle="$2"
    if grep -Fq "$needle" "$path"; then
        echo "ERROR: $path contains forbidden text: $needle" >&2
        exit 1
    fi
}

require_text "$SECURITY" '| 3.x     | Yes       |'
require_text "$SECURITY" '| 2.x and older | No  |'
forbid_text "$SECURITY" '| 2.x     | Yes       |'

CANONICAL='GitHub Releases are the canonical release history'
ARCHIVE='historical archive through v1.2.0'
NO_BACKFILL='later releases are not backfilled'
for path in "$CHANGELOG" "$DOC_SYNC" "$CLAUDE"; do
    require_text "$path" "$CANONICAL"
    require_text "$path" "$ARCHIVE"
    require_text "$path" "$NO_BACKFILL"
done

# The contributor census is intentionally Issue-originated and must not turn
# maintainer, bot, invalid-report, or PR-only activity into public credit.
require_text "$DOC_SYNC" 'external GitHub Issue reporters'
require_text "$DOC_SYNC" 'Exclude maintainer and bot accounts'
require_text "$DOC_SYNC" 'invalid/duplicate/wontfix/spam Issues'
require_text "$DOC_SYNC" 'PR-only contributors'

# The support boundary applies to both distributed Skills, not only the file
# from which this guidance happened to be copied.
require_text "$CONTRIBUTING" 'for either distributed Skill'
require_text "$CONTRIBUTING" 'applies to both distributed Skills'
require_text "$CHANGELOG" '[1.2.0]: https://github.com/niaka3dayo/agent-skills-vrc-udon/releases/tag/v1.2.0'
require_text "$CHANGELOG" '[1.0.0]: https://github.com/niaka3dayo/agent-skills-vrc-udon/releases/tag/v1.0.0'
forbid_text "$DOC_SYNC" 'CHANGELOG.md` — managed by Release Drafter, not manual edits'
require_text "$LABEL_SYNC" 'delete-other-labels: true'

label_block() {
    local label="$1"
    awk -v label="$label" '
        $0 == "- name: \"" label "\"" { found = 1; print; next }
        found && /^- name:/ { exit }
        found { print }
    ' "$LABELS"
}

RELEASE_LABEL="$(label_block 'PR: Release')"
SKILLS_LABEL="$(label_block 'PR: Skills')"
STATUS_LABEL="$(label_block 'Status: In Progress')"
require_text <(printf '%s\n' "$RELEASE_LABEL") 'color: "ededed"'
require_text <(printf '%s\n' "$SKILLS_LABEL") 'color: "ededed"'
require_text <(printf '%s\n' "$STATUS_LABEL") 'color: "FBCA04"'
require_text <(printf '%s\n' "$STATUS_LABEL") 'description: "Work in progress - do not start"'
for block in "$RELEASE_LABEL" "$SKILLS_LABEL"; do
    if grep -Fq 'description:' <<<"$block"; then
        echo "ERROR: PR labels must omit descriptions" >&2
        exit 1
    fi
done

echo 'PASS: repository governance contracts'
