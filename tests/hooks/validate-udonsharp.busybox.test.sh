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

echo "PASS: BusyBox awk validator portability"
