#!/usr/bin/env python3
"""Keep skill references navigable: tables of contents and heading anchors.

    python3 tests/docs/reference-toc.py            # check, exit 1 on drift
    python3 tests/docs/reference-toc.py --write    # rewrite the tables in place

A reference is read on demand and often only in part. A table of contents at
the top shows every section before the reader chooses where to jump, and it
only helps while it matches the headings. Links that point at a heading
(`file.md#section`) are checked too, because the CI link checker does not
follow fragments.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
MIN_LINES = 100
TOC_HEADING = "## Table of Contents"
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
LINK = re.compile(r"\[[^\]\n]*\]\(([^)\s]+)\)")


def outside_fences(lines):
    """Yield (index, line) for lines that are not inside a fenced code block."""
    fence = None
    for index, line in enumerate(lines):
        match = FENCE.match(line)
        if match:
            marker = match.group(1)[0]
            if fence is None:
                fence = marker
            elif fence == marker:
                fence = None
            continue
        if fence is None:
            yield index, line


def slug(title, seen):
    """GitHub's heading anchor: lower case, punctuation dropped, spaces to hyphens."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", title)
    text = text.replace("`", "").strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    text = text.replace(" ", "-")
    count = seen.get(text, 0)
    seen[text] = count + 1
    return text if count == 0 else f"{text}-{count}"


def heading_slugs(lines):
    """Every heading anchor in the file, in order, with its level and title."""
    seen = {}
    found = []
    for _, line in outside_fences(lines):
        match = re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", line)
        if match:
            title = match.group(2)
            found.append((len(match.group(1)), title, slug(title, seen)))
    return found


def expected_toc(lines):
    entries = [
        f"- [{title}](#{anchor})"
        for level, title, anchor in heading_slugs(lines)
        if level == 2 and f"## {title}" != TOC_HEADING
    ]
    return [TOC_HEADING, ""] + entries + [""]


def toc_span(lines):
    """(start, end) of the existing table of contents block, or None."""
    for index, line in outside_fences(lines):
        if line.rstrip() == TOC_HEADING:
            end = index + 1
            while end < len(lines) and (lines[end].strip() == "" or lines[end].startswith("- [")):
                end += 1
            return index, end
    return None


def with_toc(lines):
    block = expected_toc(lines)
    span = toc_span(lines)
    if span:
        return lines[: span[0]] + block + lines[span[1]:]
    for index, line in outside_fences(lines):
        if line.startswith("## "):
            return lines[:index] + block + lines[index:]
    return lines


def check_tocs(write):
    problems = []
    for path in sorted(SKILLS.glob("*/references/*.md")):
        text = path.read_text(encoding="utf-8")
        lines = text.split("\n")
        if len(lines) < MIN_LINES:
            continue
        updated = with_toc(lines)
        if updated == lines:
            continue
        if write:
            path.write_text("\n".join(updated), encoding="utf-8", newline="\n")
            print(f"updated {path.relative_to(ROOT).as_posix()}")
        else:
            problems.append(f"{path.relative_to(ROOT).as_posix()}: table of contents is missing or stale")
    return problems


def check_anchors():
    problems = []
    anchors = {}

    def anchors_of(path):
        if path not in anchors:
            lines = path.read_text(encoding="utf-8").split("\n")
            anchors[path] = {anchor for _, _, anchor in heading_slugs(lines)}
        return anchors[path]

    for path in sorted(SKILLS.rglob("*.md")):
        lines = path.read_text(encoding="utf-8").split("\n")
        for index, line in outside_fences(lines):
            for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):
                if "#" not in target or re.match(r"^[a-z][a-z0-9+.-]*:", target):
                    continue
                file_part, fragment = target.split("#", 1)
                destination = (path.parent / file_part).resolve() if file_part else path
                if destination.suffix != ".md" or not destination.is_file():
                    continue
                if fragment not in anchors_of(destination):
                    where = f"{path.relative_to(ROOT).as_posix()}:{index + 1}"
                    problems.append(f"{where}: no heading for #{fragment} in {destination.relative_to(ROOT).as_posix()}")
    return problems


def self_test():
    cases = {
        "Layers & Collision": "layers--collision",
        "WorldQualitySettings (SDK 3.10.5)": "worldqualitysettings-sdk-3105",
        "VRC_SceneDescriptor": "vrc_scenedescriptor",
        "Network Events with Parameters (SDK 3.8.1+)": "network-events-with-parameters-sdk-381",
        "`VRCUrl.Empty` is shared": "vrcurlempty-is-shared",
        "1. Immobilize Guard Pattern": "1-immobilize-guard-pattern",
    }
    for title, anchor in cases.items():
        got = slug(title, {})
        if got != anchor:
            raise SystemExit(f"slug({title!r}) = {got!r}, expected {anchor!r}")
    seen = {}
    if [slug("Overview", seen), slug("Overview", seen)] != ["overview", "overview-1"]:
        raise SystemExit("repeated headings must get numbered anchors")
    fenced = ["## Real", "```md", "## Not a heading", "```", "## Also Real"]
    if [title for _, title, _ in heading_slugs(fenced)] != ["Real", "Also Real"]:
        raise SystemExit("headings inside code fences must be ignored")


def main():
    write = "--write" in sys.argv[1:]
    self_test()
    problems = check_tocs(write)
    problems += check_anchors()
    if problems:
        print("\n".join(problems), file=sys.stderr)
        print("\nFix tables of contents with: python3 tests/docs/reference-toc.py --write", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
