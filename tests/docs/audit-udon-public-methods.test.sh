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
    "PASS: audited 39 public instance methods (13 runtime callbacks, 2 editor callbacks, 13 NetworkCallable entries, 11 local/custom underscore methods); classified 97 public declarations"

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
assert_rejected "$FIXTURES/invalid/list-quote-container-exposure.md" "public void ReverseNestedRemoteExposure()"
assert_rejected "$FIXTURES/invalid/list-quote-unclosed.md" "unterminated C# Markdown fence"
assert_rejected "$FIXTURES/invalid/list-tab-unclosed.md" "unterminated C# Markdown fence"
assert_rejected "$FIXTURES/invalid/network-callable-builtin.cs" "built-in Udon event cannot be NetworkCallable"
assert_rejected "$FIXTURES/invalid/network-callable-unity-builtin.cs" "built-in Udon event cannot be NetworkCallable"
assert_rejected "$FIXTURES/invalid/network-callable-arguments.md" "NetworkCallable rate must be an integer from 1 to 100"
assert_rejected "$FIXTURES/invalid/network-callable-arguments.md" "NetworkCallable attribute has an unknown named argument"
assert_rejected "$FIXTURES/invalid/network-callable-arguments.md" "NetworkCallable attribute accepts at most one argument"
assert_rejected "$FIXTURES/invalid/network-callable-arguments.md" "NetworkCallable attribute cannot be duplicated"
assert_rejected "$FIXTURES/invalid/network-callable-targets.md" "NetworkCallable attribute must target a method"
assert_rejected "$FIXTURES/invalid/network-callable-section-target.cs" "NetworkCallable attribute must target a method"
assert_rejected "$FIXTURES/invalid/network-callable-late-section-target.cs" "attribute target must begin the attribute section"
assert_rejected "$FIXTURES/invalid/inherited-overload.cs" "NetworkCallable method cannot be overloaded"
assert_rejected "$FIXTURES/invalid/partial-overload" "NetworkCallable method cannot be overloaded"
assert_rejected "$FIXTURES/invalid/partial-overload-fences.md" "NetworkCallable method cannot be overloaded"
assert_rejected "$FIXTURES/invalid/public-overload.cs" "NetworkCallable method cannot be overloaded"
assert_rejected "$FIXTURES/invalid/platform-type-shadowing.md" "unsupported NetworkCallable parameter type"
assert_rejected "$FIXTURES/invalid/sdk-callback-contracts.md" "built-in Udon event signature does not match SDK 3.10.4"
assert_rejected "$FIXTURES/invalid/sdk-callback-return-shadow.cs" "built-in Udon event signature does not match SDK 3.10.4"
assert_rejected "$FIXTURES/invalid/nested-file-scoped-namespace.cs" "file-scoped namespace must be at compilation-unit scope"
assert_rejected "$FIXTURES/invalid/late-file-scoped-namespace.cs" "file-scoped namespace must precede all members"
assert_rejected "$FIXTURES/invalid/top-level-before-file-namespace.cs" "file-scoped namespace must precede all members"
assert_rejected "$FIXTURES/invalid/empty-statement-before-file-namespace.cs" "file-scoped namespace must precede all members"
assert_rejected "$FIXTURES/invalid/nested-list-tab-exposure.md" "unterminated C# Markdown fence"
assert_rejected "$FIXTURES/invalid/nested-list-tab-unclosed.md" "unterminated C# Markdown fence"
assert_rejected "$FIXTURES/invalid/quote-list-tab-exposure.md" "unterminated C# Markdown fence"

VALID_FILE_COUNT="$(find "$FIXTURES/valid" -maxdepth 1 -type f | wc -l)"
INVALID_INPUT_COUNT="$(find "$FIXTURES/invalid" -mindepth 1 -maxdepth 1 | wc -l)"
if [ "$VALID_FILE_COUNT" -ne 15 ] || [ "$INVALID_INPUT_COUNT" -ne 52 ]; then
    echo "ERROR: fixture inventory changed without updating the regression contract" >&2
    exit 1
fi
echo "PASS: public method audit regression fixtures ($VALID_FILE_COUNT valid files, $INVALID_INPUT_COUNT invalid inputs)"
