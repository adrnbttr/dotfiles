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
  "$(fields opencode --standalone --auto --x y --prompt=p)" \
  --agent opencode --prompt p -- --x y
ok_case "5 opencode resume" \
  "$(fields opencode --standalone --auto -s s1)" \
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
err_case "9f --resume + --prompt (claude)" --resume x --prompt y
err_case "9f2 --resume + --prompt, --agent claude" --resume x --agent claude --prompt y
err_case "9h --resume + --last" --resume x --agent opencode --last
err_case "9i --env NOM invalide" --agent opencode --env 1BAD=x
err_case "9j --env sans =" --agent opencode --env NOVALUE
err_case "9k --env nom avec tiret" --agent opencode --env A-B=x
err_case "9l --env sans argument" --agent opencode --env

ok_case "13 opencode resume + prompt" \
  "$(fields opencode --standalone --auto -s ses_1 --prompt=relance)" \
  --resume ses_1 --agent opencode --prompt relance
ok_case "14 opencode deck : -- -s id + prompt" \
  "$(fields opencode --standalone --auto -s ses_x "--prompt=a b")" \
  --agent opencode --prompt "a b" -- -s ses_x
ok_case "15 opencode --last" \
  "$(fields opencode --standalone --auto --continue)" \
  --agent opencode --last

# 16 : --env, valeur JSON (espaces, guillemets, *, /, $, `) vue intacte par le faux opencode
# shellcheck disable=SC2016  # simples guillemets voulus : aucun développement
json='{"permission":{"bash":{"*":"allow","rm *":"deny"}},"path":"/tmp/a b","q":"say \"hi\" $HOME `x`"}'
rm -f "$FAKE_OUT" "$FAKE_OUT.env"
FAKE_ENV_NAME=OPENCODE_CONFIG_CONTENT timeout 20 "$SCRIPT" --agent opencode \
  --env OPENCODE_CONFIG_CONTENT="$json" --env AUTRE=1 --prompt p -- -s ses_x >"$T/log" 2>&1 &
wait_out $!
got=$(got_argv)
exp=$(fields opencode --standalone --auto -s ses_x --prompt=p)
if [ "$got" != "$exp" ]; then ko "16 --env : argv" "attendu [$exp], obtenu [$got]"
elif [ "$(cat "$FAKE_OUT.env" 2>/dev/null)" != "$json" ]; then ko "16 --env : valeur" "obtenu [$(cat "$FAKE_OUT.env" 2>/dev/null)]"
else ok "16 --env : valeur JSON intacte dans l'environnement d'opencode"; fi

# --- --create (ADR deck 0030, A) : faux opencode distinguant run / debug config / TUI ---
# forme observée de « opencode debug config --standalone » : tableau de couches {type,path,info?},
# model = objet {providerID, model, variant?}; la couche injectée (OPENCODE_CONFIG_CONTENT) est la dernière
cat > "$T/debug-ok.json" <<'JSON'
[{"type":"document","path":"/x/opencode.json","info":{"model":{"providerID":"a","model":"racine"},"agents":{"build":{"mode":"primary","model":{"providerID":"opencode","model":"deepseek-v4.1-flash"}},"plan":{"model":{"providerID":"z","model":"glm"}}}}},
 {"type":"directory","path":"/x"},
 {"type":"document","path":null,"info":{"default_agent":"build","agents":{"build":{"model":{"providerID":"zai","model":"glm-5.3","variant":"high"}}}}}]
JSON
cat > "$T/debug-first-only.json" <<'JSON'
[{"type":"document","path":"/x/opencode.json","info":{"agents":{"build":{"model":{"providerID":"opencode","model":"deepseek-v4.1-flash"}}}}},
 {"type":"document","path":null,"info":{"default_agent":"build"}}]
JSON
cat > "$T/debug-nomodel.json" <<'JSON'
[{"type":"document","path":"/x/opencode.json","info":{"model":{"providerID":"a","model":"racine"},"agents":{"plan":{"model":{"providerID":"z","model":"glm"}}}}},
 {"type":"directory","path":"/x"}]
JSON
RUNLOG="$T/runlog"

# create_case <nom> <argv TUI attendu> <ligne run attendue> <env...> -- <args...>
create_case() {
  local name=$1 exp_tui=$2 exp_run=$3
  shift 3
  rm -f "$FAKE_OUT" "$FAKE_OUT.deck" "$RUNLOG"
  env "$@" >"$T/log" 2>&1 &
  wait_out $!
  local got got_run
  got=$(got_argv)
  got_run=$(grep '^run argv:' "$RUNLOG" 2>/dev/null)
  if [ "$got" != "$exp_tui" ]; then ko "$name" "TUI : attendu [$exp_tui], obtenu [$got]"; sed 's/^/     /' "$T/log" | head -5
  elif [ "$got_run" != "$exp_run" ]; then ko "$name" "run : attendu [$exp_run], obtenu [$got_run]"
  else ok "$name"; fi
}

export FAKE_RUN_LOG="$RUNLOG"
create_case "17 --create --model : run exact puis TUI en reprise" \
  "$(fields opencode --standalone --auto -s ses_c "--prompt=a b")" \
  "run argv: [run] [--standalone] [-s] [ses_c] [--agent] [build] [--model] [p/m#v] [--title] [T explicite] [réponds ok]" \
  DECK_RUN_ID=r1 DECK_STEP=s2 timeout 20 "$SCRIPT" --agent opencode --create ses_c --model 'p/m#v' --title 'T explicite' --prompt "a b" \
  --env OPENCODE_CONFIG_CONTENT='{"k":1}'
if [ "$(grep '^run deck:' "$RUNLOG" | sed 's/ *$//')" != "run deck:" ]; then ko "17b DECK_* absentes de run" "$(grep '^run deck:' "$RUNLOG")"
elif [ "$(tr -d '[:space:]' <"$FAKE_OUT.deck")" != "DECK_RUN_IDDECK_STEP" ]; then ko "17b DECK_* présentes pour la TUI" "[$(cat "$FAKE_OUT.deck")]"
elif ! grep -q '^run cfg: {"k":1}$' "$RUNLOG"; then ko "17b --env vu par run" "$(grep '^run cfg' "$RUNLOG")"
elif ! grep -q '^run stdin-closed: oui$' "$RUNLOG"; then ko "17b stdin fermé" "$(grep '^run stdin' "$RUNLOG")"
elif grep -q '^debug argv' "$RUNLOG"; then ko "17b --model : pas de debug config" "appelé"
else ok "17b DECK_* absentes de run, présentes pour la TUI, --env vu, stdin fermé, pas de debug config"; fi

create_case "18 --create sans --model : modèle de la dernière couche (variante incluse)" \
  "$(fields opencode --standalone --auto -s ses_c --prompt=p)" \
  "run argv: [run] [--standalone] [-s] [ses_c] [--agent] [build] [--model] [zai/glm-5.3#high] [--title] [ses_c] [réponds ok]" \
  FAKE_DEBUG_FILE="$T/debug-ok.json" timeout 20 "$SCRIPT" --agent opencode --create ses_c --prompt p
grep -qx 'debug argv: debug config --standalone' "$RUNLOG" || ko "18b argv de debug config" "$(grep '^debug' "$RUNLOG")"

create_case "19 --create sans --model : seule la première couche définit build.model" \
  "$(fields opencode --standalone --auto -s ses_c --prompt=p)" \
  "run argv: [run] [--standalone] [-s] [ses_c] [--agent] [build] [--model] [opencode/deepseek-v4.1-flash] [--title] [ses_c] [réponds ok]" \
  FAKE_DEBUG_FILE="$T/debug-first-only.json" timeout 20 "$SCRIPT" --agent opencode --create ses_c --prompt p

# resolve_fail <nom> <env...> : code 2, message, ni run ni TUI
resolve_fail() {
  local name=$1
  shift
  rm -f "$FAKE_OUT" "$RUNLOG"
  local rc=0
  env "$@" timeout 20 "$SCRIPT" --agent opencode --create ses_c --prompt p >"$T/log" 2>"$T/err" || rc=$?
  if [ "$rc" != 2 ]; then ko "$name" "code $rc au lieu de 2"
  elif ! grep -q 'modèle de l.agent build introuvable' "$T/err"; then ko "$name" "message absent : $(cat "$T/err")"
  elif grep -q '^run argv' "$RUNLOG" 2>/dev/null || [ -e "$FAKE_OUT" ]; then ko "$name" "run ou TUI lancé"
  elif ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1; then ko "$name" "fichier de requête laissé"
  else ok "$name"; fi
}
resolve_fail "20 debug config sans modèle build : code 2" FAKE_DEBUG_FILE="$T/debug-nomodel.json"
resolve_fail "21 debug config en échec : code 2" FAKE_DEBUG_FILE="$T/debug-ok.json" FAKE_DEBUG_RC=1
echo 'pas du json' > "$T/debug-bad.json"
resolve_fail "22 debug config illisible : code 2" FAKE_DEBUG_FILE="$T/debug-bad.json"

# 22b : jq absent du PATH : message distinct (jq introuvable), code 2, debug config non lancé
mkdir -p "$T/nojq"
for tool in bash env timeout opencode nvim-test dirname basename rm mkdir cat tr sed grep mktemp; do
  src=$(command -v "$tool" 2>/dev/null || true)
  [ -z "$src" ] && [ -e "$T/bin/$tool" ] && src="$T/bin/$tool"
  [ -n "$src" ] && ln -sf "$src" "$T/nojq/$tool"
done
rm -f "$FAKE_OUT" "$RUNLOG"
rc=0
FAKE_RUN_LOG="$RUNLOG" FAKE_DEBUG_FILE="$T/debug-ok.json" PATH="$T/nojq" "$SCRIPT" --agent opencode --create ses_c --prompt p >"$T/log" 2>"$T/err" || rc=$?
if [ "$rc" != 2 ]; then ko "22b jq absent" "code $rc au lieu de 2 : $(cat "$T/err")"
elif ! grep -q 'jq introuvable' "$T/err" || grep -q 'introuvable dans la config' "$T/err"; then ko "22b jq absent" "message : $(cat "$T/err")"
elif grep -q '^debug argv' "$RUNLOG" 2>/dev/null || [ -e "$FAKE_OUT" ]; then ko "22b jq absent" "debug config, run ou TUI lancé"
else ok "22b jq absent : message jq introuvable, code 2, rien lancé"; fi

# 22c : fermer le volet tmux (SIGHUP) tue la création en cours (même groupe de premier plan)
if command -v tmux >/dev/null 2>&1; then
  sock="nvim-agent-test-$$-$RANDOM"
  rm -f "$T/fini" "$T/hup.started"
  # le faux run signale son démarrage via le journal ; il dormirait 8 s puis écrirait « fini »
  tmux -L "$sock" -f /dev/null new-session -d -x 80 -y 24 \
    "FAKE_RUN_LOG='$T/hup.log' FAKE_RUN_SLEEP=8 FAKE_RUN_DONE='$T/fini' '$SCRIPT' --agent opencode --create ses_h --model p/m --prompt p; true"
  for _ in $(seq 1 50); do grep -q '^run argv' "$T/hup.log" 2>/dev/null && break; sleep 0.1; done
  sleep 0.5
  started=0; grep -q '^run argv' "$T/hup.log" 2>/dev/null && started=1
  tmux -L "$sock" kill-server 2>/dev/null
  sleep 10
  if [ "$started" != 1 ]; then ko "22c fermeture du volet" "le faux run n'a pas démarré"
  elif [ -e "$T/fini" ]; then ko "22c fermeture du volet" "le faux run a survécu à kill-server (fini écrit)"
  else ok "22c fermeture du volet : la création meurt avec lui"; fi
  tmux -L "$sock" kill-server 2>/dev/null
else
  echo "SKIP 22c : tmux absent"
fi

# 23 : run en échec : code 3, message, pas de nvim
rm -f "$FAKE_OUT" "$RUNLOG" "$T/nvim.pid"
rc=0
FAKE_RUN_RC=5 timeout 20 "$SCRIPT" --agent opencode --create ses_c --model p/m --prompt p >"$T/log" 2>"$T/err" || rc=$?
if [ "$rc" != 3 ]; then ko "23 run en échec" "code $rc au lieu de 3"
elif ! grep -q 'création de la session ses_c échouée (code 5)' "$T/err"; then ko "23 run en échec" "message : $(cat "$T/err")"
elif [ -e "$FAKE_OUT" ] || [ -e "$T/nvim.pid" ]; then ko "23 run en échec" "nvim lancé"
elif ls "$T"/tmp/nvim-agent-req.* >/dev/null 2>&1; then ko "23 run en échec" "fichier de requête laissé"
else ok "23 run en échec : code 3, message, pas de nvim"; fi
unset FAKE_RUN_LOG

err_case "24a --create sans --agent" --create s --prompt p
err_case "24b --create avec claude" --agent claude --create s --prompt p
err_case "24c --create sans --prompt" --agent opencode --create s
err_case "24d --create + --resume" --agent opencode --create s --resume t --prompt p
err_case "24e --create + --last" --agent opencode --create s --last --prompt p
err_case "24f --create + --new" --agent opencode --create s --new --prompt p
err_case "24g --model sans --create" --agent opencode --model p/m
err_case "24h --create sans id" --agent opencode --create
err_case "24i --create id commençant par -" --agent opencode --create -x --prompt p
err_case "24k --title sans --create" --agent opencode --title T
err_case "24l --title sans valeur" --agent opencode --create s --prompt p --title
err_case "24j --model sans valeur" --agent opencode --create s --prompt p --model

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
