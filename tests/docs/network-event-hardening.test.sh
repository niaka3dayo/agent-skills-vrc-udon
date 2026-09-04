#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UDON_DIR="$ROOT_DIR/skills/unity-vrc-udon-sharp"
WORLD_DIR="$ROOT_DIR/skills/unity-vrc-world-sdk-3"
WORLD_SKILL="$WORLD_DIR/SKILL.md"
RULE="$UDON_DIR/rules/udonsharp-networking.md"
CONSTRAINTS_RULE="$UDON_DIR/rules/udonsharp-constraints.md"
NETWORKING_REF="$UDON_DIR/references/networking.md"
API_REF="$UDON_DIR/references/api.md"
PATTERNS_REF="$UDON_DIR/references/patterns-networking.md"
BANDWIDTH_REF="$UDON_DIR/references/networking-bandwidth.md"
MIGRATION_REF="$UDON_DIR/references/sdk-migration.md"
TROUBLESHOOTING_REF="$UDON_DIR/references/troubleshooting.md"
SYNC_EXAMPLES="$UDON_DIR/references/sync-examples.md"
DYNAMICS_REF="$UDON_DIR/references/dynamics.md"
ADVANCED_WEB_REF="$UDON_DIR/references/web-loading-advanced.md"
CHEATSHEET="$UDON_DIR/CHEATSHEET.md"
UNDO_TEMPLATE="$UDON_DIR/assets/templates/UndoableGameManager.cs"
POOL_TEMPLATE="$UDON_DIR/assets/templates/MasterManagedPlayerPool.cs"
BATCH_TEMPLATE="$UDON_DIR/assets/templates/BatchedSync.cs"
EVENTS_REF="$UDON_DIR/references/events.md"
PUBLIC_METHOD_AUDIT="$ROOT_DIR/tests/docs/audit-udon-public-methods.py"
PUBLIC_METHOD_AUDIT_TEST="$ROOT_DIR/tests/docs/audit-udon-public-methods.test.sh"
CONTRIBUTING="$ROOT_DIR/CONTRIBUTING.md"
CI="$ROOT_DIR/.github/workflows/ci.yml"
README_EN="$ROOT_DIR/README.md"
README_JA="$ROOT_DIR/README.ja.md"
README_KO="$ROOT_DIR/README.ko.md"
README_ZH_CN="$ROOT_DIR/README.zh-CN.md"
README_ZH_TW="$ROOT_DIR/README.zh-TW.md"
AGENTS_TEMPLATE="$ROOT_DIR/templates/AGENTS.md"
CLAUDE_TEMPLATE="$ROOT_DIR/templates/CLAUDE.md"
GEMINI_TEMPLATE="$ROOT_DIR/templates/GEMINI.md"

require_text() {
    local path="$1"
    local needle="$2"
    if ! grep -Fq "$needle" "$path"; then
        echo "ERROR: $path does not contain expected text: $needle" >&2
        exit 1
    fi
}

forbid_regex() {
    local path="$1"
    local pattern="$2"
    local recursive=()
    if [ -d "$path" ]; then
        recursive=(-R)
    fi
    if grep "${recursive[@]}" -Eiq "$pattern" "$path"; then
        echo "ERROR: $path contains forbidden pattern: $pattern" >&2
        grep "${recursive[@]}" -Ein "$pattern" "$path" >&2
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
    if grep "${recursive[@]}" -Fq "$needle" "$path"; then
        echo "ERROR: $path contains forbidden text: $needle" >&2
        exit 1
    fi
}

require_order() {
    local path="$1"
    local first="$2"
    local second="$3"
    local first_line
    local second_line
    first_line="$(grep -nF "$first" "$path" | head -1 | cut -d: -f1 || true)"
    second_line="$(grep -nF "$second" "$path" | head -1 | cut -d: -f1 || true)"
    if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
        echo "ERROR: $path must contain '$first' before '$second'" >&2
        exit 1
    fi
}

require_string_order() {
    local haystack="$1"
    local first="$2"
    local second="$3"
    local first_line
    local second_line
    first_line="$(grep -nF "$first" <<<"$haystack" | head -1 | cut -d: -f1 || true)"
    second_line="$(grep -nF "$second" <<<"$haystack" | head -1 | cut -d: -f1 || true)"
    if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
        echo "ERROR: source section must contain '$first' before '$second'" >&2
        exit 1
    fi
}

require_count() {
    local path="$1"
    local needle="$2"
    local expected="$3"
    local actual
    actual="$(grep -Fc "$needle" "$path" || true)"
    if [ "$actual" -ne "$expected" ]; then
        echo "ERROR: $path contains '$needle' $actual times; expected $expected" >&2
        exit 1
    fi
}

# v2.6.0 consumer migration guidance must ship with the packaged World Skill.
for mapping in \
    '| `ForceDropPickup` | `_ForceDropPickup` |' \
    '| `IsHeld` | `_IsHeld` |' \
    '| `IsOccupied` | `_IsOccupied` |' \
    '| `StopSound` | `_StopSound` |' \
    '| `SlowUpdate` | `_SlowUpdate` |'; do
    require_text "$WORLD_SKILL" "$mapping"
done
for phrase in 'Inspector event strings' '`SendCustomEvent*` calls' \
    'delayed events' '`nameof(...)` expressions' 'cross-behaviour calls' \
    'Compatibility aliases are' 'legacy network exposure'; do
    require_text "$WORLD_SKILL" "$phrase"
done

OLD_LOCAL_COMMENT='Leading underscore keeps this public custom event callable locally while blocking legacy network dispatch.'
NEW_LOCAL_COMMENT='Leading underscore keeps this public member available to local code while blocking legacy network dispatch.'
forbid_text "$WORLD_DIR" "$OLD_LOCAL_COMMENT"
LOCAL_COMMENT_COUNT="$(grep -RF "$NEW_LOCAL_COMMENT" "$WORLD_DIR" | wc -l)"
if [ "$LOCAL_COMMENT_COUNT" -ne 5 ]; then
    echo "ERROR: expected 5 accurate local-member comments, found $LOCAL_COMMENT_COUNT" >&2
    exit 1
fi

# Bash validator prerequisites and fail-open behavior are user-visible in every
# packaged entrypoint, including translated READMEs.
for path in "$UDON_DIR/SKILL.md" "$README_EN" "$README_JA" "$README_KO" \
    "$README_ZH_CN" "$README_ZH_TW"; do
    require_text "$path" '`jq`'
    require_text "$path" 'VALIDATOR-WARNING'
    require_text "$path" 'JQ_UNAVAILABLE'
done

# Current support declarations must agree on the sole active SDK 3.10.5 target.
require_text "$CONTRIBUTING" "**Active and verified target**: SDK 3.10.5"
require_text "$CONSTRAINTS_RULE" "**Active support / last verified**: SDK 3.10.5"
require_text "$RULE" "**Active support / last verified**: SDK 3.10.5"

# Historical, version-specific evidence must not be rewritten as current coverage.
require_text "$API_REF" "observed in the SDK 3.10.3 Udon wrapper symbols"

# Deprecated UdonSharp API names must not remain in the packaged skill.
forbid_text "$UDON_DIR" 'VRCInstantiate'

# Exact normative contracts: replacing any sentence with its inverse must fail.
LEGACY_SENTENCE='A parameterless public UdonSharp method whose name does not start with `_` remains exposed to legacy `SendCustomNetworkEvent` calls even without `[NetworkCallable]`.'
UNDERSCORE_SENTENCE='A leading underscore blocks legacy network calls to a public method.'
ATTRIBUTE_SENTENCE='`[NetworkCallable]` explicitly exposes an underscore-prefixed public method to network calls.'
LIFETIME_SENTENCE='`NetworkCalling.InNetworkCall` remains true through nested methods and cross-behaviour calls until the network entry method returns.'
OUTSIDE_SENTENCE='`NetworkCalling.CallingPlayer` is null or invalid outside a network call.'
SEPARATION_SENTENCE='Caller authorization and receiver ownership are separate checks: authorize `NetworkCalling.CallingPlayer`, then use `Networking.IsOwner(gameObject)` to guard synced mutation on the receiver.'

for path in "$RULE" "$NETWORKING_REF"; do
    require_text "$path" "$LEGACY_SENTENCE"
    require_text "$path" "$UNDERSCORE_SENTENCE"
    require_text "$path" "$ATTRIBUTE_SENTENCE"
    require_text "$path" "$LIFETIME_SENTENCE"
    require_text "$path" "$OUTSIDE_SENTENCE"
    require_text "$path" "$SEPARATION_SENTENCE"
    forbid_text "$path" 'A leading underscore does not block legacy network calls to a public method.'
    forbid_text "$path" '`NetworkCalling.CallingPlayer` is valid outside a network call.'
    forbid_text "$path" 'Caller authorization and receiver ownership are the same check.'
done

# Legacy dispatch and NetworkCallable signatures are described precisely.
LEGACY_RETURN_SENTENCE='A legacy parameterless public method may return a value, but remote dispatch discards that value; the method remains network attack surface and the audit includes it.'
NETWORK_CALLABLE_VOID_SENTENCE='A `[NetworkCallable]` method must return `void`.'
PRE_381_SENTENCE='SDKs before 3.8.1 do not define the `NetworkCallable` attribute or parameterized network-event API, so code that uses them normally fails to compile.'
for path in "$RULE" "$NETWORKING_REF"; do
    require_text "$path" "$LEGACY_RETURN_SENTENCE"
done
for path in "$UDON_DIR/SKILL.md" "$RULE" "$NETWORKING_REF" "$MIGRATION_REF" "$CHEATSHEET"; do
    require_text "$path" "$NETWORK_CALLABLE_VOID_SENTENCE"
done
for path in "$UDON_DIR/SKILL.md" "$NETWORKING_REF" "$MIGRATION_REF"; do
    require_text "$path" "$PRE_381_SENTENCE"
done
forbid_text "$ADVANCED_WEB_REF" 'UdonSharp blocks out parameters in user-defined methods; use fields instead.'
forbid_regex "$UDON_DIR" 'NetworkCallable.*compiles but.*ignored|compiles but.*NetworkCallable.*ignored'

# Prove the exact-sentence gate rejects an inverted contract.
INVERTED_FIXTURE="$(mktemp)"
trap 'rm -f "$INVERTED_FIXTURE"' EXIT
printf '%s\n' 'A leading underscore does not block legacy network calls to a public method.' > "$INVERTED_FIXTURE"
if (require_text "$INVERTED_FIXTURE" "$UNDERSCORE_SENTENCE") 2>/dev/null; then
    echo "ERROR: exact normative sentence gate accepted an inverted sentence" >&2
    exit 1
fi

require_text "$API_REF" "NetworkCalling.CallingPlayer"
require_text "$API_REF" "NetworkCalling.InNetworkCall"
require_text "$API_REF" "null"
require_text "$NETWORKING_REF" "https://creators.vrchat.com/worlds/udon/networking/events/"
for path in "$RULE" "$NETWORKING_REF"; do
    require_text "$path" 'Instance master is for gameplay/session arbitration, not security or access control.'
done

# Privileged, damage, and move examples derive the caller from the active call context.
for path in "$PATTERNS_REF" "$BANDWIDTH_REF" "$UNDO_TEMPLATE"; do
    require_text "$path" "NetworkCalling.CallingPlayer"
    require_text "$path" "NetworkCalling.InNetworkCall"
done

for path in "$RULE" "$NETWORKING_REF" "$PATTERNS_REF" "$MIGRATION_REF" "$CHEATSHEET"; do
    forbid_regex "$path" 'TakeDamage\([^)]*attackerId'
    forbid_regex "$path" 'caller\.isMaster'
done
for path in "$RULE" "$NETWORKING_REF" "$PATTERNS_REF" "$MIGRATION_REF" "$CHEATSHEET"; do
    require_text "$path" 'VRCPlayerApi owner = Networking.GetOwner(gameObject);'
    require_text "$path" 'caller.playerId != owner.playerId'
    require_text "$path" 'Networking.IsOwner(gameObject)'
done
require_text "$UNDO_TEMPLATE" 'VRCPlayerApi owner = Networking.GetOwner(gameObject);'
require_text "$UNDO_TEMPLATE" 'return caller.playerId == owner.playerId;'
require_text "$UNDO_TEMPLATE" 'Networking.IsOwner(gameObject)'
forbid_regex "$BANDWIDTH_REF" 'OwnerProcessMove\([^)]*playerId'
forbid_regex "$BANDWIDTH_REF" 'caller\.isMaster'
forbid_regex "$UNDO_TEMPLATE" 'OwnerProcessMove\([^)]*playerId'
forbid_regex "$UNDO_TEMPLATE" 'caller\.isMaster'

# Package-wide public method exposure classifications are structurally audited.
bash "$PUBLIC_METHOD_AUDIT_TEST"
python3 "$PUBLIC_METHOD_AUDIT" "$UDON_DIR"
python3 "$PUBLIC_METHOD_AUDIT" "$WORLD_DIR"
forbid_text "$UDON_DIR" '// NETWORK-EXPOSURE: LEGACY'

# Security-sensitive examples use attributed underscore entries and explicit policies.
require_text "$SYNC_EXAMPLES" '[NetworkCallable(1)]'
require_text "$SYNC_EXAMPLES" 'public void _VoteToYes()'
require_text "$SYNC_EXAMPLES" 'if (!NetworkCalling.InNetworkCall) return;'
require_text "$SYNC_EXAMPLES" 'VRCPlayerApi caller = NetworkCalling.CallingPlayer;'
require_text "$SYNC_EXAMPLES" 'if (!Networking.IsOwner(gameObject)) return;'
require_text "$SYNC_EXAMPLES" 'SyncedVoterPlayerIds'
require_text "$SYNC_EXAMPLES" 'if (SyncedVoterPlayerIds[i] == caller.playerId) return;'
require_text "$SYNC_EXAMPLES" 'Ownership routing chooses the receiver; it does not authorize the caller.'
for entry in _Hit _Unlock _AddCount; do
    require_text "$SYNC_EXAMPLES" "public void ${entry}()"
done
require_text "$API_REF" 'public void _OwnerSpawn()'
require_text "$API_REF" 'public void _PlayDolly()'
require_text "$DYNAMICS_REF" 'public void _DoButtonAction()'
for path in "$SYNC_EXAMPLES" "$API_REF" "$DYNAMICS_REF"; do
    require_text "$path" 'NetworkCalling.CallingPlayer'
    require_text "$path" 'NetworkCalling.InNetworkCall'
done
require_text "$API_REF" 'Any valid caller may request one available pooled object; this is an open interaction policy.'
require_text "$API_REF" 'Any valid caller may start this local-only cosmetic effect. The'
require_text "$DYNAMICS_REF" 'Any valid caller may trigger this diagnostic effect. The local'

# Master coordination is limited to non-security session arbitration.
forbid_regex "$UDON_DIR" 'banlist-style|Master-approved|master-backed'
require_text "$PATTERNS_REF" 'Instance master may coordinate capacity or a fair lottery, but master status can change and does not grant access-control authority.'
require_text "$PATTERNS_REF" 'Use an explicit owner-controlled session role policy or platform moderation primitives for exclusions and privileged actions.'

# Old unprefixed method names must not return in prose or code.
for stale_name in OwnerProcessMove OwnerUndo OwnerReset VerifyAssignments; do
    if grep -R -En "(^|[^A-Za-z0-9_])${stale_name}" "$UDON_DIR"; then
        echo "ERROR: stale method name remains: $stale_name" >&2
        exit 1
    fi
done
UNSAFE_AUDIT_FIXTURE="$(mktemp -d)"
trap 'rm -f "$INVERTED_FIXTURE"; rm -rf "$UNSAFE_AUDIT_FIXTURE"' EXIT
printf '%s\n' 'public class UnsafeExample { public void PrivilegedHelper() { } }' > "$UNSAFE_AUDIT_FIXTURE/unsafe.cs"
if python3 "$PUBLIC_METHOD_AUDIT" "$UNSAFE_AUDIT_FIXTURE" >/dev/null 2>&1; then
    echo "ERROR: public method audit accepted an unsafe legacy exposure" >&2
    exit 1
fi

# Receiver input and operational bounds are executable examples, not comments.
require_text "$PATTERNS_REF" 'private const int MaxMessageLength = 256;'
require_text "$PATTERNS_REF" 'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;'
require_text "$PATTERNS_REF" "The 256-character maximum is this receiver example's policy, not a VRChat platform limit."
require_text "$PATTERNS_REF" $'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;\n\n        messageText.text = $"{caller.displayName}: {message}";'
require_text "$PATTERNS_REF" $'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;\n\n        messages[messageIndex] = $"[{caller.displayName}] {message}";'
require_text "$NETWORKING_REF" 'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;'
require_text "$NETWORKING_REF" "The 256-character maximum is this receiver example's policy, not a VRChat platform limit."
require_text "$NETWORKING_REF" $'if (localPlayer.playerId != targetPlayerId) return;\n\n        _ProcessMessage(message, caller);'
forbid_regex "$PATTERNS_REF" 'hitPosition'

require_text "$MIGRATION_REF" 'if (damage <= 0 || damage > 25) return;'
require_text "$MIGRATION_REF" 'VRCPlayerApi owner = Networking.GetOwner(gameObject);'
require_text "$MIGRATION_REF" 'caller.playerId != owner.playerId'

require_text "$UNDO_TEMPLATE" 'private const int MaxMoves = 100;'
require_text "$UNDO_TEMPLATE" 'stateHistory = new byte[stateSize * (MaxMoves + 1)];'
require_text "$UNDO_TEMPLATE" 'if (historyCount >= MaxMoves + 1) return;'
require_order "$UNDO_TEMPLATE" 'if (historyCount >= MaxMoves + 1) return;' '_ExecuteMove(from, to);'

require_text "$BANDWIDTH_REF" 'private const int BoardSize = 9;'
require_text "$BANDWIDTH_REF" '[UdonSynced] private int[] boardState = new int[BoardSize];'
require_text "$BANDWIDTH_REF" '[UdonSynced] private int currentTurnPlayerId = -1;'
require_text "$BANDWIDTH_REF" 'public void _StartTwoPlayerSession(int firstPlayerId, int secondPlayerId)'
require_text "$BANDWIDTH_REF" 'currentTurnPlayerId = playerOneId;'
require_text "$BANDWIDTH_REF" 'if (boardState == null || boardState.Length != BoardSize) return;'
require_text "$BANDWIDTH_REF" 'if (caller.playerId != currentTurnPlayerId) return;'
require_text "$BANDWIDTH_REF" 'currentTurnPlayerId = currentTurn == 1 ? playerOneId : playerTwoId;'
require_order "$BANDWIDTH_REF" 'if (boardState == null || boardState.Length != BoardSize) return;' 'if (cellIndex < 0 || cellIndex >= BoardSize) return;'
require_order "$BANDWIDTH_REF" 'if (cellIndex < 0 || cellIndex >= BoardSize) return;' 'boardState[cellIndex] = currentTurn;'

# SDK 3.10.4 master-transfer callback and manager-owned pool identity.
forbid_text "$UDON_DIR" 'OnMasterClientSwitched'
require_text "$POOL_TEMPLATE" 'public override void OnMasterTransferred(VRCPlayerApi newMaster)'
require_text "$PATTERNS_REF" '`OnMasterTransferred(VRCPlayerApi)` rebuilds the free queue'
require_text "$POOL_TEMPLATE" 'Networking.SetOwner(Networking.LocalPlayer, gameObject);'
require_text "$POOL_TEMPLATE" 'if (!Networking.IsMaster || !Networking.IsOwner(gameObject)) return;'
require_text "$POOL_TEMPLATE" 'public override void OnOwnershipTransferred(VRCPlayerApi newOwner)'
require_text "$POOL_TEMPLATE" 'SendCustomEventDelayedSeconds(nameof(_VerifyAssignments), 2f);'
ACQUIRE_BODY="$(awk '
    /private void _AcquireManagerOwnership\(\)/ { in_method = 1 }
    /private void _EstablishCoordinator\(\)/ { exit }
    in_method { print }
' "$POOL_TEMPLATE")"
require_string_order "$ACQUIRE_BODY" 'Networking.SetOwner(Networking.LocalPlayer, gameObject);' '_EstablishCoordinator();'
require_count "$POOL_TEMPLATE" 'if (!Networking.IsMaster || !Networking.IsOwner(gameObject)) return;' 8
require_count "$POOL_TEMPLATE" 'RequestSerialization();' 1
ASSIGNMENT_WRITE_COUNT="$(grep -Ec '_assignments(\[[^]]+\])? = ' "$POOL_TEMPLATE" || true)"
if [ "$ASSIGNMENT_WRITE_COUNT" -ne 6 ]; then
    echo "ERROR: assignment mutation inventory changed; review every write guard" >&2
    exit 1
fi
require_text "$POOL_TEMPLATE" 'private void _ApplyAssignmentsLocally()'
require_count "$POOL_TEMPLATE" '_ApplyAssignmentsLocally();' 9
require_order "$POOL_TEMPLATE" '_previousAssignments = new int[poolSize];' '_ApplyAssignmentsLocally();'
POOL_APPLY_BODY="$(awk '
    /private void _ApplyAssignmentsLocally\(\)/ { in_method = 1 }
    /private void _ActivateSlot\(/ { exit }
    in_method { print }
' "$POOL_TEMPLATE")"
require_text <(printf '%s\n' "$POOL_APPLY_BODY") '_previousAssignments[i] = newId;'
require_text <(printf '%s\n' "$POOL_APPLY_BODY") '_ActivateSlot(i, player);'
require_text <(printf '%s\n' "$POOL_APPLY_BODY") '_DeactivateSlot(i);'
POOL_DESERIALIZATION_BODY="$(awk '
    /public override void OnDeserialization\(\)/ { in_method = 1 }
    /public override void OnMasterTransferred\(/ { exit }
    in_method { print }
' "$POOL_TEMPLATE")"
require_text <(printf '%s\n' "$POOL_DESERIALIZATION_BODY") '_ApplyAssignmentsLocally();'
POOL_SERIALIZE_BODY="$(awk '
    /private void _SerializeAssignments\(\)/ { in_method = 1 }
    in_method { print }
' "$POOL_TEMPLATE")"
forbid_text <(printf '%s\n' "$POOL_SERIALIZE_BODY") '_ApplyAssignmentsLocally();'
forbid_text "$PATTERNS_REF" 'The instance master owns all assignment logic'
require_text "$PATTERNS_REF" 'manager GameObject ownership is the write authority'
require_text "$API_REF" '[UdonSynced] private int[] assignedPlayerIds;'
require_text "$API_REF" 'assignedPlayerIds = new int[objectPool.Pool.Length];'
require_text "$API_REF" 'int poolIndex = _FindPoolIndex(spawned);'
require_text "$API_REF" 'assignedPlayerIds[poolIndex] = player.playerId;'
require_text "$API_REF" 'int poolIndex = _FindAssignedPoolIndex(player.playerId);'
require_text "$API_REF" 'GameObject pooledObject = objectPool.Pool[poolIndex];'
require_text "$API_REF" 'Networking.SetOwner(Networking.LocalPlayer, pooledObject);'
require_text "$API_REF" 'assignedPlayerIds[poolIndex] = 0;'
require_order "$API_REF" 'assignedPlayerIds[poolIndex] = player.playerId;' 'Networking.SetOwner(player, spawned);'
require_order "$API_REF" 'assignedPlayerIds[poolIndex] = 0;' 'objectPool.Return(pooledObject);'
forbid_text "$API_REF" 'pooledBehaviour.Owner == player'

# Authoritative local changes update the owner's display before serialization,
# while deserialization reuses the same idempotent display path.
require_text "$UNDO_TEMPLATE" 'private void _ApplyDisplayLocally()'
require_count "$UNDO_TEMPLATE" '_ApplyDisplayLocally();' 5
require_order "$UNDO_TEMPLATE" '_SaveStateToHistory(); // Initial state = history[0]' '_ApplyDisplayLocally();'
MOVE_BODY="$(awk '
    /public void _OwnerProcessMove\(/ { in_method = 1 }
    /private void _SaveStateToHistory\(/ { exit }
    in_method { print }
' "$UNDO_TEMPLATE")"
UNDO_BODY="$(awk '
    /public void _OwnerUndo\(\)/ { in_method = 1 }
    /public void _OnResetClicked\(\)/ { exit }
    in_method { print }
' "$UNDO_TEMPLATE")"
RESET_BODY="$(awk '
    /public void _OwnerReset\(\)/ { in_method = 1 }
    /public override void OnDeserialization\(\)/ { exit }
    in_method { print }
' "$UNDO_TEMPLATE")"
require_string_order "$MOVE_BODY" '_SaveStateToHistory(); // Save once after the operation' '_ApplyDisplayLocally();'
require_string_order "$UNDO_BODY" 'System.Array.Copy(stateHistory, offset, currentState, 0, stateSize);' '_ApplyDisplayLocally();'
require_string_order "$RESET_BODY" 'historyCount = 1;' '_ApplyDisplayLocally();'

# Complete examples use exact SDK 3.10.4 callback names and parameter types.
require_text "$BATCH_TEMPLATE" 'public void _OnPlayerSlotJoined(int slotIndex)'
forbid_text "$BATCH_TEMPLATE" 'public void OnPlayerJoined(int slotIndex)'
require_text "$BATCH_TEMPLATE" 'public void _OnPlayerReady(int slotIndex)'
forbid_text "$BATCH_TEMPLATE" 'public void OnPlayerReady(int slotIndex)'
require_text "$API_REF" 'public override void OnDroneTriggerEnter(VRCDroneApi drone)'
forbid_text "$API_REF" 'OnDroneTriggerEnter(Collider other)'
require_text "$EVENTS_REF" '`void OnDroneTriggerEnter(VRCDroneApi drone)`'
require_text "$EVENTS_REF" '`void OnDroneTriggerStay(VRCDroneApi drone)`'
require_text "$EVENTS_REF" '`void OnDroneTriggerExit(VRCDroneApi drone)`'
require_text "$EVENTS_REF" 'public override void OnDroneTriggerEnter(VRCDroneApi drone)'
require_text "$EVENTS_REF" 'public override void OnDroneTriggerExit(VRCDroneApi drone)'
forbid_regex "$EVENTS_REF" 'OnDroneTrigger(Enter|Stay|Exit)\(Collider'

# Targeted receiver validates call context, caller, payload, and routing in order.
require_text "$NETWORKING_REF" '[NetworkCallable(2)]'
require_text "$NETWORKING_REF" 'if (!NetworkCalling.InNetworkCall) return;'
require_text "$NETWORKING_REF" 'VRCPlayerApi caller = NetworkCalling.CallingPlayer;'
require_text "$NETWORKING_REF" 'Open caller policy: any valid caller may send a bounded message.'
require_text "$NETWORKING_REF" '_ProcessMessage(message, caller);'
require_order "$NETWORKING_REF" 'if (!NetworkCalling.InNetworkCall) return;' 'VRCPlayerApi caller = NetworkCalling.CallingPlayer;'
require_order "$NETWORKING_REF" 'if (caller == null || !caller.IsValid()) return;' 'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;'
require_order "$NETWORKING_REF" 'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;' 'if (localPlayer == null || !localPlayer.IsValid()) return;'
require_order "$NETWORKING_REF" 'if (localPlayer.playerId != targetPlayerId) return;' '_ProcessMessage(message, caller);'
require_text "$NETWORKING_REF" 'if (Time.time - lastAcceptedMessageTime < ReceiverCooldown) return;'
require_order "$NETWORKING_REF" 'if (localPlayer.playerId != targetPlayerId) return;' 'if (Time.time - lastAcceptedMessageTime < ReceiverCooldown) return;'

# Master selects an idempotent coordinator, never an authorization boundary.
forbid_text "$NETWORKING_REF" '### Master-Only Actions'
require_text "$NETWORKING_REF" '### Master-Coordinated Session Work'
require_text "$NETWORKING_REF" 'Master status selects a session coordinator; it never authorizes a request.'
require_text "$NETWORKING_REF" 'if (lastReconciledPlayerCount == playerCount) return;'

# Changed full-class examples remain copyable and self-contained.
for path in "$SYNC_EXAMPLES" "$DYNAMICS_REF" "$API_REF"; do
    require_text "$path" 'using UdonSharp;'
    require_text "$path" 'using UnityEngine;'
done
require_text "$SYNC_EXAMPLES" 'using UnityEngine.UI;'
require_text "$SYNC_EXAMPLES" 'using VRC.Udon.Common.Interfaces;'
require_text "$SYNC_EXAMPLES" 'private void RefreshCount()'
forbid_text "$SYNC_EXAMPLES" 'GetComponent<ShootGun>()'
require_text "$DYNAMICS_REF" 'using VRC.Dynamics;'
require_text "$DYNAMICS_REF" 'using VRC.Udon.Common.Interfaces;'
require_text "$API_REF" 'public class PooledObject : UdonSharpBehaviour'

# NetworkCallable rates pace a sender/event queue; receiver resource bounds are separate.
RATE_SCOPE='`[NetworkCallable(N)]` paces remote sends for one event on one behaviour and queues excess sends on the sender.'
RATE_NOT_BOUND='It is not an aggregate receiver or resource bound across callers.'
for path in "$NETWORKING_REF" "$API_REF" "$SYNC_EXAMPLES" "$DYNAMICS_REF" "$RULE" "$MIGRATION_REF" "$TROUBLESHOOTING_REF"; do
    require_text "$path" "$RATE_SCOPE"
    require_text "$path" "$RATE_NOT_BOUND"
done
require_text "$NETWORKING_REF" 'Local and `NetworkEventTarget.Self` execution bypass the rate limit, while `NetworkEventTarget.All` can fan one send out to many receiver executions.'
forbid_text "$NETWORKING_REF" 'network cost/priority indicator'
forbid_text "$NETWORKING_REF" 'network cost'
forbid_text "$NETWORKING_REF" 'scheduled at higher priority'
require_text "$NETWORKING_REF" 'the documented non-malicious drop scenario'
require_text "$NETWORKING_REF" 'server-side enforcement also protects against malicious use'
require_text "$NETWORKING_REF" '| No `params` parameters |'
require_text "$NETWORKING_REF" '| No default parameter values |'
require_text "$API_REF" 'private float lastAcceptedEventTime = float.MinValue;'
require_text "$API_REF" 'if (Time.time - lastAcceptedEventTime < ReceiverCooldown) return;'
require_text "$DYNAMICS_REF" 'if (Time.time - lastAcceptedActionTime < ReceiverCooldown) return;'
forbid_text "$TROUBLESHOOTING_REF" '**Symptoms:** Events are dropped and do not reach all clients'

# Concise rule summaries remain synchronized across user and agent entrypoints.
require_text "$README_EN" 'Never use instance master as a security or access-control boundary.'
require_text "$README_JA" 'インスタンスマスターをセキュリティやアクセス制御の境界にしてはいけません。'
require_text "$README_KO" '인스턴스 마스터를 보안 또는 접근 제어 경계로 사용하지 마세요.'
require_text "$README_ZH_CN" '不要将实例 Master 作为安全或访问控制边界。'
require_text "$README_ZH_TW" '不要將執行個體 Master 當成安全或存取控制邊界。'
for path in "$AGENTS_TEMPLATE" "$CLAUDE_TEMPLATE" "$GEMINI_TEMPLATE"; do
    require_text "$path" 'never use instance master as a security or access-control boundary.'
    require_text "$path" 'confirm `NetworkCalling.InNetworkCall` before reading `NetworkCalling.CallingPlayer`'
done

# Do not make stronger sender-security claims than the official documentation.
for path in "$RULE" "$NETWORKING_REF" "$API_REF" "$PATTERNS_REF" "$BANDWIDTH_REF" "$MIGRATION_REF" "$CHEATSHEET" "$UNDO_TEMPLATE"; do
    forbid_regex "$path" 'cryptograph|unspoofable|unforgeable|server[- ]backed|cannot be spoofed|secure sender'
done

# CI keeps this exact smoke test under the Documentation Smoke Tests job.
DOCS_JOB="$(awk '
    /^  docs:$/ { in_docs = 1 }
    in_docs && /^  [a-zA-Z0-9_-]+:$/ && $1 != "docs:" { exit }
    in_docs { print }
' "$CI")"
require_text <(printf '%s\n' "$DOCS_JOB") '    name: Documentation Smoke Tests'
require_text <(printf '%s\n' "$DOCS_JOB") $'      - name: Check network event hardening and SDK coverage\n        run: bash tests/docs/network-event-hardening.test.sh'

# The two local input handlers must reject non-owner callers before dispatch,
# while the getter comments must keep the local-only/legacy-call boundary clear.
# Reuse the public-method audit lexer so comments and literal contents cannot
# satisfy these checks, then isolate each method by its own brace-balanced body.
python3 - "$UNDO_TEMPLATE" "$UDON_DIR/assets/templates/SyncedObject.cs" "$PUBLIC_METHOD_AUDIT" <<'PY'
import importlib.util
from pathlib import Path
import sys


class RegressionError(Exception):
    pass


def load_audit_module(path: Path):
    spec = importlib.util.spec_from_file_location("udon_public_method_audit", path)
    if spec is None or spec.loader is None:
        raise RegressionError(f"could not import audit module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sequence_positions(values: list[str], needle: tuple[str, ...]) -> list[int]:
    width = len(needle)
    return [
        index
        for index in range(len(values) - width + 1)
        if tuple(values[index:index + width]) == needle
    ]


def method_body(audit, source: str, name: str, return_type: str):
    tokens = audit.lex_csharp(source)
    values = [token.value for token in tokens]
    declaration = ("public", return_type, name, "(", ")")
    candidates = []
    for index in range(len(values) - len(declaration)):
        if tuple(values[index:index + len(declaration)]) != declaration:
            continue
        opening = index + len(declaration)
        if opening < len(values) and values[opening] == "{":
            candidates.append((index, opening))

    if len(candidates) != 1:
        raise RegressionError(
            f"expected one complete declaration for {name}, found {len(candidates)}"
        )

    declaration_index, opening = candidates[0]
    depth = 0
    for index in range(opening, len(tokens)):
        value = tokens[index].value
        if value == "{":
            depth += 1
        elif value == "}":
            depth -= 1
            if depth == 0:
                return tokens[opening + 1:index], tokens[declaration_index].line
    raise RegressionError(f"unterminated body for {name}")


OWNER_GUARD = (
    "if", "(", "!", "Networking", ".", "IsOwner", "(",
    "gameObject", ")", ")", "return", ";",
)
AUTHORIZATION_GUARD = (
    "if", "(", "!", "_IsAuthorizedNetworkCaller", "(", ")", ")", "return", ";",
)
RECEIVER_SECURITY_PREFIX = AUTHORIZATION_GUARD + OWNER_GUARD
SEND_NETWORK_EVENT = ("SendCustomNetworkEvent", "(")
SET_OWNER_CALL = ("SetOwner", "(")
HANDLER_DISPATCH = {
    "_OnUndoClicked": (
        "SendCustomNetworkEvent", "(", "NetworkEventTarget", ".", "Owner", ",",
        "nameof", "(", "_OwnerUndo", ")", ")", ";",
    ),
    "_OnResetClicked": (
        "SendCustomNetworkEvent", "(", "NetworkEventTarget", ".", "Owner", ",",
        "nameof", "(", "_OwnerReset", ")", ")", ";",
    ),
}


def set_owner_call_positions(tokens) -> list[int]:
    values = [token.value for token in tokens]
    positions = sequence_positions(values, SET_OWNER_CALL)
    calls = []
    for position in positions:
        depth = 0
        closing = None
        for index in range(position + 1, len(values)):
            if values[index] == "(":
                depth += 1
            elif values[index] == ")":
                depth -= 1
                if depth == 0:
                    closing = index
                    break
        if closing is None:
            calls.append(position)
            continue
        previous = values[position - 1] if position > 0 else ""
        following = values[closing + 1] if closing + 1 < len(values) else ""
        is_declaration = previous not in {".", "?.", "::"} and following in {"{", "=>"}
        if not is_declaration:
            calls.append(position)
    return calls


def check_handler(audit, source: str, name: str):
    body, line = method_body(audit, source, name, "void")
    values = [token.value for token in body]
    guards = sequence_positions(values, OWNER_GUARD)
    sends = sequence_positions(values, SEND_NETWORK_EVENT)
    owners = set_owner_call_positions(body)

    if not guards:
        raise RegressionError(f"{name}:{line}: owner guard token sequence is missing")
    if not sends:
        raise RegressionError(f"{name}:{line}: SendCustomNetworkEvent token sequence is missing")
    if guards[0] >= sends[0]:
        raise RegressionError(f"{name}:{line}: owner guard must precede network dispatch")
    if tuple(values[:len(OWNER_GUARD)]) != OWNER_GUARD:
        raise RegressionError(f"{name}:{line}: owner guard is not the first execution statement")
    if owners:
        raise RegressionError(f"{name}:{line}: target method contains a SetOwner call")
    expected_body = OWNER_GUARD + HANDLER_DISPATCH[name]
    if tuple(values) != expected_body:
        raise RegressionError(
            f"{name}:{line}: handler must contain only the owner guard and owner dispatch"
        )
    return line


def check_receiver_security_prefix(audit, source: str, name: str):
    body, line = method_body(audit, source, name, "void")
    values = tuple(token.value for token in body)
    if values[:len(RECEIVER_SECURITY_PREFIX)] != RECEIVER_SECURITY_PREFIX:
        raise RegressionError(
            f"{name}:{line}: authorization and ownership guards must be the first tokens"
        )
    return line


def check_no_owner_transfer(audit, source: str) -> None:
    if set_owner_call_positions(audit.lex_csharp(source)):
        raise RegressionError("UndoableGameManager contains a SetOwner call")


def summary_immediately_before(source: str, method_line: int, name: str) -> str:
    lines = source.splitlines()
    cursor = method_line - 2
    if cursor < 0 or lines[cursor].strip() != "/// </summary>":
        raise RegressionError(f"{name}:{method_line}: summary is not immediately before method")
    end = cursor
    while cursor >= 0:
        stripped = lines[cursor].strip()
        if stripped == "/// <summary>":
            return "\n".join(lines[cursor:end + 1])
        if not stripped.startswith("///"):
            break
        cursor -= 1
    raise RegressionError(f"{name}:{method_line}: malformed immediately preceding summary")


GETTER_EXPECTATIONS = {
    "_GetState": (
        "bool",
        ("return", "_isActive", ";"),
        "/// Local-only public method to get current state.",
        "/// The leading underscore prevents legacy network calls.",
    ),
    "_GetLastInteractor": (
        "VRCPlayerApi",
        (
            "return",
            "VRCPlayerApi",
            ".",
            "GetPlayerById",
            "(",
            "lastInteractorId",
            ")",
            ";",
        ),
        "/// Local-only public method to get the player who last interacted with this object.",
        "/// The leading underscore prevents legacy network calls.",
    ),
}


def check_getter_summaries(audit, source: str) -> None:
    for name, (return_type, expected_body, *expected) in GETTER_EXPECTATIONS.items():
        body, line = method_body(audit, source, name, return_type)
        actual_body = tuple(token.value for token in body)
        if actual_body != expected_body:
            raise RegressionError(f"{name}:{line}: getter body does not match the exact contract")
        summary_lines = tuple(
            summary_line.strip()
            for summary_line in summary_immediately_before(source, line, name).splitlines()
        )
        expected_summary = ("/// <summary>", *expected, "/// </summary>")
        if summary_lines != expected_summary:
            raise RegressionError(f"{name}:{line}: summary does not match the exact contract")


def expect_rejected(
    audit, source: str, name: str, label: str, expected_detail: str
) -> None:
    try:
        check_handler(audit, source, name)
    except RegressionError as error:
        if expected_detail not in str(error):
            raise RegressionError(
                f"mutation {label} rejected for unexpected reason: "
                f"expected {expected_detail!r}, got {error}"
            ) from error
        print(f"PASS: mutation {label} rejected ({error})")
        return
    raise RegressionError(f"mutation {label} was accepted")


def expect_getter_rejected(
    audit, source: str, label: str, expected_detail: str
) -> None:
    try:
        check_getter_summaries(audit, source)
    except RegressionError as error:
        if expected_detail not in str(error):
            raise RegressionError(
                f"mutation {label} rejected for unexpected reason: "
                f"expected {expected_detail!r}, got {error}"
            ) from error
        print(f"PASS: mutation {label} rejected ({error})")
        return
    raise RegressionError(f"mutation {label} was accepted")


def expect_receiver_rejected(
    audit, source: str, name: str, label: str, expected_detail: str
) -> None:
    try:
        check_receiver_security_prefix(audit, source, name)
    except RegressionError as error:
        if expected_detail not in str(error):
            raise RegressionError(
                f"mutation {label} rejected for unexpected reason: "
                f"expected {expected_detail!r}, got {error}"
            ) from error
        print(f"PASS: mutation {label} rejected ({error})")
        return
    raise RegressionError(f"mutation {label} was accepted")


def replace_method_text(
    audit,
    source: str,
    name: str,
    return_type: str,
    method_marker: str,
    next_marker: str,
    old: str,
    new: str,
) -> str:
    method_body(audit, source, name, return_type)
    if method_marker not in source:
        raise RegressionError(f"could not locate {name} declaration")
    prefix, remainder = source.split(method_marker, 1)
    if next_marker not in remainder:
        raise RegressionError(f"could not locate end of {name} mutation scope")
    method_source, suffix = remainder.split(next_marker, 1)
    if method_source.count(old) != 1:
        raise RegressionError(f"expected one mutation target in {name} method scope")
    return prefix + method_marker + method_source.replace(old, new, 1) + next_marker + suffix


undo_path = Path(sys.argv[1])
synced_path = Path(sys.argv[2])
audit = load_audit_module(Path(sys.argv[3]))
undo_source = undo_path.read_text(encoding="utf-8")
synced_source = synced_path.read_text(encoding="utf-8")

for handler in ("_OnUndoClicked", "_OnResetClicked"):
    check_handler(audit, undo_source, handler)
for receiver in ("_OwnerUndo", "_OwnerReset"):
    check_receiver_security_prefix(audit, undo_source, receiver)
check_no_owner_transfer(audit, undo_source)
print("PASS: token-level owner guards, receiver security prefixes, dispatch order, and file-wide no-transfer policy")

check_getter_summaries(audit, synced_source)
print("PASS: getter XML summaries are attached to their target methods")

handler_marker = "    public void _OnUndoClicked()\n"
guard_line = "        if (!Networking.IsOwner(gameObject)) return;"
undo_guard_marker = handler_marker + "    {\n" + guard_line


def add_after_undo_guard(source: str, statement: str) -> str:
    if undo_guard_marker not in source:
        raise RegressionError("could not locate _OnUndoClicked owner guard")
    return source.replace(undo_guard_marker, undo_guard_marker + "\n" + statement, 1)


prefix, handler_source = undo_source.split(handler_marker, 1)
if guard_line not in handler_source:
    raise RegressionError("could not build comment-out guard mutation fixture")
commented_guard = prefix + handler_marker + handler_source.replace(
    guard_line, "        // " + guard_line.strip(), 1
)
expect_rejected(
    audit,
    commented_guard,
    "_OnUndoClicked",
    "comment-out guard",
    "owner guard token sequence is missing",
)

helper_marker = "    [NetworkCallable]\n    public void _OwnerUndo()"
adjacent_helper = (
    "    private void _AdjacentOwnerTransferHelper()\n"
    "    {\n"
    "        Networking.SetOwner(Networking.LocalPlayer, gameObject);\n"
    "    }\n\n"
)
if helper_marker not in undo_source:
    raise RegressionError("could not build adjacent-helper mutation fixture")
helper_fixture = undo_source.replace(helper_marker, adjacent_helper + helper_marker, 1)
check_handler(audit, helper_fixture, "_OnUndoClicked")
try:
    check_no_owner_transfer(audit, helper_fixture)
except RegressionError as error:
    print(f"PASS: mutation adjacent helper SetOwner rejected file-wide ({error})")
else:
    raise RegressionError("mutation adjacent helper SetOwner was accepted file-wide")

called_helper_fixture = add_after_undo_guard(
    helper_fixture, "        _AdjacentOwnerTransferHelper();"
)
expect_rejected(
    audit,
    called_helper_fixture,
    "_OnUndoClicked",
    "called ownership-transfer helper",
    "handler must contain only the owner guard and owner dispatch",
)

external_relay_fixture = add_after_undo_guard(
    undo_source, "        ownerRelay._ForceIdle();"
)
expect_rejected(
    audit,
    external_relay_fixture,
    "_OnUndoClicked",
    "external ownership-transfer relay",
    "handler must contain only the owner guard and owner dispatch",
)

alias_fixture = (
    "using VRCNet = VRC.SDKBase.Networking;\n"
    + add_after_undo_guard(
        undo_source, "        VRCNet.SetOwner(Networking.LocalPlayer, gameObject);"
    )
)
try:
    check_no_owner_transfer(audit, alias_fixture)
except RegressionError as error:
    print(f"PASS: mutation alias SetOwner rejected ({error})")
else:
    raise RegressionError("mutation alias SetOwner was accepted")

static_fixture = (
    "using static VRC.SDKBase.Networking;\n"
    + add_after_undo_guard(
        undo_source, "        SetOwner(Networking.LocalPlayer, gameObject);"
    )
)
try:
    check_no_owner_transfer(audit, static_fixture)
except RegressionError as error:
    print(f"PASS: mutation using-static SetOwner rejected ({error})")
else:
    raise RegressionError("mutation using-static SetOwner was accepted")

negated_doc_fixture = synced_source.replace(
    "/// Local-only public method to get current state.",
    "/// Not Local-only public method to get current state.",
    1,
)
expect_getter_rejected(
    audit,
    negated_doc_fixture,
    "negated getter summary",
    "summary does not match the exact contract",
)

contradictory_doc_fixture = synced_source.replace(
    "/// The leading underscore prevents legacy network calls.\n    /// </summary>\n"
    "    public bool _GetState()",
    "/// The leading underscore prevents legacy network calls.\n"
    "    /// This method is not local-only and the underscore does not prevent legacy calls.\n"
    "    /// </summary>\n    public bool _GetState()",
    1,
)
expect_getter_rejected(
    audit,
    contradictory_doc_fixture,
    "contradictory getter summary",
    "summary does not match the exact contract",
)

getter_body_mutations = (
    (
        "_GetState",
        "bool",
        "    public bool _GetState()\n",
        "    public VRCPlayerApi _GetLastInteractor()",
        "        return _isActive;",
        "        return !_isActive;",
        "negated _GetState body",
    ),
    (
        "_GetLastInteractor",
        "VRCPlayerApi",
        "    public VRCPlayerApi _GetLastInteractor()\n",
        "    private void LogDebug",
        "        return VRCPlayerApi.GetPlayerById(lastInteractorId);",
        "        return null;",
        "null _GetLastInteractor body",
    ),
)
for name, return_type, method_marker, next_marker, old, new, label in getter_body_mutations:
    getter_fixture = replace_method_text(
        audit,
        synced_source,
        name,
        return_type,
        method_marker,
        next_marker,
        old,
        new,
    )
    expect_getter_rejected(
        audit,
        getter_fixture,
        label,
        "getter body does not match the exact contract",
    )

AUTHORIZATION_GUARD_LINE = "        if (!_IsAuthorizedNetworkCaller()) return;"
RECEIVER_OWNER_GUARD_LINE = "        if (!Networking.IsOwner(gameObject)) return;"
receiver_method_mutations = (
    (
        "_OwnerUndo",
        "    public void _OwnerUndo()\n",
        "    public void _OnResetClicked()",
        AUTHORIZATION_GUARD_LINE + "\n",
        "",
        "removed _OwnerUndo caller authorization guard",
    ),
    (
        "_OwnerUndo",
        "    public void _OwnerUndo()\n",
        "    public void _OnResetClicked()",
        RECEIVER_OWNER_GUARD_LINE + "\n",
        "",
        "removed _OwnerUndo receiver ownership guard",
    ),
    (
        "_OwnerUndo",
        "    public void _OwnerUndo()\n",
        "    public void _OnResetClicked()",
        AUTHORIZATION_GUARD_LINE + "\n" + RECEIVER_OWNER_GUARD_LINE,
        RECEIVER_OWNER_GUARD_LINE + "\n" + AUTHORIZATION_GUARD_LINE,
        "reversed _OwnerUndo security guards",
    ),
    (
        "_OwnerReset",
        "    public void _OwnerReset()\n",
        "    // --- All clients: update display ---",
        AUTHORIZATION_GUARD_LINE + "\n",
        "",
        "removed _OwnerReset caller authorization guard",
    ),
    (
        "_OwnerReset",
        "    public void _OwnerReset()\n",
        "    // --- All clients: update display ---",
        RECEIVER_OWNER_GUARD_LINE + "\n",
        "",
        "removed _OwnerReset receiver ownership guard",
    ),
    (
        "_OwnerReset",
        "    public void _OwnerReset()\n",
        "    // --- All clients: update display ---",
        AUTHORIZATION_GUARD_LINE + "\n" + RECEIVER_OWNER_GUARD_LINE,
        RECEIVER_OWNER_GUARD_LINE + "\n" + AUTHORIZATION_GUARD_LINE,
        "reversed _OwnerReset security guards",
    ),
)
for name, method_marker, next_marker, old, new, label in receiver_method_mutations:
    receiver_fixture = replace_method_text(
        audit,
        undo_source,
        name,
        "void",
        method_marker,
        next_marker,
        old,
        new,
    )
    expect_receiver_rejected(
        audit,
        receiver_fixture,
        name,
        label,
        "authorization and ownership guards must be the first tokens",
    )

unrelated_declaration_fixture = undo_source.replace(
    helper_marker,
    "    private void SetOwner() { }\n\n" + helper_marker,
    1,
)
check_no_owner_transfer(audit, unrelated_declaration_fixture)
print("PASS: unrelated SetOwner declaration is not treated as an ownership call")
PY

echo "PASS: network-event hardening and SDK coverage smoke test"
