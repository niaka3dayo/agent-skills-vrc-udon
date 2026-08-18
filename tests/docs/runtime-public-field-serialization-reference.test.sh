#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UDON_DIR="$ROOT_DIR/skills/unity-vrc-udon-sharp"
SKILL="$UDON_DIR/SKILL.md"
RULES="$UDON_DIR/rules/udonsharp-constraints.md"
CONSTRAINTS="$UDON_DIR/references/constraints.md"
TROUBLESHOOTING="$UDON_DIR/references/troubleshooting.md"
CHEATSHEET="$UDON_DIR/CHEATSHEET.md"
UTILITIES="$UDON_DIR/references/patterns-utilities.md"
PERFORMANCE="$UDON_DIR/references/patterns-performance.md"
UI="$UDON_DIR/references/patterns-ui.md"
WEB_LOADING="$UDON_DIR/references/web-loading-advanced.md"

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
    if grep -Fq -- "$needle" "$path"; then
        echo "ERROR: $path contains obsolete text: $needle" >&2
        exit 1
    fi
}

require_count() {
    local path="$1"
    local needle="$2"
    local expected="$3"
    local actual
    actual="$( (grep -F -- "$needle" "$path" || true) | wc -l | tr -d '[:space:]')"
    if [ "$actual" -ne "$expected" ]; then
        echo "ERROR: $path contains $actual copies of '$needle'; expected $expected" >&2
        exit 1
    fi
}

# The runtime-only examples must not imply Unity/Prefab persistence. Keep this
# scoped to the named fields; a valid, intentional HideInInspector example is
# required below and is deliberately not blanket-banned.
require_count "$UTILITIES" '[System.NonSerialized] public bool ResultSuccess' 1
require_count "$UTILITIES" '[System.NonSerialized] public string[] ResultData' 1
require_count "$UTILITIES" '[System.NonSerialized] public UdonSharpBehaviour CallbackTarget' 1
require_count "$UTILITIES" '[System.NonSerialized] public string              CallbackMethod' 1
require_count "$PERFORMANCE" '[System.NonSerialized] public VRCUrl ScheduledUrl' 1
require_count "$UI" '[System.NonSerialized] public int selectedIndex' 2
require_count "$UI" '[System.NonSerialized] public int lastPointerIndex' 1
require_count "$WEB_LOADING" '[System.NonSerialized] public int LastUrlIndex' 1
require_count "$WEB_LOADING" '[System.NonSerialized] public int LastInnerIndex' 1

for path in "$UTILITIES" "$PERFORMANCE" "$UI" "$WEB_LOADING"; do
    for field in ResultSuccess ResultData CallbackTarget CallbackMethod ScheduledUrl selectedIndex lastPointerIndex LastUrlIndex LastInnerIndex; do
        # The exact declaration is checked above; this catches an accidental
        # reintroduction of the old attribute on the affected examples.
        if grep -F "[HideInInspector] public" "$path" | grep -Fq -- "$field"; then
            echo "ERROR: runtime-only field $field still uses HideInInspector in $path" >&2
            exit 1
        fi
    done
done

# Entry-point and reference documentation must distinguish persistence from
# runtime-only cross-behaviour access.
for path in "$SKILL" "$RULES" "$CONSTRAINTS" "$TROUBLESHOOTING" "$CHEATSHEET"; do
    require_text "$path" 'HideInInspector'
    require_text "$path" 'System.NonSerialized'
    require_text "$path" 'Scene/Prefab'
    require_text "$path" 'runtime-only'
done

# A positive example protects legitimate editor-time wiring; this is not an
# "all HideInInspector is forbidden" contract.
require_text "$CONSTRAINTS" '[HideInInspector] public GameObject bakedTarget'
require_text "$CONSTRAINTS" 'Editor-time wiring'
require_text "$CONSTRAINTS" 'must be persisted into a Scene or Prefab'

# The scheduler contract must handle both a null VRCUrl and the SDK's empty
# VRCUrl representation, while retaining the public SetProgramVariable name.
require_text "$PERFORMANCE" 'if (ScheduledUrl == null || string.IsNullOrEmpty(ScheduledUrl.Get())) return;'
require_text "$PERFORMANCE" 'SetProgramVariable("ScheduledUrl", url)'
forbid_text "$PERFORMANCE" 'not [HideInInspector] alone'
forbid_text "$PERFORMANCE" 'while keeping it accessible to the scheduler'

echo "PASS: runtime public field serialization contract"
