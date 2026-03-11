#!/usr/bin/env bash
# Shared helpers sourced by sync scripts.

# ensure_newline <file>
# Append a trailing newline to <file> if it does not already have one.
ensure_newline() {
  local file="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
if not p.exists():
    raise SystemExit(0)
b = p.read_bytes()
if b and not b.endswith(b"\n"):
    p.write_bytes(b + b"\n")
PY
  fi
}
