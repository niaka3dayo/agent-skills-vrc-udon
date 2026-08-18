#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

SKILL="skills/unity-vrc-udon-sharp/SKILL.md"
CONSTRAINTS="skills/unity-vrc-udon-sharp/references/constraints.md"
VIDEO="skills/unity-vrc-udon-sharp/references/patterns-video.md"

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

# Entry-point guidance must surface the anti-pattern, while the detailed
# reference explains the aliasing boundary and the fresh-instance alternative.
require_text "$SKILL" 'VRCUrl.Empty'
require_text "$SKILL" 'new VRCUrl("")'
require_text "$CONSTRAINTS" '`VRCUrl.Empty` returns a shared instance'
require_text "$CONSTRAINTS" 'serialized or synced field'
require_text "$CONSTRAINTS" 'each array element'
require_text "$CONSTRAINTS" '[SerializeField] private VRCUrl[] _urls = new VRCUrl[]'

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
