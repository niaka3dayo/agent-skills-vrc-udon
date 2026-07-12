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
CHEATSHEET="$UDON_DIR/CHEATSHEET.md"
UNDO_TEMPLATE="$UDON_DIR/assets/templates/UndoableGameManager.cs"
CONTRIBUTING="$ROOT_DIR/CONTRIBUTING.md"
CI="$ROOT_DIR/.github/workflows/ci.yml"

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
    if grep -Eiq "$pattern" "$path"; then
        echo "ERROR: $path contains forbidden pattern: $pattern" >&2
        grep -Ein "$pattern" "$path" >&2
        exit 1
    fi
}

# Current support declarations must agree on the SDK 3.10.4 upper bound.
require_text "$CONTRIBUTING" "SDK 3.7.1 - 3.10.4"
require_text "$CONSTRAINTS_RULE" "**SDK Coverage**: 3.7.1 - 3.10.4"
require_text "$RULE" "**SDK Coverage**: 3.7.1 - 3.10.4"

# Historical, version-specific evidence must not be rewritten as current coverage.
require_text "$API_REF" "observed in the SDK 3.10.3 Udon wrapper symbols"

# Always-loaded and detailed surfaces must cover legacy exposure and sender context.
for path in "$RULE" "$NETWORKING_REF"; do
    require_text "$path" "NetworkCalling.CallingPlayer"
    require_text "$path" "NetworkCalling.InNetworkCall"
    require_text "$path" "[NetworkCallable]"
    require_text "$path" "underscore"
    require_text "$path" "authorization"
done

require_text "$API_REF" "NetworkCalling.CallingPlayer"
require_text "$API_REF" "NetworkCalling.InNetworkCall"
require_text "$API_REF" "null"
require_text "$NETWORKING_REF" "https://creators.vrchat.com/worlds/udon/networking/events/"

# Privileged, damage, and move examples derive the caller from the active call context.
for path in "$PATTERNS_REF" "$BANDWIDTH_REF" "$UNDO_TEMPLATE"; do
    require_text "$path" "NetworkCalling.CallingPlayer"
    require_text "$path" "NetworkCalling.InNetworkCall"
done

for path in "$RULE" "$NETWORKING_REF" "$PATTERNS_REF" "$MIGRATION_REF" "$CHEATSHEET"; do
    forbid_regex "$path" 'TakeDamage\([^)]*attackerId'
done
forbid_regex "$BANDWIDTH_REF" 'OwnerProcessMove\([^)]*playerId'
forbid_regex "$UNDO_TEMPLATE" 'OwnerProcessMove\([^)]*playerId'

# Do not make stronger sender-security claims than the official documentation.
for path in "$RULE" "$NETWORKING_REF" "$API_REF" "$PATTERNS_REF" "$BANDWIDTH_REF" "$MIGRATION_REF" "$CHEATSHEET" "$UNDO_TEMPLATE"; do
    forbid_regex "$path" 'cryptograph|unspoofable|unforgeable|server[- ]backed|cannot be spoofed|secure sender'
done

# CI keeps this coverage from drifting.
require_text "$CI" "network-event-hardening.test.sh"

echo "PASS: network-event hardening and SDK coverage smoke test"
