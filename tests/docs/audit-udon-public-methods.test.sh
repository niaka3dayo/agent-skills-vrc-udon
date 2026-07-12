#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$ROOT_DIR/tests/docs/audit-udon-public-methods.py"
FIXTURES="$ROOT_DIR/tests/docs/fixtures/audit-udon-public-methods"

assert_rejected() {
    local fixture="$1"
    local expected="$2"
    local output

    if output="$(python3 "$AUDIT" "$fixture" 2>&1)"; then
        echo "ERROR: audit accepted invalid fixture: $fixture" >&2
        exit 1
    fi
    if ! grep -Fq "$expected" <<<"$output"; then
        echo "ERROR: audit rejected $fixture without expected diagnostic: $expected" >&2
        printf '%s\n' "$output" >&2
        exit 1
    fi
}

python3 "$AUDIT" "$FIXTURES/valid"

assert_rejected "$FIXTURES/invalid/public-nonvoid.cs" "public int ExposedValue()"
assert_rejected "$FIXTURES/invalid/multiline.cs" "public void MultilineExposure()"
assert_rejected "$FIXTURES/invalid/expression-bodied.cs" "public bool IsExposed()"
assert_rejected "$FIXTURES/invalid/network-callable-return.cs" "NetworkCallable method must return void"
assert_rejected "$FIXTURES/invalid/network-callable-name.cs" "NetworkCallable method name must start with '_'"
assert_rejected "$FIXTURES/invalid/attribute-bleed.cs" "public void AttributeBleed()"
assert_rejected "$FIXTURES/invalid/marker-bleed.cs" "public void MarkerBleed()"
assert_rejected "$FIXTURES/invalid/comment-evasion.cs" "public void CommentEvasion()"
assert_rejected "$FIXTURES/invalid/malicious-layout.md" "public string HiddenAcrossLines()"
assert_rejected "$FIXTURES/invalid/tuple-return.cs" "public (intCount,boolActive) ExposedTuple()"
assert_rejected "$FIXTURES/invalid/fake-editor-base.cs" "public void OnInspectorGUI()"

echo "PASS: public method audit regression fixtures (2 valid files, 11 invalid files)"
