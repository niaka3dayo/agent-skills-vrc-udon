#!/usr/bin/env python3
"""SDK coverage refine — stage 3 of the binary-backed discovery audit.

Reduces the Tier-1 diff to the decision-relevant signal: missing NON-ACCESSOR
(verb) methods on skill-taught components. Property get_/set_ accessors are
summarized as a count (low knowledge-delta). This is what a maintainer reads
before doing the editorial / official-docs triage (see ../README.md).

Usage:
    python refine.py [--diff diff.json]
"""
import argparse
import json


def split(ms):
    """Partition method names into (verb methods, get_/set_ accessors)."""
    methods = [m for m in ms if not m.startswith(("get_", "set_"))]
    acc = [m for m in ms if m.startswith(("get_", "set_"))]
    return methods, acc


def main():
    """Print the high-signal Tier-1 verb-method gaps from --diff."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--diff", default=".claude/audit/.generated/diff.json")
    args = ap.parse_args()
    d = json.load(open(args.diff, encoding="utf-8"))

    print("== TIER 1 high-signal: missing NON-ACCESSOR methods on skill-taught components ==")
    rows = []
    for r in d["tier1"]:
        meth, acc = split(r["missing_from_skill"])
        if meth:
            rows.append((len(meth), r["label"], meth, len(acc)))
    rows.sort(key=lambda x: -x[0])
    for n, label, meth, nacc in rows:
        print(f"  [{label}]  methods={n} (+{nacc} accessors)")
        print(f"      {', '.join(meth)}")
    print(f"\n  components with missing verb-methods: {len(rows)}")

    only_acc = [r["label"] for r in d["tier1"] if not split(r["missing_from_skill"])[0]]
    print("\n== components where ONLY accessors are missing (likely low value) ==")
    print("   " + ", ".join(only_acc))


if __name__ == "__main__":
    main()
