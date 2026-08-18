#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

SKILL="skills/unity-vrc-udon-sharp/SKILL.md"
CONSTRAINTS="skills/unity-vrc-udon-sharp/references/constraints.md"
VIDEO="skills/unity-vrc-udon-sharp/references/patterns-video.md"
EXPECTED_ARRAY_EXAMPLE="$(cat <<'EOF'
[SerializeField] private VRCUrl[] _urls = new VRCUrl[]
{
    new VRCUrl(""),
    new VRCUrl(""),
};
EOF
)"

FAILURES=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAILURES=$((FAILURES + 1))
}

require_text() {
    local path="$1" text="$2"
    if ! grep -Fq -- "$text" "$path"; then
        fail "$path is missing: $text"
    fi
}

require_regex_count() {
    local path="$1" pattern="$2" expected="$3"
    local actual
    actual="$( (grep -E -- "$pattern" "$path" || true) | wc -l | tr -d '[:space:]')"
    if [ "$actual" -ne "$expected" ]; then
        fail "$path has $actual matches for /$pattern/; expected $expected"
    fi
}

require_exact_block() {
    local path="$1" start_line="$2" end_line="$3" expected="$4"
    local actual
    actual="$(awk -v start="$start_line" -v end="$end_line" '
        $0 == start { capture = 1 }
        capture { print }
        capture && $0 == end { capture = 0 }
    ' "$path")"
    if [ "$actual" != "$expected" ]; then
        fail "$path block beginning with '$start_line' does not match the required fresh-element example"
    fi
}

# Entry-point guidance must surface the anti-pattern, while the detailed
# reference explains the aliasing boundary and the fresh-instance alternative.
require_text "$SKILL" 'VRCUrl.Empty'
require_text "$SKILL" 'new VRCUrl("")'
require_text "$SKILL" 'any UdonSharp `VRCUrl` field that needs an independent initial value'
require_text "$SKILL" '`[SerializeField]`, `[UdonSynced]`, and ordinary private fields'
require_text "$CONSTRAINTS" '`VRCUrl.Empty` returns a shared instance'
require_text "$CONSTRAINTS" 'any UdonSharp field that needs an independent initial value'
require_text "$CONSTRAINTS" '`[SerializeField]`, `[UdonSynced]`, and ordinary private fields'
require_text "$CONSTRAINTS" 'each array element'
require_text "$CONSTRAINTS" '[SerializeField] private VRCUrl[] _urls = new VRCUrl[]'
require_regex_count "$CONSTRAINTS" '^private VRCUrl _localUrl = new VRCUrl\(""\);$' 1
require_exact_block "$CONSTRAINTS" \
    '[SerializeField] private VRCUrl[] _urls = new VRCUrl[]' \
    '};' \
    "$EXPECTED_ARRAY_EXAMPLE"

# Every affected independent field initializer uses a fresh empty VRCUrl.
require_regex_count "$CONSTRAINTS" '^    \[UdonSynced\] private VRCUrl SyncedUrl_[0-7] = new VRCUrl\(""\);$' 8
require_regex_count "$VIDEO" '^    \[UdonSynced\] private VRCUrl +_(syncUrl|currentUrl) += new VRCUrl\(""\);$' 3
require_regex_count "$CONSTRAINTS" '^    \[UdonSynced\] private VRCUrl SyncedUrl_[0-7] = VRCUrl\.Empty;$' 0
require_regex_count "$VIDEO" '^    \[UdonSynced\] private VRCUrl +_(syncUrl|currentUrl) += VRCUrl\.Empty;$' 0

# This is not a blanket VRCUrl.Empty ban. Runtime sentinel returns, resets, and
# assignments remain valid and must not be swept into the initializer fix.
require_text "$CONSTRAINTS" 'default: return VRCUrl.Empty;'
require_text "$CONSTRAINTS" 'SetUrlAtIndex(_metadataList.Count, VRCUrl.Empty);'
require_text "$VIDEO" 'if (_queueUrls[i] == null) _queueUrls[i] = VRCUrl.Empty;'

if [ "$FAILURES" -ne 0 ]; then
    printf 'FAIL: %s VRCUrl.Empty initializer contract assertion(s) failed\n' "$FAILURES" >&2
    exit 1
fi

printf 'PASS: VRCUrl.Empty field initializer contract\n'
