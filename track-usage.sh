#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
PYTHON_BIN="${PYTHON_BIN:-${PYTHON:-python3}}"

if [ -x "$VENV_PYTHON" ]; then
    PYTHON_BIN="$VENV_PYTHON"
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "Error: python3 not found. Install Python 3 to run the Copilot usage tracker." >&2
    exit 1
fi

exec "$PYTHON_BIN" "$SCRIPT_DIR/copilot_usage.py" track "$@"
