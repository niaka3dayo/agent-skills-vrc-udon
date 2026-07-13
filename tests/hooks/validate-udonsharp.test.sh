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
SHARED_FIXTURES="$REPO_ROOT/tests/hooks/fixtures/validate-udonsharp"
SHARED_RULES="$SHARED_FIXTURES/rules.tsv"
SHARED_CASES="$SHARED_FIXTURES/cases.tsv"
TEMPLATE_CASES="$SHARED_FIXTURES/template-cases.tsv"
TEMPLATE_ROOT="$REPO_ROOT/skills/unity-vrc-udon-sharp/assets/templates"
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
    RUN_HOOK_INPUT="{\"tool_input\":{\"file_path\":\"$file_path\"}}"
    RUN_HOOK_STDOUT=$(printf '%s' "$RUN_HOOK_INPUT" | "$HOOK" 2>"$stderr_path")
    RUN_HOOK_STATUS=$?
}

materialize_fixture() {
    local source="$1" target="$2" newline="$3"
    if [ "$newline" = "LF" ]; then
        cp "$source" "$target"
        return
    fi

    local final_lf=0
    if [[ -s "$source" ]] && [[ "$(tail -c 1 "$source" | wc -l | tr -d '[:space:]')" -eq 1 ]]; then
        final_lf=1
    fi
    awk -v final_lf="$final_lf" '
        {
            sub(/\r$/, "")
            if (NR > 1) printf "\r\n"
            printf "%s", $0
        }
        END {
            if (final_lf) printf "\r\n"
        }
    ' "$source" > "$target"
}

run_shared_parity_matrix() {
    local expected_inventory='GENERIC;ASYNC;TRY_CATCH;LINQ;YIELD_RETURN;INTERFACE;START_COROUTINE;ADD_LISTENER;LAMBDA;SYNC_NO_SERIALIZE;SYNC_NO_OWNER;PLAYER_VALIDITY;UNITY_CALLBACK_OVERRIDE;GETCOMPONENT_UDON;SYSTEM_IO_NET;SYNC_COUNT;SYNC_ARRAY;SYNC_MODE_CONFLICT;MULTIDIM_ARRAY;METHOD_OVERLOAD'
    local rule_ids=()
    local rule_substrings=()
    local seen_rule_ids=';'
    local seen_rule_substrings=';'
    local id substring extra

    while IFS=$'\t' read -r id substring extra || [ -n "${id:-}" ]; do
        if [ -z "$id" ] || [ -z "$substring" ] || [ -n "${extra:-}" ]; then
            echo "FAIL [shared rules] malformed rules.tsv row: ${id:-}<TAB>${substring:-}"
            FAIL=$((FAIL + 1))
            return
        fi
        if [[ ! "$id" =~ ^[A-Z][A-Z0-9_]*$ ]] || [[ "$seen_rule_ids" == *";$id;"* ]]; then
            echo "FAIL [shared rules] unknown or duplicate rule ID: $id"
            FAIL=$((FAIL + 1))
            return
        fi
        if [[ "$seen_rule_substrings" == *";$substring;"* ]]; then
            echo "FAIL [shared rules] duplicate warning substring: $substring"
            FAIL=$((FAIL + 1))
            return
        fi
        rule_ids+=("$id")
        rule_substrings+=("$substring")
        seen_rule_ids+="$id;"
        seen_rule_substrings+="$substring;"
    done < "$SHARED_RULES"

    local actual_inventory
    actual_inventory="$(IFS=';'; echo "${rule_ids[*]}")"
    if [ "$actual_inventory" != "$expected_inventory" ]; then
        echo "FAIL [shared rules] 20-rule inventory mismatch"
        echo "  expected: $expected_inventory"
        echo "  actual:   $actual_inventory"
        FAIL=$((FAIL + 1))
        return
    fi
    echo "PASS [shared rules] 20-rule inventory is exact"
    PASS=$((PASS + 1))

    map_warning_file() {
        local warning_file="$1"
        mapped_ids_result=()
        mapping_failed=0
        local actual_seen=';'
        local warning_line match_count matched_id index

        while IFS= read -r warning_line || [ -n "$warning_line" ]; do
            if [[ "$warning_line" == *"[UdonSharp] VALIDATOR-WARNING:"* ]] ||
                [[ "$warning_line" == *"lexical mask length mismatch"* ]]; then
                echo "FAIL [shared mapping] validator internal failure detected"
                mapping_failed=1
                return
            fi
            if [[ ! "$warning_line" =~ \[UdonSharp\][[:space:]]+(BLOCKED|WARNING|SYNC-BLOAT|ERROR): ]]; then
                continue
            fi

            match_count=0
            matched_id=''
            for ((index = 0; index < ${#rule_ids[@]}; index++)); do
                if [[ "$warning_line" == *"${rule_substrings[$index]}"* ]]; then
                    match_count=$((match_count + 1))
                    matched_id="${rule_ids[$index]}"
                fi
            done
            if [ "$match_count" -ne 1 ]; then
                echo "FAIL [shared mapping] warning line maps to $match_count rule IDs"
                echo "  line: $warning_line"
                mapping_failed=1
                return
            fi
            if [[ "$actual_seen" == *";$matched_id;"* ]]; then
                echo "FAIL [shared mapping] duplicate actual rule ID: $matched_id"
                mapping_failed=1
                return
            fi
            actual_seen+="$matched_id;"
            mapped_ids_result+=("$matched_id")
        done < "$warning_file"
    }

    local synthetic_warning_file="$TMPROOT/shared-order-meta.err"
    printf '[UdonSharp] BLOCKED: %s\n[UdonSharp] BLOCKED: %s\n'         "${rule_substrings[1]}" "${rule_substrings[0]}" > "$synthetic_warning_file"
    map_warning_file "$synthetic_warning_file"
    local synthetic_actual
    synthetic_actual="$(IFS=';'; echo "${mapped_ids_result[*]}")"
    if [ "$mapping_failed" -eq 0 ] && [ "$synthetic_actual" = "${rule_ids[1]};${rule_ids[0]}" ]; then
        echo "PASS [shared mapping] actual warning order is preserved"
        PASS=$((PASS + 1))
    else
        echo "FAIL [shared mapping] actual warning order was reordered"
        FAIL=$((FAIL + 1))
    fi

    local seen_case_ids=';'
    local expected_rule_coverage=';'
    local case_id fixture newline expected_ids case_extra
    local case_count=0
    while IFS=$'\t' read -r case_id fixture newline expected_ids case_extra || [ -n "${case_id:-}" ]; do
        case_count=$((case_count + 1))
        if [ -z "$case_id" ] || [ -z "$fixture" ] || [ -z "$newline" ] || [ -z "$expected_ids" ] || [ -n "${case_extra:-}" ]; then
            echo "FAIL [shared case $case_count] malformed cases.tsv row"
            FAIL=$((FAIL + 1))
            continue
        fi
        if [[ "$seen_case_ids" == *";$case_id;"* ]]; then
            echo "FAIL [shared case $case_id] duplicate case ID"
            FAIL=$((FAIL + 1))
            continue
        fi
        seen_case_ids+="$case_id;"
        if [ "$newline" != "LF" ] && [ "$newline" != "CRLF" ]; then
            echo "FAIL [shared case $case_id] unknown newline mode: $newline"
            FAIL=$((FAIL + 1))
            continue
        fi
        if [ ! -f "$SHARED_FIXTURES/$fixture" ]; then
            echo "FAIL [shared case $case_id] missing fixture: $fixture"
            FAIL=$((FAIL + 1))
            continue
        fi

        local expected=''
        local expected_seen=';'
        if [ "$expected_ids" != "-" ]; then
            local expected_parts=()
            IFS=';' read -r -a expected_parts <<< "$expected_ids"
            local expected_id
            for expected_id in "${expected_parts[@]}"; do
                if [[ "$seen_rule_ids" != *";$expected_id;"* ]]; then
                    echo "FAIL [shared case $case_id] unknown expected rule ID: $expected_id"
                    FAIL=$((FAIL + 1))
                    expected='__INVALID__'
                    break
                fi
                if [[ "$expected_seen" == *";$expected_id;"* ]]; then
                    echo "FAIL [shared case $case_id] duplicate expected rule ID: $expected_id"
                    FAIL=$((FAIL + 1))
                    expected='__INVALID__'
                    break
                fi
                expected_seen+="$expected_id;"
                expected_rule_coverage+="$expected_id;"
            done
            if [ "$expected" = '__INVALID__' ]; then
                continue
            fi
            local ordered_expected=()
            for id in "${rule_ids[@]}"; do
                if [[ "$expected_seen" == *";$id;"* ]]; then
                    ordered_expected+=("$id")
                fi
            done
            expected="$(IFS=';'; echo "${ordered_expected[*]}")"
            if [ "$expected" != "$expected_ids" ]; then
                echo "FAIL [shared case $case_id] expected IDs are not in rules.tsv order"
                FAIL=$((FAIL + 1))
                continue
            fi
        fi

        local materialized="$TMPROOT/shared-$case_id.cs"
        materialize_fixture "$SHARED_FIXTURES/$fixture" "$materialized" "$newline"

        local stderr_path="$TMPROOT/shared-$case_id.err"
        run_hook "$materialized" "$stderr_path"
        if [ "$RUN_HOOK_STATUS" -ne 0 ]; then
            echo "FAIL [shared case $case_id] hook exit: $RUN_HOOK_STATUS"
            FAIL=$((FAIL + 1))
            continue
        fi
        if [ "$RUN_HOOK_STDOUT" != "$RUN_HOOK_INPUT" ]; then
            echo "FAIL [shared case $case_id] stdout did not preserve hook input"
            FAIL=$((FAIL + 1))
            continue
        fi
        if grep -Fq 'validator internal error' "$stderr_path"; then
            echo "FAIL [shared case $case_id] lexical mask invariant failed"
            FAIL=$((FAIL + 1))
            continue
        fi
        map_warning_file "$stderr_path"
        if [ "$mapping_failed" -ne 0 ]; then
            echo "FAIL [shared case $case_id] warning mapping failed"
            FAIL=$((FAIL + 1))
            continue
        fi
        local actual_ids=("${mapped_ids_result[@]}")
        local actual
        actual="$(IFS=';'; echo "${actual_ids[*]}")"
        if [ "$actual" = "$expected" ]; then
            echo "PASS [shared case $case_id] rules=${actual:--}"
            PASS=$((PASS + 1))
        else
            echo "FAIL [shared case $case_id] rules mismatch"
            echo "  expected: ${expected:--}"
            echo "  actual:   ${actual:--}"
            FAIL=$((FAIL + 1))
        fi
    done < "$SHARED_CASES"

    local template_name template_expected template_extra template_path template_stderr template_actual
    local template_count=0
    while IFS=$'\t' read -r template_name template_expected template_extra || [ -n "$template_name" ]; do
        template_count=$((template_count + 1))
        if [ -z "$template_name" ] || [ -z "$template_expected" ] || [ -n "${template_extra:-}" ]; then
            echo "FAIL [template case $template_count] malformed template-cases.tsv row"
            FAIL=$((FAIL + 1))
            continue
        fi
        template_path="$TEMPLATE_ROOT/$template_name"
        if [ ! -f "$template_path" ]; then
            echo "FAIL [template case $template_name] missing template"
            FAIL=$((FAIL + 1))
            continue
        fi
        template_stderr="$TMPROOT/template-$template_count.err"
        run_hook "$template_path" "$template_stderr"
        if [ "$RUN_HOOK_STATUS" -ne 0 ]; then
            echo "FAIL [template case $template_name] hook exit: $RUN_HOOK_STATUS"
            FAIL=$((FAIL + 1))
            continue
        fi
        if [ "$RUN_HOOK_STDOUT" != "$RUN_HOOK_INPUT" ]; then
            echo "FAIL [template case $template_name] stdout did not preserve hook input"
            FAIL=$((FAIL + 1))
            continue
        fi
        map_warning_file "$template_stderr"
        if [ "$mapping_failed" -ne 0 ]; then
            echo "FAIL [template case $template_name] warning mapping failed"
            FAIL=$((FAIL + 1))
            continue
        fi
        template_actual="$(IFS=';'; echo "${mapped_ids_result[*]}")"
        if [ "$template_expected" = "-" ]; then template_expected=""; fi
        if [ "$template_actual" = "$template_expected" ]; then
            echo "PASS [template case $template_name] rules=${template_actual:--}"
            PASS=$((PASS + 1))
        else
            echo "FAIL [template case $template_name] expected=${template_expected:--} actual=${template_actual:--}"
            FAIL=$((FAIL + 1))
        fi
    done < "$TEMPLATE_CASES"

    local repository_template_count
    repository_template_count="$(find "$TEMPLATE_ROOT" -maxdepth 1 -type f -name '*.cs' | wc -l | tr -d '[:space:]')"
    if [ "$template_count" = "$repository_template_count" ]; then
        echo "PASS [template cases] manifest covers all $template_count templates"
        PASS=$((PASS + 1))
    else
        echo "FAIL [template cases] manifest=$template_count repository=$repository_template_count"
        FAIL=$((FAIL + 1))
    fi

    for id in "${rule_ids[@]}"; do
        if [[ "$expected_rule_coverage" != *";$id;"* ]]; then
            echo "FAIL [shared rules] rule ID missing from expected cases: $id"
            FAIL=$((FAIL + 1))
        fi
    done
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

A_STDERR=$(cat "$TMPROOT/case_a.err")
assert_contains "A: jq absence is explicit" "$A_STDERR" 'VALIDATOR-WARNING: validation skipped (JQ_UNAVAILABLE)'
if [ "$(wc -l < "$TMPROOT/case_a.err" | tr -d '[:space:]')" = "1" ]; then
    echo "PASS [A: operational warning] exactly one stderr line"
    PASS=$((PASS + 1))
else
    echo "FAIL [A: operational warning] expected exactly one stderr line"
    FAIL=$((FAIL + 1))
fi

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

MALFORMED_INPUT='{"tool_input":'
MALFORMED_STDOUT=$(printf '%s' "$MALFORMED_INPUT" | "$HOOK" 2>"$TMPROOT/malformed.err")
MALFORMED_RC=$?
assert_exit "B2: malformed JSON → exit 0" 0 "$MALFORMED_RC"
assert_contains "B2: malformed JSON passes input through" "$MALFORMED_STDOUT" "$MALFORMED_INPUT"
assert_contains "B2: parse failure is explicit" "$(cat "$TMPROOT/malformed.err")" 'VALIDATOR-WARNING: validation skipped (JSON_PARSE_FAILED)'

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

BAD_TMPDIR="$TMPROOT/does-not-exist"
TMPFAIL_STDOUT=$(printf '%s' "$CASE_C_INPUT" | TMPDIR="$BAD_TMPDIR" "$HOOK" 2>"$TMPROOT/tmpfail.err")
TMPFAIL_RC=$?
assert_exit "C2: temp creation failure → exit 0" 0 "$TMPFAIL_RC"
assert_contains "C2: temp failure passes input through" "$TMPFAIL_STDOUT" "$CASE_C_FILE"
assert_contains "C2: temp failure is explicit" "$(cat "$TMPROOT/tmpfail.err")" 'VALIDATOR-WARNING: validation skipped (TEMP_CREATE_FAILED)'
if [ "$(wc -l < "$TMPROOT/tmpfail.err" | tr -d '[:space:]')" = "1" ]; then
    echo "PASS [C2: operational warning] exactly one stderr line"
    PASS=$((PASS + 1))
else
    echo "FAIL [C2: operational warning] expected exactly one stderr line"
    FAIL=$((FAIL + 1))
fi

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
    [UdonSynced] // Blank trivia does not detach an attribute from its declaration.

    private int[] values;
}
CSEOF
run_hook "$CASE_P_FILE" "$TMPROOT/case_P.err"
P_STDERR=$(cat "$TMPROOT/case_P.err")
assert_contains "P: blank trivia preserves attribute attachment" "$P_STDERR" "$SYNC_BLOAT_WARNING"

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

# ------------------------------------------------------------
# EOF/newline preservation and adversarial raw-string performance
# ------------------------------------------------------------
printf 'alpha\nbeta' > "$TMPROOT/no-final-lf.txt"
materialize_fixture "$TMPROOT/no-final-lf.txt" "$TMPROOT/no-final-crlf.txt" CRLF
printf 'alpha\r\nbeta' > "$TMPROOT/no-final-expected.txt"
if cmp -s "$TMPROOT/no-final-crlf.txt" "$TMPROOT/no-final-expected.txt"; then
    echo "PASS [materializer] CRLF conversion preserves missing final newline"
    PASS=$((PASS + 1))
else
    echo "FAIL [materializer] CRLF conversion changed missing final newline"
    FAIL=$((FAIL + 1))
fi

printf 'alpha\nbeta\n' > "$TMPROOT/final-lf.txt"
materialize_fixture "$TMPROOT/final-lf.txt" "$TMPROOT/final-crlf.txt" CRLF
printf 'alpha\r\nbeta\r\n' > "$TMPROOT/final-expected.txt"
if cmp -s "$TMPROOT/final-crlf.txt" "$TMPROOT/final-expected.txt"; then
    echo "PASS [materializer] CRLF conversion preserves final newline"
    PASS=$((PASS + 1))
else
    echo "FAIL [materializer] CRLF conversion lost final newline"
    FAIL=$((FAIL + 1))
fi

RAW_PERF_FILE="$TMPROOT/raw-performance.cs"
{
    printf 'using UdonSharp;\npublic class RawPerformance : UdonSharpBehaviour\n{\n    private string value = '
    for ((raw_i = 0; raw_i < 15000; raw_i++)); do printf '"'; done
    printf '\n'
    for ((raw_i = 0; raw_i < 14999; raw_i++)); do printf '"'; done
    printf '\n'
    for ((raw_i = 0; raw_i < 15000; raw_i++)); do printf '"'; done
    printf ';\n}\n'
} > "$RAW_PERF_FILE"
RAW_PERF_INPUT="{\"tool_input\":{\"file_path\":\"$RAW_PERF_FILE\"}}"
if command -v timeout >/dev/null 2>&1; then
    printf '%s' "$RAW_PERF_INPUT" | timeout 5s "$HOOK" >/dev/null 2>"$TMPROOT/raw-performance.err"
    RAW_PERF_RC=$?
else
    printf '%s' "$RAW_PERF_INPUT" | "$HOOK" >/dev/null 2>"$TMPROOT/raw-performance.err"
    RAW_PERF_RC=$?
fi
assert_exit "raw string linear scan" 0 "$RAW_PERF_RC"
assert_not_contains "raw string scan has no internal failure" "$(cat "$TMPROOT/raw-performance.err")" 'VALIDATOR-WARNING'

DOLLAR_RUN_PERF_LOG="$TMPROOT/dollar-run-performance.log"
if python3 - "$HOOK" "$TMPROOT" >"$DOLLAR_RUN_PERF_LOG" 2>&1 <<'PY'
import json
import pathlib
import subprocess
import sys
import time

hook = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])


def measure(run_length: int) -> float:
    source = root / f"dollar-run-{run_length}.cs"
    source.write_text(
        "using UdonSharp;\n"
        "public class DollarRun : UdonSharpBehaviour\n"
        "{\n"
        "    private int value = " + "$" * run_length + ";\n"
        "}\n",
        encoding="utf-8",
    )
    payload = json.dumps({"tool_input": {"file_path": str(source)}}, separators=(",", ":"))
    started = time.monotonic()
    result = subprocess.run(
        [str(hook)],
        input=payload,
        text=True,
        capture_output=True,
        timeout=15,
        check=False,
    )
    elapsed = time.monotonic() - started
    if result.returncode != 0:
        raise RuntimeError(f"{run_length} dollars exited {result.returncode}")
    if result.stdout.strip() != payload:
        raise RuntimeError(f"{run_length} dollars did not preserve stdout")
    if "VALIDATOR-WARNING" in result.stderr:
        raise RuntimeError(f"{run_length} dollars triggered an internal failure")
    return elapsed


measure(100)
small = measure(2000)
large = measure(8000)
limit = min(2.5, small * 8 + 0.5)
print(f"contiguous dollars: 2000={small:.3f}s 8000={large:.3f}s limit={limit:.3f}s")
if large > limit:
    raise SystemExit(1)
PY
then
    echo "PASS [contiguous dollar scan] $(cat "$DOLLAR_RUN_PERF_LOG")"
    PASS=$((PASS + 1))
else
    echo "FAIL [contiguous dollar scan]"
    sed 's/^/  /' "$DOLLAR_RUN_PERF_LOG"
    FAIL=$((FAIL + 1))
fi

DECLARATION_CAP_FILE="$TMPROOT/declaration-cap.cs"
{
    printf 'using UdonSharp;\npublic class DeclarationCap : UdonSharpBehaviour\n{\n    [UdonSynced]\n    '
    head -c 270000 /dev/zero | tr '\0' 'A'
    printf '\n'
} > "$DECLARATION_CAP_FILE"
run_hook "$DECLARATION_CAP_FILE" "$TMPROOT/declaration-cap.err"
assert_exit "declaration cap fails open" 0 "$RUN_HOOK_STATUS"
if [ "$RUN_HOOK_STDOUT" = "$RUN_HOOK_INPUT" ]; then
    echo "PASS [declaration cap] stdout preserves hook input"
    PASS=$((PASS + 1))
else
    echo "FAIL [declaration cap] stdout did not preserve hook input"
    FAIL=$((FAIL + 1))
fi
if grep -Fxq '[UdonSharp] VALIDATOR-WARNING: validation skipped (ATTRIBUTE_SCAN_FAILED)' "$TMPROOT/declaration-cap.err" &&
    [ "$(wc -l < "$TMPROOT/declaration-cap.err" | tr -d '[:space:]')" = "1" ]; then
    echo "PASS [declaration cap] exactly one operational warning"
    PASS=$((PASS + 1))
else
    echo "FAIL [declaration cap] expected exactly one ATTRIBUTE_SCAN_FAILED warning"
    FAIL=$((FAIL + 1))
fi

UNICODE_DECLARATION_CAP_FILE="$TMPROOT/declaration-cap-unicode.cs"
python3 - "$UNICODE_DECLARATION_CAP_FILE" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    "using UdonSharp;\n"
    "public class DeclarationCapUnicode : UdonSharpBehaviour\n"
    "{\n"
    "    [UdonSynced]\n"
    "    " + "界" * 88000 + "\n",
    encoding="utf-8",
)
PY
UNICODE_CAP_INPUT="{\"tool_input\":{\"file_path\":\"$UNICODE_DECLARATION_CAP_FILE\"}}"
for cap_locale in C C.UTF-8; do
    if ! locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -Fxq "$(printf '%s' "$cap_locale" | tr '[:upper:]' '[:lower:]' | tr -d '-')" &&
        [ "$cap_locale" != C ]; then
        continue
    fi
    cap_stderr="$TMPROOT/declaration-cap-unicode-${cap_locale//[^A-Za-z0-9]/_}.err"
    cap_stdout=$(printf '%s' "$UNICODE_CAP_INPUT" | LC_ALL="$cap_locale" "$HOOK" 2>"$cap_stderr")
    cap_status=$?
    assert_exit "unicode declaration cap ($cap_locale) fails open" 0 "$cap_status"
    if [ "$cap_stdout" = "$UNICODE_CAP_INPUT" ] &&
        [ "$(cat "$cap_stderr")" = '[UdonSharp] VALIDATOR-WARNING: validation skipped (ATTRIBUTE_SCAN_FAILED)' ]; then
        echo "PASS [unicode declaration cap $cap_locale] UTF-8 byte limit is stable"
        PASS=$((PASS + 1))
    else
        echo "FAIL [unicode declaration cap $cap_locale] byte-limit contract mismatch"
        FAIL=$((FAIL + 1))
    fi
done

DECLARATION_PERF_LOG="$TMPROOT/declaration-performance.log"
if python3 - "$HOOK" "$TMPROOT" >"$DECLARATION_PERF_LOG" 2>&1 <<'PY'
import json
import pathlib
import subprocess
import sys
import time

hook = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])


def measure(line_count: int) -> float:
    source = root / f"pending-declaration-{line_count}.cs"
    source.write_text(
        "using UdonSharp;\n"
        "public class PendingDeclaration : UdonSharpBehaviour\n"
        "{\n"
        "    [UdonSynced]\n"
        + "    Identifier\n" * line_count,
        encoding="utf-8",
    )
    payload = json.dumps({"tool_input": {"file_path": str(source)}}, separators=(",", ":"))
    started = time.monotonic()
    result = subprocess.run(
        [str(hook)],
        input=payload,
        text=True,
        capture_output=True,
        timeout=15,
        check=False,
    )
    elapsed = time.monotonic() - started
    if result.returncode != 0:
        raise RuntimeError(f"{line_count} lines exited {result.returncode}")
    if result.stdout.strip() != payload:
        raise RuntimeError(f"{line_count} lines did not preserve stdout")
    if "VALIDATOR-WARNING" in result.stderr:
        raise RuntimeError(f"{line_count} lines triggered an internal failure")
    return elapsed


measure(100)
small = measure(2000)
large = measure(8000)
limit = min(3.5, small * 8 + 0.5)
print(f"pending declaration: 2000={small:.3f}s 8000={large:.3f}s limit={limit:.3f}s")
if large > limit:
    raise SystemExit(1)
PY
then
    echo "PASS [pending declaration scan] $(cat "$DECLARATION_PERF_LOG")"
    PASS=$((PASS + 1))
else
    echo "FAIL [pending declaration scan]"
    sed 's/^/  /' "$DECLARATION_PERF_LOG"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# Process contracts: exact passthrough bytes and explicit lambda-scan failure
# ------------------------------------------------------------
BYTE_PASSTHROUGH_LOG="$TMPROOT/byte-passthrough.log"
if python3 - "$HOOK" >"$BYTE_PASSTHROUGH_LOG" 2>&1 <<'PY'
import subprocess
import sys

hook = sys.argv[1]
base = b'{"tool_input":{}}'
for label, payload in (
    ("no-final-newline", base),
    ("one-lf", base + b"\n"),
    ("two-lf", base + b"\n\n"),
    ("crlf", base + b"\r\n"),
):
    result = subprocess.run([hook], input=payload, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"{label}: exit={result.returncode}")
    if result.stdout != payload:
        raise RuntimeError(
            f"{label}: stdout mismatch input={payload!r} output={result.stdout!r}"
        )
print("exact passthrough bytes: 4/4")
PY
then
    echo "PASS [byte passthrough] $(cat "$BYTE_PASSTHROUGH_LOG")"
    PASS=$((PASS + 1))
else
    echo "FAIL [byte passthrough]"
    sed 's/^/  /' "$BYTE_PASSTHROUGH_LOG"
    FAIL=$((FAIL + 1))
fi

REAL_AWK=$(command -v awk)
AWK_FAILURE_DIR="$TMPROOT/awk-lambda-failure"
mkdir -p "$AWK_FAILURE_DIR"
cat > "$AWK_FAILURE_DIR/awk" <<EOF
#!/bin/sh
count_file='$AWK_FAILURE_DIR/count'
count=0
if [ -f "\$count_file" ]; then count=\$(cat "\$count_file"); fi
count=\$((count + 1))
printf '%s' "\$count" > "\$count_file"
if [ "\$count" -eq 3 ]; then exit 42; fi
exec '$REAL_AWK' "\$@"
EOF
chmod +x "$AWK_FAILURE_DIR/awk"
LAMBDA_FAILURE_FILE="$TMPROOT/lambda-scan-failure.cs"
cat > "$LAMBDA_FAILURE_FILE" <<'CSEOF'
using UdonSharp;
public class LambdaScanFailure : UdonSharpBehaviour
{
    private void Run() { Example.Apply(value => value + 1); }
}
CSEOF
LAMBDA_FAILURE_INPUT="{\"tool_input\":{\"file_path\":\"$LAMBDA_FAILURE_FILE\"}}"
printf '%s' "$LAMBDA_FAILURE_INPUT" | PATH="$AWK_FAILURE_DIR:$PATH" "$HOOK" \
    >"$TMPROOT/lambda-scan-failure.out" 2>"$TMPROOT/lambda-scan-failure.err"
LAMBDA_FAILURE_RC=$?
assert_exit "lambda scanner failure fails open" 0 "$LAMBDA_FAILURE_RC"
if cmp -s <(printf '%s' "$LAMBDA_FAILURE_INPUT") "$TMPROOT/lambda-scan-failure.out"; then
    echo "PASS [lambda scanner failure] stdout is byte-exact"
    PASS=$((PASS + 1))
else
    echo "FAIL [lambda scanner failure] stdout changed"
    FAIL=$((FAIL + 1))
fi
if [ "$(cat "$TMPROOT/lambda-scan-failure.err")" = \
    '[UdonSharp] VALIDATOR-WARNING: validation skipped (LAMBDA_SCAN_FAILED)' ]; then
    echo "PASS [lambda scanner failure] exactly one operational warning"
    PASS=$((PASS + 1))
else
    echo "FAIL [lambda scanner failure] expected exactly one LAMBDA_SCAN_FAILED warning"
    sed 's/^/  /' "$TMPROOT/lambda-scan-failure.err"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# Shared Bash/PowerShell rule inventory and lexical-mask matrix
# ------------------------------------------------------------
if grep -nF -e '\s' -e '\w' -e '\b' "$HOOK" >"$TMPROOT/non-posix-regex.log"; then
    echo "FAIL [portable grep regex] GNU-only shorthand remains"
    sed 's/^/  /' "$TMPROOT/non-posix-regex.log"
    FAIL=$((FAIL + 1))
else
    echo "PASS [portable grep regex] POSIX ERE uses no \\s/\\w/\\b shorthand"
    PASS=$((PASS + 1))
fi

run_shared_parity_matrix

echo ""
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
