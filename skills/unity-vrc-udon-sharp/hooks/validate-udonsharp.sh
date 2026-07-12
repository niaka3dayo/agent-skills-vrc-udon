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

# Check if this is an UdonSharp file
if ! grep -q "using UdonSharp\|UdonSharpBehaviour" "$file_path" 2>/dev/null; then
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
if grep -qE "=>\s*\{|=>\s*[^;{]+;" "$file_path"; then
    # Exclude property getters/setters (get => / set =>)
    if grep -qE "\)\s*=>" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: Lambda expression detected. Use named methods instead.")
    fi
fi

# Networking issues
if grep -qE "\[UdonSynced\]" "$file_path"; then
    if ! grep -qE "RequestSerialization\s*\(" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode.")
    fi
    if ! grep -qE "Networking\.SetOwner\s*\(|SetOwner\s*\(" "$file_path"; then
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
synced_count=$(grep -c '\[UdonSynced\]' "$file_path" 2>/dev/null) || synced_count=0
if [[ "$synced_count" -gt 5 ]]; then
    warnings+=("[UdonSharp] SYNC-BLOAT: $synced_count synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md.")
fi

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
if awk '
    function mask_block_comments(line,    masked, position, pair) {
        masked = ""
        position = 1
        while (position <= length(line)) {
            pair = substr(line, position, 2)
            if (in_block_comment) {
                if (pair == "*/") {
                    masked = masked "  "
                    in_block_comment = 0
                    position += 2
                } else {
                    masked = masked " "
                    position++
                }
            } else if (pair == "//") {
                return masked substr(line, position)
            } else if (pair == "/*") {
                masked = masked "  "
                in_block_comment = 1
                position += 2
            } else {
                masked = masked substr(line, position, 1)
                position++
            }
        }
        return masked
    }

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
        line = mask_block_comments(line)

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
            if (attribute_remainder ~ /^(\/\/.*)?$/) {
                previous_line_has_attribute = 1
            }
        }
    }

    END { exit found ? 0 : 1 }
' "$file_path"; then
    warnings+=("[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows.")
fi

# NoVariableSync + [UdonSynced] conflict
if grep -qE 'NoVariableSync' "$file_path" && \
    grep -qE '\[UdonSynced\]' "$file_path"; then
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
