#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

require_text() {
    local path="$1"
    local text="$2"
    grep -Fq -- "$text" "$path" || fail "$path is missing: $text"
}

forbid_text() {
    local path="$1"
    local text="$2"
    if grep -Fq -- "$text" "$path"; then
        fail "$path still contains stale active-support text: $text"
    fi
}

forbid_regex() {
    local path="$1"
    local pattern="$2"
    if grep -Eq -- "$pattern" "$path"; then
        fail "$path still matches stale active-support pattern: $pattern"
    fi
}

README_FILES=(
    "$ROOT_DIR/README.md"
    "$ROOT_DIR/README.ja.md"
    "$ROOT_DIR/README.zh-CN.md"
    "$ROOT_DIR/README.zh-TW.md"
    "$ROOT_DIR/README.ko.md"
)

# The repository-level contract must name the one actively verified target and
# distinguish it from historical feature-introduction entries. This wording is
# deliberately English in the canonical README so future translations can be
# checked against the same policy without treating VRChat's own policy as ours.
require_text "$ROOT_DIR/README.md" '**Active support / last verified**: VRChat SDK 3.10.4'
require_text "$ROOT_DIR/README.md" 'From v4.0.0 onward, the support policy is latest stable SDK only; the support target moves to a new stable release only after this repository verifies it. A new stable release is not supported automatically.'
require_text "$ROOT_DIR/README.md" 'historical feature-introduction notes'
require_text "$ROOT_DIR/README.md" "not a statement about VRChat's own SDK policy"
forbid_text "$ROOT_DIR/README.md" 'VRChat_SDK-3.7.1--3.10.4'
forbid_text "$ROOT_DIR/README.md" 'SDK coverage (3.7.1 - 3.10.4)'

# All translations carry the same current target and must not advertise the old
# range in their badge or accuracy note.
for path in "${README_FILES[@]}"; do
    require_text "$path" '3.10.4'
    forbid_regex "$path" '3\.7\.1.{0,8}3\.10\.4'
done

# Translations must carry the same stable-only policy and verification gate,
# rather than merely repeating the current version number.
declare -A README_POLICY=()
README_POLICY["$ROOT_DIR/README.md"]='From v4.0.0 onward, the support policy is latest stable SDK only; the support target moves to a new stable release only after this repository verifies it.'
README_POLICY["$ROOT_DIR/README.ja.md"]='v4.0.0以降は最新の安定版SDKのみをサポートし、新しい安定版への切り替えはこのリポジトリで検証してから行います。'
README_POLICY["$ROOT_DIR/README.zh-CN.md"]='从 v4.0.0 起，本项目只支持最新的稳定版 SDK；只有在本仓库完成验证后，支持目标才会切换到新的稳定版本。'
README_POLICY["$ROOT_DIR/README.zh-TW.md"]='從 v4.0.0 起，本專案只支援最新的穩定版 SDK；只有在本儲存庫完成驗證後，支援目標才會切換到新的穩定版本。'
README_POLICY["$ROOT_DIR/README.ko.md"]='v4.0.0부터는 최신 안정 SDK만 지원하며, 새 안정 버전으로의 지원 전환은 이 저장소에서 검증한 뒤에만 진행합니다.'
for path in "${README_FILES[@]}"; do
    require_text "$path" "${README_POLICY[$path]}"
done

# Both distributed skills expose the same active-support boundary. Historical
# version rows may remain, but the former range must not remain a coverage claim.
for path in \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/SKILL.md" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/SKILL.md"; do
    require_text "$path" 'Active support / last verified'
    require_text "$path" 'SDK 3.10.4'
    require_text "$path" 'historical'
    forbid_regex "$path" '(Supported SDK Versions|SDK Coverage|Covered versions|SDK 3\.7\.1-3\.10\.4|SDK 3\.7\.1 - 3\.10\.4)'
done

for path in \
    "$ROOT_DIR/templates/AGENTS.md" \
    "$ROOT_DIR/templates/CLAUDE.md" \
    "$ROOT_DIR/templates/GEMINI.md"; do
    require_text "$path" 'From v4.0.0 onward'
    require_text "$path" 'not supported or validation targets'
done

# Reference headers are active-support declarations, not feature-introduction
# history. Keep the historical baseline in body text where it explains an API.
for path in \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/api.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/constraints.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/dynamics.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/events.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/image-loading-vram.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/networking.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/persistence.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/testing.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/troubleshooting.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/web-loading-advanced.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/web-loading.md" \
    "$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/components.md"; do
    require_text "$path" 'Active support / last verified'
    require_text "$path" '3.10.4'
done

for path in \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md"; do
    require_text "$path" 'Active support / last verified'
    require_text "$path" '3.10.4'
    forbid_regex "$path" 'SDK Coverage.*3\.7\.1'
done

# Distributed agent templates and maintainer guidance must teach the same
# active-vs-historical boundary.
for path in "$ROOT_DIR/templates/AGENTS.md" "$ROOT_DIR/templates/CLAUDE.md" "$ROOT_DIR/templates/GEMINI.md"; do
    require_text "$path" 'active: 3.10.4'
    require_text "$path" 'historical'
    forbid_regex "$path" 'SDK \(3\.7\.1.{0,8}3\.10\.4\)'
done

require_text "$ROOT_DIR/CONTRIBUTING.md" '**Active and verified target**: SDK 3.10.4'
require_text "$ROOT_DIR/CONTRIBUTING.md" 'historical migration information only'
require_text "$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/skill-structure.md" '**Active support / last verified**: SDK 3.10.4'
require_text "$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/update-checklist.md" 'active-versus-historical boundary'
require_text "$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/changelog-sources.md" 'active and verified target'

# This contract must be part of the required Documentation Smoke Tests job.
CI="$ROOT_DIR/.github/workflows/ci.yml"
require_text "$CI" 'Check SDK active support policy'
require_text "$CI" 'bash tests/docs/sdk-support-policy.test.sh'

echo "PASS: SDK active support policy contract"
