#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORPUS_FIXTURE="$ROOT_DIR/tests/docs/fixtures/sdk-support-policy-corpus.json"

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

# Keep the tracked literal census and its classifications alongside the
# contract. The fixture deliberately excludes this test file's negative
# examples and immutable CHANGELOG entries from the stale-declaration scan.
[ -f "$CORPUS_FIXTURE" ] || fail "missing SDK support-policy corpus census: $CORPUS_FIXTURE"
python3 - "$CORPUS_FIXTURE" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
scan = data["scan"]
files = scan["files"]
assert scan["literal"] == "3.7.1"
assert scan["occurrences"] == sum(item["occurrences"] for item in files) == 61
assert scan["files_with_literal"] == len(files) == 28
assert sum(data["classification_counts"].values()) == scan["occurrences"]
stale = data["active_support_declarations"]["stale_active_declaration_scan"]
assert stale["matches"] == []
assert stale["result"] == "no stale active-support declarations"
assert {item["path"] for item in data["test_contracts"]} == {
    "tests/docs/sdk-support-policy.test.sh",
    "tests/docs/community-contributors.test.sh",
    "tests/docs/network-event-hardening.test.sh",
}
PY

# Re-run the stale declaration scan against the live tracked corpus. The
# changelog and this test's negative fixtures intentionally retain old release
# wording as historical/test evidence. Match any numeric active range rather
# than hard-coding the retired lower bound, so a future policy regression such
# as 3.8.1 - 3.10.4 cannot silently pass.
STALE_ACTIVE_DECLARATION_PATTERN='(^|[^[:alnum:]])(Supported SDK Versions|SDK Coverage|Covered versions)(\*\*)?[[:space:]]*[:(][^[:cntrl:]]*[0-9]+\.[0-9]+\.[0-9]+'
STALE_ACTIVE_SCAN_PATTERN="$STALE_ACTIVE_DECLARATION_PATTERN|this skill.?s coverage range|this skill targets SDK[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+|VRChat_SDK-[0-9]+\.[0-9]+\.[0-9]+--[0-9]+\.[0-9]+\.[0-9]+|SDK[[:space:]]+3\.7\.1[[:space:]]*(-|–)[[:space:]]*3\.10\.4"
STALE_ACTIVE_SCAN="$(git -C "$ROOT_DIR" grep -n -E "$STALE_ACTIVE_SCAN_PATTERN" -- '*.md' ':!CHANGELOG.md' ':!tests/docs/*' || true)"
[ -z "$STALE_ACTIVE_SCAN" ] || fail "stale active-support declaration found:\n$STALE_ACTIVE_SCAN"

# A future SDK is not an active support target until this repository verifies
# it. Reject the easy-to-miss "3.10.4 or newer" routing form while preserving
# historical feature-introduction notes such as "SDK 3.8.1+".
FUTURE_AUTO_SUPPORT_PATTERN='SDK[[:space:]]+3\.10\.4[[:space:]]+or[[:space:]]+newer'
FUTURE_AUTO_SUPPORT_SCAN="$(git -C "$ROOT_DIR" grep -n -E -i "$FUTURE_AUTO_SUPPORT_PATTERN" -- '*.md' ':!CHANGELOG.md' ':!tests/docs/*' || true)"
[ -z "$FUTURE_AUTO_SUPPORT_SCAN" ] || fail "unverified future SDK auto-support wording found:\n$FUTURE_AUTO_SUPPORT_SCAN"

# Keep the two negative cases executable. This is the mutation guard for the
# contract itself: broad old ranges must be rejected, future auto-support must
# be rejected, and an SDK x+ feature-introduction note must remain allowed.
MUTATED_REFERENCE="$(mktemp)"
trap 'rm -f "$MUTATED_REFERENCE"' EXIT
cp "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/vrctween.md" "$MUTATED_REFERENCE"
cat >> "$MUTATED_REFERENCE" <<'EOF'

**Supported SDK Versions**: 3.8.1 - 3.10.4
Route this reference to projects using SDK 3.10.4 or newer.
Historical feature introduction: SDK 3.8.1+ remains valid migration context.
EOF
grep -Eiq "$STALE_ACTIVE_DECLARATION_PATTERN" "$MUTATED_REFERENCE" \
    || fail "mutation guard missed an arbitrary old active SDK range"
grep -Eiq "$FUTURE_AUTO_SUPPORT_PATTERN" "$MUTATED_REFERENCE" \
    || fail "mutation guard missed unverified future SDK auto-support wording"
if grep -Eiq 'Historical feature introduction: SDK 3\.8\.1\+' "$MUTATED_REFERENCE" \
    && ! grep -Eiq "$STALE_ACTIVE_DECLARATION_PATTERN" <(grep -E 'Historical feature introduction:' "$MUTATED_REFERENCE"); then
    echo "PASS: historical SDK x+ introduction note remains allowed"
else
    fail "historical SDK x+ introduction note was treated as an active declaration"
fi
echo "PASS: arbitrary old active SDK range mutation rejected"
echo "PASS: unverified future SDK auto-support mutation rejected"

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
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/vrctween.md" '**Active support / last verified**: SDK 3.10.4'
forbid_regex "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/vrctween.md" 'SDK 3\.10\.4\+|SDK 3\.10\.4 or newer'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/CHEATSHEET.md" '## VRCTween (introduced in SDK 3.10.4)'
forbid_regex "$ROOT_DIR/skills/unity-vrc-udon-sharp/CHEATSHEET.md" '## VRCTween \(SDK 3\.10\.4\+\)|on SDK 3\.10\.4\+'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-utilities.md" 'Solution on the active SDK target (3.10.4)'
forbid_regex "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-utilities.md" 'routeable SDK 3\.10\.4\+|on SDK 3\.10\.4\+'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-networking.md" 'historical migration guidance for unsupported older projects'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/web-loading-advanced.md" 'Historical migration guidance only: SDK 3.7.1 introduced the available surface'

# This contract must be part of the required Documentation Smoke Tests job.
CI="$ROOT_DIR/.github/workflows/ci.yml"
require_text "$CI" 'Check SDK active support policy'
require_text "$CI" 'bash tests/docs/sdk-support-policy.test.sh'

echo "PASS: SDK active support policy contract"
