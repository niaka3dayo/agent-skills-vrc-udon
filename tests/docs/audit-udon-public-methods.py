#!/usr/bin/env python3
"""Audit legacy network exposure in UdonSharp examples.

Every parameterless public void method in Markdown or C# templates must be one
of these deliberately narrow categories:

1. a standard Unity message or overridden Udon callback in the allowlists;
2. an intentionally exposed legacy network entry with the adjacent marker
   ``// NETWORK-EXPOSURE: LEGACY``; or
3. an underscore-prefixed ``[NetworkCallable]`` entry; or
4. an underscore-prefixed local/custom helper.

Keep the callback allowlist narrow. Add the legacy marker only to examples
whose purpose is to demonstrate backwards-compatible legacy network events.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


UNITY_MESSAGE_ALLOWLIST = {
    "FixedUpdate",
    "LateUpdate",
    "OnDisable",
    "OnEnable",
    "Start",
    "Update",
}

UDON_OVERRIDE_CALLBACK_ALLOWLIST = {
    "Interact",
    "OnDeserialization",
    "OnDrop",
    "OnInspectorGUI",
    "OnPersistenceUsageUpdated",
    "OnPickup",
    "OnPickupUseDown",
    "OnPickupUseUp",
    "OnPostSerialization",
    "OnPreSerialization",
    "OnSpawn",
    "OnVideoEnd",
    "OnVideoReady",
    "OnVideoStart",
    "OnVRCQualitySettingsChanged",
    "PostLateUpdate",
}

LEGACY_MARKER = "// NETWORK-EXPOSURE: LEGACY"
NETWORK_CALLABLE_RE = re.compile(r"\[NetworkCallable(?:\([^]]*\))?\]")
METHOD_RE = re.compile(
    r"\bpublic\s+(?P<modifiers>(?:(?:override|virtual|static)\s+)*)"
    r"void\s+(?P<name>[A-Za-z_]\w*)\s*\(\s*\)"
)


def has_adjacent_legacy_marker(lines: list[str], index: int) -> bool:
    """Allow only a marker on one of the two immediately preceding lines."""
    start = max(0, index - 2)
    return any(LEGACY_MARKER in lines[candidate] for candidate in range(start, index))


def has_adjacent_network_callable(lines: list[str], index: int) -> bool:
    """Recognize an attribute on the method line or two preceding lines."""
    start = max(0, index - 2)
    return any(
        NETWORK_CALLABLE_RE.search(lines[candidate])
        for candidate in range(start, index + 1)
    )


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: audit-udon-public-methods.py <unity-vrc-udon-sharp-dir>", file=sys.stderr)
        return 2

    skill_dir = Path(sys.argv[1])
    paths = sorted((*skill_dir.rglob("*.md"), *skill_dir.rglob("*.cs")))
    violations: list[str] = []
    counts = {"callback": 0, "legacy": 0, "network_callable": 0, "local": 0}

    for path in paths:
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            for match in METHOD_RE.finditer(line):
                name = match.group("name")
                modifiers = match.group("modifiers").split()
                if name.startswith("_"):
                    category = (
                        "network_callable"
                        if has_adjacent_network_callable(lines, index)
                        else "local"
                    )
                    counts[category] += 1
                elif name in UNITY_MESSAGE_ALLOWLIST:
                    counts["callback"] += 1
                elif name in UDON_OVERRIDE_CALLBACK_ALLOWLIST and "override" in modifiers:
                    counts["callback"] += 1
                elif has_adjacent_legacy_marker(lines, index):
                    counts["legacy"] += 1
                else:
                    relative = path.relative_to(skill_dir.parent.parent)
                    violations.append(f"{relative}:{index + 1}: public void {name}()")

    if violations:
        print(
            "ERROR: parameterless public void methods without '_' expose a legacy "
            "network entry unless they are callbacks or explicitly marked legacy:",
            file=sys.stderr,
        )
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1

    total = sum(counts.values())
    print(
        "PASS: audited "
        f"{total} parameterless public void methods "
        f"({counts['callback']} callbacks, {counts['legacy']} legacy entries, "
        f"{counts['network_callable']} NetworkCallable entries, "
        f"{counts['local']} local/custom underscore methods)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
