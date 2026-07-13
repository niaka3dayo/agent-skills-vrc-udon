#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="${DOC_TEST_ROOT:-$SOURCE_ROOT_DIR}"
WORLD_SKILL="$ROOT_DIR/skills/unity-vrc-world-sdk-3/SKILL.md"
UDON_SKILL="$ROOT_DIR/skills/unity-vrc-udon-sharp/SKILL.md"
REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/build-validation.md"
COMPONENTS_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/components.md"
UDON_API_REF="$ROOT_DIR/skills/unity-vrc-udon-sharp/references/api.md"
PERFORMANCE_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/performance.md"
LIGHTING_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/lighting.md"
WORLD_CHEATSHEET="$ROOT_DIR/skills/unity-vrc-world-sdk-3/CHEATSHEET.md"
UPLOAD_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/upload.md"
UDON_MIGRATION_REF="$ROOT_DIR/skills/unity-vrc-udon-sharp/references/sdk-migration.md"

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
    'Fully baked (no realtime shadows)' 'immediate FPS halving' \
    'Shaders: Mobile-only (Standard Lite, Toon Lit)' \
    'SDK versions below 3.9.0 are **deprecated' \
    'Each template compiles without modification'; do
    forbid_text "$WORLD_SKILL" "$obsolete_claim"
done
for path in "$UDON_SKILL" "$UDON_MIGRATION_REF"; do
    forbid_text "$path" 'SDK versions below 3.9.0'
    forbid_text "$path" 'New world uploads are no longer possible'
done
for path in "$ROOT_DIR"/README*.md; do
    forbid_text "$path" 'December 2, 2025'
    forbid_text "$path" '2025年12月2日'
    forbid_text "$path" '2025년 12월 2일'
    forbid_text "$path" '2025 年 12 月 2 日'
done
for obsolete_claim in '| Real-time shadows | Not supported |' \
    '❌ Real-time shadow casting and receiving' \
    '□ No real-time shadow settings on any light' \
    '5–8 MB' '5-8 MB' '200K' 'hard cap' \
    'Mandatory: all lighting must be baked' 'Realtime lights = 0' \
    'No Mixed lights with Shadowmask' 'No custom HLSL shaders' \
    '(often -40-50% render cost)' '(often -30-50% GPU cost)' \
    '(often -30-70% VRAM)' '(often -30-60% draw calls)' \
    '(often -10-20% CPU)'; do
    forbid_text "$PERFORMANCE_REF" "$obsolete_claim"
done
for obsolete_claim in 'Non-Directional (required)' 'No shadow support on Quest' \
    'Lights:     Baked only' 'Quest: Realtime lights = 0'; do
    forbid_text "$LIGHTING_REF" "$obsolete_claim"
done
for obsolete_claim in '| Realtime Lights | 0-1 | 0 |' \
    '| Unity Constraints | ✅ | ❌ |' \
    '| Polygons | 500K-1M | 50K-100K |' \
    '| Materials | No limit | 25 or less |'; do
    forbid_text "$WORLD_CHEATSHEET" "$obsolete_claim"
done
require_text "$WORLD_SKILL" 'profile each target device before keeping realtime lighting or shadows'
require_text "$PERFORMANCE_REF" 'keep only after profiling on the target Android device'
require_text "$PERFORMANCE_REF" '100 MB'
require_text "$PERFORMANCE_REF" 'approximately 250,000 triangles'
require_text "$PERFORMANCE_REF" 'Shaders are not restricted for worlds'
require_text "$PERFORMANCE_REF" 'not an upload limit'
require_text "$LIGHTING_REF" 'target-device profiling'
require_text "$WORLD_CHEATSHEET" 'profile on the target Android device'
require_text "$WORLD_SKILL" 'static checks; import them into the target SDK project'
require_text "$WORLD_SKILL" 'supported devices, representative scenes, and expected player count'
require_text "$PERFORMANCE_REF" 'Project-defined criteria'
require_text "$WORLD_CHEATSHEET" 'Project-defined'
require_text "$UPLOAD_REF" 'Project-defined frame-time or frame-rate target met'

# Keep the translated README guidance neutral: it tells maintainers to check
# the currently supported SDK without hard-coding a historical cutoff.
require_text "$ROOT_DIR/README.md" \
    'Before publishing, confirm that the project uses an SDK version currently supported by VRChat.'
require_text "$ROOT_DIR/README.ja.md" \
    '公開前に、VRChatが現在サポートしているSDKバージョンをプロジェクトで使用していることを確認してください。'
require_text "$ROOT_DIR/README.zh-CN.md" \
    '发布前，请确认项目使用的是 VRChat 当前支持的 SDK 版本。'
require_text "$ROOT_DIR/README.zh-TW.md" \
    '發佈前，請確認專案使用的是 VRChat 目前支援的 SDK 版本。'
require_text "$ROOT_DIR/README.ko.md" \
    '게시하기 전에 프로젝트에서 VRChat이 현재 지원하는 SDK 버전을 사용하고 있는지 확인하세요.'

python3 - "$ROOT_DIR" <<'PY'
import bisect
import re
import sys
import unicodedata
from pathlib import Path

root = Path(sys.argv[1])
errors = []


def folded(text):
    return unicodedata.normalize("NFKC", text).replace("\r\n", "\n").casefold()


def pieces(value, split_semicolons=True):
    value = re.sub(r"\s+", " ", value).strip()
    separator = (
        r"(?<=[.!?])\s+|(?<=[。！？])\s*"
        r"|,\s*(?=(?:while|whereas|but|however)\b)"
    )
    if split_semicolons:
        separator += r"|[;；]\s*"
    return [part.strip() for part in re.split(
        separator, value
    ) if part.strip()]


def units(text, split_semicolons=True):
    list_marker = re.compile(r"^\s*(?:[-*+]\s|\d+[.)]\s)")
    atx_heading = re.compile(r"^\s*#{1,6}\s")
    setext_or_rule = re.compile(r"^\s*(?:=+|-+|\*\s*\*\s*\*.*)\s*$")
    quote_marker = re.compile(r"^(?:(?: {0,3})> ?)+")
    fence_marker = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
    block = []
    block_kind = None
    block_quote_depth = 0
    fenced_with = None
    indented_code = False

    def flush():
        nonlocal block, block_kind, block_quote_depth
        result = pieces(" ".join(block), split_semicolons)
        block = []
        block_kind = None
        block_quote_depth = 0
        return result

    records = []
    for raw_line in folded(text).splitlines():
        quote = quote_marker.match(raw_line)
        quote_text = quote.group(0) if quote else ""
        quote_depth = quote_text.count(">")
        line = raw_line[len(quote_text):] if quote else raw_line
        records.append((line, quote_depth))

    table_rows = set()
    for index, (line, quote_depth) in enumerate(records):
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or not all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if index == 0 or "|" not in records[index - 1][0] or records[index - 1][1] != quote_depth:
            continue
        table_rows.update((index - 1, index))
        following = index + 1
        while (
            following < len(records)
            and records[following][1] == quote_depth
            and records[following][0].strip()
            and "|" in records[following][0]
        ):
            table_rows.add(following)
            following += 1

    for index, (line, quote_depth) in enumerate(records + [("", 0)]):
        fence = fence_marker.match(line)

        if fenced_with is not None:
            if fence:
                marker = fence.group(1)
                remainder = fence.group(2)
                if (
                    marker[0] == fenced_with[0]
                    and len(marker) >= fenced_with[1]
                    and not remainder.strip()
                ):
                    if fenced_with[2]:
                        yield from flush()
                    fenced_with = None
                    continue
            if not fenced_with[2]:
                continue
            fence = None
        if fence:
            marker_kind = fence.group(1)[0]
            yield from flush()
            info_string = fence.group(2).strip()
            semantic = info_string in {"", "text", "markdown", "md"}
            fenced_with = (marker_kind, len(fence.group(1)), semantic)
            continue
        if indented_code:
            if not line.strip() or re.match(r"^(?: {4}|\t)", line):
                continue
            indented_code = False
        if block_kind != "list" and re.match(r"^(?: {4}|\t)", line):
            yield from flush()
            indented_code = True
            continue
        if not line.strip():
            yield from flush()
            continue
        if setext_or_rule.match(line):
            yield from flush()
            continue
        if atx_heading.match(line):
            yield from flush()
            yield from pieces(line, split_semicolons)
            continue
        if index in table_rows:
            yield from flush()
            yield from pieces(line, split_semicolons)
            continue
        if list_marker.match(line):
            yield from flush()
            block = [line]
            block_kind = "list"
            block_quote_depth = quote_depth
            continue

        if block_kind is None:
            block_kind = "quote" if quote_depth else "plain"
            block_quote_depth = quote_depth
        elif quote_depth != block_quote_depth and not (
            block_kind in {"quote", "list"} and quote_depth == 0
        ):
            yield from flush()
            block_kind = "quote" if quote_depth else "plain"
            block_quote_depth = quote_depth
        block.append(line)


SDK_LABEL = (
    r"(?:(?<![A-Za-z0-9_])(?:vrchat\s*)?sdk(?![A-Za-z0-9_])|"
    r"(?<![A-Za-z0-9_])sdk(?:バージョン|버전|版本))"
)
VERSION = r"\d+\.\d+\.\d+"
SDK_TOKEN = re.compile(SDK_LABEL, re.IGNORECASE)
# A sentence-ending full stop is punctuation, not a fourth version component.
VERSION_TOKEN = re.compile(rf"(?<![\d.]){VERSION}(?!\d)(?!\.\d)", re.IGNORECASE)
SDK_THRESHOLD = re.compile(
    r"(?:\+|\b(?:or|and)\s+(?:a\s+)?(?:newer|later|higher|above|up)\b"
    r"|\b(?:newer|later|higher|above|older|earlier|lower)\s+than\b"
    r"|\b(?:below|under|older|earlier|prior\s+to|before|at\s+least|minimum)\b"
    r"|以降|以上|以前|以下|未満|より(?:新しい|古い)"
    r"|或更高|或更新|或以上|及更高|及更新|及以上|更早|更旧|低于|小于|之前"
    r"|이상|이후|이전|이하|미만|보다\s*(?:높|낮)|더\s*(?:높|낮))", re.I
)
ACTION = re.compile(
    r"(?:\b(?:publish(?:ing|ed|es)?|upload(?:ing|ed|s)?)\b"
    r"|公開|発行|アップロード|发布|發布|發佈|上传|上傳|게시|업로드|퍼블리시|발행)", re.I
)
REQUIRED = re.compile(
    r"(?:\b(?:require(?:s|d)?|need(?:s|ed)?|must|mandatory|necessary|minimum|at\s+least)\b"
    r"|必要|必須|需要|必须|要求|필요|필수|요구|해야)", re.I
)
NEGATIVE = re.compile(
    r"(?:\b(?:cannot|can\s*not|can't|unable\s+to|no\s+longer|not\s+possible|"
    r"unavailable|unsupported|prohibited|blocked|deprecated)\b"
    r"|\b(?:does|do|is|are)\s+not\s+(?:support|allow|possible|available)\b"
    r"|できません|できない|不可|非対応|非推奨|サポートされ(?:ていません|ません)"
    r"|无法|無法|不能|不可|不支持|不支援|不再|弃用|棄用"
    r"|지원되지|지원하지\s*않|게시할\s*수\s*없|업로드할\s*수\s*없|"
    r"사용할\s*수\s*없|비지원|더\s*이상|게시\s*불가|업로드\s*불가)", re.I
)


def nearest_match(matches, starts, position):
    if not matches:
        return None
    index = bisect.bisect_left(starts, position)
    candidates = []
    if index < len(matches):
        candidates.append(matches[index])
    if index:
        candidates.append(matches[index - 1])
    return min(candidates, key=lambda match: abs(match.start() - position))


def within(matches, starts, position, limit):
    left = bisect.bisect_left(starts, position - limit)
    right = bisect.bisect_right(starts, position + limit)
    return matches[left:right]


def required_relation_is_negated(unit, relation):
    prefix = unit[max(0, relation.start() - 36):relation.start()]
    prefix = re.split(r"[,;；]|\bbut\b|\bhowever\b", prefix)[-1]
    return bool(re.search(
        r"\b(?:not|never)\s*$|\b(?:does?|did|is|are|was|were|must|should|"
        r"may|can|could|would)\s+not\s*$",
        prefix,
    ))


def sdk_cutoff_clause(unit):
    sdk_labels = list(SDK_TOKEN.finditer(unit))
    versions = list(VERSION_TOKEN.finditer(unit))
    thresholds = list(SDK_THRESHOLD.finditer(unit))
    required_relations = list(REQUIRED.finditer(unit))
    negative_relations = list(NEGATIVE.finditer(unit))
    relations = sorted(
        [(match, "required") for match in required_relations]
        + [(match, "negative") for match in negative_relations],
        key=lambda item: item[0].start(),
    )
    actions = list(ACTION.finditer(unit))
    label_starts = [match.start() for match in sdk_labels]
    version_starts = [match.start() for match in versions]
    threshold_starts = [match.start() for match in thresholds]
    action_starts = [match.start() for match in actions]
    relation_matches = [item[0] for item in relations]
    relation_starts = [match.start() for match in relation_matches]
    relation_kinds = {id(match): kind for match, kind in relations}

    for version in versions:
        label = nearest_match(sdk_labels, label_starts, version.start())
        threshold = nearest_match(thresholds, threshold_starts, version.start())
        if label is None or threshold is None:
            continue
        if abs(label.start() - version.start()) > 128:
            continue
        if nearest_match(versions, version_starts, label.start()) is not version:
            continue
        if abs(threshold.start() - version.start()) > 48:
            continue
        if nearest_match(versions, version_starts, threshold.start()) is not version:
            continue

        candidates = within(relation_matches, relation_starts, version.start(), 176)
        for relation in candidates:
            relation_kind = relation_kinds[id(relation)]
            if relation_kind == "required" and required_relation_is_negated(unit, relation):
                continue
            action = nearest_match(actions, action_starts, relation.start())
            if action is None or abs(action.start() - relation.start()) > 104:
                continue
            ordered = sorted(
                ((version.start(), "version"),
                 (relation.start(), "relation"),
                 (action.start(), "action"))
            )
            if ordered[1][1] == "action":
                if relation_kind != "negative":
                    prefix = unit[max(action.end(), relation.start() - 24):relation.start()]
                    adjective = re.fullmatch(
                        r"\s*(?:is|are|was|were)\s+",
                        prefix,
                    ) and re.fullmatch(
                        r"mandatory|required|necessary|必須|必要|必须|需要|필수|필요",
                        relation.group(0),
                        re.I,
                    )
                    if not adjective:
                        continue
            if max(version.start(), relation.start(), action.start()) - min(
                version.start(), relation.start(), action.start()
            ) > 192:
                continue
            return True
    return False


SDK_COREFERENCE = re.compile(r"^\s*(?:it|this\s+sdk)\b", re.I)


def sdk_threshold_context(clause):
    return bool(
        SDK_TOKEN.search(clause)
        and VERSION_TOKEN.search(clause)
        and SDK_THRESHOLD.search(clause)
    )


def sdk_cutoff(unit):
    previous_context = None
    for clause in pieces(unit, split_semicolons=True):
        if sdk_cutoff_clause(clause):
            return True
        coreference = SDK_COREFERENCE.match(clause)
        if previous_context is not None and coreference:
            carried = previous_context + " " + clause[coreference.end():]
            if sdk_cutoff_clause(carried):
                return True
        previous_context = clause if sdk_threshold_context(clause) else None
    return False


readme_paths = sorted(root.glob("README*.md"))
for path in readme_paths:
    for unit in units(path.read_text(encoding="utf-8"), split_semicolons=False):
        if sdk_cutoff(unit):
            errors.append(f"SDK cutoff: {path.name}: {unit[:180]}")


NUMERIC_FPS = (
    r"(?:\b\d+(?:\.\d+)?\s*\+?\s*fps\b|\b\d+(?:\.\d+)?\s*\+?\s*"
    r"frames?\s*(?:per\s*second|/\s*s)\b|\bfps\s*(?:target\s*(?:of|=|:)\s*)?"
    r"\d+(?:\.\d+)?\s*\+?)"
)
PROJECT_TARGET = (
    r"\bproject\s*-\s*defined\b[^.!?;]{0,70}?\btarget\b[^.!?;]{0,35}"
    r"(?:\bfps\b|\bframe\s*-?\s*(?:rate|time)\b)|\bproject\s*-\s*defined\b"
    r"[^.!?;]{0,70}(?:\bfps\b|\bframe\s*-?\s*(?:rate|time)\b)[^.!?;]{0,35}?\btarget\b"
)
NAMED_FPS_TARGET = r"\bfps\s*-?\s*target\b"
FRAME_MEASURE = r"(?:\bfps\b|\bframe\s*-?\s*(?:rate|time)\b)"
MINIMUM_FRAME_TARGET = (
    rf"(?:\bminimum\s+requirements?\b[^.!?;]{{0,60}}{FRAME_MEASURE}"
    rf"|{FRAME_MEASURE}[^.!?;]{{0,60}}\bminimum\s+requirements?\b"
    rf"|\bminimum\s+{FRAME_MEASURE}\s+requirements?\b)"
)
TARGET_SOURCE = rf"(?:{NUMERIC_FPS}|{PROJECT_TARGET}|{NAMED_FPS_TARGET}|{MINIMUM_FRAME_TARGET})"
FPS_TARGET = re.compile(TARGET_SOURCE, re.I)
UPLOAD = r"(?:\b(?:upload|publish)(?:ing|ed|s|es)?\b|上传|上傳|公開|發布|發佈|게시|업로드)"
OBLIGATION = r"(?:\b(?:require(?:s|d)?|need(?:s|ed)?|must|mandatory|required|necessary)\b|必須|必须|需要|必要|要求|필수|필요|요구)"
TARGET_COPULA_OBLIGATION = re.compile(
    rf"{TARGET_SOURCE}(?:\s+target)?\s+"
    rf"(?:under\s+minimum\s+requirements?\s+)?(?:is|are)\s+"
    rf"(?:not\s+optional\s+(?:and|but)\s+(?:is|are)\s+)?"
    rf"(?:an?\s+)?{OBLIGATION}[^.!?;]{{0,36}}(?:for\s+|to\s+)?{UPLOAD}", re.I
)
TARGET_UPLOAD_GATE = re.compile(
    rf"{TARGET_SOURCE}(?:\s+target)?\s+"
    rf"(?:under\s+minimum\s+requirements?\s+)?(?:is|are)\s+(?:an?\s+)?"
    rf"{UPLOAD}\s+(?:gate|requirement|threshold|limit)s?", re.I
)
TARGET_DIRECT_BLOCK = re.compile(
    rf"{TARGET_SOURCE}(?:\s+target)?[^.!?;]{{0,28}}"
    rf"(?:cannot|can\s*not|can't|must\s+not|may\s+not)\s+"
    rf"(?:be\s+)?(?:uploaded|published|upload|publish)\b", re.I
)
UPLOAD_REQUIRES_TARGET = re.compile(
    rf"{UPLOAD}[^.!?;]{{0,28}}(?:requires?|needs?|must\s+(?:meet|reach))"
    rf"[^.!?;]{{0,48}}{TARGET_SOURCE}", re.I
)
UPLOAD_ONLY_TARGET = re.compile(
    rf"{UPLOAD}[^.!?;]{{0,28}}(?:"
    rf"(?:is|are|was|were)?\s*(?:allowed|permitted)\s+only|"
    rf"(?:is|are|was|were)?\s*only\s+(?:allowed|permitted))"
    rf"[^.!?;]{{0,36}}{TARGET_SOURCE}", re.I
)
UPLOAD_BELOW_BLOCK = re.compile(
    rf"{UPLOAD}[^.!?;]{{0,24}}(?:cannot|can\s*not|can't)\s+proceed\s+"
    rf"(?:below|under)\s+{TARGET_SOURCE}", re.I
)
COREFERENCE = re.compile(
    r"^\s*(?:it|that|this\s+target|such\s+(?:a\s+)?target|the\s+target)\b", re.I
)


def direct_fps_upload_gate(clause):
    return any(pattern.search(clause) for pattern in (
        TARGET_COPULA_OBLIGATION,
        TARGET_UPLOAD_GATE,
        TARGET_DIRECT_BLOCK,
        UPLOAD_REQUIRES_TARGET,
        UPLOAD_ONLY_TARGET,
        UPLOAD_BELOW_BLOCK,
    ))


def fps_upload_gate(unit):
    previous_has_target = False
    clauses = []
    for sentence in pieces(unit, split_semicolons=True):
        clauses.extend(
            part.strip()
            for part in re.split(r"\bbut\b", sentence)
            if part.strip()
        )
    for clause in clauses:
        has_target = bool(FPS_TARGET.search(clause))
        if has_target and direct_fps_upload_gate(clause):
            return True
        if previous_has_target:
            coreference = COREFERENCE.match(clause)
            if coreference:
                carried = "fps target" + clause[coreference.end():]
                if direct_fps_upload_gate(carried):
                    return True
            elif re.match(r"^\s*(?:is|are)\b", clause):
                if direct_fps_upload_gate("fps target " + clause):
                    return True
        previous_has_target = has_target
    return False


performance_paths = readme_paths + [
    root / "skills/unity-vrc-world-sdk-3/SKILL.md",
    root / "skills/unity-vrc-world-sdk-3/CHEATSHEET.md",
    root / "skills/unity-vrc-world-sdk-3/references/performance.md",
    root / "skills/unity-vrc-world-sdk-3/references/upload.md",
]
for path in performance_paths:
    for unit in units(path.read_text(encoding="utf-8"), split_semicolons=False):
        if fps_upload_gate(unit):
            errors.append(f"FPS upload obligation: {path.relative_to(root)}: {unit[:180]}")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)
print("PASS: semantic SDK cutoff and FPS upload-gate checks")
PY

run_mutation_checks() (
    set -euo pipefail
    local fixture_root="" fixture_parent fixture_prefix
    local mutation_exit mutation_output mutation_failures=0
    fixture_parent="${TMPDIR:-/tmp}"
    fixture_prefix="$fixture_parent/build-validation-mutations.${BASHPID:-$$}"
    cleanup_fixture() {
        if [[ -n "${fixture_root:-}" ]]; then
            rm -rf -- "$fixture_root"
        fi
        rm -rf -- "$fixture_prefix".*
    }
    trap cleanup_fixture EXIT
    trap 'cleanup_fixture; trap - EXIT; exit 129' HUP
    trap 'cleanup_fixture; trap - EXIT; exit 130' INT
    trap 'cleanup_fixture; trap - EXIT; exit 143' TERM
    fixture_root="$(mktemp -d "$fixture_prefix.XXXXXX")"
    set +e

    reset_fixture() {
        rm -rf -- "$fixture_root"
        mkdir -p -- "$fixture_root"
        cp -a -- "$SOURCE_ROOT_DIR"/README*.md "$fixture_root/"
        cp -a -- "$SOURCE_ROOT_DIR/skills" "$fixture_root/"
    }
    append_mutation() {
        python3 - "$1" "$2" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").rstrip("\n") + "\n\n" + sys.argv[2] + "\n", encoding="utf-8")
PY
    }
    run_case() {
        local expectation="$1" label="$2" path="$3" text="$4" diagnostic="${5:-}"
        local relative_path expected_error
        if ! reset_fixture || ! append_mutation "$path" "$text"; then
            echo "ERROR: could not prepare mutation $label" >&2
            mutation_failures=$((mutation_failures + 1))
            return 0
        fi
        if mutation_output="$(DOC_TEST_ROOT="$fixture_root" DOC_TEST_RUN_MUTATIONS=0 bash "$SCRIPT_PATH" 2>&1)"; then
            mutation_exit=0
        else
            mutation_exit=$?
        fi
        relative_path="${path#"$fixture_root"/}"
        expected_error="ERROR: $diagnostic: $relative_path:"
        if [[ "$expectation" == reject && "$mutation_exit" -eq 0 ]]; then
            echo "ERROR: mutation $label was accepted (expected $diagnostic)" >&2
            mutation_failures=$((mutation_failures + 1))
        elif [[ "$expectation" == reject && ! "$mutation_output" == *"$expected_error"* ]]; then
            echo "ERROR: mutation $label rejected without diagnostic: $expected_error" >&2
            printf '%s\n' "$mutation_output" | tail -n 5 >&2
            mutation_failures=$((mutation_failures + 1))
        elif [[ "$expectation" == accept && "$mutation_exit" -ne 0 ]]; then
            echo "ERROR: valid mutation $label was rejected (exit $mutation_exit)" >&2
            printf '%s\n' "$mutation_output" | tail -n 5 >&2
            mutation_failures=$((mutation_failures + 1))
        else
            echo "PASS: mutation $label ${expectation}ed (exit $mutation_exit${diagnostic:+; diagnostic: $diagnostic})"
        fi
    }

    SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
    sdk_cases=(
        'README.md|English positive SDK requirement|Publishing requires SDK 3.9.0 or newer.|SDK cutoff'
        'README.ja.md|Japanese positive SDK requirement|公開にはSDK 3.9.0以降が必要です。|SDK cutoff'
        'README.zh-CN.md|Simplified Chinese positive SDK requirement|发布需要 SDK 3.9.0 或更高版本。|SDK cutoff'
        'README.zh-TW.md|Traditional Chinese positive SDK requirement|發佈需要 SDK 3.9.0 或更新版本。|SDK cutoff'
        'README.ko.md|Korean positive SDK requirement|게시하려면 SDK 3.9.0 이상이 필요합니다.|SDK cutoff'
        'README.md|English negative SDK cutoff|SDK 3.9.0 and older cannot be uploaded.|SDK cutoff'
        'README.md|English reverse-order SDK requirement|SDK 3.9.0 or newer is required for publishing.|SDK cutoff'
        'README.md|English separated SDK label reverse order|Projects using version 3.9.0 or earlier cannot be published with the VRChat Worlds SDK.|SDK cutoff'
        'README.md|English line-wrapped SDK requirement|Publishing requires\nSDK 3.9.0 or newer.|SDK cutoff'
        'README.md|English blockquote-wrapped SDK requirement|> Publishing requires\n> SDK 3.9.0 or newer.|SDK cutoff'
        'README.md|English list-wrapped SDK requirement|- Publishing requires\n  SDK 3.9.0 or newer.|SDK cutoff'
        'README.md|English mandatory SDK requirement|SDK 3.9.0 or newer is mandatory for publishing.|SDK cutoff'
        'README.md|English standalone newer-than SDK requirement|Publishing requires an SDK newer than 3.9.0.|SDK cutoff'
        'README.md|English action-middle mandatory SDK requirement|Using SDK 3.9.0 or newer for publishing is mandatory.|SDK cutoff'
        'README.ja.md|Japanese action-middle negative SDK cutoff|SDK 3.9.0以前はアップロードできません。|SDK cutoff'
        'README.ko.md|Korean action-middle negative SDK cutoff|SDK 3.9.0 이전은 업로드할 수 없습니다.|SDK cutoff'
        'README.md|English lazy-list SDK requirement|- Publishing requires\nSDK 3.9.0 or newer.|SDK cutoff'
        'README.md|English lazy-blockquote SDK requirement|> Publishing requires\nSDK 3.9.0 or newer.|SDK cutoff'
        'README.md|English indented pseudo-fence SDK requirement|    ```text\nPublishing requires SDK 3.9.0 or newer.\n    ```|SDK cutoff'
        'README.md|English coreferenced SDK requirement|VRChat SDK 3.9.0 or newer; it is mandatory for publishing.|SDK cutoff'
        'README.md|English text-fenced SDK cutoff|```text\nPublishing requires SDK 3.9.0 or newer.\n```|SDK cutoff'
        'README.md|English markdown-fenced SDK cutoff|```markdown\nPublishing requires SDK 3.9.0 or newer.\n```|SDK cutoff'
        'README.md|English md-fenced SDK cutoff|```md\nPublishing requires SDK 3.9.0 or newer.\n```|SDK cutoff'
        'README.md|English unspecified-fenced SDK cutoff|```\nPublishing requires SDK 3.9.0 or newer.\n```|SDK cutoff'
        'README.md|English blockquote text-fenced SDK cutoff|> ```text\n> Publishing requires SDK 3.9.0 or newer.\n> ```|SDK cutoff'
        'README.md|English long text-fenced SDK cutoff|````text\n```text\nPublishing requires SDK 3.9.0 or newer.\n```\n````|SDK cutoff'
    )
    for spec in "${sdk_cases[@]}"; do
        IFS='|' read -r relative label text diagnostic <<< "$spec"
        printf -v text '%b' "$text"
        run_case reject "$label" "$fixture_root/$relative" "$text" "$diagnostic"
    done
    fps_reject_cases=(
        'Uploading requires project-defined FPS|Uploading requires meeting the project-defined target FPS.'
        'Project-defined mandatory upload gate|Project-defined frame-rate target is mandatory for uploading.'
        'Unrelated negation does not cancel mandatory gate|The target is not a fixed limit; the project-defined frame-rate target is mandatory for uploading.'
        'Not optional does not cancel mandatory gate|Project-defined frame-rate target is not optional; it is a mandatory upload gate.'
        'Same-clause not optional does not cancel mandatory gate|The FPS Target is not optional and is mandatory for uploading.'
        'Numeric 45 FPS mandatory upload gate|45+ FPS is mandatory for uploading.'
        'Numeric 60 FPS mandatory upload gate|Uploading requires at least 60+ FPS.'
        'Numeric 72 FPS upload threshold|72 FPS is an upload threshold.'
        'Named FPS Target upload gate|The FPS Target is mandatory for uploading.'
        'Minimum Requirements frame-rate upload gate|Minimum Requirements for frame rate are mandatory for uploading.'
        'Named target under minimum requirements|The FPS Target under Minimum Requirements is an upload gate.'
        'Below numeric FPS cannot upload|Worlds below 45+ FPS cannot be uploaded.'
        'Upload allowed only at numeric FPS|Uploads are allowed only at 45+ FPS.'
        'Upload only allowed at numeric FPS|Uploads are only allowed at 45 FPS.'
        'Upload cannot proceed below numeric FPS|Uploads cannot proceed below 45 FPS.'
        'Mixed local FPS obligation|The FPS Target is not mandatory for profiling but is mandatory for uploading.'
        'Text-fenced numeric FPS upload gate|```text\n45+ FPS is mandatory for uploading.\n```'
    )
    for spec in "${fps_reject_cases[@]}"; do
        IFS='|' read -r label text <<< "$spec"
        printf -v text '%b' "$text"
        run_case reject "$label" "$fixture_root/skills/unity-vrc-world-sdk-3/references/performance.md" \
            "$text" 'FPS upload obligation'
    done
    accept_cases=(
        'FPS guidance is not an upload gate|skills/unity-vrc-world-sdk-3/references/performance.md|45+ FPS is guidance; the upload gate does not apply.'
        'Local negation exempts an upload gate|skills/unity-vrc-world-sdk-3/references/performance.md|45+ FPS is guidance, not an upload gate.'
        'Negated FPS guidance in text fence remains accepted|skills/unity-vrc-world-sdk-3/references/performance.md|```text\n45+ FPS is guidance; the upload gate does not apply.\n```'
        'Current SDK deprecated API limitation|README.md|VRChat SDK 3.10.4 does not support a deprecated API.'
        'Current SDK support plus legacy upload note|README.md|SDK 3.10.4 is currently supported for publishing; legacy SDK upload restrictions are deprecated.'
        'SDK and publishing split across paragraphs|README.md|VRChat SDK 3.10.4 or newer adds the current API.\n\nPublishing requires a separate checklist.'
        'Bash code-fenced SDK cutoff remains ignored|README.md|```bash\nPublishing requires SDK 3.9.0 or newer.\n```'
        'Shell code-fenced SDK cutoff remains ignored|README.md|```sh\nPublishing requires SDK 3.9.0 or newer.\n```'
        'CSharp code-fenced SDK cutoff remains ignored|README.md|```csharp\nPublishing requires SDK 3.9.0 or newer.\n```'
        'CSharp alias code-fenced SDK cutoff remains ignored|README.md|```cs\nPublishing requires SDK 3.9.0 or newer.\n```'
        'PowerShell code-fenced SDK cutoff remains ignored|README.md|```powershell\nPublishing requires SDK 3.9.0 or newer.\n```'
        'Other code-fenced SDK cutoff remains ignored|README.md|```python\nPublishing requires SDK 3.9.0 or newer.\n```'
        'SDK label and publishing before unrelated checklist requirement|README.md|VRChat SDK 3.9.0 or newer publishing requires a separate checklist.'
        'SDK checklist requirement before unrelated upload mention|README.md|VRChat SDK 3.9.0 or newer publishing requires a separate checklist before uploading.'
        'Current SDK publishing support plus versioned legacy API|README.md|VRChat SDK 3.10.4 is currently supported for publishing, while version 3.9.0 or earlier uses a deprecated API.'
        'Negated mandatory SDK cutoff|README.md|SDK 3.9.0 or newer is not mandatory for publishing.'
        'Negated required SDK cutoff|README.md|SDK 3.9.0 or newer is not required for publishing.'
        'Unity version owns publishing requirement|README.md|Publishing with VRChat SDK 3.10.4 requires Unity 2022.3.22 or newer.'
        'Negated coreferenced SDK requirement|README.md|VRChat SDK 3.9.0 or newer; it is not mandatory for publishing.'
        'Setext heading separates SDK and publishing|README.md|VRChat SDK 3.9.0 or newer\n===\nPublishing requires a separate checklist.'
        'Pipe-less GFM table rows remain separate|README.md|SDK guidance | Status\n--- | ---\nVRChat SDK 3.9.0 or newer | Reference only\nPublishing requires a separate checklist | Current process'
        'Blockquote blank paragraph separates SDK and publishing|README.md|> VRChat SDK 3.9.0 or newer\n>\n> Publishing requires a separate checklist.'
        'PowerShell code-fenced FPS gate remains ignored|skills/unity-vrc-world-sdk-3/references/performance.md|```powershell\n45+ FPS is mandatory for uploading.\n```'
        'Numeric 45 FPS guidance|skills/unity-vrc-world-sdk-3/references/performance.md|45+ FPS is guidance, not an upload limit.'
        'Numeric 60 FPS guidance|skills/unity-vrc-world-sdk-3/references/performance.md|60+ FPS is a profiling example, not an upload requirement.'
        'Numeric 72 FPS guidance|skills/unity-vrc-world-sdk-3/references/performance.md|72 FPS may be a project target, not an upload gate.'
        'Named FPS Target guidance|skills/unity-vrc-world-sdk-3/references/performance.md|FPS Target is a project label, not an upload limit.'
        'Minimum Requirements guidance|skills/unity-vrc-world-sdk-3/references/performance.md|Minimum Requirements for frame rate are guidance, not upload limits.'
        'Named FPS Target explicitly not mandatory|skills/unity-vrc-world-sdk-3/references/performance.md|The FPS Target is not mandatory for uploading.'
        'Coreferenced target explicitly not mandatory|skills/unity-vrc-world-sdk-3/references/performance.md|Project-defined frame-rate target is guidance; it is not a mandatory upload gate.'
        'FPS guidance and unrelated SDK validation|skills/unity-vrc-world-sdk-3/references/performance.md|45+ FPS is guidance, not an upload limit; uploading requires passing SDK validation.'
        'FPS validation is not upload prohibition|skills/unity-vrc-world-sdk-3/references/performance.md|The 45 FPS target cannot be validated before uploading.'
        'FPS guidance with unrelated validation|skills/unity-vrc-world-sdk-3/references/performance.md|45 FPS is guidance and SDK validation is required for uploading.'
        'FPS guidance with unrelated validation after semicolon|skills/unity-vrc-world-sdk-3/references/performance.md|45 FPS is guidance; this SDK validation is required for uploading.'
        'Long outer code fence remains ignored|README.md|````bash\n```text\nPublishing requires SDK 3.9.0 or newer.\n```\n````'
        'Indented code block is ignored|README.md|    Publishing requires SDK 3.9.0 or newer.'
    )
    for spec in "${accept_cases[@]}"; do
        IFS='|' read -r label relative text <<< "$spec"
        printf -v text '%b' "$text"
        run_case accept "$label" "$fixture_root/$relative" "$text"
    done

    run_case reject 'English inline-pipe wrapped SDK requirement' "$fixture_root/README.md" \
        $'Publishing requires VRChat SDK 3.9.0\nor newer for the `PC | Android` upload workflow.' 'SDK cutoff'

    set -e
    if ! cleanup_fixture; then
        echo "ERROR: could not remove mutation fixture" >&2
        mutation_failures=$((mutation_failures + 1))
    elif [[ -e "$fixture_root" ]]; then
        echo "ERROR: mutation fixture was not cleaned up" >&2
        mutation_failures=$((mutation_failures + 1))
    else
        echo "PASS: mutation fixture cleaned up"
    fi
    trap - EXIT HUP INT TERM
    if [[ "$mutation_failures" -ne 0 ]]; then
        echo "ERROR: $mutation_failures documentation mutation checks failed" >&2
        return 1
    fi
)

if [[ "${DOC_TEST_RUN_MUTATIONS:-1}" == 1 ]]; then
    run_mutation_checks
fi

# World upload content warnings must match VRChat's current five-label contract.
extract_content_warning_section() {
    awk '
        /^## Content Warnings[[:space:]]*$/ { section_level = 2; in_section = 1; next }
        /^### Content Warnings[[:space:]]*$/ { section_level = 3; in_section = 1; next }
        in_section && section_level == 2 && /^## / { exit }
        in_section && section_level == 3 && /^### / { exit }
        in_section { print }
    ' "$1"
}

EXPECTED_CONTENT_WARNING_LABELS=$'□ Sexually Suggestive\n□ Adult Language and Themes\n□ Graphic Violence\n□ Excessive Gore\n□ Extreme Horror'
for content_warning_doc in "$WORLD_CHEATSHEET" "$UPLOAD_REF"; do
    content_warning_section="$(extract_content_warning_section "$content_warning_doc")"
    actual_content_warning_labels="$(printf '%s\n' "$content_warning_section" | grep -E '^□ ' || true)"
    if [[ "$actual_content_warning_labels" != "$EXPECTED_CONTENT_WARNING_LABELS" ]]; then
        echo "ERROR: $content_warning_doc has a non-canonical Content Warnings label set" >&2
        printf 'expected:\n%s\nactual:\n%s\n' "$EXPECTED_CONTENT_WARNING_LABELS" "$actual_content_warning_labels" >&2
        exit 1
    fi
done

require_text "$WORLD_SKILL" '#### Key Properties'
forbid_text "$WORLD_SKILL" '#### All Properties'

echo "PASS: build-validation reference coverage smoke test"
