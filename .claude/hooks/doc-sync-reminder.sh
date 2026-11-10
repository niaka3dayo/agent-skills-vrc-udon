#!/usr/bin/env bash
# PostToolUse hook: remind about documentation sync when skill content changes.
# This hook is for repository maintenance (not distributed to end users).
#
# Reads JSON from stdin (Claude Code hook protocol). When the edited file is
# under skills/ or templates/, replies with hookSpecificOutput.additionalContext
# on stdout. Claude Code never shows the model stderr from a hook that exits 0,
# so a reminder printed there would not reach the agent.

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
CONTEXT=""

case "/$FILE_PATH" in
    */skills/*/SKILL.md)
        CONTEXT="SKILL.md changed - check the Skills section of all five READMEs"
        ;;
    */skills/*/rules/*.md)
        CONTEXT="Rule file changed - check templates/*.md for valid path references"
        ;;
    */skills/*/hooks/*)
        CONTEXT="Hook changed - check the Hooks section of all five READMEs"
        ;;
    */skills/*/references/*.md)
        CONTEXT="Reference changed - check the reference counts in all five READMEs"
        ;;
    */skills/*/assets/templates/*.cs)
        CONTEXT="C# template changed - check the template counts in all five READMEs"
        ;;
    */templates/*.md)
        CONTEXT="Distribution template changed - check the Install/Structure sections of all five READMEs"
        ;;
esac

if [ -n "$CONTEXT" ]; then
    jq -cn --arg context "[doc-sync] $CONTEXT. See .claude/rules/doc-sync.md for the full checklist." \
        '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
fi

exit 0
