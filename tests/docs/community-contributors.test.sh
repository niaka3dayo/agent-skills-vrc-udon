#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README_FILES=(
    "$ROOT_DIR/README.md"
    "$ROOT_DIR/README.ja.md"
    "$ROOT_DIR/README.ko.md"
    "$ROOT_DIR/README.zh-CN.md"
    "$ROOT_DIR/README.zh-TW.md"
)

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

CENSUS="$ROOT_DIR/tests/docs/fixtures/community-contributor-census.json"
DOC_SYNC="$ROOT_DIR/.claude/rules/doc-sync.md"
[ -f "$CENSUS" ] || fail "missing contributor census evidence: $CENSUS"
[ -f "$DOC_SYNC" ] || fail "missing documentation sync rule: $DOC_SYNC"

# The census is the sole source of truth. The README contract intentionally
# contains only stable profile links and avatar attributes; Issue evidence stays
# in the fixture for auditability rather than being duplicated in each README.
python3 - "$CENSUS" "$DOC_SYNC" "${README_FILES[@]}" <<'PY'
import json
import re
import sys
from pathlib import Path

census_path = Path(sys.argv[1])
doc_sync_path = Path(sys.argv[2])
readme_paths = [Path(path) for path in sys.argv[3:]]
data = json.loads(census_path.read_text(encoding="utf-8"))
classification = data["classification"]
contributors = data["contributors"]

doc_sync = doc_sync_path.read_text(encoding="utf-8")
community_rule_match = re.search(
    r"^5\. \*\*Community contributors\*\*:(.*?)(?=^6\.)",
    doc_sync,
    re.MULTILINE | re.DOTALL,
)
assert community_rule_match, "the maintainer rule has no Community contributors item"
community_rule = community_rule_match.group(1)
assert "ordered profile-linked avatar block" in community_rule, (
    "the maintainer rule must preserve the avatar-only README contract"
)
assert "across all five READMEs" in community_rule, (
    "the maintainer rule must keep all five README translations in scope"
)
assert "tests/docs/fixtures/community-contributor-census.json" in community_rule, (
    "the maintainer rule must name the Issue-evidence source of truth"
)
assert "do not duplicate them in the README sections" in community_rule, (
    "the maintainer rule must keep Issue evidence out of the README sections"
)
assert not re.search(
    r"(?:Issue\s+links?.*descriptions?|descriptions?.*Issue\s+links?)",
    community_rule,
    re.IGNORECASE | re.DOTALL,
), (
    "the maintainer rule still requires the removed contributor list format"
)

excluded_handles = {
    "niaka3dayo",
    "github-actions",
    "dependabot",
    "renovate",
}
expected_handles = [contributor["handle"] for contributor in contributors]
assert expected_handles
assert len(expected_handles) == len(set(expected_handles)), (
    "the census contains duplicate contributor handles"
)
assert not excluded_handles.intersection(expected_handles)
assert all(re.fullmatch(r"[A-Za-z0-9_-]+", handle) for handle in expected_handles)

ureishi = next(
    contributor for contributor in contributors if contributor["handle"] == "ureishi"
)
assert ureishi["issues"] == [337, 338, 341, 342, 344]
assert ureishi["evidence"]["merged_prs"] == [339, 340, 345, 347, 348]
assert ureishi["evidence"]["classification"] == "implemented and confirmed"
assert "open_accepted_issues" not in ureishi["evidence"], (
    "the census still records closed @ureishi reports as open work"
)

# Keep the census integrity checks here so the contract cannot silently become
# detached from the evidence that selected the eight reporters.
expected_issues = sorted(
    {
        int(issue)
        for contributor in contributors
        for issue in contributor["issues"]
    }
)
all_fixture_issues = [
    issue
    for contributor in contributors
    for issue in contributor["issues"]
]
assert classification["issues_scanned"] >= 1
assert classification["selected_reporters"] == len(expected_handles)
assert classification["selected_issues"] == len(expected_issues) > 0
assert len(all_fixture_issues) == len(set(all_fixture_issues)) == len(expected_issues)
assert classification["duplicate_invalid_wontfix_spam_issues_selected"] == 0

start_marker = "<!-- community-contributors:start -->"
end_marker = "<!-- community-contributors:end -->"
heading_re = re.compile(
    r'^<h2 id="community-contributors">[^\n]*</h2>$', re.MULTILINE
)
entry_re = re.compile(
    r'^<a href="https://github\.com/(?P<href>[A-Za-z0-9_-]+)" '
    r'title="@(?P<title>[A-Za-z0-9_-]+)"><img '
    r'src="https://github\.com/(?P<src>[A-Za-z0-9_-]+)\.png\?size=64" '
    r'width="(?P<width>64)" height="(?P<height>64)" '
    r'alt="@(?P<alt>[A-Za-z0-9_-]+)"></a>$'
)
issue_url_re = re.compile(
    r"https://github\.com/[^\s)\"]+/issues(?:[/#]|$)"
)
profile_href_re = re.compile(
    r'href="https://github\.com/([A-Za-z0-9_-]+)"'
)
legacy_profile_list_re = re.compile(
    r"(?m)^-\s+\["
)

canonical_block = None
for path in readme_paths:
    text = path.read_text(encoding="utf-8")
    assert text.count(start_marker) == 1, (
        f"{path} must contain exactly one community-contributors start marker"
    )
    assert text.count(end_marker) == 1, (
        f"{path} must contain exactly one community-contributors end marker"
    )

    heading_matches = list(heading_re.finditer(text))
    assert len(heading_matches) == 1, (
        f"{path} must contain exactly one community-contributors heading"
    )
    heading = heading_matches[0]
    start = text.index(start_marker)
    end = text.index(end_marker)
    assert heading.end() < start < end, (
        f"{path} has an invalid heading/marker order"
    )

    tail_start = end + len(end_marker)
    next_heading = re.search(r"^<h2[ >]", text[tail_start:], re.MULTILINE)
    assert next_heading, f"{path} has no heading after community-contributors section"
    section_end = tail_start + next_heading.start()
    tail = text[tail_start:section_end]
    assert tail.strip() == "---", (
        f"{path} must contain only the separator after the contributor marker"
    )

    intro = text[heading.end() : start]
    assert intro.strip(), f"{path} is missing its localized thank-you text"
    section = text[heading.start() : section_end]
    assert not issue_url_re.search(section), (
        f"{path} contains an Issue URL in the contributor section"
    )
    assert not legacy_profile_list_re.search(section), (
        f"{path} contains a legacy Markdown contributor list"
    )
    assert profile_href_re.findall(section) == expected_handles, (
        f"{path} has an extra, missing, or out-of-order profile href in the "
        "contributor section"
    )

    block = text[start + len(start_marker) : end]
    block_match = re.fullmatch(r"\n<p>\n(?P<entries>.+)\n</p>\n", block, re.DOTALL)
    assert block_match, (
        f"{path} must contain one newline-delimited <p> avatar block between markers"
    )
    entry_lines = block_match.group("entries").split("\n")
    assert len(entry_lines) == len(expected_handles), (
        f"{path} has {len(entry_lines)} avatar lines; "
        f"expected {len(expected_handles)}"
    )

    actual_handles = []
    for line_number, line in enumerate(entry_lines, start=1):
        match = entry_re.fullmatch(line)
        assert match, (
            f"{path} avatar line {line_number} does not use the exact "
            "profile/avatar contract"
        )
        attributes = match.groupdict()
        handle = attributes["href"]
        assert attributes["title"] == handle
        assert attributes["src"] == handle
        assert attributes["alt"] == handle
        actual_handles.append(handle)

    assert actual_handles == expected_handles, (
        f"{path} contributor handle order differs from the census: "
        f"actual={actual_handles} expected={expected_handles}"
    )
    assert len(actual_handles) == len(set(actual_handles)), (
        f"{path} contains duplicate contributor profiles"
    )
    assert canonical_block is None or block == canonical_block, (
        f"{path} contributor avatar block differs from the other READMEs"
    )
    canonical_block = block

print(
    "PASS: exact fixture-ordered profile-linked avatar blocks, markers, "
    "attributes, and contributor-section exclusions across all five READMEs"
)
PY
