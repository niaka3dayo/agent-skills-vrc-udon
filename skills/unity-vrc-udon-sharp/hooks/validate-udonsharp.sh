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
    printf '[UdonSharp] VALIDATOR-WARNING: validation skipped (JQ_UNAVAILABLE)\n' >&2
    printf '%s\n' "$input"
    exit 0
fi

if ! file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null); then
    printf '[UdonSharp] VALIDATOR-WARNING: validation skipped (JSON_PARSE_FAILED)\n' >&2
    printf '%s\n' "$input"
    exit 0
fi

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
if [[ ! -r "$file_path" ]]; then
    printf '[UdonSharp] VALIDATOR-WARNING: validation skipped (SOURCE_READ_FAILED)\n' >&2
    printf '%s\n' "$input"
    exit 0
fi

# Build a code-only view of the source. Comments and literal text become spaces,
# while executable code inside interpolation holes stays visible to every rule.
# CR/LF positions and byte length are preserved.
masked_file=""
skip_validation() {
    local code="$1"
    printf '[UdonSharp] VALIDATOR-WARNING: validation skipped (%s)\n' "$code" >&2
    printf '%s\n' "$input"
    exit 0
}

if ! masked_file=$(mktemp 2>/dev/null); then
    skip_validation "TEMP_CREATE_FAILED"
fi
trap 'rm -f "$masked_file"' EXIT

ends_with_lf=0
if [[ -s "$file_path" ]] && [[ "$(tail -c 1 "$file_path" | wc -l | tr -d '[:space:]')" -eq 1 ]]; then
    ends_with_lf=1
fi

if ! LC_ALL=C awk -v ends_with_lf="$ends_with_lf" '
    BEGIN {
        LINE_COMMENT = 1
        BLOCK_COMMENT = 2
        comment_state = 0
        stack_depth = 0
        quote_character = sprintf("%c", 39)
        first_record = 1
    }

    function emit_mask(count) {
        while (count-- > 0) printf " "
    }

    function run_length(text, start, wanted,    count) {
        count = 0
        while (substr(text, start + count, 1) == wanted) count++
        return count
    }

    function push_literal(kind_value, interpolated_value, quote_width_value, brace_width_value) {
        stack_depth++
        frame_type[stack_depth] = "L"
        literal_kind[stack_depth] = kind_value
        interpolated[stack_depth] = interpolated_value
        quote_width[stack_depth] = quote_width_value
        brace_width[stack_depth] = brace_width_value
    }

    function push_hole(width) {
        stack_depth++
        frame_type[stack_depth] = "H"
        close_width[stack_depth] = width
        paren_depth[stack_depth] = 0
        bracket_depth[stack_depth] = 0
        code_brace_depth[stack_depth] = 0
        format_mode[stack_depth] = 0
    }

    function pop_frame(    depth) {
        depth = stack_depth
        delete frame_type[depth]
        delete literal_kind[depth]
        delete interpolated[depth]
        delete quote_width[depth]
        delete brace_width[depth]
        delete close_width[depth]
        delete paren_depth[depth]
        delete bracket_depth[depth]
        delete code_brace_depth[depth]
        delete format_mode[depth]
        stack_depth--
    }

    function open_interpolation(run, width) {
        emit_mask(run)
        push_hole(width)
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
                if (comment_state == LINE_COMMENT) comment_state = 0
                if (stack_depth > 0 && frame_type[stack_depth] == "L" &&
                    (literal_kind[stack_depth] == "R" || literal_kind[stack_depth] == "C")) {
                    pop_frame()
                }
                position++
                continue
            }

            if (comment_state == LINE_COMMENT) {
                emit_mask(1)
                position++
                continue
            }

            if (comment_state == BLOCK_COMMENT) {
                if (character == "*" && next_character == "/") {
                    emit_mask(2)
                    comment_state = 0
                    position += 2
                } else {
                    emit_mask(1)
                    position++
                }
                continue
            }

            if (stack_depth > 0 && frame_type[stack_depth] == "L") {
                kind = literal_kind[stack_depth]

                if (kind == "R" || kind == "C") {
                    closing = kind == "R" ? "\"" : quote_character
                    if (character == "\\") {
                        emit_mask(1)
                        position++
                        if (position <= length(line) && substr(line, position, 1) != "\r") {
                            emit_mask(1)
                            position++
                        }
                        continue
                    }
                    if (character == closing) {
                        emit_mask(1)
                        position++
                        pop_frame()
                        continue
                    }
                } else if (kind == "V" && character == "\"") {
                    count = run_length(line, position, "\"")
                    emit_mask(count)
                    position += count
                    if (count % 2 == 1) pop_frame()
                    continue
                } else if (kind == "W" && character == "\"") {
                    count = run_length(line, position, "\"")
                    if (count >= quote_width[stack_depth]) {
                        width = quote_width[stack_depth]
                        emit_mask(width)
                        position += width
                        pop_frame()
                    } else {
                        emit_mask(count)
                        position += count
                    }
                    continue
                }

                if (interpolated[stack_depth] && character == "{") {
                    count = run_length(line, position, "{")
                    width = brace_width[stack_depth]
                    if (width == 1) {
                        if (count % 2 == 0) {
                            emit_mask(count)
                        } else {
                            open_interpolation(count, width)
                        }
                    } else if (count < width) {
                        emit_mask(count)
                    } else {
                        open_interpolation(count, width)
                    }
                    position += count
                    continue
                }
                if (interpolated[stack_depth] && character == "}") {
                    count = run_length(line, position, "}")
                    emit_mask(count)
                    position += count
                    continue
                }

                emit_mask(1)
                position++
                continue
            }

            if (stack_depth > 0 && frame_type[stack_depth] == "H") {
                if (format_mode[stack_depth]) {
                    if (character == "}") {
                        count = run_length(line, position, "}")
                        width = close_width[stack_depth]
                        if (count >= width) {
                            emit_mask(width)
                            position += width
                            pop_frame()
                        } else {
                            emit_mask(count)
                            position += count
                        }
                    } else {
                        emit_mask(1)
                        position++
                    }
                    continue
                }

                if (character == "}" &&
                    paren_depth[stack_depth] == 0 &&
                    bracket_depth[stack_depth] == 0 &&
                    code_brace_depth[stack_depth] == 0) {
                    count = run_length(line, position, "}")
                    width = close_width[stack_depth]
                    if (count >= width) {
                        emit_mask(width)
                        position += width
                        pop_frame()
                        continue
                    }
                }

                if (character == ":" &&
                    paren_depth[stack_depth] == 0 &&
                    bracket_depth[stack_depth] == 0 &&
                    code_brace_depth[stack_depth] == 0 &&
                    substr(line, position - 1, 1) != ":" &&
                    next_character != ":") {
                    emit_mask(1)
                    format_mode[stack_depth] = 1
                    position++
                    continue
                }
            }

            if (character == "/" && next_character == "/") {
                emit_mask(2)
                comment_state = LINE_COMMENT
                position += 2
                continue
            }
            if (character == "/" && next_character == "*") {
                emit_mask(2)
                comment_state = BLOCK_COMMENT
                position += 2
                continue
            }

            if (character == "$") {
                dollar_count = run_length(line, position, "$")
                after_dollars = position + dollar_count
                delimiter_length = run_length(line, after_dollars, "\"")
                if (delimiter_length >= 3) {
                    emit_mask(dollar_count + delimiter_length)
                    push_literal("W", 1, delimiter_length, dollar_count)
                    position += dollar_count + delimiter_length
                    continue
                }
                if (dollar_count == 1 && substr(line, after_dollars, 2) == "@\"") {
                    emit_mask(3)
                    push_literal("V", 1, 1, 1)
                    position += 3
                    continue
                }
                if (dollar_count == 1 && substr(line, after_dollars, 1) == "\"") {
                    emit_mask(2)
                    push_literal("R", 1, 1, 1)
                    position += 2
                    continue
                }
            }

            if (character == "@" && substr(line, position + 1, 2) == "$\"") {
                emit_mask(3)
                push_literal("V", 1, 1, 1)
                position += 3
                continue
            }
            if (character == "@" && next_character == "\"") {
                emit_mask(2)
                push_literal("V", 0, 1, 0)
                position += 2
                continue
            }

            if (character == "\"") {
                delimiter_length = run_length(line, position, "\"")
                if (delimiter_length >= 3) {
                    emit_mask(delimiter_length)
                    push_literal("W", 0, delimiter_length, 0)
                    position += delimiter_length
                } else {
                    emit_mask(1)
                    push_literal("R", 0, 1, 0)
                    position++
                }
                continue
            }

            if (character == quote_character) {
                emit_mask(1)
                push_literal("C", 0, 1, 0)
                position++
                continue
            }

            if (stack_depth > 0 && frame_type[stack_depth] == "H") {
                if (character == "(") paren_depth[stack_depth]++
                else if (character == ")" && paren_depth[stack_depth] > 0) paren_depth[stack_depth]--
                else if (character == "[") bracket_depth[stack_depth]++
                else if (character == "]" && bracket_depth[stack_depth] > 0) bracket_depth[stack_depth]--
                else if (character == "{") code_brace_depth[stack_depth]++
                else if (character == "}" && code_brace_depth[stack_depth] > 0) code_brace_depth[stack_depth]--
            }

            printf "%s", character
            position++
        }

        if (comment_state == LINE_COMMENT) comment_state = 0
        if (stack_depth > 0 && frame_type[stack_depth] == "L" &&
            (literal_kind[stack_depth] == "R" || literal_kind[stack_depth] == "C")) {
            pop_frame()
        }
    }

    END {
        if (ends_with_lf) printf "\n"
    }
' "$file_path" > "$masked_file" 2>/dev/null; then
    skip_validation "LEXER_FAILED"
fi

source_length=$(wc -c < "$file_path" 2>/dev/null | tr -d '[:space:]') || skip_validation "SOURCE_READ_FAILED"
masked_length=$(wc -c < "$masked_file" 2>/dev/null | tr -d '[:space:]') || skip_validation "LEXER_FAILED"
if [[ "$source_length" != "$masked_length" ]]; then
    skip_validation "MASK_LENGTH_MISMATCH"
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
if grep -qE "List<|Dictionary<|HashSet<|Queue<|Stack<" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Generic collections (List<T>, Dictionary<K,V>) not supported. Use arrays or DataList/DataDictionary.")
fi

# async/await
if grep -qE "\basync\b|\bawait\b" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: async/await not supported. Use SendCustomEventDelayedSeconds() instead.")
fi

# try/catch
if grep -qE "\btry\s*\{|\bcatch\s*\(|\bfinally\s*\{" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: try/catch/finally not supported. Use defensive null checks and validation.")
fi

# LINQ
if grep -qE "\.Where\(|\.Select\(|\.OrderBy\(|\.FirstOrDefault\(|\.Any\(|\.All\(" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: LINQ not supported. Use manual for loops.")
fi

# yield return (coroutines)
if grep -qE "\byield\s+return\b" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Coroutines (yield return) not supported. Use SendCustomEventDelayedSeconds().")
fi

# interface declaration
if grep -qE "^\s*(public\s+)?interface\s+" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Interfaces not supported. Use base class inheritance or SendCustomEvent pattern.")
fi

# StartCoroutine
if grep -qE "StartCoroutine\s*\(" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: StartCoroutine not available. Use SendCustomEventDelayedSeconds() instead.")
fi

# Check for AddListener (not supported - delegates blocked)
if grep -qE "\.AddListener\s*\(" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: AddListener() not supported. Use Inspector OnClick -> SendCustomEvent instead.")
fi

# Lambda expressions on one physical line. Keep Bash and PowerShell on the
# same ASCII space/tab contract and exclude declaration/property expression bodies.
if awk '
    {
        line = $0
        candidate = line
        sub(/^[[:blank:]]*((public|private|protected|internal|static|virtual|override|abstract|sealed|new)[[:blank:]]+)*[A-Za-z_][A-Za-z0-9_.:<>,?\[\]]*[[:blank:]]+[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*\([^)]*\)[[:blank:]]*=>/, "", candidate)
        sub(/^[[:blank:]]*((public|private|protected|internal|static|virtual|override|abstract|sealed|new)[[:blank:]]+)*[A-Za-z_][A-Za-z0-9_.:<>,?\[\]]*[[:blank:]]+[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*=>/, "", candidate)
        gsub(/(^|[;{[:blank:]])(get|set|init)[[:blank:]]*=>/, " ", candidate)
        if (candidate ~ /\)[[:blank:]]*=>[[:blank:]]*(\{|[^;{]+;)/ ||
            candidate ~ /(^|[=(,[:blank:]])[A-Za-z_][A-Za-z0-9_]*[[:blank:]]*=>[[:blank:]]*(\{|[^;{]+;)/) {
            found = 1
            exit
        }
    }
    END { exit found ? 0 : 1 }
' "$masked_file"; then
    warnings+=("[UdonSharp] WARNING: Lambda expression detected. Use named methods instead.")
fi

# Parse leading attribute sections and attach them to the declaration that
# follows. The scanner handles multiline sections and declarations, and only
# splits attribute lists on top-level commas.
if ! sync_stats=$(awk '
    function reset_pending() {
        pending_synced = 0
        pending_no_variable_sync = 0
        declaration_buffer = ""
    }

    function normalize_space(text) {
        gsub(/[ \t\r\n]+/, " ", text)
        sub(/^ /, "", text)
        sub(/ $/, "", text)
        return text
    }

    function inspect_attribute(segment, target,    compact, name, arguments, open) {
        compact = segment
        gsub(/[ \t\r\n]/, "", compact)
        if (compact == "") return

        open = index(compact, "(")
        if (open > 0) {
            name = substr(compact, 1, open - 1)
            arguments = substr(compact, open + 1, length(compact) - open - 1)
        } else {
            name = compact
            arguments = ""
        }
        sub(/^global::/, "", name)
        sub(/^UdonSharp[.]/, "", name)
        sub(/Attribute$/, "", name)

        if ((target == "" || target == "field") && name == "UdonSynced") {
            pending_synced = 1
        }
        if ((target == "" || target == "type") && name == "UdonBehaviourSyncMode") {
            gsub(/global::/, "", arguments)
            gsub(/UdonSharp[.]/, "", arguments)
            if (arguments == "BehaviourSyncMode.NoVariableSync") {
                pending_no_variable_sync = 1
            }
        }
    }

    function inspect_group(content,    compact, target, position, character, segment, parens, brackets, braces) {
        compact = content
        gsub(/[ \t\r\n]/, "", compact)
        target = ""
        if (compact ~ /^(assembly|module|field|event|method|param|property|return|type|typevar):/) {
            target = compact
            sub(/:.*/, "", target)
            sub(/^[^:]*:/, "", compact)
        }

        segment = ""
        parens = brackets = braces = 0
        for (position = 1; position <= length(compact); position++) {
            character = substr(compact, position, 1)
            if (character == "," && parens == 0 && brackets == 0 && braces == 0) {
                inspect_attribute(segment, target)
                segment = ""
                continue
            }
            segment = segment character
            if (character == "(") parens++
            else if (character == ")" && parens > 0) parens--
            else if (character == "[") brackets++
            else if (character == "]" && brackets > 0) brackets--
            else if (character == "{") braces++
            else if (character == "}" && braces > 0) braces--
        }
        inspect_attribute(segment, target)
    }

    function begin_attribute() {
        collecting_attribute = 1
        attribute_content = ""
        attribute_parens = 0
        attribute_brackets = 0
        attribute_braces = 0
    }

    function is_class(declaration) {
        return declaration ~ /^((public|private|protected|internal|abstract|sealed|static|partial|new)[ ]+)*class[ ]+[A-Za-z_][A-Za-z0-9_]*/
    }

    function is_field(declaration) {
        if (declaration ~ /^((public|private|protected|internal|static|readonly|const|volatile|new)[ ]+)*(class|struct|interface|enum|delegate|event|record)[ ]+/) return 0
        if (declaration ~ /[)][ ]*(\{|=>)/) return 0
        return declaration ~ /^((public|private|protected|internal|static|readonly|const|volatile|new)[ ]+)*([A-Za-z_][A-Za-z0-9_.:<>,?]*[ ]*(\[[ ]*\])?[ ]+)+[A-Za-z_][A-Za-z0-9_]*[ ]*(=|,|;)/
    }

    function is_other_declaration(declaration) {
        if (declaration ~ /^((public|private|protected|internal|abstract|sealed|static|partial|readonly|new)[ ]+)*(class|struct|interface|enum|delegate|event|record|namespace)([ ]|$)/) return 1
        return declaration ~ /[({;]|=>/
    }

    function process_declaration(fragment,    declaration) {
        if (!(pending_synced || pending_no_variable_sync)) return
        fragment = normalize_space(fragment)
        if (fragment == "") return
        if (declaration_buffer != "") declaration_buffer = declaration_buffer " " fragment
        else declaration_buffer = fragment
        declaration = normalize_space(declaration_buffer)

        if (pending_no_variable_sync && is_class(declaration)) {
            has_no_variable_sync = 1
            reset_pending()
            return
        }
        if (pending_synced && is_field(declaration)) {
            synced_count++
            if (declaration ~ /^((public|private|protected|internal|static|readonly|const|volatile|new)[ ]+)*(int|float)[ ]*\[[ ]*\][ ]+/) {
                has_large_synced_array = 1
            }
            reset_pending()
            return
        }
        if (is_other_declaration(declaration)) reset_pending()
    }

    function consume_line(text,    position, character, remainder) {
        if (declaration_buffer != "") {
            process_declaration(text)
            return
        }

        position = 1
        while (position <= length(text)) {
            if (collecting_attribute) {
                character = substr(text, position, 1)
                if (character == "]" && attribute_parens == 0 &&
                    attribute_brackets == 0 && attribute_braces == 0) {
                    inspect_group(attribute_content)
                    collecting_attribute = 0
                    attribute_content = ""
                    position++
                    continue
                }

                attribute_content = attribute_content character
                if (character == "(") attribute_parens++
                else if (character == ")" && attribute_parens > 0) attribute_parens--
                else if (character == "[") attribute_brackets++
                else if (character == "]" && attribute_brackets > 0) attribute_brackets--
                else if (character == "{") attribute_braces++
                else if (character == "}" && attribute_braces > 0) attribute_braces--
                position++
                continue
            }

            while (position <= length(text) && substr(text, position, 1) ~ /[ \t]/) position++
            if (position > length(text)) return
            if (substr(text, position, 1) == "[") {
                begin_attribute()
                position++
                continue
            }

            remainder = substr(text, position)
            process_declaration(remainder)
            return
        }
    }

    BEGIN {
        reset_pending()
        collecting_attribute = 0
    }

    {
        line = $0
        sub(/\r$/, "", line)
        if (line ~ /^[ \t]*$/ && !collecting_attribute) next
        if (collecting_attribute) attribute_content = attribute_content "\n"
        consume_line(line)
    }

    END {
        printf "%d|%d|%d\n", synced_count, has_no_variable_sync, has_large_synced_array
    }
' "$masked_file"); then
    skip_validation "ATTRIBUTE_SCAN_FAILED"
fi
IFS='|' read -r synced_count has_no_variable_sync has_large_synced_array <<< "$sync_stats"

# Networking issues
if [[ "$synced_count" -gt 0 ]]; then
    if ! grep -qE "RequestSerialization\s*\(" "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode.")
    fi
    if ! grep -qE "Networking\.(SetOwner|IsOwner)\s*\(|(^|[^.[:alnum:]_])IsOwner\s*\(" "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no Networking.SetOwner() or Networking.IsOwner() guard. Confirm ownership before writes.")
    fi
fi

# VRCPlayerApi without validity check
if grep -qE "VRCPlayerApi\s+\w+\s*=" "$masked_file"; then
    if ! grep -qE "\.IsValid\s*\(\)|Utilities\.IsValid\s*\(|player\s*!=\s*null" "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: VRCPlayerApi used. Always check player != null && player.IsValid() before use.")
    fi
fi

# Check for override on Unity standard callbacks (should NOT have override)
if grep -qE "override\s+void\s+(OnTriggerEnter|OnTriggerStay|OnTriggerExit|OnCollisionEnter|OnCollisionStay|OnCollisionExit|OnAnimatorMove|OnAnimatorIK)" "$masked_file"; then
    warnings+=("[UdonSharp] WARNING: Unity callbacks (OnTriggerEnter etc.) should NOT use 'override'. Only VRChat events need override.")
fi

# Generic GetComponent<UdonBehaviour> (not exposed)
if grep -qE "GetComponent<UdonBehaviour>" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: GetComponent<UdonBehaviour>() not exposed. Use (UdonBehaviour)GetComponent(typeof(UdonBehaviour)) instead.")
fi

# System.Net / System.IO (blocked - use VRC downloaders)
if grep -qE "using\s+System\.(Net|IO)\b|System\.Net\.|System\.IO\." "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: System.Net/System.IO not available. Use VRCStringDownloader or VRCImageDownloader instead. See references/web-loading.md.")
fi

# Sync bloat: too many synced variables (>5)
if [[ "$synced_count" -gt 5 ]]; then
    warnings+=("[UdonSharp] SYNC-BLOAT: $synced_count synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md.")
fi

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
if [[ "$has_large_synced_array" -eq 1 ]]; then
    warnings+=("[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows.")
fi

# NoVariableSync + [UdonSynced] conflict
if [[ "$has_no_variable_sync" -eq 1 && "$synced_count" -gt 0 ]]; then
    warnings+=("[UdonSharp] ERROR: NoVariableSync mode but [UdonSynced] variables found. Remove [UdonSynced] or change sync mode.")
fi

# ref parameter in method declaration
if grep -qE '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bref\s+\w' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: ref parameters not supported in UdonSharp. Use return values or synced fields instead.")
fi

# out parameter in method declaration
if grep -qE '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bout\s+\w' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: out parameters not supported in UdonSharp. Use return values instead.")
fi

# Multi-dimensional arrays (T[,])
if grep -qE '\w+\s*\[,' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Multi-dimensional arrays (T[,]) not supported. Use jagged arrays (T[][]) or flatten to 1D instead.")
fi

# Method overloading (same name, different signatures)
overloaded=$(grep -oE '^\s*(public|private|protected|internal|override|virtual|static|public\s+override|private\s+static|public\s+static)(\s+(public|private|protected|internal|override|virtual|static))?\s+(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(' "$masked_file" \
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
