#!/usr/bin/env bash
# Every long reference keeps a table of contents that matches its headings, and
# every link to a heading under skills/ resolves. See reference-toc.py.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 "$ROOT_DIR/tests/docs/reference-toc.py"

echo "PASS: reference tables of contents and heading links"
