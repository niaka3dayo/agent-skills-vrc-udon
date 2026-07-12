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
        echo "ERROR: Udon routing metadata still has a broad trigger: $needle" >&2
        exit 1
    fi
}

UDON_DESCRIPTION="$(frontmatter_description "$UDON_SKILL")"
WORLD_DESCRIPTION="$(frontmatter_description "$WORLD_SKILL")"

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

# These broad/component-oriented phrases are owned by the World Skill, not bare
# activation terms in the Udon Skill frontmatter.
for phrase in 'VRC SDK' 'VRChat world' PhysBones Contacts 'Box Contacts' \
    'Global Avatar PhysBone Colliders' VRCPhysBoneCollider VRCTween; do
    forbid_text "$UDON_DESCRIPTION" "$phrase"
    require_text "$WORLD_DESCRIPTION" "$phrase"
done

echo "PASS: static Skill metadata routing contract (not a model-router test; 7 positive, 7 exclusion, 8 overlap phrases)"
