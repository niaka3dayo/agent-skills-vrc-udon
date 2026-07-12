#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UDON_DIR="$ROOT_DIR/skills/unity-vrc-udon-sharp"
RULE="$UDON_DIR/rules/udonsharp-networking.md"
CONSTRAINTS_RULE="$UDON_DIR/rules/udonsharp-constraints.md"
NETWORKING_REF="$UDON_DIR/references/networking.md"
API_REF="$UDON_DIR/references/api.md"
PATTERNS_REF="$UDON_DIR/references/patterns-networking.md"
BANDWIDTH_REF="$UDON_DIR/references/networking-bandwidth.md"
MIGRATION_REF="$UDON_DIR/references/sdk-migration.md"
SYNC_EXAMPLES="$UDON_DIR/references/sync-examples.md"
DYNAMICS_REF="$UDON_DIR/references/dynamics.md"
CHEATSHEET="$UDON_DIR/CHEATSHEET.md"
UNDO_TEMPLATE="$UDON_DIR/assets/templates/UndoableGameManager.cs"
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

# Current support declarations must agree on the SDK 3.10.4 upper bound.
require_text "$CONTRIBUTING" "SDK 3.7.1 - 3.10.4"
require_text "$CONSTRAINTS_RULE" "**SDK Coverage**: 3.7.1 - 3.10.4"
require_text "$RULE" "**SDK Coverage**: 3.7.1 - 3.10.4"

# Historical, version-specific evidence must not be rewritten as current coverage.
require_text "$API_REF" "observed in the SDK 3.10.3 Udon wrapper symbols"

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
require_text "$API_REF" 'Any valid caller may start this local-only cosmetic effect; the rate limit bounds repeated calls.'
require_text "$DYNAMICS_REF" 'Any valid caller may trigger this diagnostic effect; it does not change authoritative state.'

# Master coordination is limited to non-security session arbitration.
forbid_regex "$UDON_DIR" 'banlist-style|Master-approved|master-backed'
require_text "$PATTERNS_REF" 'Instance master may coordinate capacity or a fair lottery, but master status can change and does not grant access-control authority.'
require_text "$PATTERNS_REF" 'Use an explicit owner-controlled session role policy or platform moderation primitives for exclusions and privileged actions.'

# Old unprefixed method names must not return in prose or code.
for stale_name in OwnerProcessMove OwnerUndo OwnerReset VerifyAssignments; do
    if rg -n "(^|[^A-Za-z0-9_])${stale_name}" "$UDON_DIR"; then
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
require_text "$NETWORKING_REF" $'if (string.IsNullOrEmpty(message) || message.Length > MaxMessageLength) return;\n    if (Networking.LocalPlayer.playerId != targetPlayerId) return;\n    _ProcessMessage(message);'
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

# Concise rule summaries remain synchronized across user and agent entrypoints.
require_text "$README_EN" 'Never use instance master as a security or access-control boundary.'
require_text "$README_JA" 'インスタンスマスターをセキュリティやアクセス制御の境界にしてはいけません。'
require_text "$README_KO" '인스턴스 마스터를 보안 또는 접근 제어 경계로 사용하지 마세요.'
require_text "$README_ZH_CN" '不要将实例 Master 作为安全或访问控制边界。'
require_text "$README_ZH_TW" '不要將執行個體 Master 當成安全或存取控制邊界。'
for path in "$AGENTS_TEMPLATE" "$CLAUDE_TEMPLATE" "$GEMINI_TEMPLATE"; do
    require_text "$path" 'never use instance master as a security or access-control boundary.'
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

echo "PASS: network-event hardening and SDK coverage smoke test"
