#!/bin/bash
# UdonSharp Code Validation Hook (Linux/macOS)
# Checks for common constraint violations in UdonSharp code.
#
# Usage: Called as a PostToolUse hook when a .cs file is written or edited
# Input: JSON via stdin with tool_input.file_path, or a Codex apply_patch
#        payload with the patch text in tool_input.command
# Output: Diagnostics on stderr for a person, and the same lines on stdout as
#         one JSON object (hookSpecificOutput.additionalContext) for the agent.
#         Prints nothing when there is nothing to report. Always exits 0.

set -e

# JSON cannot contain a raw NUL byte, so reading to a NUL delimiter takes the
# whole payload.
input=''
IFS= read -r -d '' input || true

# A host agent (Claude Code, Gemini CLI, Codex) never shows the model stderr
# from a hook that exits 0. It parses stdout as one JSON object and adds
# additionalContext to the model's context, so diagnostics must go there to
# be acted on. The event name is echoed back because hosts name it differently.
hook_event=""

json_escape() {
    local text="$1" backslash='\'
    text=${text//"$backslash"/$backslash$backslash}
    text=${text//\"/$backslash\"}
    text=${text//$'\n'/${backslash}n}
    text=${text//$'\t'/${backslash}t}
    text=${text//$'\r'/${backslash}r}
    # The remaining control characters cannot be written raw in JSON, and the
    # diagnostics never need them.
    printf '%s' "$text" | LC_ALL=C tr -d '\000-\037'
}

report_to_agent() {
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
        "$(json_escape "${hook_event:-PostToolUse}")" "$(json_escape "$1")"
}

skip_validation() {
    local message="[UdonSharp] VALIDATOR-WARNING: validation skipped ($1)"
    printf '%s\n' "$message" >&2
    report_to_agent "$message"
    exit 0
}

# Read the three fields the hook needs without jq, which Git Bash on Windows
# does not ship (Issue #394). Splitting the payload on double quotes walks it
# in linear time: a piece that ends in an odd number of backslashes ended at an
# escaped quote, so the string continues. Each field is printed on its own
# line in printf %b form: hook_event_name, tool_input.file_path (or filePath),
# tool_input.command.
if ! fields=$(printf '%s' "$input" | LC_ALL=C awk '
    function hex_value(text,    position, value, digit) {
        value = 0
        for (position = 1; position <= 4; position++) {
            digit = index("0123456789abcdef", tolower(substr(text, position, 1)))
            if (digit == 0) return 65533
            value = value * 16 + digit - 1
        }
        return value
    }

    function byte(value) {
        return sprintf("\\0%03o", value)
    }

    function encode_code_point(code) {
        if (code == 92) return "\\\\"
        if (code >= 32 && code < 127) return sprintf("%c", code)
        if (code < 128) return byte(code)
        if (code < 2048) return byte(192 + int(code / 64)) byte(128 + code % 64)
        if (code < 65536) {
            return byte(224 + int(code / 4096)) byte(128 + int(code / 64) % 64) byte(128 + code % 64)
        }
        return byte(240 + int(code / 262144)) byte(128 + int(code / 4096) % 64) \
            byte(128 + int(code / 64) % 64) byte(128 + code % 64)
    }

    # Turn the body of a JSON string into printf %b form. Splitting on the
    # backslash leaves the escape character at the start of each later piece;
    # an empty piece is the second backslash of an escaped backslash.
    function decode(raw,    out, pieces, total, at, piece, escape, code, low) {
        gsub(/\n/, "\\n", raw)
        total = split(raw, pieces, "\\")
        out = pieces[1]
        for (at = 2; at <= total; at++) {
            piece = pieces[at]
            if (piece == "") {
                at++
                out = out "\\\\" pieces[at]
                continue
            }
            escape = substr(piece, 1, 1)
            if (escape == "u") {
                code = hex_value(substr(piece, 2, 4))
                piece = substr(piece, 6)
                if (code >= 55296 && code <= 56319 && piece == "" && substr(pieces[at + 1], 1, 1) == "u") {
                    low = hex_value(substr(pieces[at + 1], 2, 4))
                    if (low >= 56320 && low <= 57343) {
                        code = 65536 + (code - 55296) * 1024 + low - 56320
                        at++
                        piece = substr(pieces[at], 6)
                    }
                }
                out = out encode_code_point(code) piece
            } else if (escape == "\"" || escape == "/") {
                out = out piece
            } else {
                out = out "\\" piece
            }
        }
        return out
    }

    function wanted(    name) {
        name = key[depth]
        if (depth == 1) return name == "hook_event_name"
        return depth == 2 && key[1] == "tool_input" && \
            (name == "file_path" || name == "filePath" || name == "command")
    }

    function scan(text,    position, character) {
        gsub(/[ \t\r\n]/, "", text)
        for (position = 1; position <= length(text); position++) {
            character = substr(text, position, 1)
            if (character == "{" || character == "[") depth++
            else if (character == "}" || character == "]") depth--
        }
        after_colon = (substr(text, length(text), 1) == ":")
        return substr(text, 1, 1)
    }

    { payload = payload $0 "\n" }

    END {
        total_parts = split(payload, part, "\"")
        outline = part[1]
        gsub(/[ \t\r\n]/, "", outline)
        if (total_parts <= 1 && outline == "") exit 0
        if (substr(outline, 1, 1) != "{") exit 1

        depth = 0
        scan(part[1])
        at_part = 2
        while (at_part <= total_parts) {
            keep = after_colon && wanted()
            text = part[at_part]
            escaped = 0
            while (match(part[at_part], /\\+$/) && RLENGTH % 2 == 1) {
                at_part++
                if (at_part > total_parts) exit 1
                escaped = 1
                if (keep) text = text "\"" part[at_part]
            }
            at_part++
            if (at_part > total_parts) exit 1
            # scan() moves depth, so the string belongs to the level before it.
            was_value = after_colon
            level = depth
            if (scan(part[at_part]) == ":" && !was_value) {
                key[level] = escaped ? "" : text
            } else if (keep) {
                value[level, key[level]] = decode(text)
            }
            at_part++
        }
        if (depth != 0) exit 1

        print value[1, "hook_event_name"]
        print ((2, "file_path") in value) ? value[2, "file_path"] : value[2, "filePath"]
        print value[2, "command"]
    }
'); then
    skip_validation "JSON_PARSE_FAILED"
fi

event_field=""
path_field=""
command_field=""
{
    IFS= read -r event_field || true
    IFS= read -r path_field || true
    IFS= read -r command_field || true
} <<< "$fields"
hook_event=$(printf '%b' "$event_field")
file_path=$(printf '%b' "$path_field")

# Codex edits files with apply_patch, whose hook input carries the patch text
# in tool_input.command instead of a path. Validate each .cs file the patch
# adds, updates, or moves, and name the file in front of its findings.
# shortcut: relative paths resolve against the hook working directory, which
# Codex sets to the session directory; read the payload cwd if a host differs.
if [[ -z "$file_path" && -n "$command_field" ]]; then
    patch_paths=$(printf '%b\n' "$command_field" | tr -d '\r' | sed -n \
        -e 's/^\*\*\* Add File: \(.*\.cs\)$/\1/p' \
        -e 's/^\*\*\* Update File: \(.*\.cs\)$/\1/p' \
        -e 's/^\*\*\* Move to: \(.*\.cs\)$/\1/p' | sort -u)
    patch_report=""
    while IFS= read -r patch_path; do
        [[ -n "$patch_path" ]] || continue
        patch_payload="{\"tool_input\":{\"file_path\":\"$(json_escape "$patch_path")\"}}"
        patch_status=0
        patch_stderr=$(printf '%s' "$patch_payload" | "$BASH" "${BASH_SOURCE[0]}" 2>&1 >/dev/null) || patch_status=$?
        patch_findings=$(printf '%s\n' "$patch_stderr" | grep -F '[UdonSharp]' || true)
        if [[ -z "$patch_findings" && "$patch_status" -ne 0 ]]; then
            patch_findings="[UdonSharp] VALIDATOR-WARNING: validation skipped (PATCH_FILE_FAILED)"
            patch_stderr="$patch_findings"
        fi
        [[ -n "$patch_findings" ]] || continue
        printf '\n[UdonSharp] FILE: %s\n%s\n' "$patch_path" "$patch_stderr" >&2
        patch_report+="[UdonSharp] FILE: $patch_path"$'\n'"$patch_findings"$'\n'
    done <<< "$patch_paths"
    if [[ -n "$patch_report" ]]; then
        report_to_agent "${patch_report%$'\n'}"
    fi
    exit 0
fi

# Only process .cs files
if [[ ! "$file_path" =~ \.cs$ ]]; then
    exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
    exit 0
fi
if [[ ! -r "$file_path" ]]; then
    skip_validation "SOURCE_READ_FAILED"
fi

# Build a code-only view of the source. Comments and literal text become spaces,
# while executable code inside interpolation holes stays visible to every rule.
# CR/LF positions and byte length are preserved.
masked_file=""
flat_file=""

if ! masked_file=$(mktemp 2>/dev/null); then
    skip_validation "TEMP_CREATE_FAILED"
fi
trap 'rm -f "$masked_file" "$flat_file"' EXIT

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
                printf "%s", substr(line, position, dollar_count)
                position += dollar_count
                continue
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

# Rules that span physical lines consume one fixed-size flattened copy instead
# of repeatedly concatenating the source inside awk. Replacing CR/LF bytes with
# spaces preserves token boundaries and keeps BusyBox awk scans linear.
if ! flat_file=$(mktemp 2>/dev/null); then
    skip_validation "TEMP_CREATE_FAILED"
fi
if ! LC_ALL=C tr '\r\n' '  ' < "$masked_file" > "$flat_file"; then
    skip_validation "FLATTEN_FAILED"
fi

# Require a concrete UdonSharpBehaviour base, including qualified and using-
# alias forms. External project types are intentionally not resolved here.
base_scan_status=0
LC_ALL=C awk '
    function has_base(source, base,    pattern) {
        pattern = "class[[:space:]]+" identifier_pattern "[[:space:]]*:[[:space:]]*" base "([,<{[:space:]]|$)"
        return source ~ pattern
    }

    BEGIN {
        # In the C locale, non-ASCII UTF-8 bytes are neither punctuation nor
        # whitespace. This accepts Unicode and verbatim (@) identifiers without
        # relying on GNU-specific regular-expression features.
        identifier_pattern = "@?(_|[^[:space:][:punct:][:digit:]])(_|[^[:space:][:punct:]])*"
    }

    { source = $0 }

    END {
        if (has_base(source, "UdonSharpBehaviour") ||
            has_base(source, "UdonSharp\\.UdonSharpBehaviour") ||
            has_base(source, "global::UdonSharp\\.UdonSharpBehaviour")) exit 0

        remainder = source
        alias_pattern = "using[[:space:]]+" identifier_pattern "[[:space:]]*=[[:space:]]*(global::)?UdonSharp(\\.UdonSharpBehaviour)?[[:space:]]*;"
        while (match(remainder, alias_pattern)) {
            declaration = substr(remainder, RSTART, RLENGTH)
            sub(/^using[[:space:]]+/, "", declaration)
            split(declaration, parts, "=")
            alias = parts[1]
            target = parts[2]
            gsub(/[[:space:]]/, "", alias)
            sub(/^@/, "", alias)
            gsub(/[[:space:];]/, "", target)
            if (target ~ /UdonSharpBehaviour$/) {
                if (has_base(source, "@?" alias)) exit 0
            } else if (has_base(source, "@?" alias "\\.UdonSharpBehaviour")) {
                exit 0
            }
            remainder = substr(remainder, RSTART + RLENGTH)
        }
        exit 1
    }
' "$flat_file" || base_scan_status=$?
if [[ "$base_scan_status" -eq 1 ]]; then
    exit 0
fi
if [[ "$base_scan_status" -ne 0 ]]; then
    skip_validation "BASE_SCAN_FAILED"
fi

# === Validation Rules ===
warnings=()

# Context-sensitive generic collections
if grep -qE "List[[:space:]]*<|Dictionary[[:space:]]*<|HashSet[[:space:]]*<|Queue[[:space:]]*<|Stack[[:space:]]*<" "$flat_file"; then
    warnings+=("[UdonSharp] WARNING: Generic collections (List<T>, Dictionary<K,V>) detected. Check whether this code only generates a Udon-compatible field initial value in the Unity Editor or runs in Udon runtime; generic collections are not supported in Udon runtime.")
fi

# async/await
if grep -qE '(^|[^[:alnum:]_])(async|await)([^[:alnum:]_]|$)' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: async/await not supported. Use SendCustomEventDelayedSeconds() instead.")
fi

# try/catch
if grep -qE '(^|[^[:alnum:]_])try[[:space:]]*[{]|(^|[^[:alnum:]_])catch[[:space:]]*[(]|(^|[^[:alnum:]_])finally[[:space:]]*[{]' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: try/catch/finally not supported. Use defensive null checks and validation.")
fi

# LINQ
if grep -qE "\.Where\(|\.Select\(|\.OrderBy\(|\.FirstOrDefault\(|\.Any\(|\.All\(" "$masked_file"; then
    warnings+=("[UdonSharp] WARNING: LINQ not supported in Udon runtime. Check whether this code only generates a Udon-compatible field initial value in the Unity Editor or runs in Udon runtime.")
fi

# yield return (coroutines)
if grep -qE '(^|[^[:alnum:]_])yield[[:space:]]+return([^[:alnum:]_]|$)' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Coroutines (yield return) not supported. Use SendCustomEventDelayedSeconds().")
fi

# interface declaration
if grep -qE '^[[:space:]]*(public[[:space:]]+)?interface[[:space:]]+' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Interfaces not supported. Use base class inheritance or SendCustomEvent pattern.")
fi

# StartCoroutine
if grep -qE 'StartCoroutine[[:space:]]*[(]' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: StartCoroutine not available. Use SendCustomEventDelayedSeconds() instead.")
fi

# Check for AddListener (not supported - delegates blocked)
if grep -qE '[.]AddListener[[:space:]]*[(]' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: AddListener() not supported. Use Inspector OnClick -> SendCustomEvent instead.")
fi

# Lambda expressions across logical lines. Every declaration expression body is
# masked before looking for lambda arrows, including multiple members on one line.
lambda_scan_status=0
LC_ALL=C awk '
    function trim(text) {
        sub(/^[ \t]+/, "", text)
        sub(/[ \t]+$/, "", text)
        return text
    }

    function is_identifier(name) {
        return name ~ identifier_pattern
    }

    function strip_leading_attributes(text,    depth, position, character) {
        text = trim(text)
        while (substr(text, 1, 1) == "[") {
            depth = 0
            for (position = 1; position <= length(text); position++) {
                character = substr(text, position, 1)
                if (character == "[") depth++
                else if (character == "]") {
                    depth--
                    if (depth == 0) break
                }
            }
            if (depth != 0) return text
            text = trim(substr(text, position + 1))
        }
        return text
    }

    function member_segment(text, arrow,    position, character) {
        for (position = arrow - 1; position >= 1; position--) {
            character = substr(text, position, 1)
            if (character == ";" || character == "{" || character == "}") {
                return trim(substr(text, position + 1, arrow - position - 1))
            }
        }
        return trim(substr(text, 1, arrow - 1))
    }

    function matching_open_paren(text,    depth, position, character) {
        depth = 0
        for (position = length(text); position >= 1; position--) {
            character = substr(text, position, 1)
            if (character == ")") depth++
            else if (character == "(") {
                depth--
                if (depth == 0) return position
            }
        }
        return 0
    }

    function is_declaration_arrow(text, arrow,    segment, had_modifier, open, prefix, name, return_type) {
        segment = strip_leading_attributes(member_segment(text, arrow))
        if (segment ~ /^(get|set|init)[ \t]*$/) return 1

        had_modifier = 0
        while (match(segment, /^(public|private|protected|internal|static|abstract|virtual|sealed|new|override|extern|partial|async|unsafe|readonly)[ \t]+/)) {
            segment = trim(substr(segment, RLENGTH + 1))
            had_modifier = 1
        }
        if (segment == "" || segment ~ /[=;]/ || segment ~ /^(return|throw|yield|case|goto|new)([ \t]|$)/) return 0

        if (substr(segment, length(segment), 1) == ")") {
            open = matching_open_paren(segment)
            if (open == 0) return 0
            prefix = trim(substr(segment, 1, open - 1))
        } else {
            if (segment ~ /[()]/) return 0
            prefix = segment
        }

        name = prefix
        sub(/^.*[ \t]/, "", name)
        if (!is_identifier(name)) return 0
        return_type = prefix
        sub(/[ \t][^ \t]*$/, "", return_type)
        if (return_type != prefix && trim(return_type) != "") return 1

        # A modifier plus one identifier is a constructor declaration. Without
        # the modifier it is a call or another expression, not a member.
        return had_modifier
    }

    function mask_declaration_arrows(text,    search_from, relative, arrow, position, character, has_boundary, declaration_masked) {
        search_from = 1
        declaration_masked = 0
        while ((relative = index(substr(text, search_from), "=>")) > 0) {
            arrow = search_from + relative - 1
            has_boundary = 0
            if (declaration_masked) {
                for (position = search_from; position < arrow; position++) {
                    character = substr(text, position, 1)
                    if (character == ";" || character == "{" || character == "}") {
                        has_boundary = 1
                        break
                    }
                }
                if (has_boundary) declaration_masked = 0
            }
            if (!declaration_masked && is_declaration_arrow(text, arrow)) {
                text = substr(text, 1, arrow - 1) "  " substr(text, arrow + 2)
                declaration_masked = 1
            }
            search_from = arrow + 2
        }
        return text
    }

    BEGIN {
        identifier_pattern = "^@?(_|[^[:space:][:punct:][:digit:]])(_|[^[:space:][:punct:]])*$"
        simple_lambda_pattern = "(^|[=(,[:blank:]])@?(_|[^[:space:][:punct:][:digit:]])(_|[^[:space:][:punct:]])*[[:blank:]]*=>[[:blank:]]*(\\{|[^;{]+;)"
    }

    {
        candidate = mask_declaration_arrows($0)
        if (candidate ~ /\)[[:blank:]]*=>[[:blank:]]*(\{|[^;{]+;)/ ||
            candidate ~ simple_lambda_pattern) {
            found = 1
            exit
        }
    }
    END { exit found ? 0 : 1 }
' "$flat_file" || lambda_scan_status=$?
if [[ "$lambda_scan_status" -eq 0 ]]; then
    warnings+=("[UdonSharp] WARNING: Lambda expression detected. Check whether this code only generates a Udon-compatible field initial value in the Unity Editor or runs in Udon runtime; lambda expressions are not supported in Udon runtime.")
elif [[ "$lambda_scan_status" -ne 1 ]]; then
    skip_validation "LAMBDA_SCAN_FAILED"
fi

# Parse leading attribute sections and attach them to the declaration that
# follows. The scanner handles multiline sections and declarations, and only
# splits attribute lists on top-level commas.
if ! sync_stats=$(LC_ALL=C awk '
    function clear_declaration(    chunk_index) {
        for (chunk_index = 1; chunk_index <= declaration_chunk_count; chunk_index++) {
            delete declaration_chunks[chunk_index]
        }
        declaration_chunk_count = 0
        declaration_size = 0
        declaration_parens = 0
        declaration_brackets = 0
        declaration_braces = 0
        declaration_has_assignment = 0
    }

    function reset_pending() {
        pending_synced = 0
        pending_sync_mode = 0
        clear_declaration()
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
            if (arguments == "BehaviourSyncMode.NoVariableSync" || arguments == "BehaviourSyncMode.None") {
                pending_sync_mode = arguments
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
        return declaration ~ /^((public|private|protected|internal|abstract|sealed|static|partial|new)[ ]+)*class([ ]|$)/
    }

    function field_declarator_count(declaration,    position, character, next_character, parens, brackets, braces, angles, delimiter_position, delimiter, header, identifier, bare_identifier, type_name, count) {
        field_is_large_array = 0
        if (declaration ~ /^((public|private|protected|internal|static|readonly|const|volatile|new)[ ]+)*(class|struct|interface|enum|delegate|event|record)([ ]|$)/) return 0

        parens = brackets = braces = angles = 0
        delimiter_position = 0
        delimiter = ""
        for (position = 1; position <= length(declaration); position++) {
            character = substr(declaration, position, 1)
            next_character = substr(declaration, position + 1, 1)
            if (character == "(") parens++
            else if (character == ")" && parens > 0) parens--
            else if (character == "[") brackets++
            else if (character == "]" && brackets > 0) brackets--
            else if (character == "{") braces++
            else if (character == "}" && braces > 0) braces--
            else if (character == "<" && parens == 0 && brackets == 0 && braces == 0) angles++
            else if (character == ">" && angles > 0 && parens == 0 && brackets == 0 && braces == 0) angles--
            else if (parens == 0 && brackets == 0 && braces == 0 && angles == 0 &&
                     (character == "=" || character == "," || character == ";")) {
                if (character == "=" && next_character == ">") return 0
                delimiter_position = position
                delimiter = character
                break
            }
        }
        if (delimiter_position == 0) return 0

        header = normalize_space(substr(declaration, 1, delimiter_position - 1))
        while (sub(/^(public|private|protected|internal|static|readonly|const|volatile|new)[ ]+/, "", header)) { }
        if (header !~ / /) return 0
        identifier = header
        sub(/^.* /, "", identifier)
        bare_identifier = identifier
        sub(/^@/, "", bare_identifier)
        if (bare_identifier == "" || bare_identifier ~ /^[0-9]/ ||
            bare_identifier ~ /[][(){}.,:;=+*\/%!?&|^~<>-]/) return 0
        type_name = header
        sub(/[ ][^ ]*$/, "", type_name)
        type_name = normalize_space(type_name)
        if (type_name == "") return 0
        if (type_name ~ /^(int|float)[ ]*\[[ ]*\]$/) field_is_large_array = 1

        count = (delimiter == "," ? 2 : 1)
        if (delimiter == ";") return count
        parens = brackets = braces = 0
        for (position = delimiter_position + 1; position <= length(declaration); position++) {
            character = substr(declaration, position, 1)
            if (character == "(") parens++
            else if (character == ")" && parens > 0) parens--
            else if (character == "[") brackets++
            else if (character == "]" && brackets > 0) brackets--
            else if (character == "{") braces++
            else if (character == "}" && braces > 0) braces--
            else if (character == "," && parens == 0 && brackets == 0 && braces == 0) count++
            else if (character == ";" && parens == 0 && brackets == 0 && braces == 0) return count
        }
        return 0
    }

    function append_declaration(fragment) {
        if (fragment == "") return
        if (declaration_chunk_count > 0) declaration_size++
        declaration_chunks[++declaration_chunk_count] = fragment
        declaration_size += length(fragment)
        if (declaration_size > max_declaration_size) {
            scan_failed = 1
            exit 2
        }
    }

    function complete_declaration(    declaration, chunk_index, declarator_count) {
        declaration = ""
        for (chunk_index = 1; chunk_index <= declaration_chunk_count; chunk_index++) {
            if (declaration != "") declaration = declaration " "
            declaration = declaration declaration_chunks[chunk_index]
        }
        declaration = normalize_space(declaration)

        if (pending_sync_mode != "" && pending_sync_mode != 0 && is_class(declaration)) {
            if (pending_sync_mode == "BehaviourSyncMode.None") has_none_sync = 1
            else has_no_variable_sync = 1
            reset_pending()
            return
        }
        declarator_count = pending_synced ? field_declarator_count(declaration) : 0
        if (declarator_count > 0) {
            synced_count += declarator_count
            if (field_is_large_array) has_large_synced_array = 1
            reset_pending()
            return
        }
        reset_pending()
    }

    function declaration_boundary(text, start,    position, character, next_character) {
        for (position = start; position <= length(text); position++) {
            character = substr(text, position, 1)
            next_character = substr(text, position + 1, 1)
            if (character == "(") declaration_parens++
            else if (character == ")" && declaration_parens > 0) declaration_parens--
            else if (character == "[") declaration_brackets++
            else if (character == "]" && declaration_brackets > 0) declaration_brackets--
            else if (character == "{") {
                if (declaration_parens == 0 && declaration_brackets == 0 &&
                    declaration_braces == 0 && !declaration_has_assignment) return position
                declaration_braces++
            } else if (character == "}" && declaration_braces > 0) declaration_braces--
            else if (character == "=" && next_character != ">" &&
                     declaration_parens == 0 && declaration_brackets == 0 && declaration_braces == 0) {
                declaration_has_assignment = 1
            } else if (character == ";" && declaration_parens == 0 &&
                       declaration_brackets == 0 && declaration_braces == 0) return position
        }
        return 0
    }

    function consume_declaration_fragment(text, start,    boundary) {
        if (!(pending_synced || pending_sync_mode)) return start
        boundary = declaration_boundary(text, start)
        if (boundary > 0) append_declaration(substr(text, start, boundary - start + 1))
        else append_declaration(substr(text, start))
        if (boundary > 0) {
            complete_declaration()
            return boundary + 1
        }
        return length(text) + 1
    }

    function find_attribute_after_boundary(text, start,    position, character, after_boundary) {
        after_boundary = 0
        for (position = start; position <= length(text); position++) {
            character = substr(text, position, 1)
            if (character == ";" || character == "{" || character == "}") {
                after_boundary = 1
                continue
            }
            if (after_boundary && character ~ /[ \t]/) continue
            if (after_boundary && character == "[") return position
            if (after_boundary) after_boundary = 0
        }
        return length(text) + 1
    }

    function consume_line(text,    position, character) {
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
            if ((pending_synced || pending_sync_mode) && declaration_chunk_count > 0) {
                position = consume_declaration_fragment(text, position)
                continue
            }
            if (substr(text, position, 1) == "[") {
                begin_attribute()
                position++
                continue
            }
            if (pending_synced || pending_sync_mode) {
                position = consume_declaration_fragment(text, position)
                continue
            }
            position = find_attribute_after_boundary(text, position)
            if (position > length(text)) return
        }
    }

    BEGIN {
        reset_pending()
        collecting_attribute = 0
        max_declaration_size = 262144
    }

    {
        line = $0
        sub(/\r$/, "", line)
        if (line ~ /^[ \t]*$/ && !collecting_attribute) next
        if (collecting_attribute) attribute_content = attribute_content "\n"
        consume_line(line)
    }

    END {
        if (scan_failed) exit 2
        printf "%d|%d|%d|%d\n", synced_count, has_no_variable_sync, has_large_synced_array, has_none_sync
    }
' "$masked_file"); then
    skip_validation "ATTRIBUTE_SCAN_FAILED"
fi
IFS='|' read -r synced_count has_no_variable_sync has_large_synced_array has_none_sync <<< "$sync_stats"

# Networking issues
if [[ "$synced_count" -gt 0 ]]; then
    if ! grep -qE 'RequestSerialization[[:space:]]*[(]' "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode.")
    fi
    if ! grep -qE 'Networking[.](SetOwner|IsOwner)[[:space:]]*[(]|(^|[^.[:alnum:]_])IsOwner[[:space:]]*[(]' "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no Networking.SetOwner() or Networking.IsOwner() guard. Confirm ownership before writes.")
    fi
fi

# VRCPlayerApi without validity check
if grep -qE 'VRCPlayerApi[[:space:]]+@?[_[:alpha:]][_[:alnum:]]*[[:space:]]*=' "$masked_file"; then
    if ! grep -qE '[.]IsValid[[:space:]]*[(][[:space:]]*[)]|Utilities[.]IsValid[[:space:]]*[(]|player[[:space:]]*!=[[:space:]]*null' "$masked_file"; then
        warnings+=("[UdonSharp] WARNING: VRCPlayerApi used. Always check player != null && player.IsValid() before use.")
    fi
fi

# Check for override on Unity standard callbacks (should NOT have override)
if grep -qE 'override[[:space:]]+void[[:space:]]+(OnTriggerEnter|OnTriggerStay|OnTriggerExit|OnCollisionEnter|OnCollisionStay|OnCollisionExit|OnAnimatorMove|OnAnimatorIK)' "$masked_file"; then
    warnings+=("[UdonSharp] WARNING: Unity callbacks (OnTriggerEnter etc.) should NOT use 'override'. Only VRChat events need override.")
fi

# Generic GetComponent<UdonBehaviour> (not exposed)
if grep -qE "GetComponent<UdonBehaviour>" "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: GetComponent<UdonBehaviour>() not exposed. Use (UdonBehaviour)GetComponent(typeof(UdonBehaviour)) instead.")
fi

# System.Net / System.IO (blocked - use VRC downloaders)
if grep -qE 'using[[:space:]]+System[.](Net|IO)([^[:alnum:]_]|$)|System[.]Net[.]|System[.]IO[.]' "$masked_file"; then
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

# A None-mode behaviour cannot receive network events, and the compiler does
# not report it (Issue #383). A call on another behaviour is not flagged.
if [[ "$has_none_sync" -eq 1 ]] && grep -qE '(^|[^[:alnum:]_])NetworkCallable(Attribute)?[[:space:]]*[],(]|(^|[^.[:alnum:]_])(this[[:space:]]*[.][[:space:]]*)?SendCustomNetworkEvent[[:space:]]*[(]' "$masked_file"; then
    warnings+=("[UdonSharp] WARNING: BehaviourSyncMode.None cannot receive network events, but this file declares [NetworkCallable] or calls SendCustomNetworkEvent on itself. The event is never delivered. Use Manual or Continuous, or send the event to a synced behaviour.")
fi

# Multi-dimensional arrays (T[,])
if grep -qE '[_[:alnum:]]+[[:space:]]*\[[[:space:]]*,' "$masked_file"; then
    warnings+=("[UdonSharp] BLOCKED: Multi-dimensional arrays (T[,]) not supported. Use jagged arrays (T[][]) or flatten to 1D instead.")
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
    report_to_agent "$(printf '%s\n' "${warnings[@]}")"
fi
