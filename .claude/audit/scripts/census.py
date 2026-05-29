#!/usr/bin/env python3
"""SDK coverage census — stage 1 of the binary-backed discovery audit.

Parses the Udon wrapper module assembly's metadata (TypeDef -> MethodList) to
enumerate, per VRC extern type, the methods Udon can dispatch. The extern
signatures (e.g. ``__Shuffle__SystemVoid``) are the wrapper class's own
MethodDefs, so type->method ownership is recovered exactly — ``strings | grep``
cannot do this because the metadata string heap is not grouped by type.

This is a DISCOVERY tool. Binary presence is never sufficient for inclusion;
see CONTRIBUTING.md "Content Scope" and ../README.md for the policy.

Requires: pip install dnfile pefile

Usage:
    python census.py [--dll PATH] [--out census.json]

Default --dll points at the gitignored local SDK workspace described in
unity-project-for-sdk-search/README.md. Override for a different SDK version.
"""
import argparse
import json
import os
import sys
from collections import Counter

try:
    import dnfile
except ImportError:
    sys.exit("dnfile is required: pip install dnfile pefile")

DEFAULT_DLL = (
    "unity-project-for-sdk-search/sdk-search-project/Packages/com.vrchat.worlds/"
    "Runtime/Udon/External/VRC.Udon.VRCWrapperModules.dll"
)
# Generated output goes here — covered by .claude/audit/.gitignore so the
# near-complete symbol listing is never committed (it is not an API mirror).
DEFAULT_OUT = ".claude/audit/.generated/census.json"

# Method names that appear on many extern types are Unity/Object boilerplate
# (GetComponent family, Equals, get_transform, ...), not a component's own API.
BOILERPLATE_MIN_TYPES = 8

INFRA_NAMES = {".ctor", ".cctor", "get_Name", "get_GetterType"}


def sval(x):
    """Return the plain string value of a dnfile string-heap field."""
    return x.value if hasattr(x, "value") else str(x)


def is_infra(name):
    """True for wrapper-class members that are not Udon extern signatures."""
    if name in INFRA_NAMES:
        return True
    if name.startswith("GetExternFunction"):
        return True
    if "." in name:  # interface-explicit re-implementations (dup of __ form)
        return True
    return not name.startswith("__")


def decode(sym):
    """__Name__[Args__]Return  ->  (name, [args], return)."""
    body = sym[2:] if sym.startswith("__") else sym
    parts = body.split("__")
    if len(parts) == 1:
        return parts[0], [], ""
    if len(parts) == 2:
        return parts[0], [], parts[1]
    name, ret = parts[0], parts[-1]
    args = "__".join(parts[1:-1])
    return name, (args.split("_") if args else []), ret


def main():
    """Parse the wrapper DLL and write the per-type method census to --out."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--dll", default=DEFAULT_DLL, help="path to VRC.Udon.VRCWrapperModules.dll")
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args()

    dn = dnfile.dnPE(args.dll)
    tds = dn.net.mdtables.TypeDef

    census = {}
    name_freq = Counter()
    for td in tds.rows:
        nm = sval(td.TypeName)
        if not nm.startswith("ExternVRC") or nm.endswith("Array"):
            continue
        methods, seen = [], set()
        for m in td.MethodList:
            mname = sval(m.row.Name) if hasattr(m, "row") else sval(m.Name)
            if is_infra(mname) or mname in seen:
                continue
            seen.add(mname)
            dn_name, margs, ret = decode(mname)
            methods.append({"raw": mname, "name": dn_name, "args": margs, "ret": ret})
        census[nm] = methods
        for dn_name in {x["name"] for x in methods}:
            name_freq[dn_name] += 1

    boiler = {n for n, c in name_freq.items() if c >= BOILERPLATE_MIN_TYPES}
    summary = {}
    for t, ms in census.items():
        distinct = sorted({m["name"] for m in ms if m["name"] not in boiler})
        summary[t] = {"total": len(ms), "distinctive": len(distinct), "distinctive_methods": distinct}

    out = {"n_types": len(census), "boilerplate": sorted(boiler), "census": census, "summary": summary}
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    print(f"wrote {args.out}: {len(census)} extern types, {len(boiler)} boilerplate names dropped")


if __name__ == "__main__":
    main()
