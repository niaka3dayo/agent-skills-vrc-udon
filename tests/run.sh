#!/usr/bin/env bash
# Run every test suite that CI runs.
#
# Usage: tests/run.sh [filter]
#   filter  run only suites whose path contains this text (e.g. "layers")
#
# Needs bash, python3 and jq. The BusyBox and PowerShell suites run when
# busybox and pwsh are installed and are reported as skipped otherwise; CI
# always runs them.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
FILTER="${1:-}"

case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
        # The suites rely on symlinks, `env -i` and UTF-8 Python defaults.
        echo "ERROR: run this script on Linux, macOS, or inside WSL; Git Bash on Windows is not supported." >&2
        exit 2
        ;;
esac

for tool in python3 jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool is required" >&2
        exit 2
    fi
done

passed=0
failed=0
skipped=0

run_suite() {
    local label="$1"
    shift
    local output
    if output="$("$@" 2>&1)"; then
        echo "PASS $label"
        passed=$((passed + 1))
    else
        echo "FAIL $label"
        # CI logs keep the whole output; a terminal gets the end of it.
        if [ -n "${CI:-}" ]; then
            printf '%s\n' "$output" | sed 's/^/    /'
        else
            printf '%s\n' "$output" | tail -20 | sed 's/^/    /'
        fi
        failed=$((failed + 1))
    fi
}

skip_suite() {
    echo "SKIP $1 ($2)"
    skipped=$((skipped + 1))
}

for suite in tests/docs/*.test.sh tests/hooks/*.test.sh; do
    [[ "$suite" == *"$FILTER"* ]] || continue
    if [[ "$suite" == *busybox* ]] && ! command -v busybox >/dev/null 2>&1; then
        skip_suite "$suite" "busybox not installed"
        continue
    fi
    run_suite "$suite" bash "$suite"
done

POWERSHELL_SUITE="tests/hooks/validate-udonsharp.test.ps1"
if [[ "$POWERSHELL_SUITE" == *"$FILTER"* ]]; then
    if command -v pwsh >/dev/null 2>&1; then
        run_suite "$POWERSHELL_SUITE" pwsh -NoLogo -NoProfile -File "$POWERSHELL_SUITE"
    else
        skip_suite "$POWERSHELL_SUITE" "pwsh not installed"
    fi
fi

echo "Summary: $passed passed, $failed failed, $skipped skipped"
if [ $((passed + failed)) -eq 0 ]; then
    echo "ERROR: no suite matched '$FILTER'" >&2
    exit 2
fi
[ "$failed" -eq 0 ]
