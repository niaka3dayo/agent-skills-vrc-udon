#!/usr/bin/env bash
set -euo pipefail

# Symlink integrity checker for CI
# Verifies that all AI tool directories correctly link to skills/

ERRORS=0
CHECKED=0

check_symlink() {
  local link="$1"
  local expected_target="$2"

  CHECKED=$((CHECKED + 1))

  if [ ! -L "$link" ]; then
    echo "ERROR: $link is not a symlink"
    ERRORS=$((ERRORS + 1))
    return
  fi

  local actual_target
  actual_target=$(readlink "$link")

  if [ "$actual_target" != "$expected_target" ]; then
    echo "ERROR: $link -> $actual_target (expected $expected_target)"
    ERRORS=$((ERRORS + 1))
    return
  fi

  if [ ! -e "$link" ]; then
    echo "ERROR: $link -> $actual_target (broken symlink)"
    ERRORS=$((ERRORS + 1))
    return
  fi

  echo "  OK: $link -> $actual_target"
}

echo "Checking symlink integrity..."
echo ""

# Skills symlinks
for dir in .claude .agents .codex .gemini; do
  check_symlink "$dir/skills/unity-vrc-udon-sharp" "../../skills/unity-vrc-udon-sharp"
  check_symlink "$dir/skills/unity-vrc-world-sdk-3" "../../skills/unity-vrc-world-sdk-3"
  check_symlink "$dir/skills/unity-vrc-skills-renovator" "../../skills/unity-vrc-skills-renovator"
done

# Rules symlinks
for dir in .claude .agents .codex .gemini; do
  check_symlink "$dir/rules/udonsharp-constraints.md" "../../skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md"
  check_symlink "$dir/rules/udonsharp-networking.md" "../../skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md"
  check_symlink "$dir/rules/udonsharp-sync-selection.md" "../../skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md"
done

echo ""
echo "Checked: $CHECKED symlinks"

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS errors found"
  exit 1
else
  echo "PASSED: All symlinks are valid"
  exit 0
fi
