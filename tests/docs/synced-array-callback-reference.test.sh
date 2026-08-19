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
require_text "$RULES" "late joiner's first \`OnDeserialization()\`"
require_text "$RULES" 'baseline'
require_text "$RULES" 'historical one-shot side effect'

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
require_text "$NETWORKING" 'first received revision as a baseline'
require_text "$NETWORKING" 'historical one-shot effects'
require_text "$NETWORKING" 'class RevisionGuardedArray'

# Every user-facing surface should route array reactions through
# OnDeserialization, while keeping scalar FieldChangeCallback guidance intact.
require_text "$SYNC_EXAMPLES" 'Array values: use OnDeserialization, not FieldChangeCallback'
require_text "$SYNC_EXAMPLES" 'same length, reassigning the array, or changing its length'
require_text "$TROUBLESHOOTING" '### Synced Array Callback Silent Failure'
require_text "$TROUBLESHOOTING" 'same-length element changes, array reassignments, and array length changes'
require_text "$TROUBLESHOOTING" 'ApplyValues()'
require_text "$TROUBLESHOOTING" 'late joiner'
require_text "$TROUBLESHOOTING" 'baseline'
require_text "$CHEATSHEET" 'Array contents changed: use `OnDeserialization()`'
require_text "$CHEATSHEET" 'late joiner'
require_text "$CHEATSHEET" 'baseline'
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

# Check the executable shape of the canonical example and the two existing
# array examples. Presence checks alone cannot detect a callback deleted from
# a receiver, an owner apply deleted before serialization, or a request moved
# into the element-update loop.
python3 - "$RULES" "$NETWORKING" "$SYNC_EXAMPLES" "$PATTERNS" "$TROUBLESHOOTING" <<'PY'
from pathlib import Path
import re
import sys


def fail(message: str) -> None:
    print(f"ERROR: structural contract: {message}", file=sys.stderr)
    raise SystemExit(1)


def csharp_blocks(path: Path) -> list[str]:
    return re.findall(r"```csharp\s*\n(.*?)```", path.read_text(), re.S)


def class_block(path: Path, class_name: str) -> str:
    for block in csharp_blocks(path):
        if f"class {class_name}" in block:
            return block
    fail(f"class {class_name} not found in {path}")


def method_block(source: str, signature: str) -> str:
    start = source.find(signature)
    if start < 0:
        fail(f"method {signature} not found")
    brace = source.find("{", start)
    if brace < 0:
        fail(f"method {signature} has no body")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    fail(f"method {signature} has an unterminated body")


def balanced_block(source: str, opening: int) -> str:
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : index + 1]
    fail("unterminated nested block")


def assert_order(label: str, source: str, *needles: str) -> None:
    positions = []
    for needle in needles:
        position = source.find(needle)
        if position < 0:
            fail(f"{label} is missing {needle!r}")
        positions.append(position)
    if positions != sorted(positions):
        fail(f"{label} is not ordered as {needles!r}")


rules = Path(sys.argv[1])
networking = Path(sys.argv[2])
sync_examples = Path(sys.argv[3])
patterns = Path(sys.argv[4])
troubleshooting = Path(sys.argv[5])

canonical = class_block(rules, "SyncedArrayExample")
canonical_owner = method_block(canonical, "public override void Interact()")
loop_start = re.search(r"\bfor\s*\([^{}\n]*?\)[ \t]*", canonical_owner)
if not loop_start:
    fail("canonical owner has no element update loop")
loop_body_start = loop_start.end()
while loop_body_start < len(canonical_owner) and canonical_owner[loop_body_start].isspace():
    loop_body_start += 1
if canonical_owner.startswith("{", loop_body_start):
    loop = balanced_block(canonical_owner, loop_body_start)
    loop_end = loop_body_start + len(loop)
else:
    newline = canonical_owner.find("\n", loop_body_start)
    if newline < 0:
        fail("canonical owner loop has no body line")
    loop = canonical_owner[loop_body_start:newline]
    loop_end = newline
if "_syncedValues[i] =" not in loop:
    fail("canonical owner loop does not update every element")
if "RequestSerialization();" in loop:
    fail("canonical owner requests serialization inside the element loop")
assert_order(
    "canonical owner",
    canonical_owner[loop_end:],
    "ApplyValues();",
    "RequestSerialization();",
)
if canonical_owner.count("RequestSerialization();") != 1:
    fail("canonical owner must request serialization exactly once")
canonical_receiver = method_block(canonical, "public override void OnDeserialization()")
if "ApplyValues();" not in canonical_receiver:
    fail("canonical receiver does not apply from OnDeserialization")

networking_class = class_block(networking, "SyncedArrayReceiver")
networking_setter = method_block(networking_class, "public void _SetValues(int[] values)")
assert_order(
    "networking _SetValues null guard",
    networking_setter,
    "if (values == null) return;",
    "if (!Networking.IsOwner(gameObject))",
    "_syncedValues = values;",
)
troubleshooting_source = "\n".join(csharp_blocks(troubleshooting))
troubleshooting_setter = method_block(
    troubleshooting_source,
    "public void _SetValues(int[] values)",
)
assert_order(
    "troubleshooting _SetValues null guard",
    troubleshooting_setter,
    "if (values == null) return;",
    "if (!Networking.IsOwner(gameObject))",
    "_syncedValues = values;",
)

vote = class_block(sync_examples, "VoteSystemCore")
vote_owner = method_block(vote, "public void _VoteToYes()")
assert_order(
    "vote owner",
    vote_owner,
    "SyncedVoterPlayerIds[SyncedVoterCount] = caller.playerId;",
    "SyncedVoterCount++;",
    "++SyncedYesCount;",
    "RefreshCount();",
    "RequestSerialization();",
)
vote_receiver = method_block(vote, "public override void OnDeserialization()")
if "RefreshCount();" not in vote_receiver:
    fail("vote receiver no longer refreshes from OnDeserialization")

revision = class_block(networking, "RevisionGuardedArray")
revision_owner = method_block(revision, "public void _SetValues(int[] values)")
assert_order(
    "revision owner",
    revision_owner,
    "_revision++;",
    "ApplyValues();",
    "ApplyOneShotIfNeeded();",
    "RequestSerialization();",
)
revision_receiver = method_block(
    revision,
    "public override void OnDeserialization()",
)
assert_order(
    "revision receiver baseline",
    revision_receiver,
    "ApplyValues();",
    "ApplyOneShotIfNeeded();",
)
if "PlayOneShot();" in revision_receiver:
    fail("revision receiver must delegate one-shot handling to ApplyOneShotIfNeeded()")
revision_helper = method_block(revision, "private void ApplyOneShotIfNeeded()")
assert_order(
    "revision helper",
    revision_helper,
    "if (!_hasAppliedRevision)",
    "_appliedRevision = _revision;",
    "return;",
    "PlayOneShot();",
)

playlist = class_block(patterns, "SyncedPlaylist")
playlist_owner = method_block(playlist, "public void SetTitles(string[] titles)")
assert_order(
    "playlist owner",
    playlist_owner,
    "_syncedTitles = JoinForSync(_titles);",
    "OnPlaylistUpdated();",
    "RequestSerialization();",
)
if playlist_owner.count("RequestSerialization();") != 1:
    fail("playlist owner must request serialization exactly once")
playlist_receiver = method_block(playlist, "public override void OnDeserialization()")
assert_order(
    "playlist receiver",
    playlist_receiver,
    "_titles = SplitFromSync(_syncedTitles);",
    "OnPlaylistUpdated();",
)

# This scanner deliberately spans newlines across consecutive attributes and
# the array declaration. A one-line grep misses the mutation it is intended
# to reject. Keep one malformed multiline fixture as a self-test of the
# scanner itself, then scan every active Markdown C# block in the skill.
array_declaration = re.compile(
    r"(?P<attributes>(?:\s*\[[^\]]+\]\s*)+)"
    r"(?P<declaration>(?:public|private|protected|internal)?\s*"
    r"[A-Za-z_][A-Za-z0-9_<>.,?]*\s*\[\s*\]\s+"
    r"[A-Za-z_][A-Za-z0-9_]*\s*(?:=[^;]*)?;)",
    re.S,
)


def forbidden_array_declarations(source: str) -> list[str]:
    return [
        match.group(0)
        for match in array_declaration.finditer(source)
        if "UdonSynced" in match.group("attributes")
        and "FieldChangeCallback" in match.group("attributes")
    ]


bad_fixture = """[UdonSynced,\n    FieldChangeCallback(nameof(Values))]\nprivate int[] _values;"""
if not forbidden_array_declarations(bad_fixture):
    fail("multiline array callback scanner self-test did not detect its fixture")

skill_root = rules.parents[1]
for path in skill_root.rglob("*.md"):
    for block in csharp_blocks(path):
        if forbidden_array_declarations(block):
            fail(f"FieldChangeCallback is attached to a synced array declaration in {path}")
for path in skill_root.rglob("*.cs"):
    if forbidden_array_declarations(path.read_text()):
        fail(f"FieldChangeCallback is attached to a synced array declaration in {path}")

print("PASS: canonical, vote, playlist, null-guard, and multiline-array structural contracts")
PY

# Regression-check the existing contributor census and all five README copies;
# this Issue is already represented there and should not cause doc churn.
bash "$ROOT_DIR/tests/docs/community-contributors.test.sh"

echo 'PASS: synced array callback and VRCUrl[] reference contract'
