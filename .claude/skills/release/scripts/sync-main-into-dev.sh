#!/usr/bin/env bash
# Release step 1: make sure dev contains the current main history.
#
# When origin/main is not an ancestor of origin/dev, this opens a sync PR from a
# fresh branch, waits for the seven required checks, merges it with a merge
# commit, and verifies the ancestry again. When dev already contains main it
# does nothing.
#
# Usage: bash .claude/skills/release/scripts/sync-main-into-dev.sh
set -e
git fetch origin

if ! git merge-base --is-ancestor origin/main origin/dev; then
  SYNC_BRANCH="chore/sync-main-into-dev-$(date +%Y%m%d%H%M%S)"
  git switch --create "$SYNC_BRANCH" origin/dev
  git merge --no-ff origin/main -m "chore: sync main into dev before release"
  git push -u origin "$SYNC_BRANCH"

  SYNC_PR=$(gh pr create --base dev --head "$SYNC_BRANCH" \
    --title "chore: sync main into dev before release" \
    --body "Merge the current main history into dev before the next release.")

  REQUIRED_CHECKS=(
    "Symlink Integrity"
    "Hook Scripts"
    "Documentation Smoke Tests"
    "Markdown Links"
    "npm Pack Test"
    "EditorConfig"
    "Version Sync"
  )
  for ((attempt = 1; attempt <= 30; attempt++)); do
    REGISTERED_CHECKS=""
    if REGISTERED_CHECKS=$(gh pr view "$SYNC_PR" --json statusCheckRollup \
      --jq '.statusCheckRollup[] | (.name // .context)' 2>/dev/null); then
      :
    fi

    MISSING_CHECKS=()
    for REQUIRED_CHECK in "${REQUIRED_CHECKS[@]}"; do
      if ! grep -Fqx -- "$REQUIRED_CHECK" <<<"$REGISTERED_CHECKS"; then
        MISSING_CHECKS+=("$REQUIRED_CHECK")
      fi
    done
    if (( ${#MISSING_CHECKS[@]} == 0 )); then
      break
    fi
    if (( attempt == 30 )); then
      printf 'ERROR: timed out waiting for required checks to register. Missing checks:\n' >&2
      printf '  - %s\n' "${MISSING_CHECKS[@]}" >&2
      exit 1
    fi
    sleep 10
  done

  gh pr checks "$SYNC_PR" --required --watch
  gh pr merge "$SYNC_PR" --merge --delete-branch

  git fetch origin
  git merge-base --is-ancestor origin/main origin/dev
else
  echo "OK: origin/dev already contains origin/main"
fi
