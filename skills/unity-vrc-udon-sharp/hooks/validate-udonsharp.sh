#!/bin/bash
# UdonSharp Code Validation Hook (Linux/macOS)
# Checks for common constraint violations in UdonSharp code.
#
# Usage: Called as PostToolUse hook when editing .cs files
# Input: JSON via stdin with tool_input.file_path
# Output: Warnings to stderr, original input to stdout

set -e

input=$(cat)

# Require jq for JSON parsing. Without this guard, jq absence under set -e
# aborts every PostToolUse hook invocation on .cs edits with a "command not
# found" message, breaking validation silently for users on minimal Linux
# images and macOS without Homebrew jq (Issue #165, Case A). Pass input
# through so the original edit still propagates downstream.
if ! command -v jq &>/dev/null; then
    echo "$input"
    exit 0
fi

# Tolerate jq parse failures: if the incoming JSON is malformed, fall through
# to the empty-file_path branch (which exits cleanly) instead of aborting
# under set -e (Issue #165, Case B).
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null || true)

# Only process .cs files
if [[ ! "$file_path" =~ \.cs$ ]]; then
    echo "$input"
    exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
    echo "$input"
    exit 0
fi

# Mask comments and C# literals for structural and sync-only predicates. The
# output preserves every byte and physical line break; general rules continue
# to inspect the raw source so interpolation expressions remain visible.
masked_file=$(mktemp)
trap 'rm -f "$masked_file"' EXIT
ends_with_lf=0
if [[ -s "$file_path" ]] && [[ "$(tail -c 1 "$file_path" | wc -l | tr -d '[:space:]')" -eq 1 ]]; then
    ends_with_lf=1
fi

LC_ALL=C awk -v ends_with_lf="$ends_with_lf" '
    BEGIN {
        CODE = 0
        LINE_COMMENT = 1
        BLOCK_COMMENT = 2
        REGULAR_STRING = 3
        VERBATIM_STRING = 4
        CHARACTER = 5
        RAW_STRING = 6
        state = CODE
        quote_character = sprintf("%c", 39)
        first_record = 1
    }

    function spaces(count,    result) {
        result = ""
        while (count-- > 0) result = result " "
        return result
    }

    function quote_run(text, start,    count) {
        count = 0
        while (substr(text, start + count, 1) == "\"") count++
        return count
    }

    {
        if (!first_record) printf "\n"
        first_record = 0
        line = $0
        position = 1

        while (position <= length(line)) {
            character = substr(line, position, 1)
            next_character = substr(line, position + 1, 1)

            if (character == "\r") {
                printf "\r"
                if (state == LINE_COMMENT || state == REGULAR_STRING || state == CHARACTER) state = CODE
                position++
                continue
            }

            if (state == LINE_COMMENT) {
                printf " "
                position++
                continue
            }

            if (state == BLOCK_COMMENT) {
                if (character == "*" && next_character == "/") {
                    printf "  "
                    state = CODE
                    position += 2
                } else {
                    printf " "
                    position++
                }
                continue
            }

            if (state == REGULAR_STRING || state == CHARACTER) {
                closing_character = state == REGULAR_STRING ? "\"" : quote_character
                if (character == "\\") {
                    printf " "
                    position++
                    if (position <= length(line) && substr(line, position, 1) != "\r") {
                        printf " "
                        position++
                    }
                } else {
                    printf " "
                    if (character == closing_character) state = CODE
                    position++
                }
                continue
            }

            if (state == VERBATIM_STRING) {
                if (character == "\"" && next_character == "\"") {
                    printf "  "
                    position += 2
                } else {
                    printf " "
                    if (character == "\"") state = CODE
                    position++
                }
                continue
            }

            if (state == RAW_STRING) {
                if (character == "\"" && quote_run(line, position) >= raw_delimiter_length) {
                    printf "%s", spaces(raw_delimiter_length)
                    position += raw_delimiter_length
                    state = CODE
                } else {
                    printf " "
                    position++
                }
                continue
            }

            if (character == "/" && next_character == "/") {
                printf "  "
                state = LINE_COMMENT
                position += 2
                continue
            }
            if (character == "/" && next_character == "*") {
                printf "  "
                state = BLOCK_COMMENT
                position += 2
                continue
            }

            if (character == "$") {
                dollar_count = 0
                while (substr(line, position + dollar_count, 1) == "$") dollar_count++
                after_dollars = position + dollar_count
                delimiter_length = quote_run(line, after_dollars)
                if (delimiter_length >= 3) {
                    printf "%s", spaces(dollar_count + delimiter_length)
                    raw_delimiter_length = delimiter_length
                    state = RAW_STRING
                    position += dollar_count + delimiter_length
                    continue
                }
                if (dollar_count == 1 && substr(line, after_dollars, 2) == "@\"") {
                    printf "   "
                    state = VERBATIM_STRING
                    position += 3
                    continue
                }
                if (dollar_count == 1 && substr(line, after_dollars, 1) == "\"") {
                    printf "  "
                    state = REGULAR_STRING
                    position += 2
                    continue
                }
            }

            if (character == "@" && substr(line, position + 1, 2) == "$\"") {
                printf "   "
                state = VERBATIM_STRING
                position += 3
                continue
            }
            if (character == "@" && next_character == "\"") {
                printf "  "
                state = VERBATIM_STRING
                position += 2
                continue
            }

            if (character == "\"") {
                delimiter_length = quote_run(line, position)
                if (delimiter_length >= 3) {
                    printf "%s", spaces(delimiter_length)
                    raw_delimiter_length = delimiter_length
                    state = RAW_STRING
                    position += delimiter_length
                } else {
                    printf " "
                    state = REGULAR_STRING
                    position++
                }
                continue
            }

            if (character == quote_character) {
                printf " "
                state = CHARACTER
                position++
                continue
            }

            printf "%s", character
            position++
        }

        if (state == LINE_COMMENT || state == REGULAR_STRING || state == CHARACTER) state = CODE
    }

    END {
        if (ends_with_lf) printf "\n"
    }
' "$file_path" > "$masked_file"

if [[ "$(wc -c < "$file_path" | tr -d '[:space:]')" -ne "$(wc -c < "$masked_file" | tr -d '[:space:]')" ]]; then
    echo "[UdonSharp] validator internal error: lexical mask length mismatch" >&2
    echo "$input"
    exit 0
fi

# Require a concrete UdonSharpBehaviour base, including qualified and using-
# alias forms. External project types are intentionally not resolved here.
if ! awk '
    function has_base(source, base,    pattern) {
        pattern = "class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[^{;]*[,:[:space:]]" base "([,<{[:space:]]|$)"
        return source ~ pattern
    }

    {
        source = source (NR == 1 ? "" : " ") $0
    }

    END {
        if (has_base(source, "UdonSharpBehaviour") ||
            has_base(source, "UdonSharp\\.UdonSharpBehaviour") ||
            has_base(source, "global::UdonSharp\\.UdonSharpBehaviour")) exit 0

        remainder = source
        alias_pattern = "using[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(global::)?UdonSharp(\\.UdonSharpBehaviour)?[[:space:]]*;"
        while (match(remainder, alias_pattern)) {
            declaration = substr(remainder, RSTART, RLENGTH)
            sub(/^using[[:space:]]+/, "", declaration)
            split(declaration, parts, "=")
            alias = parts[1]
            target = parts[2]
            gsub(/[[:space:]]/, "", alias)
            gsub(/[[:space:];]/, "", target)
            if (target ~ /UdonSharpBehaviour$/) {
                if (has_base(source, alias)) exit 0
            } else if (has_base(source, alias "\\.UdonSharpBehaviour")) {
                exit 0
            }
            remainder = substr(remainder, RSTART + RLENGTH)
        }
        exit 1
    }
' "$masked_file"; then
    echo "$input"
    exit 0
fi

# === Validation Rules ===
warnings=()

# Blocked generics
if grep -qE "List<|Dictionary<|HashSet<|Queue<|Stack<" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Generic collections (List<T>, Dictionary<K,V>) not supported. Use arrays or DataList/DataDictionary.")
fi

# async/await
if grep -qE "\basync\b|\bawait\b" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: async/await not supported. Use SendCustomEventDelayedSeconds() instead.")
fi

# try/catch
if grep -qE "\btry\s*\{|\bcatch\s*\(|\bfinally\s*\{" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: try/catch/finally not supported. Use defensive null checks and validation.")
fi

# LINQ
if grep -qE "\.Where\(|\.Select\(|\.OrderBy\(|\.FirstOrDefault\(|\.Any\(|\.All\(" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: LINQ not supported. Use manual for loops.")
fi

# yield return (coroutines)
if grep -qE "\byield\s+return\b" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Coroutines (yield return) not supported. Use SendCustomEventDelayedSeconds().")
fi

# interface declaration
if grep -qE "^\s*(public\s+)?interface\s+" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Interfaces not supported. Use base class inheritance or SendCustomEvent pattern.")
fi

# StartCoroutine
if grep -qE "StartCoroutine\s*\(" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: StartCoroutine not available. Use SendCustomEventDelayedSeconds() instead.")
fi

# Check for AddListener (not supported - delegates blocked)
if grep -qE "\.AddListener\s*\(" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: AddListener() not supported. Use Inspector OnClick -> SendCustomEvent instead.")
fi

# Lambda expressions
if grep -qE '\)[ \t]*=>[ \t]*(\{|[^;{]+;)' "$file_path"; then
    warnings+=("[UdonSharp] WARNING: Lambda expression detected. Use named methods instead.")
fi

# Attribute-aware sync inventory from MaskedSource. Comments and literals do
# not contribute attributes, counts, modes, or call-presence predicates.
sync_stats=$(awk '
    function analyze_attribute(content,    compact) {
        compact = content
        gsub(/[ \t\r\n]/, "", compact)
        if (compact ~ /(^|,|:)UdonSynced(Attribute)?($|,|\()/) synced_count++
        if (compact ~ /(^|,)UdonBehaviourSyncMode(Attribute)?\(BehaviourSyncMode\.NoVariableSync\)($|,)/) has_no_variable_sync = 1
    }

    {
        line = $0 "\n"
        for (position = 1; position <= length(line); position++) {
            character = substr(line, position, 1)
            pair = substr(line, position, 2)
            if (!in_attribute) {
                if (character == "[") {
                    in_attribute = 1
                    attribute_content = ""
                }
            } else if (pair == "[]") {
                attribute_content = attribute_content pair
                position++
            } else if (character == "]") {
                analyze_attribute(attribute_content)
                in_attribute = 0
                attribute_content = ""
            } else {
                attribute_content = attribute_content character
            }
        }
    }

    END { printf "%d|%d\n", synced_count, has_no_variable_sync }
' "$masked_file")
IFS='|' read -r synced_count has_no_variable_sync <<< "$sync_stats"

# Networking issues
if [[ "$synced_count" -gt 0 ]]; then
    if ! grep -qE "RequestSerialization\s*\(" "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode.")
    fi
    if ! grep -qE "Networking\.SetOwner\s*\(|SetOwner\s*\(" "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no Networking.SetOwner(). Ownership required to modify synced variables.")
    fi
fi

# VRCPlayerApi without validity check
if grep -qE "VRCPlayerApi\s+\w+\s*=" "$file_path"; then
    if ! grep -qE "\.IsValid\s*\(\)|player\s*!=\s*null" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: VRCPlayerApi used. Always check player != null && player.IsValid() before use.")
    fi
fi

# Check for override on Unity standard callbacks (should NOT have override)
if grep -qE "override\s+void\s+(OnTriggerEnter|OnTriggerStay|OnTriggerExit|OnCollisionEnter|OnCollisionStay|OnCollisionExit|OnAnimatorMove|OnAnimatorIK)" "$file_path"; then
    warnings+=("[UdonSharp] WARNING: Unity callbacks (OnTriggerEnter etc.) should NOT use 'override'. Only VRChat events need override.")
fi

# Generic GetComponent<UdonBehaviour> (not exposed)
if grep -qE "GetComponent<UdonBehaviour>" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: GetComponent<UdonBehaviour>() not exposed. Use (UdonBehaviour)GetComponent(typeof(UdonBehaviour)) instead.")
fi

# System.Net / System.IO (blocked - use VRC downloaders)
if grep -qE "using\s+System\.(Net|IO)\b|System\.Net\.|System\.IO\." "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: System.Net/System.IO not available. Use VRCStringDownloader or VRCImageDownloader instead. See references/web-loading.md.")
fi

# Sync bloat: too many synced variables (>5)
if [[ "$synced_count" -gt 5 ]]; then
    warnings+=("[UdonSharp] SYNC-BLOAT: $synced_count synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md.")
fi

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
if awk '
    function is_synced_array_field_prefix(line) {
        return line ~ /^[ \t]*((public|private|protected|internal|static|readonly)[ \t]+)*(int|float)[ \t]*\[\][ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*(=|,|;)/
    }

    function find_attribute_group_end(text,    character, position) {
        position = 2
        while (position <= length(text)) {
            if (substr(text, position, 2) == "[]") {
                position += 2
                continue
            }

            character = substr(text, position, 1)
            if (character == "]") return position
            position++
        }

        return 0
    }

    function parse_leading_attribute_groups(line,    closing_bracket, content, rest) {
        attribute_group_count = 0
        attribute_has_udon_synced = 0
        rest = line
        sub(/^[ \t]*/, "", rest)

        while (substr(rest, 1, 1) == "[") {
            closing_bracket = find_attribute_group_end(rest)
            if (closing_bracket == 0) break

            content = substr(rest, 2, closing_bracket - 2)
            if (content ~ /(^|,)[ \t]*UdonSynced(Attribute)?[ \t]*($|,|[(])/) {
                attribute_has_udon_synced = 1
            }

            attribute_group_count++
            rest = substr(rest, closing_bracket + 1)
            sub(/^[ \t]*/, "", rest)
        }

        attribute_remainder = rest
        return attribute_group_count
    }

    {
        line = $0
        sub(/\r$/, "", line)

        if (previous_line_has_attribute && is_synced_array_field_prefix(line)) {
            found = 1
            exit
        }

        previous_line_has_attribute = 0
        if (parse_leading_attribute_groups(line) && attribute_has_udon_synced) {
            if (is_synced_array_field_prefix(attribute_remainder)) {
                found = 1
                exit
            }
            if (attribute_remainder ~ /^[ \t]*$/) {
                previous_line_has_attribute = 1
            }
        }
    }

    END { exit found ? 0 : 1 }
' "$masked_file"; then
    warnings+=("[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows.")
fi

# NoVariableSync + [UdonSynced] conflict
if [[ "$has_no_variable_sync" -eq 1 && "$synced_count" -gt 0 ]]; then
    warnings+=("[UdonSharp] ERROR: NoVariableSync mode but [UdonSynced] variables found. Remove [UdonSynced] or change sync mode.")
fi

# ref parameter in method declaration
if grep -qE '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bref\s+\w' "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: ref parameters not supported in UdonSharp. Use return values or synced fields instead.")
fi

# out parameter in method declaration
if grep -qE '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bout\s+\w' "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: out parameters not supported in UdonSharp. Use return values instead.")
fi

# Multi-dimensional arrays (T[,])
if grep -qE '\w+\s*\[,' "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Multi-dimensional arrays (T[,]) not supported. Use jagged arrays (T[][]) or flatten to 1D instead.")
fi

# Method overloading (same name, different signatures)
overloaded=$(grep -oE '^\s*(public|private|protected|internal|override|virtual|static|public\s+override|private\s+static|public\s+static)(\s+(public|private|protected|internal|override|virtual|static))?\s+(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(' "$file_path" \
    | grep -oE '[A-Za-z_][A-Za-z0-9_]*\s*\($' \
    | sed 's/[[:space:]]*($//' \
    | sort | uniq -d)
if [[ -n "$overloaded" ]]; then
    warnings+=("[UdonSharp] WARNING: Method overloading detected for: $(echo "$overloaded" | tr '\n' ' '). Only simple overloads may work; prefer unique method names.")
fi

# Output warnings
if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "" >&2
    echo "=== UdonSharp Validation Warnings ===" >&2
    for warning in "${warnings[@]}"; do
        echo "$warning" >&2
    done
    echo "===================================" >&2
    echo "" >&2
fi

# Always output original input to allow the edit to proceed
echo "$input"
