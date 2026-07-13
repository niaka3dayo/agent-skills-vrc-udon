#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORLD_SKILL="$ROOT_DIR/skills/unity-vrc-world-sdk-3/SKILL.md"
UDON_SKILL="$ROOT_DIR/skills/unity-vrc-udon-sharp/SKILL.md"
REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/build-validation.md"
COMPONENTS_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/components.md"
UDON_API_REF="$ROOT_DIR/skills/unity-vrc-udon-sharp/references/api.md"
PERFORMANCE_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/performance.md"

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

forbid_text() {
    local path="$1"
    local needle="$2"
    if grep -Fq "$needle" "$path"; then
        echo "ERROR: $path contains obsolete text: $needle" >&2
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

# Keep the World component reference aligned with the known ASCII Udon API
# heading and its GitHub-Flavored Markdown fragment.
DYNAMICS_HEADING='## VRChat Dynamics API (SDK 3.10.0+)'
require_text "$UDON_API_REF" "$DYNAMICS_HEADING"
DYNAMICS_SLUG="$(printf '%s\n' "$DYNAMICS_HEADING" \
    | sed -E 's/^#{1,6}[[:space:]]+//' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9 _-]//g; s/[[:space:]]+/-/g; s/-+/-/g; s/^-|-$//g')"
if [[ "$DYNAMICS_SLUG" != "vrchat-dynamics-api-sdk-3100" ]]; then
    echo "ERROR: unexpected GFM slug for known Dynamics heading: $DYNAMICS_SLUG" >&2
    exit 1
fi
require_text "$COMPONENTS_REF" "../../unity-vrc-udon-sharp/references/api.md#$DYNAMICS_SLUG"
forbid_text "$COMPONENTS_REF" "#physbones-and-contacts-sdk-3100"

# Keep optimization references on the current official Android guide.
CURRENT_ANDROID_GUIDE='https://creators.vrchat.com/platforms/android/quest-content-optimization/'
OLD_ANDROID_GUIDE='https://creators.vrchat.com/platforms/android/android-content-optimization/'
OLD_UDON_PERFORMANCE_GUIDE='https://creators.vrchat.com/worlds/udon/performance-and-optimization/'
require_text "$WORLD_SKILL" "$CURRENT_ANDROID_GUIDE"
require_text "$PERFORMANCE_REF" "$CURRENT_ANDROID_GUIDE"
for path in "$WORLD_SKILL" "$PERFORMANCE_REF"; do
    forbid_text "$path" "$OLD_ANDROID_GUIDE"
    forbid_text "$path" "$OLD_UDON_PERFORMANCE_GUIDE"
done
for obsolete_claim in '10-30 FPS' '3-5× draw call overhead' \
    'typically run at 90+ FPS on PC' 'Build for Quest and get PC for free' \
    '~2× slower than PC VR' 'Realtime is only viable on PC-only worlds' \
    'Fully baked (no realtime shadows)'; do
    forbid_text "$WORLD_SKILL" "$obsolete_claim"
done
for obsolete_claim in '| Real-time shadows | Not supported |' \
    '❌ Real-time shadow casting and receiving' \
    '□ No real-time shadow settings on any light'; do
    forbid_text "$PERFORMANCE_REF" "$obsolete_claim"
done
require_text "$WORLD_SKILL" 'profile each target device before keeping realtime lighting or shadows'
require_text "$PERFORMANCE_REF" 'keep only after profiling on the target Android device'

echo "PASS: build-validation reference coverage smoke test"
