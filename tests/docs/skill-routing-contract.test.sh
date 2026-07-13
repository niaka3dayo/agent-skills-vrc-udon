#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UDON_SKILL="$ROOT_DIR/skills/unity-vrc-udon-sharp/SKILL.md"
WORLD_SKILL="$ROOT_DIR/skills/unity-vrc-world-sdk-3/SKILL.md"

frontmatter_description() {
    awk '
        /^description:/ { in_description = 1 }
        in_description && /^(license|metadata):/ { exit }
        in_description { print }
    ' "$1"
}

folded_description_length() {
    awk '
        /^description:[[:space:]]*>[+-]?[[:space:]]*$/ {
            in_description = 1
            next
        }
        in_description && /^[^[:space:]]/ { exit }
        in_description {
            line = $0
            sub(/^    /, "", line)
            if (has_line) total++
            total += length(line)
            has_line = 1
        }
        END {
            if (!has_line) exit 2
            print total + 1
        }
    ' "$1"
}

require_text() {
    local haystack="$1"
    local needle="$2"
    if ! grep -Fq "$needle" <<<"$haystack"; then
        echo "ERROR: routing metadata is missing: $needle" >&2
        exit 1
    fi
}

forbid_text() {
    local haystack="$1"
    local needle="$2"
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "ERROR: routing metadata contains an ambiguous trigger: $needle" >&2
        exit 1
    fi
}

UDON_DESCRIPTION="$(frontmatter_description "$UDON_SKILL")"
WORLD_DESCRIPTION="$(frontmatter_description "$WORLD_SKILL")"

for skill in "$UDON_SKILL" "$WORLD_SKILL"; do
    length="$(folded_description_length "$skill")"
    if [ "$length" -gt 1024 ]; then
        echo "ERROR: Skill description exceeds 1024 characters: $skill ($length)" >&2
        exit 1
    fi
done

# Positive Udon/runtime phrases must remain explicit in the Udon Skill metadata.
for phrase in UdonSharp NetworkCalling CallingPlayer 'network authorization' \
    'local public helper' 'public-method audit' 'C# to Udon'; do
    require_text "$UDON_DESCRIPTION" "$phrase"
done

# Scene/component requests must be explicitly excluded and routed to World SDK 3.
for phrase in 'scene setup' 'component setup' 'Build Panel' layers optimization upload \
    'unity-vrc-world-sdk-3'; do
    require_text "$UDON_DESCRIPTION" "$phrase"
done

# Runtime API contexts belong to Udon even when they mention Dynamics or tweening.
for phrase in 'VRCTween calls' 'PhysBone/Contact callbacks' \
    'VRCPhysBoneCollider runtime access'; do
    require_text "$UDON_DESCRIPTION" "$phrase"
done

# Scene and Inspector contexts belong to World SDK 3. The World description must
# also reject the ambiguous "world scripting" phrase and route C# calls back to Udon.
for phrase in 'VRChat world scene' 'VRC SDK' 'component placement' \
    'VRCPhysBoneCollider component setup' 'Build Panel warning'; do
    require_text "$WORLD_DESCRIPTION" "$phrase"
done
for phrase in 'VRChat world scripting' 'Triggers on: VRCTween'; do
    forbid_text "$WORLD_DESCRIPTION" "$phrase"
done
require_text "$WORLD_DESCRIPTION" 'Do not use for UdonSharp C# or VRCTween calls'
require_text "$WORLD_DESCRIPTION" 'unity-vrc-udon-sharp for runtime scripting'

echo "PASS: static contextual Skill metadata routing contract (not a model-router test)"
