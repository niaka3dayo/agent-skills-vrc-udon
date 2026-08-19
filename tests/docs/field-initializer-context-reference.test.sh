#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file="$1" text="$2"
    grep -Fq -- "$text" "$file" || fail "$file is missing: $text"
}

assert_runtime_warning_row() {
    local file="$1"
    awk '/List<T>/ && /LINQ/ && /(lambda|ラムダ|람다)/ && /Editor/ && /Udon runtime/ && /WARNING/ { found = 1 } END { exit !found }' "$file" ||
        fail "$file does not classify List<T>/LINQ/lambdas as context-sensitive WARNINGs"
    awk '/async\/await/ && /try\/catch/ && /ERROR/ { found = 1 } END { exit !found }' "$file" ||
        fail "$file no longer keeps unrelated runtime blockers at ERROR"
}

SKILL="skills/unity-vrc-udon-sharp/SKILL.md"
RULES="skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md"
REFERENCE="skills/unity-vrc-udon-sharp/references/constraints.md"
TROUBLESHOOTING="skills/unity-vrc-udon-sharp/references/troubleshooting.md"
CHEATSHEET="skills/unity-vrc-udon-sharp/CHEATSHEET.md"

assert_contains "$SKILL" "Editor-evaluated field initializers"
assert_contains "$SKILL" "Udon runtime code"
assert_contains "$SKILL" "Random.Range"
assert_contains "$SKILL" "baked default"
assert_contains "$SKILL" "per-instance, per-client, or per-session randomness"
assert_contains "$SKILL" "lazy-init guard"
assert_contains "$RULES" "## Blocked in Udon Runtime"
assert_contains "$RULES" "Editor-Evaluated Field Initializers"
assert_contains "$RULES" 'Nondeterministic calls such as `Random.Range`'
assert_contains "$RULES" "compiled Udon program's baked default"
assert_contains "$REFERENCE" "### Editor-Evaluated Field Initializers vs. Udon Runtime"
assert_contains "$REFERENCE" "Random.Range"
assert_contains "$REFERENCE" "per-instance, per-client, or per-session randomness"
assert_contains "$REFERENCE" "private readonly string[] numberLabels"
assert_contains "$REFERENCE" ".Select(value =>"
assert_contains "$REFERENCE" "public static int[] CreateSquares"
assert_contains "$REFERENCE" "List<int> values = new List<int>();"
assert_contains "$REFERENCE" "The final field type and value must be supported by Udon."
assert_contains "$REFERENCE" "Networking.LocalPlayer"
assert_contains "$REFERENCE" "FindObjectsByType"
assert_contains "$REFERENCE" "loading thread"
assert_contains "$REFERENCE" "Start()"
assert_contains "$REFERENCE" "Interact()"
assert_contains "$TROUBLESHOOTING" "Editor-evaluated field initializer"
assert_contains "$TROUBLESHOOTING" "Random.Range"
assert_contains "$TROUBLESHOOTING" "baked default"
assert_contains "$TROUBLESHOOTING" "Udon runtime"
assert_contains "$CHEATSHEET" "## Features Blocked in Udon Runtime"
assert_contains "$CHEATSHEET" "Random.Range"
assert_contains "$CHEATSHEET" "baked default"

mapfile -t readmes < <(find . -maxdepth 1 -type f -name 'README*.md' -printf '%f\n' | sort)
expected_readmes=(README.ja.md README.ko.md README.md README.zh-CN.md README.zh-TW.md)
[ "${readmes[*]}" = "${expected_readmes[*]}" ] || fail "expected exactly the five maintained README translations"

for readme in "${expected_readmes[@]}"; do
    assert_contains "$readme" "Udon runtime"
    assert_runtime_warning_row "$readme"
done

printf 'PASS: field initializer and Udon runtime documentation boundary\n'
