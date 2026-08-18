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

CENSUS="$ROOT_DIR/tests/docs/fixtures/community-contributor-census.json"
[ -f "$CENSUS" ] || fail "missing contributor census evidence: $CENSUS"

# The census is the sole source of truth. Each README is compared against the
# fixture's contributor handles and per-contributor Issue set, rather than
# keeping a second hard-coded list in this test.
python3 - "$CENSUS" "${README_FILES[@]}" <<'PY'
import json
import re
import sys
from pathlib import Path

census_path = Path(sys.argv[1])
readme_paths = [Path(path) for path in sys.argv[2:]]
data = json.loads(census_path.read_text(encoding="utf-8"))
classification = data["classification"]
contributors = data["contributors"]

excluded_handles = {
    "niaka3dayo",
    "github-actions",
    "dependabot",
    "renovate",
}
expected_by_handle = {
    contributor["handle"]: sorted({int(issue) for issue in contributor["issues"]})
    for contributor in contributors
}
assert len(expected_by_handle) == len(contributors)
assert not excluded_handles.intersection(expected_by_handle)
expected_issues = sorted({issue for issues in expected_by_handle.values() for issue in issues})
all_fixture_issues = [issue for contributor in contributors for issue in contributor["issues"]]
assert classification["issues_scanned"] >= 1
assert classification["selected_reporters"] == len(expected_by_handle) > 0
assert classification["selected_issues"] == len(expected_issues) > 0
assert len(all_fixture_issues) == len(set(all_fixture_issues)) == len(expected_issues)
assert classification["duplicate_invalid_wontfix_spam_issues_selected"] == 0

profile_re = re.compile(r"https://github\.com/([A-Za-z0-9_-]+)\)")
contributor_line_re = re.compile(
    r"^- \[@([A-Za-z0-9_-]+)\]\(https://github\.com/([A-Za-z0-9_-]+)\)",
    re.MULTILINE,
)
issue_re = re.compile(
    r"https://github\.com/niaka3dayo/agent-skills-vrc-udon/issues/(\d+)"
)

for path in readme_paths:
    text = path.read_text(encoding="utf-8")
    heading = '<h2 id="community-contributors">'
    start = text.find(heading)
    assert start >= 0, f"{path} is missing the community-contributors section"
    body_start = start + len(heading)
    next_heading = re.search(r"^<h2[ >]", text[body_start:], re.MULTILINE)
    assert next_heading, f"{path} has an unterminated community-contributors section"
    body = text[body_start : body_start + next_heading.start()]
    assert body.strip(), f"{path} has an empty community-contributors section"

    profile_matches = profile_re.findall(body)
    profile_handles = set(profile_matches)
    expected_handles = set(expected_by_handle)
    assert len(profile_matches) == len(profile_handles) == len(expected_handles), (
        f"{path} has {len(profile_handles)} unique contributor profiles; "
        f"expected {len(expected_handles)}"
    )
    assert profile_handles == expected_handles, (
        f"{path} contributor profiles differ from the census: "
        f"actual={sorted(profile_handles)} expected={sorted(expected_handles)}"
    )
    assert not excluded_handles.intersection(profile_handles), (
        f"{path} credits a maintainer or bot in the contributor section"
    )

    actual_by_handle = {}
    for match in contributor_line_re.finditer(body):
        display_handle, linked_handle = match.groups()
        assert display_handle == linked_handle, (
            f"{path} has a contributor profile/link mismatch for @{display_handle}"
        )
        assert display_handle not in actual_by_handle, (
            f"{path} lists @{display_handle} more than once"
        )
        line_end = body.find("\n", match.start())
        line = body[match.start() : line_end if line_end >= 0 else len(body)]
        actual_by_handle[display_handle] = sorted(
            {int(issue) for issue in issue_re.findall(line)}
        )
    assert actual_by_handle == expected_by_handle, (
        f"{path} per-contributor Issue links differ from the census: "
        f"actual={actual_by_handle} expected={expected_by_handle}"
    )

    actual_issues = sorted({int(issue) for issue in issue_re.findall(body)})
    assert actual_issues == expected_issues, (
        f"{path} aggregate Issue links differ from the census: "
        f"actual={actual_issues} expected={expected_issues}"
    )

print(
    "PASS: community contributor profiles, per-contributor Issues, and "
    "aggregate Issue census are exact across all five READMEs"
)
PY
