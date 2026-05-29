#!/usr/bin/env python3
"""SDK coverage diff — stage 2 of the binary-backed discovery audit.

Diffs the per-component distinctive-method census (census.json) against what the
skill text currently mentions, producing two tiers:

  Tier 1 — skill already covers the component, but binary methods are unmentioned
           (the "already here but incomplete" gap, e.g. VRCObjectPool/Shuffle).
  Tier 2 — components the skill does not mention at all.

This is "binary minus skill". It is NOT "binary minus official docs" — the
official-docs check is the editorial gate (stage performed by hand, see
../README.md and ../sdk-coverage-ledger.md). Most Tier-1 entries are
doc-covered and get skipped.

Usage:
    python diff.py [--census census.json] [--skill-dir PATH] [--out diff.json]
"""
import argparse
import glob
import json
import os
import re

DEFAULT_SKILL_DIR = "skills/unity-vrc-udon-sharp"
# Generated output goes here — covered by .claude/audit/.gitignore (never committed).
DEFAULT_CENSUS = ".claude/audit/.generated/census.json"
DEFAULT_OUT = ".claude/audit/.generated/diff.json"

# Namespace segments stripped (longest-first) to recover a component's short name.
NS = sorted([
    "VRCSDK3", "VRCSDKBase", "VRCSDK", "VRCDynamics", "VRCEconomy",
    "ConstraintComponents", "ContactComponents", "PhysBoneComponents", "ComponentsBase",
    "Components", "Constraint", "Contact", "Dynamics", "PhysBone", "Rendering", "Persistence",
    "Image", "Midi", "Video", "StringLoading", "Platform", "UdonNetworkCalling", "NetworkCalling",
    "Udon", "Economy", "Data", "SDK3", "SDKBase", "Base",
], key=len, reverse=True)


def clean_name(extern):
    """Recover a component's short name by stripping namespace segments."""
    s = extern[len("Extern"):] if extern.startswith("Extern") else extern
    changed = True
    while changed:
        changed = False
        for tok in NS:
            if s.startswith(tok) and len(s) > len(tok):
                s = s[len(tok):]
                changed = True
                break
    return s


def cand2(extern):
    """Fallback short name: the trailing VRC-prefixed token, if any."""
    s = extern[len("Extern"):] if extern.startswith("Extern") else extern
    m = re.search(r"(VRC[A-Za-z0-9]+)$", s)
    return m.group(1) if m else None


def prop_token(name):
    """Strip a get_/set_ accessor prefix to the underlying property name."""
    return name.split("_", 1)[1] if name.startswith(("get_", "set_")) else name


def main():
    """Diff the census against skill text; write tiered gaps to --out."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--census", default=DEFAULT_CENSUS)
    ap.add_argument("--skill-dir", default=DEFAULT_SKILL_DIR)
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args()

    data = json.load(open(args.census, encoding="utf-8"))
    census, boiler = data["census"], set(data["boilerplate"])

    texts = []
    for ext in ("**/*.md", "**/*.cs"):
        for p in glob.glob(os.path.join(args.skill_dir, ext), recursive=True):
            texts.append(open(p, encoding="utf-8", errors="ignore").read())
    skill = "\n".join(texts)

    def in_skill(tok):
        """True if token appears in skill text on a word-ish boundary."""
        return bool(tok) and re.search(r"(?<![A-Za-z0-9])" + re.escape(tok) + r"(?![A-Za-z0-9])", skill) is not None

    tier1, tier2 = [], []
    for extern, methods in census.items():
        label, c2 = clean_name(extern), cand2(extern)
        distinct = sorted({m["name"] for m in methods if m["name"] not in boiler})
        if not distinct:
            continue
        comp_mentioned = in_skill(label) or in_skill(c2)
        mentioned, missing = [], []
        for meth in distinct:
            (mentioned if in_skill(prop_token(meth)) else missing).append(meth)
        # Keys are SKILL-PRESENCE only, not official-doc status. "missing_from_skill"
        # is a discovery signal; whether it is truly undocumented is decided by the
        # by-hand editorial gate (see ../README.md "Triage"), never by this script.
        rec = {"type": extern, "label": label, "n_distinct": len(distinct),
               "mentioned_in_skill": mentioned, "missing_from_skill": missing}
        if comp_mentioned and missing:
            tier1.append(rec)
        elif not comp_mentioned:
            tier2.append(rec)

    tier1.sort(key=lambda r: -len(r["missing_from_skill"]))
    tier2.sort(key=lambda r: -r["n_distinct"])
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    json.dump({"tier1": tier1, "tier2": tier2}, open(args.out, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"wrote {args.out}: tier1={len(tier1)} (covered-but-incomplete), tier2={len(tier2)} (unmentioned)")


if __name__ == "__main__":
    main()
