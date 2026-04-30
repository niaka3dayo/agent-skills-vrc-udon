#!/usr/bin/env bash
# Smoke test for skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
# Covers the failure modes reported in Issue #165:
#   Case A: jq absent  → must exit 0 with stdout = input passthrough
#   Case B: jq present, file_path missing → must exit 0 cleanly (no abort)
#   Case C: jq present, valid .cs with List<T> → existing WARNING on stderr (happy path)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh"
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

PASS=0
FAIL=0

assert_exit() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "PASS [$label] exit=$actual"
        PASS=$((PASS + 1))
    else
        echo "FAIL [$label] exit: expected=$expected actual=$actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        echo "PASS [$label] contains: $needle"
        PASS=$((PASS + 1))
    else
        echo "FAIL [$label] missing: $needle"
        echo "  haystack (truncated): $(printf '%s' "$haystack" | head -c 200)"
        FAIL=$((FAIL + 1))
    fi
}

# ------------------------------------------------------------
# Case A: jq absent → exit 0, stdout = input passthrough
# ------------------------------------------------------------
NOJQ_BIN="$TMPROOT/nojq-bin"
mkdir -p "$NOJQ_BIN"

# Symlink standard tools the hook needs, but deliberately omit jq.
for tool in bash cat grep sed sort uniq tr head awk dirname basename rm mkdir; do
    src=""
    for dir in /bin /usr/bin /usr/local/bin; do
        if [ -x "$dir/$tool" ]; then
            src="$dir/$tool"
            break
        fi
    done
    if [ -n "$src" ]; then
        ln -s "$src" "$NOJQ_BIN/$tool"
    fi
done

# Confirm jq really is missing in NOJQ_BIN PATH (precondition guard).
jq_check=$(env -i PATH="$NOJQ_BIN" "$NOJQ_BIN/bash" -c 'command -v jq >/dev/null && echo FOUND || echo MISSING')
if [ "$jq_check" != "MISSING" ]; then
    echo "ABORT: precondition failed — NOJQ_BIN PATH still resolves jq ($jq_check)"
    exit 2
fi

CASE_A_INPUT='{"tool_input":{"file_path":"Foo.cs"}}'
A_STDOUT=$(printf '%s' "$CASE_A_INPUT" | env -i PATH="$NOJQ_BIN" HOME="${HOME:-/tmp}" "$NOJQ_BIN/bash" "$HOOK" 2>"$TMPROOT/case_a.err")
A_RC=$?

assert_exit "A: jq absent → exit 0" 0 "$A_RC"
assert_contains "A: stdout passes input through" "$A_STDOUT" '"file_path":"Foo.cs"'

# ------------------------------------------------------------
# Case B: jq present, file_path / filePath both missing → exit 0, no abort
# ------------------------------------------------------------
# Precondition: Cases B and C run against the unrestricted environment and
# require jq to actually be installed. Without this guard, a runner that
# happens to lack jq would silently fall through Case A's new passthrough
# and stop testing what B/C claim to test.
if ! command -v jq >/dev/null 2>&1; then
    echo "ABORT: Cases B/C require jq in PATH (precondition not met)"
    exit 2
fi

CASE_B_INPUT='{"tool_input":{}}'
B_STDOUT=$(printf '%s' "$CASE_B_INPUT" | "$HOOK" 2>"$TMPROOT/case_b.err")
B_RC=$?

assert_exit "B: jq present + no file_path → exit 0" 0 "$B_RC"
assert_contains "B: stdout passes input through" "$B_STDOUT" '"tool_input":{}'

# ------------------------------------------------------------
# Case C: jq present, valid .cs with List<T> → expected WARNING on stderr (happy path)
# ------------------------------------------------------------
CASE_C_FILE="$TMPROOT/Sample.cs"
cat > "$CASE_C_FILE" <<'CSEOF'
using UdonSharp;
using System.Collections.Generic;
public class Sample : UdonSharpBehaviour
{
    private List<int> items = new List<int>();
}
CSEOF
CASE_C_INPUT="{\"tool_input\":{\"file_path\":\"$CASE_C_FILE\"}}"
C_STDOUT=$(printf '%s' "$CASE_C_INPUT" | "$HOOK" 2>"$TMPROOT/case_c.err")
C_RC=$?
C_STDERR=$(cat "$TMPROOT/case_c.err")

assert_exit "C: happy path → exit 0" 0 "$C_RC"
assert_contains "C: List<T> WARNING fires" "$C_STDERR" 'Generic collections (List<T>'

echo ""
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
