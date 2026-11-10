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

# The active SDK target is declared once per skill, in the bold line of each
# SKILL.md. Everything below reads it from there, so an SDK bump needs no edit
# to this test, and a second declaration cannot disagree with the first.
UDON_SKILL="$ROOT_DIR/skills/unity-vrc-udon-sharp/SKILL.md"
WORLD_SKILL="$ROOT_DIR/skills/unity-vrc-world-sdk-3/SKILL.md"
active_target() {
    sed -nE 's/^\*\*Active support \/ last verified\*\*: SDK ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' "$1"
}
ACTIVE="$(active_target "$UDON_SKILL")"
[[ "$ACTIVE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "$UDON_SKILL must declare exactly one active SDK target"
[ "$(active_target "$WORLD_SKILL")" = "$ACTIVE" ] \
    || fail "the two skills declare different active SDK targets"
for path in "$UDON_SKILL" "$WORLD_SKILL"; do
    grep -Fxq '## SDK Versions' "$path" \
        || fail "$path needs the '## SDK Versions' heading that other files link to"
done

# No other file under skills/ declares or restates the active target. Each copy
# was one more edit per SDK bump, and the copies drifted: 14 files kept an old
# historical range and persistence.md kept a second one.
SKILL_DOCS=('skills/*.md' ':!skills/*/SKILL.md')
REDECLARED="$(git -C "$ROOT_DIR" grep -n -F 'Active support / last verified' -- "${SKILL_DOCS[@]}" || true)"
[ -z "$REDECLARED" ] || fail "the active SDK target is declared outside SKILL.md:\n$REDECLARED"
RESTATED_PATTERN='(^|[^[:alnum:]])active( and verified| verified)?( SDK)?( support)? target[^.;|]{0,30}[0-9]+\.[0-9]+\.[0-9]+'
RESTATED="$(git -C "$ROOT_DIR" grep -n -i -E "$RESTATED_PATTERN" -- "${SKILL_DOCS[@]}" || true)"
[ -z "$RESTATED" ] || fail "the active SDK number is restated outside SKILL.md:\n$RESTATED"
for restated in \
    'on the active SDK target (3.10.6)' \
    'the active verified target is SDK 3.10.6' \
    '(introduced in SDK 3.7.4; active target 3.10.6)' \
    'Use the active SDK target, 3.10.6; for historical migration'; do
    grep -Eiq "$RESTATED_PATTERN" <<<"$restated" \
        || fail "restatement guard missed: $restated"
done
for allowed in \
    '`IsActive`, `GlobalWeight`, `SmoothingFactor`, source methods (SDK 3.10.6+)' \
    'Prefer over helper objects on the active SDK target' \
    'introduced in SDK 3.10.4'; do
    if grep -Eiq "$RESTATED_PATTERN" <<<"$allowed"; then
        fail "restatement guard rejected an allowed line: $allowed"
    fi
done
echo "PASS: active SDK target is declared once per skill ($ACTIVE)"

# Re-run the stale declaration scan against the live tracked corpus. The
# changelog and this test's negative fixtures intentionally retain old release
# wording as historical/test evidence. Match any numeric active range rather
# than hard-coding the retired lower bound, so a future policy regression such
# as 3.8.1 - 3.10.4 cannot silently pass.
STALE_ACTIVE_DECLARATION_PATTERN='(^|[^[:alnum:]])(Supported SDK Versions|SDK Coverage|Covered versions)(\*\*)?[[:space:]]*[:(][^[:cntrl:]]*[0-9]+\.[0-9]+\.[0-9]+'
STALE_ACTIVE_SCAN_PATTERN="$STALE_ACTIVE_DECLARATION_PATTERN|this skill.?s coverage range|this skill targets SDK[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+|VRChat_SDK-[0-9]+\.[0-9]+\.[0-9]+--[0-9]+\.[0-9]+\.[0-9]+"
STALE_ACTIVE_SCAN="$(git -C "$ROOT_DIR" grep -n -E "$STALE_ACTIVE_SCAN_PATTERN" -- '*.md' ':!CHANGELOG.md' ':!tests/docs/*' || true)"
[ -z "$STALE_ACTIVE_SCAN" ] || fail "stale active-support declaration found:\n$STALE_ACTIVE_SCAN"

# Every copy of the historical range must name the same upper bound. The copies
# drifted once: 14 files still read 3.7.1-3.10.4 after 3.10.5 became historical.
HISTORICAL_RANGES="$(git -C "$ROOT_DIR" grep -ohE '3\.7\.1-[0-9]+\.[0-9]+\.[0-9]+' -- '*.md' ':!CHANGELOG.md' ':!tests/docs/*' | sort -u)"
[ "$(grep -c . <<<"$HISTORICAL_RANGES")" -eq 1 ] \
    || fail "historical SDK range literals disagree: $(tr '\n' ' ' <<<"$HISTORICAL_RANGES")"

# A future SDK is not an active support target until this repository verifies
# it. Reject the easy-to-miss "3.10.5 or newer" routing form while preserving
# historical feature-introduction notes such as "SDK 3.8.1+".
FUTURE_AUTO_SUPPORT_PATTERN='SDK[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+or[[:space:]]+newer'
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
Route this reference to projects using SDK 3.10.5 or newer.
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
require_text "$ROOT_DIR/README.md" "**Active support / last verified**: VRChat SDK $ACTIVE"
require_text "$ROOT_DIR/README.md" 'From v4.0.0 onward, the support policy is latest stable SDK only; the support target moves to a new stable release only after this repository verifies it. A new stable release is not supported automatically.'
require_text "$ROOT_DIR/README.md" 'historical feature-introduction notes'
require_text "$ROOT_DIR/README.md" "not a statement about VRChat's own SDK policy"
forbid_text "$ROOT_DIR/README.md" 'VRChat_SDK-3.7.1--3.10.4'
forbid_text "$ROOT_DIR/README.md" 'SDK coverage (3.7.1 - 3.10.4)'

# All translations carry the same current target and must not advertise the old
# range in their badge or accuracy note.
for path in "${README_FILES[@]}"; do
    require_text "$path" "$ACTIVE"
    require_text "$path" "VRChat_SDK-$ACTIVE-"
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
    require_text "$path" "SDK $ACTIVE"
    require_text "$path" 'historical'
    forbid_regex "$path" '(Supported SDK Versions|SDK Coverage|Covered versions)'
done

for path in \
    "$ROOT_DIR/templates/AGENTS.md" \
    "$ROOT_DIR/templates/CLAUDE.md" \
    "$ROOT_DIR/templates/GEMINI.md"; do
    require_text "$path" 'From v4.0.0 onward'
    require_text "$path" 'not supported or validation targets'
done

# Rules keep their historical labels as labels, never as a coverage claim.
for path in \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md" \
    "$ROOT_DIR/skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md"; do
    forbid_regex "$path" 'SDK Coverage.*3\.7\.1'
done

# Distributed agent templates and maintainer guidance must teach the same
# active-vs-historical boundary.
for path in "$ROOT_DIR/templates/AGENTS.md" "$ROOT_DIR/templates/CLAUDE.md" "$ROOT_DIR/templates/GEMINI.md"; do
    require_text "$path" "active: $ACTIVE"
    require_text "$path" 'historical'
    forbid_regex "$path" 'SDK \(3\.7\.1.{0,8}3\.10\.4\)'
done

require_text "$ROOT_DIR/CONTRIBUTING.md" "**Active and verified target**: SDK $ACTIVE"
require_text "$ROOT_DIR/CONTRIBUTING.md" 'historical migration information only'
require_text "$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/skill-structure.md" "**Active support / last verified**: SDK $ACTIVE"
require_text "$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/update-checklist.md" 'active-versus-historical boundary'
require_text "$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/changelog-sources.md" 'active and verified target'
forbid_regex "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/vrctween.md" 'SDK 3\.10\.4\+|SDK 3\.10\.4 or newer'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/CHEATSHEET.md" '## VRCTween (introduced in SDK 3.10.4)'
forbid_regex "$ROOT_DIR/skills/unity-vrc-udon-sharp/CHEATSHEET.md" '## VRCTween \(SDK 3\.10\.4\+\)|on SDK 3\.10\.4\+'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-utilities.md" 'Solution on the active SDK target'
forbid_regex "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-utilities.md" 'routeable SDK 3\.10\.4\+|on SDK 3\.10\.4\+'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/web-loading-advanced.md" 'Historical migration guidance only: SDK 3.7.1 introduced the available surface'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-networking.md" 'remains the recommended choice on the active SDK target.'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-networking.md" 'valid alternative for small, capacity-limited worlds'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-networking.md" 'valid for single-player preview or debugging'
require_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-networking.md" 'historical migration context, not an active-support cutoff'
forbid_text "$ROOT_DIR/skills/unity-vrc-udon-sharp/references/patterns-networking.md" 'not as active support routes'

# This contract must be part of the required Documentation Smoke Tests job,
# which runs every tests/docs suite through tests/run.sh.
CI="$ROOT_DIR/.github/workflows/ci.yml"
require_text "$CI" 'bash tests/run.sh tests/docs/'

echo "PASS: SDK active support policy contract"
