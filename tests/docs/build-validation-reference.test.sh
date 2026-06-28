#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORLD_SKILL="$ROOT_DIR/skills/unity-vrc-world-sdk-3/SKILL.md"
UDON_SKILL="$ROOT_DIR/skills/unity-vrc-udon-sharp/SKILL.md"
REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/build-validation.md"

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

require_file "$REF"

# SDK evidence and color/severity model
require_text "$REF" "Last verified SDK"
require_text "$REF" 'VRChat Worlds SDK `3.10.4`'
require_text "$REF" 'Base SDK `3.10.4`'
require_text "$REF" "OnGUIError"
require_text "$REF" "OnGUIWarning"
require_text "$REF" "OnGUIInformation"
require_text "$REF" "Auto Fix"

# Representative red/yellow/white alert families from the SDK 3.10.4 catalog
require_text "$REF" "A VRCSceneDescriptor is required to build a World"
require_text "$REF" "A VRCSceneDescriptor or VRCAvatarDescriptor"
require_text "$REF" "Multiple Pipeline Managers found in scene. Please remove all but one."
require_text "$REF" "You can only have a single Pipeline Manager in a Scene"
require_text "$REF" "SDK V3 is not enabled."
require_text "$REF" "Multiple pipelines are present. V3 pipeline will take priority"
require_text "$REF" "Multiple scene descriptors"
require_text "$REF" "Object Sync cannot share an object with a manually synchronized Udon Behaviour"
require_text "$REF" "You have Event Handlers in your scene that are not allowed in this build configuration."
require_text "$REF" 'removes each `VRC_EventHandler` component'
require_text "$REF" "You must address Layers and Collision Matrix issues before you can build."
require_text "$REF" "Android texture format not ASTC"
require_text "$REF" "AudioSource"
require_text "$REF" "VRC_SpatialAudioSource"
require_text "$REF" 'Gain `0 dB`'
require_text "$REF" "Unsupported mobile shader"
require_text "$REF" "Found one or more UI graphics using Unity's built-in UI shader"
require_text "$REF" "VRCSuperSampledUIMaterial.mat"
require_text "$REF" "Billboard particles allow roll"
require_text "$REF" "Box mipmap filtering"
require_text "$REF" "Everything looks good"

# Existing entrypoints must route copied validation messages to the catalog.
for path in \
    "$WORLD_SKILL" \
    "$UDON_SKILL" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/CHEATSHEET.md" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/upload.md" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/troubleshooting.md" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/audio-video.md" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/components.md"; do
    require_file "$path"
    require_text "$path" "build-validation.md"
done

echo "PASS: build-validation reference coverage smoke test"
