#!/usr/bin/env bash
# Lance les tests nvim-agent : requête Lua, puis script de bout en bout. Exige nvim et les plugins
# snacks.nvim / opencode.nvim dans ~/.local/share/nvim/lazy (donc pas lancé par la CI).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in lua_request_test.sh script_test.sh; do
  echo "== $t"
  bash "$here/$t" || rc=1
done
exit $rc
