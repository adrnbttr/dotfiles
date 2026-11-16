#!/usr/bin/env bash
# Isolation commune aux tests nvim-agent (à sourcer) : dossier temporaire, faux agents dans le PATH,
# XDG_* de test, init.lua minimal (config du worktree + snacks.nvim/opencode.nvim en LECTURE seule
# depuis ~/.local/share/nvim/lazy). Aucun réseau, écritures uniquement dans le dossier temporaire.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$ROOT/config/.config/nvim"
FAKE="$ROOT/tests/nvim-agent/fakes/fake-agent"
LAZY="${LAZY_DIR:-$HOME/.local/share/nvim/lazy}"

for p in snacks.nvim opencode.nvim; do
  [ -d "$LAZY/$p" ] || { echo "SKIP: plugin $p introuvable dans $LAZY"; exit 2; }
done

T="$(mktemp -d)"
trap 'jobs -p | xargs -r kill 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/state" "$T/cache" "$T/tmp"
ln -s "$FAKE" "$T/bin/claude"
ln -s "$FAKE" "$T/bin/opencode"

export PATH="$T/bin:$PATH"
export XDG_CONFIG_HOME="$ROOT/config/.config"
export XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache" TMPDIR="$T/tmp"
export FAKE_OUT="$T/out"

cat > "$T/init.lua" <<LUA
vim.opt.rtp:prepend("$CONF")
vim.opt.rtp:append("$LAZY/snacks.nvim")
vim.opt.rtp:append("$LAZY/opencode.nvim")
vim.o.swapfile = false
-- opener opencode : config du spec NickvanDyke/opencode.nvim de plugins/ai.lua, sans lazy.nvim
for _, spec in ipairs(dofile("$CONF/lua/plugins/ai.lua")) do
  if spec[1] == "NickvanDyke/opencode.nvim" then
    require("snacks").setup({ terminal = {} })
    spec.config()
  end
end
LUA
