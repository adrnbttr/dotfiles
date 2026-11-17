#!/usr/bin/env bash
# Test de bout en bout de bin/.local/bin/nvim-agent : script -> vrai nvim headless (config du worktree)
# -> faux agent. Vérifie l'argv exact reçu, les erreurs, le nettoyage du fichier de requête et l'enveloppe zsh nvim().
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
  local pid=$1
  for _ in $(seq 1 100); do
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

# 9g : TMPDIR relatif refusé (code 2)
rm -f "$FAKE_OUT" "$T/nvim.pid"
rc=0
TMPDIR=relatif timeout 20 "$SCRIPT" --agent claude >"$T/log" 2>"$T/err" || rc=$?
if [ "$rc" = 2 ] && grep -q '^nvim-agent: ' "$T/err" && [ ! -e "$T/nvim.pid" ]; then ok "9g TMPDIR relatif refusé"
else ko "9g TMPDIR relatif" "code $rc, nvim lancé : $([ -e "$T/nvim.pid" ] && echo oui || echo non)"; fi

# 10a : nvim qui sort sans lire -c (--version) : aucun fichier de requête, code de nvim rendu
cat > "$T/bin/nvim-exit7" <<'SH'
#!/usr/bin/env bash
exit 7
SH
chmod +x "$T/bin/nvim-exit7"
rc=0
NVIM_AGENT_NVIM="$T/bin/nvim-exit7" timeout 20 "$SCRIPT" --agent claude --prompt secret --version >"$T/log" 2>&1 || rc=$?
if [ "$rc" != 7 ]; then ko "10a nvim sans -c" "code $rc au lieu de 7"
elif ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1; then ko "10a nvim sans -c" "fichier de requête laissé"
else ok "10a --prompt secret --version : aucun fichier, code de nvim rendu"; fi

# 10b : SIGTERM envoyé au script pendant que nvim tourne : aucun fichier, nvim arrêté, code 143
cat > "$T/bin/nvim-sleep" <<SH
#!/usr/bin/env bash
echo \$\$ > "$T/sleep.pid"
exec sleep 30
SH
chmod +x "$T/bin/nvim-sleep"
rm -f "$T/sleep.pid"
NVIM_AGENT_NVIM="$T/bin/nvim-sleep" "$SCRIPT" --agent claude --prompt secret >"$T/log" 2>&1 &
spid=$!
for _ in $(seq 1 100); do [ -s "$T/sleep.pid" ] && break; sleep 0.1; done
seen=0
ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1 && seen=1
kill -TERM "$spid" 2>/dev/null
rc=0
wait "$spid" 2>/dev/null || rc=$?
nvpid=$(cat "$T/sleep.pid" 2>/dev/null)
if [ "$seen" != 1 ]; then ko "10b SIGTERM" "fichier de requête absent avant le signal (test sans valeur)"
elif ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1; then ko "10b SIGTERM" "fichier de requête laissé"
elif [ -n "$nvpid" ] && kill -0 "$nvpid" 2>/dev/null; then ko "10b SIGTERM" "nvim encore vivant"
elif [ "$rc" != 143 ]; then ko "10b SIGTERM" "code $rc au lieu de 143"
else ok "10b SIGTERM : aucun fichier, nvim arrêté, code 143"; fi

# 11 : enveloppe zsh, fonction extraite de zsh/.zshrc (pas tout le fichier)
if command -v zsh >/dev/null 2>&1; then
  sed -n '/^nvim() {$/,/^}$/p' "$ROOT/zsh/.zshrc" >"$T/nvim-func.zsh"
  rm -f "$FAKE_OUT"
  # shellcheck disable=SC2016  # guillemets simples voulus : $1 est développé par le zsh enfant
  PATH="$ROOT/bin/.local/bin:$PATH" timeout 20 zsh -c \
    'source "$1"; nvim --agent claude --prompt x' _ "$T/nvim-func.zsh" >"$T/log" 2>&1 &
  wait_out $!
  got=$(got_argv)
  exp=$(fields claude --permission-mode auto x)
  if [ "$got" = "$exp" ]; then ok "11 enveloppe zsh : délégation à nvim-agent"; else ko "11 enveloppe zsh" "attendu [$exp], obtenu [$got]"; sed 's/^/     /' "$T/log" | head -5; fi

  # 12 : « -- » dans les arguments : ancien chemin (request_agent), nvim reçoit « -- notes.md »,
  # aucune requête nvim-agent. Faux nvim qui note son argv.
  mkdir -p "$T/fakenvim"
  cat > "$T/fakenvim/nvim" <<'SH'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$NVIM_ARGV_OUT"
SH
  chmod +x "$T/fakenvim/nvim"
  rm -f "$T/nvim-argv"
  # shellcheck disable=SC2016  # guillemets simples voulus : $1 est développé par le zsh enfant
  NVIM_ARGV_OUT="$T/nvim-argv" PATH="$T/fakenvim:$ROOT/bin/.local/bin:$PATH" timeout 20 zsh -c \
    'source "$1"; nvim --agent claude -- notes.md' _ "$T/nvim-func.zsh" >"$T/log" 2>&1
  argv=$(tr '\0' '|' <"$T/nvim-argv" 2>/dev/null)
  case "$argv" in
    *"request_agent("*"|--|notes.md|") if [[ "$argv" == *".request('"* ]]; then ko "12 -- ancien chemin" "requête nvim-agent détectée [$argv]"; else ok "12 -- : ancien chemin, nvim reçoit -- notes.md"; fi ;;
    *) ko "12 -- ancien chemin" "argv nvim [$argv]" ;;
  esac
else
  echo "SKIP 11, 12 : zsh absent"
fi

[ "$fails" = 0 ] && echo "Tous les cas OK" || echo "$fails echec(s)"
exit $((fails > 0))
