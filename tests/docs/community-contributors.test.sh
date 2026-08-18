#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README_FILES=(
    "$ROOT_DIR/README.md"
    "$ROOT_DIR/README.ja.md"
    "$ROOT_DIR/README.zh-CN.md"
    "$ROOT_DIR/README.zh-TW.md"
    "$ROOT_DIR/README.ko.md"
)

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

EXPECTED_HANDLES=(
    KatanoShingo
    Guribo
    haru0416-dev
    Yodokoro
    tetradice
    owlboy
    nomlasvrc
    ureishi
)
EXPECTED_ISSUES=(
    164 165 171 181 182 189 199 213 267 281
    286 297 302 324 333 337 338 341 342 344
)

CENSUS="$ROOT_DIR/tests/docs/fixtures/community-contributor-census.json"
[ -f "$CENSUS" ] || fail "missing contributor census evidence: $CENSUS"
python3 - "$CENSUS" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
classification = data["classification"]
contributors = data["contributors"]
issues = sorted(issue for contributor in contributors for issue in contributor["issues"])
assert classification["issues_scanned"] >= 1
assert classification["selected_reporters"] == len(contributors) == 8
assert classification["selected_issues"] == len(issues) == 20
assert len(set(issues)) == 20
assert classification["duplicate_invalid_wontfix_spam_issues_selected"] == 0
PY

section() {
    local path="$1"
    awk '
        /<h2 id="community-contributors">/ { found=1; next }
        found && /^<h2[ >]/ { exit }
        found { print }
    ' "$path"
}

for path in "${README_FILES[@]}"; do
    body="$(section "$path")"
    [ -n "$body" ] || fail "$path is missing the community-contributors section"

    for handle in "${EXPECTED_HANDLES[@]}"; do
        grep -Fq -- "https://github.com/$handle" <<<"$body" \
            || fail "$path is missing contributor @$handle"
    done

    # Keep the section bounded to the issue-originated contributors and avoid
    # silently crediting the maintainer or automation accounts.
    if grep -Eiq 'github\.com/(niaka3dayo|github-actions|dependabot|renovate)(\)|$)' <<<"$body"; then
        fail "$path credits a maintainer or bot in the contributor section"
    fi

    actual_issues="$(grep -Eo 'https://github\.com/niaka3dayo/agent-skills-vrc-udon/issues/[0-9]+' <<<"$body" | sort -u || true)"
    expected_issues="$(printf '%s\n' "${EXPECTED_ISSUES[@]}" | sed 's#^#https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/#' | sort -u)"
    [ "$actual_issues" = "$expected_issues" ] \
        || fail "$path has a different Issue census from the other READMEs"

    issue_count="$(grep -Eo 'https://github\.com/niaka3dayo/agent-skills-vrc-udon/issues/[0-9]+' <<<"$body" | sort -u | wc -l)"
    [ "$issue_count" -eq "${#EXPECTED_ISSUES[@]}" ] \
        || fail "$path has $issue_count unique Issue links; expected ${#EXPECTED_ISSUES[@]}"
done

echo "PASS: community contributor list is synchronized across all READMEs"
