#!/usr/bin/env bash
# PostToolUse hook: remind about documentation sync when skill content changes.
# This hook is for repository maintenance (not distributed to end users).
#
# Reads JSON from stdin (Claude Code hook protocol).
# Outputs a reminder to stderr if the edited file is under skills/ or templates/.

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# Require jq for JSON parsing; silently skip if unavailable
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Extract the file path from the tool input
# Works for both Write and Edit tools
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Check if the file is under a monitored path.
# Prepend "/" to ensure */glob patterns match both relative and absolute paths.
NEEDS_REMINDER=false
CONTEXT=""

case "/$FILE_PATH" in
    */skills/*/SKILL.md)
        NEEDS_REMINDER=true
        CONTEXT="SKILL.md changed - check README.md/README.ja.md Skills section"
        ;;
    */skills/*/rules/*.md)
        NEEDS_REMINDER=true
        CONTEXT="Rule file changed - check templates/*.md for valid path references"
        ;;
    */skills/*/hooks/*)
        NEEDS_REMINDER=true
        CONTEXT="Hook changed - check README.md Hooks section"
        ;;
    */skills/*/references/*.md)
        NEEDS_REMINDER=true
        CONTEXT="Reference changed - check README.md Skills section reference counts"
        ;;
    */skills/*/assets/templates/*.cs)
        NEEDS_REMINDER=true
        CONTEXT="C# template changed - check README.md Skills section template counts"
        ;;
    */templates/*.md)
        NEEDS_REMINDER=true
        CONTEXT="Distribution template changed - check README.md Install/Structure section"
        ;;
    */bin/install.mjs)
        NEEDS_REMINDER=true
        CONTEXT="Installer changed - check README.md Install section, CLAUDE.md Testing section"
        ;;
esac

if [ "$NEEDS_REMINDER" = true ]; then
    echo "[doc-sync] $CONTEXT" >&2
    echo "See .claude/rules/doc-sync.md for the full documentation sync checklist." >&2
fi

exit 0
