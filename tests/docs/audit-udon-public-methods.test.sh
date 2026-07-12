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

assert_accepted_count() {
    local fixture="$1"
    local expected="$2"
    local output

    output="$(python3 "$AUDIT" "$fixture")"
    if [ "$output" != "$expected" ]; then
        echo "ERROR: unexpected audit count for $fixture" >&2
        printf 'expected: %s\nactual:   %s\n' "$expected" "$output" >&2
        exit 1
    fi
}

assert_accepted_count \
    "$FIXTURES/valid" \
    "PASS: audited 24 public instance methods (6 runtime callbacks, 2 editor callbacks, 10 NetworkCallable entries, 6 local/custom underscore methods); classified 62 public declarations"

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
assert_rejected "$FIXTURES/invalid/unicode-exposure.cs" "public void 危険()"
assert_rejected "$FIXTURES/invalid/unicode-escape-exposure.cs" "legacy network exposure"
assert_rejected "$FIXTURES/invalid/verbatim-exposure.cs" "public void @Danger()"
assert_rejected "$FIXTURES/invalid/type-alias-return.cs" "NetworkCallable method must return void"
assert_rejected "$FIXTURES/invalid/namespace-alias-name.cs" "NetworkCallable method name must start with '_'"
assert_rejected "$FIXTURES/invalid/qualified-return.cs" "NetworkCallable method must return void"
assert_rejected "$FIXTURES/invalid/global-qualified-name.cs" "NetworkCallable method name must start with '_'"
assert_rejected "$FIXTURES/invalid/unterminated-csharp-fence.md" "unterminated C# Markdown fence"
assert_rejected "$FIXTURES/invalid/unterminated-literal.cs" "unterminated string literal"
assert_rejected "$FIXTURES/invalid/unterminated-comment.cs" "unterminated block comment"
assert_rejected "$FIXTURES/invalid/unterminated-attribute.cs" "unmatched '['"
assert_rejected "$FIXTURES/invalid/unclassified-public.cs" "unclassified public declaration"
assert_rejected "$FIXTURES/invalid/container-exposure.md" "public void BlockquoteRemoteExposure()"
assert_rejected "$FIXTURES/invalid/malformed-container-csharp.md" "unterminated C# Markdown fence"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be virtual"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be override"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be abstract"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be extern"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be async"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method must be an instance method"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot have more than 8 parameters"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable parameter cannot use params"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable parameter cannot have a default value"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be generic"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable parameter cannot use ref, out, in, or this"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method cannot be overloaded"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "NetworkCallable method must be public"
assert_rejected "$FIXTURES/invalid/network-callable-contract.cs" "unsupported NetworkCallable parameter type"
assert_rejected "$FIXTURES/invalid/unrelated-namespace-shadow.cs" "NetworkCallable method must return void"
assert_rejected "$FIXTURES/invalid/unknown-attribute-binding.cs" "cannot safely bind NetworkCallable attribute name"
assert_rejected "$FIXTURES/invalid/network-callable-nonmethod.cs" "NetworkCallable attribute must target a method"

echo "PASS: public method audit regression fixtures (9 valid files, 30 invalid files)"
