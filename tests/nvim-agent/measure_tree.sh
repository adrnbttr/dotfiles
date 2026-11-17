#!/usr/bin/env bash
# Mesure (J-dot T4) : arbre de processus et pane_pid d'un agent lancé par nvim-agent dans tmux
# (pane_pid = le script nvim-agent, nvim en est un enfant : plus d'exec),
# comme le fera deck. Faux claude uniquement, serveur tmux privé (-L deck-test-jdot-$$), aucun réseau.
# Usage : tests/nvim-agent/measure_tree.sh   (sortie brute sur stdout, code 0 si les mesures ont abouti)
set -u
# shellcheck source=tests/nvim-agent/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SCRIPT="$ROOT/bin/.local/bin/nvim-agent"

SOCK="deck-test-jdot-$$"
tm() { tmux -L "$SOCK" "$@"; }
# shellcheck disable=SC2317  # appelée indirectement par trap EXIT (faux positif)
cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null
  rm -f "/tmp/tmux-$(id -u)/$SOCK"
  [ -n "${T:-}" ] && pkill -f -- "$T/bin/claude" 2>/dev/null
  rm -rf "$T"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# faux claude : imite un hook (sh -c 'echo $PPID'), note son pid et son comm, puis dort 30 s
rm -f "$T/bin/claude"
cat > "$T/bin/claude" <<SH
#!/usr/bin/env bash
d="\${FAKE_DIR:?}"
printf '%s\0' "\$@" | tr '\0' ' ' > "\$d/argv"
sh -c 'echo "\$PPID" > "\$1"' sh "\$d/hook_ppid"
echo \$\$ > "\$d/self_pid"
read -r c < /proc/\$\$/comm; echo "\$c" > "\$d/self_comm"
sleep 30 &
trap 'kill \$!; exit 143' TERM
wait
SH
chmod +x "$T/bin/claude"

# nvim visible (non headless) sur la config du worktree. Sans lazy.nvim, VeryLazy n'est jamais émis :
# l'init de test l'émet après VimEnter (simulation ; lazy.nvim et neo-tree réels ne sont pas exercés).
cat >> "$T/init.lua" <<'LUA'
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function()
  vim.schedule(function() vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" }) end)
end })
LUA
cat > "$T/bin/nvim-test" <<SH
#!/usr/bin/env bash
exec nvim -u "$T/init.lua" -i NONE "\$@"
SH
chmod +x "$T/bin/nvim-test"
export NVIM_AGENT_NVIM="$T/bin/nvim-test"
export TERM=xterm-256color
unset TMUX

wait_file() { local _; for _ in $(seq 1 100); do [ -s "$1" ] && return 0; sleep 0.1; done; return 1; }

descendants() { local p=$1 c; echo "$p"; for c in $(pgrep -P "$p"); do descendants "$c"; done; }

run_case() { # run_case <nom> <args nvim-agent...>
  local name=$1; shift
  local s="s-$name" d="$T/$name"
  mkdir -p "$d"
  export FAKE_DIR="$d"
  echo "=================== CAS $name : nvim-agent $*"
  tm new-session -d -x 120 -y 30 -s "$s" -c "$T" -e "DECK_TEST=1" -e "FAKE_DIR=$d" \
    -- env -C "$T" -- "$SCRIPT" "$@" || { echo "ECHEC new-session"; return 1; }
  wait_file "$d/self_pid" || { echo "ECHEC : faux claude jamais lancé"; tm capture-pane -p -t "$s" | head -10; return 1; }
  sleep 1
  local panepid claude nvimpid
  panepid=$(tm display -p -t "$s" '#{pane_pid}')
  claude=$(cat "$d/self_pid")
  nvimpid=$(pgrep -P "$panepid" -x nvim | head -1)   # nvim, enfant direct du script (pane_pid)
  echo "--- 1. pane_pid=$panepid ; comm(pane_pid)=$(cat "/proc/$panepid/comm") ; pid du nvim enfant direct de pane_pid=${nvimpid:-aucun}"
  echo "--- argv reçu par le faux claude : $(cat "$d/argv")"
  echo "--- 2. arbre sous le pane"
  ps -o pid,ppid,sid,comm,args --forest -p "$(descendants "$panepid" | paste -sd,)" | cut -c1-120
  echo "--- 3. hook \$PPID=$(cat "$d/hook_ppid") ; pid faux claude=$claude ; comm=$(cat "$d/self_comm") ; ppid du faux claude=$(ps -o ppid= -p "$claude" | tr -d ' ') (comm $(cat /proc/"$(ps -o ppid= -p "$claude" | tr -d ' ')"/comm))"
  echo "--- 5. capture-pane (10 premières lignes)"
  tm capture-pane -p -t "$s" | head -10
  echo "--- 4. kill du faux claude ($claude)"
  kill "$claude"; sleep 1.5
  echo "nvim vivant : $(kill -0 "$panepid" 2>/dev/null && echo oui || echo non) ; session : $(tm has-session -t "$s" 2>/dev/null && echo oui || echo non)"
  echo "pane_dead=$(tm display -p -t "$s" '#{pane_dead}' 2>/dev/null) ; sleep orphelin : $(pgrep -fx 'sleep 30' >/dev/null && echo oui || echo non)"
  echo "--- capture après kill (10 premières lignes)"
  tm capture-pane -p -t "$s" 2>/dev/null | head -10
  pkill -P "$claude" 2>/dev/null
  tm kill-session -t "$s" 2>/dev/null
}

rc=0
run_case prompt --agent claude --prompt "bonjour deck" -- --settings /tmp/f.json || rc=1
run_case resume --resume abc -- --settings /tmp/f.json || rc=1
exit $rc
