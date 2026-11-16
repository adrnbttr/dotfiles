#!/usr/bin/env bash
# Test de bout en bout de bin/.local/bin/nvim-agent : script -> vrai nvim headless (config du worktree)
# -> faux agent. Vérifie l'argv exact reçu, les erreurs, l'exec et l'enveloppe zsh nvim().
set -u
# shellcheck source=tests/nvim-agent/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SCRIPT="$ROOT/bin/.local/bin/nvim-agent"

# faux "nvim" : note son pid, puis devient le vrai nvim headless isolé qui quitte seul
cat > "$T/bin/nvim-test" <<SH
#!/usr/bin/env bash
echo \$\$ > "$T/nvim.pid"
exec nvim --headless -u "$T/init.lua" -i NONE \
  -c "lua vim.defer_fn(function() vim.cmd('qa!') end, 2500)" "\$@"
SH
chmod +x "$T/bin/nvim-test"
export NVIM_AGENT_NVIM="$T/bin/nvim-test"

fails=0
ok() { echo "OK   $1"; }
ko() { echo "FAIL $1 : $2"; fails=$((fails + 1)); }

# fields <champs...> : argv attendu, champs séparés par |
fields() { printf '%s|' "$@"; }

# attend (au plus 10 s) le fichier du faux agent ; la fin de nvim est laissée à son minuteur
wait_out() {
  local pid=$1 i
  for i in $(seq 1 100); do
    [ -e "$FAKE_OUT" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  return 0
}

got_argv() { [ -e "$FAKE_OUT" ] && tr '\0' '|' <"$FAKE_OUT" || printf -- '-'; }

# ok_case <nom> <attendu> <args...> : lance le script, compare l'argv du faux agent
ok_case() {
  local name=$1 expected=$2
  shift 2
  rm -f "$FAKE_OUT"
  timeout 20 "$SCRIPT" "$@" >"$T/log" 2>&1 &
  wait_out $!
  local got
  got=$(got_argv)
  if [ "$got" = "$expected" ]; then ok "$name"; else
    ko "$name" "attendu [$expected], obtenu [$got]"
    sed 's/^/     /' "$T/log" | head -5
  fi
  ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1 && ko "$name" "fichier de requête non supprimé"
  return 0
}

# err_case <nom> <args...> : code 2, message nvim-agent:, rien lancé, aucun fichier laissé
err_case() {
  local name=$1
  shift
  rm -f "$FAKE_OUT" "$T/nvim.pid"
  local rc=0
  timeout 20 "$SCRIPT" "$@" >"$T/log" 2>"$T/err" || rc=$?
  if [ "$rc" != 2 ]; then ko "$name" "code $rc au lieu de 2"
  elif ! grep -q '^nvim-agent: ' "$T/err"; then ko "$name" "message d'erreur absent"
  elif [ -e "$FAKE_OUT" ] || [ -e "$T/nvim.pid" ]; then ko "$name" "quelque chose a été lancé"
  elif ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1; then ko "$name" "fichier de requête laissé"
  else ok "$name"; fi
  rm -f "$T/nvim.pid"
}

ok_case "1 claude prompt + args relayés" \
  "$(fields claude --permission-mode auto --settings f x)" \
  --agent claude --prompt x -- --settings f
ok_case "2 prompt commençant par -" \
  "$(fields claude --permission-mode auto --settings f -- -x)" \
  --agent claude --prompt -x -- --settings f
ok_case "3 resume claude par défaut" \
  "$(fields claude --permission-mode auto --resume abc --settings f)" \
  --resume abc -- --settings f
ok_case "4 opencode prompt + args" \
  "$(fields opencode --auto --x y --prompt=p)" \
  --agent opencode --prompt p -- --x y
ok_case "5 opencode resume" \
  "$(fields opencode --auto -s s1)" \
  --agent opencode --resume s1
ok_case "6 arguments relayés intacts" \
  "$(fields claude --permission-mode plan "a b" $'l1\nl2' "" -x)" \
  --agent claude -- "a b" $'l1\nl2' "" -x
ok_case "7 claude seul (plan)" \
  "$(fields claude --permission-mode plan)" \
  --agent claude
ok_case "8 claude --last" \
  "$(fields claude --permission-mode plan --continue)" \
  --agent claude --last

err_case "9a sans agent"
err_case "9b agent inconnu" --agent gemini
err_case "9c --prompt sans texte" --agent claude --prompt
err_case "9d --new + --last" --agent claude --new --last
err_case "9e --resume sans id" --resume
err_case "9f --resume + --prompt" --resume x --prompt y

# 10 : exec. Le faux nvim note son pid ; il doit être celui du processus qui a lancé le script.
rm -f "$FAKE_OUT" "$T/nvim.pid"
bash -c 'echo $$ > "$1"; shift; exec "$@"' _ "$T/script.pid" "$SCRIPT" --agent claude >"$T/log" 2>&1 &
wait_out $!
if [ -s "$T/script.pid" ] && [ -s "$T/nvim.pid" ] && [ "$(cat "$T/script.pid")" = "$(cat "$T/nvim.pid")" ]; then
  ok "10 exec : nvim reprend le pid du script"
else ko "10 exec" "pid script [$(cat "$T/script.pid" 2>/dev/null)] pid nvim [$(cat "$T/nvim.pid" 2>/dev/null)]"; fi

# 11 : enveloppe zsh, fonction extraite de zsh/.zshrc (pas tout le fichier)
if command -v zsh >/dev/null 2>&1; then
  sed -n '/^nvim() {$/,/^}$/p' "$ROOT/zsh/.zshrc" >"$T/nvim-func.zsh"
  rm -f "$FAKE_OUT"
  PATH="$ROOT/bin/.local/bin:$PATH" timeout 20 zsh -c \
    'source "$1"; nvim --agent claude --prompt x -- --settings f' _ "$T/nvim-func.zsh" >"$T/log" 2>&1 &
  wait_out $!
  got=$(got_argv)
  exp=$(fields claude --permission-mode auto --settings f x)
  if [ "$got" = "$exp" ]; then ok "11 enveloppe zsh"; else ko "11 enveloppe zsh" "attendu [$exp], obtenu [$got]"; sed 's/^/     /' "$T/log" | head -5; fi
else
  echo "SKIP 11 : zsh absent"
fi

[ $fails = 0 ] && echo "Tous les cas OK" || echo "$fails echec(s)"
exit $((fails > 0))
