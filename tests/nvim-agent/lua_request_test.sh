#!/usr/bin/env bash
# Test headless de require('config.ai_tab').request(<fichier>) : argv exact de claude et d'opencode.
# Isolation : nvim --clean (aucun plugin utilisateur), rtp vers la config du worktree. opencode exige
# les plugins snacks.nvim (terminal) et opencode.nvim : leurs dossiers sont ajoutes au rtp en LECTURE
# seule depuis le XDG_DATA_HOME par defaut (~/.local/share/nvim/lazy), sans lazy.nvim.
# Aucun reseau, faux claude/opencode, ecritures uniquement dans le dossier temporaire.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$ROOT/config/.config/nvim"
FAKE="$ROOT/tests/nvim-agent/fakes/fake-agent"
LAZY="${LAZY_DIR:-$HOME/.local/share/nvim/lazy}"

T="$(mktemp -d)"
trap 'jobs -p | xargs -r kill 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/state" "$T/cache" "$T/tmp"
ln -s "$FAKE" "$T/bin/claude"
ln -s "$FAKE" "$T/bin/opencode"

export PATH="$T/bin:$PATH"
export XDG_CONFIG_HOME="$ROOT/config/.config"
export XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache" TMPDIR="$T/tmp"
export FAKE_OUT="$T/out"

for p in snacks.nvim opencode.nvim; do
  [ -d "$LAZY/$p" ] || { echo "SKIP: plugin $p introuvable dans $LAZY"; exit 2; }
done

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

fails=0
# nul <champs...> : ecrit un fichier de requete (champs termines par NUL)
nul() { printf '%s\0' "$@"; }

# run <nom> <attendu|-> : requete lue sur stdin ; attendu = argv separe par des espaces
# (ou "-" : rien ne doit etre lance). Les prompts a retours ligne sont testes via le tag @NL@.
run() {
  local name="$1" expected="$2"
  rm -f "$FAKE_OUT"
  cat > "$T/req"
  timeout 20 nvim --headless -u "$T/init.lua" -i NONE \
    -c "lua require('config.ai_tab').request('$T/req')" \
    -c "lua vim.defer_fn(function() vim.cmd('qa!') end, $([ "$expected" = - ] && echo 3000 || echo 8000))" \
    >"$T/nvim.log" 2>&1 &
  local pid=$!
  local i
  for i in $(seq 1 100); do
    [ -e "$FAKE_OUT" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  local got="-"
  if [ -e "$FAKE_OUT" ]; then
    got="$(tr '\0' '\n' < "$FAKE_OUT" | paste -sd' ')"
  fi
  local ok=1
  [ "$got" = "$expected" ] || ok=0
  [ -e "$T/req" ] && { ok=0; echo "  (fichier de requete non supprime)"; }
  if [ $ok = 1 ]; then echo "OK   $name"; else
    echo "FAIL $name : attendu [$expected], obtenu [$got]"; sed 's/^/     nvim: /' "$T/nvim.log" | head -5; fails=$((fails+1)); fi
}

nul v1 claude new "" "x" --settings f | run "claude new + prompt + args" "claude --permission-mode auto --settings f x"
nul v1 claude new "" "-x y" | run "claude prompt commencant par -" "claude --permission-mode auto -- -x y"
nul v1 claude resume abc "" --settings f | run "claude resume + args" "claude --permission-mode auto --resume abc --settings f"
nul v1 claude new "" "" | run "claude sans prompt (plan)" "claude --permission-mode plan"
nul v1 claude last "" "" | run "claude last" "claude --permission-mode plan --continue"
nul v1 opencode new "" "hello" | run "opencode prompt" "opencode --auto --prompt=hello"
nul v1 opencode resume ses_1 "" --model m | run "opencode resume + args" "opencode --auto -s ses_1 --model m"
nul v2 claude new "" "x" | run "version inconnue" -
nul v1 gemini new "" "x" | run "agent inconnu" -
nul v1 claude bizarre "" "x" | run "mode inconnu" -
nul v1 claude resume "" "x" | run "resume sans id" -

# prompt a retours ligne : argv comparee champ a champ
rm -f "$FAKE_OUT"
nul v1 claude new "" $'a\nb' | cat > "$T/req"
timeout 20 nvim --headless -u "$T/init.lua" -i NONE -c "lua require('config.ai_tab').request('$T/req')" \
  -c "lua vim.defer_fn(function() vim.cmd('qa!') end, 8000)" >/dev/null 2>&1 &
pid=$!
for i in $(seq 1 100); do [ -e "$FAKE_OUT" ] && break; sleep 0.1; done
kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
if [ "$(tr '\0' '|' < "$FAKE_OUT" 2>/dev/null)" = $'claude|--permission-mode|auto|a\nb|' ]; then
  echo "OK   prompt multiligne en un seul argument"
else echo "FAIL prompt multiligne"; fails=$((fails+1)); fi

[ $fails = 0 ] && echo "Tous les cas OK" || echo "$fails echec(s)"
exit $((fails > 0))
