#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

if ! command -v busybox >/dev/null 2>&1; then
    echo "ERROR: busybox is required for the validator portability test" >&2
    exit 1
fi

cat > "$TMPROOT/awk" <<'EOF'
#!/bin/sh
exec busybox awk "$@"
EOF
chmod +x "$TMPROOT/awk"

if ! PATH="$TMPROOT:$PATH" bash "$ROOT_DIR/tests/hooks/validate-udonsharp.test.sh" > "$TMPROOT/suite.log" 2>&1; then
    cat "$TMPROOT/suite.log" >&2
    exit 1
fi

if ! PATH="$TMPROOT:$PATH" python3 - "$ROOT_DIR/skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh" "$TMPROOT" <<'PY'
import json
import pathlib
import subprocess
import sys
import time

hook = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])


def measure(line_count: int) -> float:
    source = root / f"busybox-base-scan-{line_count}.cs"
    source.write_text(
        "using UdonSharp;\n"
        "public class BusyBoxBaseScan : UdonSharpBehaviour\n"
        "{\n"
        + "    [Example] private int value;\n" * line_count
        + "}\n",
        encoding="utf-8",
    )
    payload = json.dumps({"tool_input": {"file_path": str(source)}}, separators=(",", ":"))
    started = time.monotonic()
    result = subprocess.run(
        [str(hook)], input=payload, text=True, capture_output=True, timeout=20, check=False
    )
    elapsed = time.monotonic() - started
    if result.returncode != 0 or result.stdout != payload:
        raise RuntimeError(
            f"{line_count} lines: exit={result.returncode} stdout_exact={result.stdout == payload}"
        )
    if "VALIDATOR-WARNING" in result.stderr:
        raise RuntimeError(f"{line_count} lines: internal failure: {result.stderr}")
    return elapsed


measure(100)
small = measure(2000)
large = measure(8000)
limit = small * 6 + 0.75
print(f"BusyBox base scan: 2000={small:.3f}s 8000={large:.3f}s limit={limit:.3f}s")
if large > limit:
    raise SystemExit(1)
PY
then
    echo "ERROR: BusyBox awk base scan is not linear enough" >&2
    exit 1
fi

echo "PASS: BusyBox awk validator portability"
