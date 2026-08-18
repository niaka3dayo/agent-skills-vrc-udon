#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UDON_DIR="$ROOT_DIR/skills/unity-vrc-udon-sharp"
RULES="$UDON_DIR/rules/udonsharp-networking.md"
NETWORKING="$UDON_DIR/references/networking.md"
SYNC_EXAMPLES="$UDON_DIR/references/sync-examples.md"
TROUBLESHOOTING="$UDON_DIR/references/troubleshooting.md"
CHEATSHEET="$UDON_DIR/CHEATSHEET.md"
SKILL="$UDON_DIR/SKILL.md"
CONSTRAINTS="$UDON_DIR/references/constraints.md"
PATTERNS="$UDON_DIR/references/patterns-networking.md"

require_text() {
    local path="$1"
    local needle="$2"
    if ! grep -Fq -- "$needle" "$path"; then
        echo "ERROR: $path does not contain expected text: $needle" >&2
        exit 1
    fi
}

forbid_text() {
    local path="$1"
    local needle="$2"
    local recursive=()
    if [ -d "$path" ]; then
        recursive=(-R)
    fi
    if grep "${recursive[@]}" -Fq -- "$needle" "$path"; then
        echo "ERROR: $path contains obsolete text: $needle" >&2
        exit 1
    fi
}

# Keep one canonical, idempotent array-receiver contract in the always-loaded
# rules. The three mutation shapes are intentionally listed separately so a
# future edit cannot make only length changes sound exceptional.
require_text "$RULES" '### Synced Arrays: OnDeserialization Is the Receiver Hook'
require_text "$RULES" 'same-length element changes'
require_text "$RULES" 'array reassignments'
require_text "$RULES" 'array length changes'
require_text "$RULES" 'must not depend on `FieldChangeCallback`'
require_text "$RULES" 'the same idempotent `ApplyValues()` method'
require_text "$RULES" '[UdonSynced] private int[] _syncedValues = new int[4];'
require_text "$RULES" 'public override void OnDeserialization()'
require_text "$RULES" 'RequestSerialization();'
require_text "$RULES" 'revision is only an optional guard for non-idempotent side effects'
require_text "$RULES" 'does not provide ordering or stale-packet rejection'

# The detailed reference must point to the two official examples and preserve
# the owner-immediate/remote-deserialization split.
require_text "$NETWORKING" 'https://creators.vrchat.com/worlds/udon/networking/network-components/#onvariablechanged'
require_text "$NETWORKING" 'https://creators.vrchat.com/worlds/examples/udon-example-scene/'
require_text "$NETWORKING" 'same-length element changes'
require_text "$NETWORKING" 'array reassignments'
require_text "$NETWORKING" 'array length changes'
require_text "$NETWORKING" 'owner applies the same idempotent method immediately'
require_text "$NETWORKING" 'remote clients apply it from `OnDeserialization()`'
require_text "$NETWORKING" 'one `RequestSerialization()` after the complete array update'
require_text "$NETWORKING" 'revision does not establish ordering'
require_text "$NETWORKING" '[UdonSynced] private int _revision;'
require_text "$NETWORKING" 'ApplyOneShotIfNeeded()'

# Every user-facing surface should route array reactions through
# OnDeserialization, while keeping scalar FieldChangeCallback guidance intact.
require_text "$SYNC_EXAMPLES" 'Array values: use OnDeserialization, not FieldChangeCallback'
require_text "$SYNC_EXAMPLES" 'same length, reassigning the array, or changing its length'
require_text "$TROUBLESHOOTING" '### Synced Array Callback Silent Failure'
require_text "$TROUBLESHOOTING" 'same-length element changes, array reassignments, and array length changes'
require_text "$TROUBLESHOOTING" 'ApplyValues()'
require_text "$CHEATSHEET" 'Array contents changed: use `OnDeserialization()`'
require_text "$SKILL" 'Synced arrays: always apply them from `OnDeserialization()`'

# VRCUrl[] is a supported sync type. The old workaround wording must not
# return in any distributed UdonSharp document.
require_text "$CONSTRAINTS" '`VRCUrl[]` syncs like any other supported array type.'
require_text "$CONSTRAINTS" 'Fixed slots bound capacity and make the maximum list size explicit'
forbid_text "$CONSTRAINTS" '(array sync not supported)'
forbid_text "$UDON_DIR" 'array sync not supported'

# A single Manual request is made after a batch update; element-by-element
# writes do not imply multiple deserialization callbacks.
require_text "$PATTERNS" 'one `RequestSerialization()` after all elements are updated'
require_text "$PATTERNS" 'OnDeserialization runs after the serialized snapshot is applied'
forbid_text "$PATTERNS" 'produces multiple `OnDeserialization` callbacks'

# Never reintroduce FieldChangeCallback on a synced array declaration while
# scalar callback examples remain allowed.
if grep -RInE '\[UdonSynced[^]]*FieldChangeCallback[^]]*\][[:space:]]*[^\n;]*\[\]' "$UDON_DIR" \
    --include='*.md' --include='*.cs'; then
    echo 'ERROR: FieldChangeCallback is attached to a synced array declaration' >&2
    exit 1
fi

# Regression-check the existing contributor census and all five README copies;
# this Issue is already represented there and should not cause doc churn.
bash "$ROOT_DIR/tests/docs/community-contributors.test.sh"

echo 'PASS: synced array callback and VRCUrl[] reference contract'
