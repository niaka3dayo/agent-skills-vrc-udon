#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_DIR="$ROOT_DIR/skills/unity-vrc-udon-sharp"
MIGRATION="$SKILL_DIR/references/sdk-migration.md"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

require_text() {
    local path="$1"
    local expected="$2"
    grep -Fqx -- "$expected" "$path" \
        || fail "$path is missing exact contract text: $expected"
}

require_text "$SKILL_DIR/references/web-loading.md" \
    'On SDK 3.10.4, pass `this` as the receiver argument; the explicit cast is no longer needed.'
require_text "$SKILL_DIR/references/web-loading.md" \
    'The receiver argument is still required for UdonSharp callbacks, including on SDK 3.10.4.'
require_text "$SKILL_DIR/references/web-loading.md" \
    'VRCStringDownloader.LoadUrl(dataUrl, this);'
require_text "$SKILL_DIR/references/web-loading.md" \
    'downloader.DownloadImage(imageUrl, material, this);'
if grep -RFn --include='*.md' -- 'VRC.SDK3.ImageLoading' "$SKILL_DIR" >/dev/null; then
    fail "$SKILL_DIR still teaches the removed VRC.SDK3.ImageLoading namespace"
fi
require_text "$SKILL_DIR/references/web-loading.md" \
    '| `VRCImageDownloader` | Image download (Texture2D) | `VRC.SDK3.Image` |'
require_text "$SKILL_DIR/references/sdk-migration.md" \
    'The cast below is historical migration syntax for SDK 3.10.3 and earlier; do not copy it into an active 3.10.5 example.'
require_text "$SKILL_DIR/SKILL.md" \
    'SDK 3.10.4: `UdonSharpBehaviour` implements `IUdonEventReceiver` directly.'
grep -Fq -- 'https://creators.vrchat.com/releases/release-3-10-4/' "$SKILL_DIR/SKILL.md" \
    || fail "$SKILL_DIR/SKILL.md is missing the official SDK 3.10.4 release-note link"

python3 - "$SKILL_DIR" "$MIGRATION" <<'PY'
from pathlib import Path
import re
import sys

skill_dir = Path(sys.argv[1])
migration = Path(sys.argv[2]).resolve()


def csharp_blocks(path: Path):
    lines = path.read_text(encoding="utf-8").splitlines()
    in_block = False
    language = ""
    block = []
    start = 0
    for number, line in enumerate(lines, 1):
        if line.startswith("```"):
            if not in_block:
                in_block = True
                language = line[3:].strip().lower()
                block = []
                start = number + 1
            else:
                if language in {"csharp", "cs"}:
                    yield start, "\n".join(block)
                in_block = False
                language = ""
        elif in_block:
            block.append(line)


def code_marker_positions(source: str, marker: str):
    """Yield marker positions outside C# comments and string/char literals."""
    index = 0
    state = "code"
    quote = ""
    verbatim = False
    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""
        if state == "line-comment":
            if char == "\n":
                state = "code"
            index += 1
            continue
        if state == "block-comment":
            if char == "*" and next_char == "/":
                state = "code"
                index += 2
            else:
                index += 1
            continue
        if state == "string":
            if verbatim:
                if char == quote:
                    if next_char == quote:
                        index += 2
                    else:
                        state = "code"
                        index += 1
                else:
                    index += 1
            elif char == "\\":
                index += 2
            elif char == quote:
                state = "code"
                index += 1
            else:
                index += 1
            continue
        if char == "/" and next_char == "/":
            state = "line-comment"
            index += 2
            continue
        if char == "/" and next_char == "*":
            state = "block-comment"
            index += 2
            continue
        if char in {"'", '"'}:
            quote = char
            verbatim = char == '"' and (
                (index > 0 and source[index - 1] == "@")
                or source[max(0, index - 2):index] in {"$@", "@$"}
            )
            state = "string"
            index += 1
            continue
        marker_end = index + len(marker)
        if source.startswith(marker, index) and re.match(
            r"\s*\(", source[marker_end:]
        ):
            yield index
            index = marker_end
        else:
            index += 1


def call_arguments(source: str, marker: str):
    """Yield balanced arguments for calls whose expression starts at marker."""
    for marker_start in code_marker_positions(source, marker):
        marker_end = marker_start + len(marker)
        opening = marker_end + re.match(r"\s*\(", source[marker_end:]).end() - 1
        depth = 0
        quote = None
        escaped = False
        line_comment = False
        for index in range(opening, len(source)):
            char = source[index]
            next_char = source[index + 1] if index + 1 < len(source) else ""
            if line_comment:
                if char == "\n":
                    line_comment = False
                continue
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char == "/" and next_char == "/":
                line_comment = True
                continue
            if char in {"'", '"'}:
                quote = char
                continue
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    yield source[opening + 1:index]
                    break

active_files = [
    path for path in skill_dir.rglob("*.md")
    if path.resolve() != migration
]

# A cast is a historical migration aid only. Active guidance must use the
# direct SDK 3.10.4 receiver form.
active_casts = []
cast_pattern = re.compile(r"\(\s*IUdonEventReceiver\s*\)\s*this")
for path in active_files:
    text = path.read_text(encoding="utf-8")
    for match in cast_pattern.finditer(text):
        line_number = text.count("\n", 0, match.start()) + 1
        active_casts.append(f"{path}:{line_number}: {match.group(0)}")
if active_casts:
    raise SystemExit("active IUdonEventReceiver casts found:\n" + "\n".join(active_casts))

migration_text = migration.read_text(encoding="utf-8")
migration_casts = re.findall(r"\(\s*IUdonEventReceiver\s*\)\s*this", migration_text)
if len(migration_casts) != 1:
    raise SystemExit(
        "expected exactly one historical IUdonEventReceiver cast in sdk-migration.md; "
        f"found {len(migration_casts)}"
    )

# Calls in active C# examples must pass the receiver explicitly. API
# declarations are skipped by their typed first argument / receiver type.
missing_receivers = []
for path in active_files:
    for start, block in csharp_blocks(path):
        for marker in (
            "VRCStringDownloader.LoadUrl",
            "DownloadImage",
            "NetworkCalling.GetQueuedEvents",
        ):
            for args in call_arguments(block, marker):
                args_without_comments = re.sub(r"//.*?(?=\n|$)", "", args)
                first_argument = args_without_comments.split(",", 1)[0].strip()
                if re.match(r"(?:IUdonEventReceiver|VRCUrl)\s+\w+\b", first_argument):
                    continue
                if not re.search(r"(?:^|,)\s*this\s*(?:,|$)", args_without_comments):
                    missing_receivers.append(f"{path}:{start}: {marker}({args.strip()})")
        # If a block no longer refers to the interface or NetworkEventTarget,
        # the namespace import is dead and should not be taught to users.
        if "using VRC.Udon.Common.Interfaces;" in block:
            if not re.search(r"\bIUdonEventReceiver\b|\bNetworkEventTarget\b", block):
                raise SystemExit(
                    f"unused VRC.Udon.Common.Interfaces import in {path}:{start}"
                )
if missing_receivers:
    raise SystemExit(
        "receiver argument missing or not direct this in active examples:\n"
        + "\n".join(missing_receivers)
    )

print("PASS: active receiver examples use direct this with an explicit receiver argument")
print("PASS: historical casts remain isolated to sdk-migration.md")
print("PASS: unused IUdonEventReceiver namespace imports are absent from active blocks")
PY
