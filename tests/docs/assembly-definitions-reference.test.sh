#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UDON_DIR="$ROOT_DIR/skills/unity-vrc-udon-sharp"
SKILL="$UDON_DIR/SKILL.md"
CHEATSHEET="$UDON_DIR/CHEATSHEET.md"
EDITOR_REF="$UDON_DIR/references/editor-scripting.md"
REF="$UDON_DIR/references/assembly-definitions.md"
CI="$ROOT_DIR/.github/workflows/ci.yml"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "ERROR: missing file: $path" >&2
        exit 1
    fi
}

require_text() {
    local path="$1"
    local needle="$2"
    if ! grep -Fq "$needle" "$path"; then
        echo "ERROR: $path does not contain expected text: $needle" >&2
        exit 1
    fi
}

require_any_text() {
    local path="$1"
    shift
    local needle
    for needle in "$@"; do
        if grep -Fq "$needle" "$path"; then
            return 0
        fi
    done
    echo "ERROR: $path does not contain any expected text: $*" >&2
    exit 1
}

require_file "$REF"

# Core reference guidance and evidence links
require_any_text "$REF" "world-only" "simple one-off" "ordinary"
require_text "$REF" "do not add an asmdef by default"
require_text "$REF" 'Unity `.asmdef`'
require_text "$REF" "U# Assembly Definition"
require_text "$REF" "Source Assembly"
require_text "$REF" "does not belong to a U# assembly"
require_text "$REF" "VPM"
require_text "$REF" "Runtime/Editor"
require_any_text "$REF" "Editor-only scripts" "editor-only scripts"
require_text "$REF" "UdonSharpBehaviours"
require_text "$REF" "Auto Referenced"
require_text "$REF" "compile reference policy"
require_text "$REF" "not build inclusion"
require_any_text "$REF" "prefab-first" "prefab first"
require_text "$REF" "code-integration API"
require_text "$REF" "internal runtime code"
require_text "$REF" "https://udonsharp.docs.vrchat.com/migration/"
require_text "$REF" "https://docs.unity3d.com/Manual/assembly-definition-file-format.html"

# Entrypoints route asmdef/package work to the reference.
for path in "$SKILL" "$CHEATSHEET" "$EDITOR_REF"; do
    require_file "$path"
    require_text "$path" "assembly-definitions.md"
done

# SKILL.md discovery surfaces and tables include the new topic.
require_text "$SKILL" "asmdef"
require_text "$SKILL" "VPM package"
require_text "$SKILL" "U# Assembly Definition"
require_text "$SKILL" "Auto Referenced"
require_text "$SKILL" 'Unity `.asmdef`'
require_text "$SKILL" "without matching U# Assembly Definition"
require_text "$SKILL" "VPM/package/asmdef workflows"
require_text "$SKILL" "assembly-definitions.md"

# Cheatsheet includes the short decision note.
require_any_text "$CHEATSHEET" "simple world scripts" "world scripts"
require_any_text "$CHEATSHEET" "package/asmdef" "U# Assembly Definition"
require_text "$CHEATSHEET" "Auto Referenced"

# CI docs job runs this smoke test.
require_text "$CI" "assembly-definitions-reference.test.sh"

echo "PASS: assembly-definitions reference coverage smoke test"
