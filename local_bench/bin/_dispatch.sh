#!/usr/bin/env bash
# Shared body for the local_bench command shims. Each shim (return_txt,
# list_files, ...) is a one-line wrapper that sources this with its own name.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$HERE/../../.venv/bin/python3"
if [ ! -x "$PY" ]; then
  PY="python3"
fi
exec "$PY" "$HERE/../cli.py" "$CMD_NAME" "$@"
