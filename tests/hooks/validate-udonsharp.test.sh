#!/usr/bin/env bash
# Smoke test for skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
# Covers the failure modes reported in Issue #165:
#   Case A: jq absent  → must exit 0 with stdout = input passthrough
#   Case B: jq present, file_path missing → must exit 0 cleanly (no abort)
#   Case C: jq present, valid .cs with List<T> → existing WARNING on stderr (happy path)
#   Cases D-H: synced array detection regressions from Issue #307
#   Cases I-P: field forms, CRLF, and block-comment review regressions
#   Cases Q-V: combined/chained attribute-group regressions

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

assert_not_contains() {
    local label="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        echo "FAIL [$label] unexpected: $needle"
        echo "  haystack (truncated): $(printf '%s' "$haystack" | head -c 200)"
        FAIL=$((FAIL + 1))
    else
        echo "PASS [$label] does not contain: $needle"
        PASS=$((PASS + 1))
    fi
}

run_hook() {
    local file_path="$1" stderr_path="$2"
    local hook_input
    hook_input="{\"tool_input\":{\"file_path\":\"$file_path\"}}"
    printf '%s' "$hook_input" | "$HOOK" 2>"$stderr_path" >/dev/null
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

# ------------------------------------------------------------
# Cases D-G: synced int[]/float[] on the same or immediately preceding line
# ------------------------------------------------------------
SYNC_BLOAT_WARNING='Synced int[]/float[] detected'

for case_spec in \
    "D:same-line int[]:[UdonSynced] private int[] values;" \
    "E:preceding-line int[]:[UdonSynced]|    private int[] values;" \
    "F:same-line float[]:[UdonSynced] private float[] values;" \
    "G:preceding-line float[]:[UdonSynced]|    private float[] values;"
do
    case_id=${case_spec%%:*}
    remainder=${case_spec#*:}
    case_label=${remainder%%:*}
    declaration=${remainder#*:}
    case_file="$TMPROOT/case_${case_id}.cs"

    {
        echo 'using UdonSharp;'
        echo 'public class Sample : UdonSharpBehaviour'
        echo '{'
        printf '    %s\n' "$declaration" | tr '|' '\n'
        echo '}'
    } > "$case_file"

    run_hook "$case_file" "$TMPROOT/case_${case_id}.err"
    case_stderr=$(cat "$TMPROOT/case_${case_id}.err")
    assert_contains "$case_id: $case_label warns" "$case_stderr" "$SYNC_BLOAT_WARNING"
done

# ------------------------------------------------------------
# Case H: ordinary unsynced arrays must not emit the sync-bloat warning
# ------------------------------------------------------------
CASE_H_FILE="$TMPROOT/case_H.cs"
cat > "$CASE_H_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] private byte[] compactValues;
    private int[] integerValues;
    private float[] floatValues;
}
CSEOF
run_hook "$CASE_H_FILE" "$TMPROOT/case_H.err"
H_STDERR=$(cat "$TMPROOT/case_H.err")
assert_not_contains "H: unsynced int[]/float[] do not warn" "$H_STDERR" "$SYNC_BLOAT_WARNING"

# ------------------------------------------------------------
# Cases I-J: CRLF input must match same-line and preceding-line declarations
# ------------------------------------------------------------
CASE_I_FILE="$TMPROOT/case_I.cs"
printf '%s\r\n' \
    'using UdonSharp;' \
    'public class Sample : UdonSharpBehaviour' \
    '{' \
    '    [UdonSynced] private int[] values;' \
    '}' > "$CASE_I_FILE"
run_hook "$CASE_I_FILE" "$TMPROOT/case_I.err"
I_STDERR=$(cat "$TMPROOT/case_I.err")
assert_contains "I: CRLF same-line declaration warns" "$I_STDERR" "$SYNC_BLOAT_WARNING"

CASE_J_FILE="$TMPROOT/case_J.cs"
printf '%s\r\n' \
    'using UdonSharp;' \
    'public class Sample : UdonSharpBehaviour' \
    '{' \
    '    [UdonSynced]' \
    '    private float[] values;' \
    '}' > "$CASE_J_FILE"
run_hook "$CASE_J_FILE" "$TMPROOT/case_J.err"
J_STDERR=$(cat "$TMPROOT/case_J.err")
assert_contains "J: CRLF preceding-line declaration warns" "$J_STDERR" "$SYNC_BLOAT_WARNING"

# ------------------------------------------------------------
# Cases K-M: valid declaration prefixes need not end on the first line
# ------------------------------------------------------------
CASE_K_FILE="$TMPROOT/case_K.cs"
cat > "$CASE_K_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] private int[] values =
        new int[]
        {
            1,
            2
        };
}
CSEOF
run_hook "$CASE_K_FILE" "$TMPROOT/case_K.err"
K_STDERR=$(cat "$TMPROOT/case_K.err")
assert_contains "K: multiline initializer warns" "$K_STDERR" "$SYNC_BLOAT_WARNING"

CASE_L_FILE="$TMPROOT/case_L.cs"
cat > "$CASE_L_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] // Applies to the immediately following physical line.
    private float[] values;
}
CSEOF
run_hook "$CASE_L_FILE" "$TMPROOT/case_L.err"
L_STDERR=$(cat "$TMPROOT/case_L.err")
assert_contains "L: attribute with trailing line comment warns" "$L_STDERR" "$SYNC_BLOAT_WARNING"

CASE_M_FILE="$TMPROOT/case_M.cs"
cat > "$CASE_M_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] private int[] values, previousValues;
}
CSEOF
run_hook "$CASE_M_FILE" "$TMPROOT/case_M.err"
M_STDERR=$(cat "$TMPROOT/case_M.err")
assert_contains "M: multiple declarators warn" "$M_STDERR" "$SYNC_BLOAT_WARNING"

# ------------------------------------------------------------
# Cases N-P: block comments do not contain declarations for this rule, and
# an attribute applies to exactly the immediately following physical line.
# ------------------------------------------------------------
CASE_N_FILE="$TMPROOT/case_N.cs"
cat > "$CASE_N_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    /*
    [UdonSynced] private int[] values;
    */
}
CSEOF
run_hook "$CASE_N_FILE" "$TMPROOT/case_N.err"
N_STDERR=$(cat "$TMPROOT/case_N.err")
assert_not_contains "N: same-line declaration in block comment does not warn" "$N_STDERR" "$SYNC_BLOAT_WARNING"

CASE_O_FILE="$TMPROOT/case_O.cs"
cat > "$CASE_O_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    /*
    [UdonSynced]
    private float[] values;
    */
}
CSEOF
run_hook "$CASE_O_FILE" "$TMPROOT/case_O.err"
O_STDERR=$(cat "$TMPROOT/case_O.err")
assert_not_contains "O: preceding-line declaration in block comment does not warn" "$O_STDERR" "$SYNC_BLOAT_WARNING"

CASE_P_FILE="$TMPROOT/case_P.cs"
cat > "$CASE_P_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] // The blank line consumes the attribute association.

    private int[] values;
}
CSEOF
run_hook "$CASE_P_FILE" "$TMPROOT/case_P.err"
P_STDERR=$(cat "$TMPROOT/case_P.err")
assert_not_contains "P: attribute does not skip a physical line" "$P_STDERR" "$SYNC_BLOAT_WARNING"

# ------------------------------------------------------------
# Cases Q-V: UdonSynced may share or precede other attribute groups, but an
# unrelated attribute group must not mark the field as synced.
# ------------------------------------------------------------
for case_spec in \
    "Q:combined attributes on same line:[UdonSynced, FieldChangeCallback(nameof(Values))] private int[] values;" \
    "R:combined attributes on preceding line:[UdonSynced, FieldChangeCallback(nameof(Values))]|    private float[] values;" \
    "S:chained attributes on same line:[UdonSynced][FieldChangeCallback(nameof(Values))] private float[] values;" \
    "T:chained attributes on preceding line:[UdonSynced][FieldChangeCallback(nameof(Values))]|    private int[] values;"
do
    case_id=${case_spec%%:*}
    remainder=${case_spec#*:}
    case_label=${remainder%%:*}
    declaration=${remainder#*:}
    case_file="$TMPROOT/case_${case_id}.cs"

    {
        echo 'using UdonSharp;'
        echo 'public class Sample : UdonSharpBehaviour'
        echo '{'
        printf '    %s\n' "$declaration" | tr '|' '\n'
        echo '}'
    } > "$case_file"

    run_hook "$case_file" "$TMPROOT/case_${case_id}.err"
    case_stderr=$(cat "$TMPROOT/case_${case_id}.err")
    assert_contains "$case_id: $case_label warns" "$case_stderr" "$SYNC_BLOAT_WARNING"
done

CASE_U_FILE="$TMPROOT/case_U.cs"
cat > "$CASE_U_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [FieldChangeCallback(nameof(Values))]
    private int[] values;
}
CSEOF
run_hook "$CASE_U_FILE" "$TMPROOT/case_U.err"
U_STDERR=$(cat "$TMPROOT/case_U.err")
assert_not_contains "U: FieldChangeCallback-only field does not warn" "$U_STDERR" "$SYNC_BLOAT_WARNING"

CASE_V_FILE="$TMPROOT/case_V.cs"
cat > "$CASE_V_FILE" <<'CSEOF'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced, Example(typeof(int[]))] private float[] values;
}
CSEOF
run_hook "$CASE_V_FILE" "$TMPROOT/case_V.err"
V_STDERR=$(cat "$TMPROOT/case_V.err")
assert_contains "V: array type inside combined attribute group warns" "$V_STDERR" "$SYNC_BLOAT_WARNING"

echo ""
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
