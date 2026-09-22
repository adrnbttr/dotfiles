# If you come from bash you might have to change your $PATH.
export PATH="$HOME/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

# Allow using Ctrl-S in terminal apps (disable XON/XOFF flow control).
if [[ -t 0 ]] && command -v stty >/dev/null 2>&1; then
  stty -ixon 2>/dev/null || true
fi

# Path to your oh-my-zsh installation.
: "${ZSH:=$HOME/.oh-my-zsh}"

# Keep all customizations out of the OMZ git repo to allow `omz update`.
: "${ZSH_CUSTOM:=${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-zsh}"

# Extra Zsh plugins live outside this repo (installed by ./script/bootstrap).
ZSH_PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

DEFAULT_USER="adrien"

# History (portable + shared)
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}" 2>/dev/null || true
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# Theme provided by this dotfiles repo (stowed into $ZSH_CUSTOM).
if [[ -f "$ZSH_CUSTOM/themes/adrien-agnoster.zsh-theme" ]]; then
  ZSH_THEME="adrien-agnoster"
else
  ZSH_THEME="agnoster"
fi

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git fzf)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

fzf_edit() {
  local file
  local bat_cmd=""
  if command -v bat >/dev/null 2>&1; then
    bat_cmd="bat"
  elif command -v batcat >/dev/null 2>&1; then
    bat_cmd="batcat"
  fi

  if [[ -n "$bat_cmd" ]]; then
    file=$(fzf --preview="$bat_cmd --style=numbers --color=always --line-range=:500 {}" --height 40%)
  else
    file=$(fzf --height 40%)
  fi
  if [[ -n "$file" ]]; then
    nvim "$file"
  fi
}
alias fe='fzf_edit'

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Google Cloud SDK (support both the standard install path and older Downloads-based installs)
if [[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]]; then
  source "$HOME/google-cloud-sdk/path.zsh.inc"
elif [[ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]]; then
  source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
fi

if [[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]]; then
  source "$HOME/google-cloud-sdk/completion.zsh.inc"
elif [[ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]]; then
  source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"
fi

v() {
  nvim "$1"
}

# Isolation par worktree pour marvin-suite (MAR-868/869) : chaque worktree
# obtient ports + DB `marvin_dev_<nom>` isolés. Opt-in requis, sinon DB/ports
# partagés. Indispensable pour faire tourner plusieurs worktrees en parallèle.
export MARVIN_WORKTREE_ISOLATION=1

# --- Helpers WezTerm (équivalents de `kitty @`) ---
# Vrai si on tourne dans WezTerm avec la CLI joignable. Sous WSL (WezTerm
# Windows), la CLI est wezterm.exe, appelée via l'interop Windows.
_in_wezterm() {
  [[ -n "${WEZTERM_PANE:-}" || "${TERM_PROGRAM:-}" == "WezTerm" ]] || return 1
  if command -v wezterm >/dev/null 2>&1; then
    _WEZ_BIN=wezterm
  elif command -v wezterm.exe >/dev/null 2>&1; then
    _WEZ_BIN=wezterm.exe
  else
    return 1
  fi
}

_wezcli() {
  command "${_WEZ_BIN:-wezterm}" cli "$@"
}

# TERM=wezterm (soulignement ondulé dans nvim) n'existe pas sur les serveurs
# distants : on retombe sur xterm-256color pour ssh.
if [[ "$TERM" == "wezterm" ]]; then
  alias ssh='TERM=xterm-256color ssh'
fi

# Chaque session vit dans son propre workspace WezTerm (de, ms, github,
# marvin) : on bascule entre elles avec ctrl+shift+s sans rien fermer.
# Relancer une session n'ajoute que les onglets manquants (nouveaux worktrees)
# puis bascule dessus ; les onglets existants (nvim, Claude...) sont conservés.
#
# Ordre important : on bascule d'abord l'interface sur le workspace, puis on
# crée onglets et splits dans la fenêtre affichée. Créés dans une fenêtre
# cachée, ils héritent d'une taille périmée (80x24 ou taille d'une ancienne
# interface) et le split 70/30 est faux, voire le bas du split hors écran.
#
# _wez_ws_begin <workspace> prépare les variables lues par les helpers
# suivants ; elles doivent être déclarées `local` dans l'appelant :
#   local _wez_ws _wez_win _wez_titles _wez_first _wez_placeholder
_wez_ws_begin() {
  _wez_ws="$1"
  _wez_win=""
  _wez_first=""
  _wez_placeholder=""
  local json i
  if ! json=$(_wezcli list --format json 2>/dev/null); then
    echo "wezterm: CLI injoignable (wezterm cli list)" >&2
    return 1
  fi
  _wez_win=$(_wez_ws_window "$json")
  # Titres sans l'espace de marge ajouté par _wez_tab.
  _wez_titles=$(jq -r --arg ws "$_wez_ws" '.[] | select(.workspace == $ws) | .tab_title | rtrimstr(" ")' <<<"$json")

  # Bascule via une user var interceptée par wezterm.lua ("user-var-changed").
  # Un workspace inexistant est créé par l'interface avec un shell temporaire,
  # fermé par _wez_ws_finish une fois les vrais onglets ouverts.
  printf '\033]1337;SetUserVar=switch_workspace=%s\007' "$(print -rn -- "$_wez_ws" | base64 | tr -d '\n')" >/dev/tty
  if [[ -z "$_wez_win" ]]; then
    for i in {1..30}; do
      sleep 0.1
      json=$(_wezcli list --format json 2>/dev/null)
      _wez_win=$(_wez_ws_window "$json")
      [[ -n "$_wez_win" ]] && break
    done
    _wez_placeholder=$(jq -r --arg ws "$_wez_ws" 'first(.[] | select(.workspace == $ws) | .pane_id) // empty' <<<"$json")
  else
    # Laisse l'interface redimensionner la fenêtre qu'elle vient d'afficher.
    sleep 0.3
  fi
  if [[ -z "$_wez_win" ]]; then
    echo "wezterm: impossible d'ouvrir le workspace '$_wez_ws'" >&2
    return 1
  fi
}

# window_id du workspace courant dans le JSON de `wezterm cli list`.
_wez_ws_window() {
  jq -r --arg ws "$_wez_ws" 'first(.[] | select(.workspace == $ws) | .window_id) // empty' <<<"$1"
}

# Vrai si le workspace courant a déjà un onglet portant ce titre.
_wez_has_tab() {
  [[ -n "$_wez_titles" ]] && (( ${${(f)_wez_titles}[(Ie)$1]} ))
}

# Ouvre un onglet titré dans la fenêtre du workspace. pane_id dans $REPLY.
#   Usage : _wez_tab <cwd> <titre> [commande...]
_wez_tab() {
  local cwd="$1" title="$2"
  shift 2
  (( $# > 0 )) && set -- -- "$@"
  REPLY=$(_wezcli spawn --window-id "$_wez_win" --cwd "$cwd" "$@" 2>/dev/null)
  [[ -n "$REPLY" ]] || return 1
  : "${_wez_first:=$REPLY}"
  # Espace final : marge entre le texte et le bord droit de l'onglet (la barre
  # native de WezTerm n'a pas de réglage de padding).
  _wezcli set-tab-title --pane-id "$REPLY" "$title " >/dev/null 2>&1
}

# Titre court pour un onglet de worktree : sans le préfixe du workspace
# ("de-", "ms-", déjà affiché à droite de la barre) et limité à 14 caractères,
# pour que ~11 onglets tiennent sans que WezTerm ne tronque les titres.
#   Usage : _wez_short_title <prefixe> <nom>   (résultat dans $REPLY)
_wez_short_title() {
  REPLY="${2#${1}-}"
  REPLY="${REPLY[1,14]}"
}

# Ajoute un terminal en bas du pane donné (pourcentage = hauteur du bas).
#   Usage : _wez_split_bottom <pane_id> <cwd> [percent]
_wez_split_bottom() {
  _wezcli split-pane --pane-id "$1" --bottom --percent "${3:-50}" --cwd "$2" >/dev/null 2>&1
}

# Ferme le shell temporaire (si de vrais onglets ont été ouverts) et active
# le premier onglet créé.
_wez_ws_finish() {
  if [[ -n "$_wez_placeholder" && -n "$_wez_first" ]]; then
    _wezcli kill-pane --pane-id "$_wez_placeholder" >/dev/null 2>&1
  fi
  [[ -n "$_wez_first" ]] && _wezcli activate-pane --pane-id "$_wez_first" >/dev/null 2>&1
  return 0
}

# Session Marvin statique : un onglet par projet actif (cf. marvin-session.conf).
marvin_session() {
  if _in_wezterm; then
    local base="$HOME/Documents/github/marvin"
    local -a projects=(
      "Data Engineering:$base/data-engineering"
      "Marvin Suite:$base/marvin-suite"
      "Keystone:$base/keystone"
    )
    local _wez_ws _wez_win _wez_titles _wez_first _wez_placeholder entry
    _wez_ws_begin "marvin" || return 1
    for entry in $projects; do
      _wez_has_tab "${entry%%:*}" && continue
      _wez_tab "${entry#*:}" "${entry%%:*}" && _wez_split_bottom "$REPLY" "${entry#*:}"
    done
    _wez_has_tab "Marvin" || _wez_tab "$base" "Marvin"
    _wez_ws_finish
    return 0
  fi

  local session="$HOME/.config/kitty/marvin-session.conf"
  if [[ ! -f "$session" ]]; then
    echo "marvin-session: session file not found: $session" >&2
    return 1
  fi
  nohup kitty --session "$session" >/dev/null 2>&1 &
  disown
  return 0
}

github_session() {
  local root="${GITHUB_DIR:-$HOME/Documents/github/perso}"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/kitty"
  local session="$state_dir/github-session.conf"

  if [[ ! -d "$root" ]]; then
    echo "github-session: directory not found: $root" >&2
    return 1
  fi

  mkdir -p "$state_dir" 2>/dev/null || true

  local -a repos
  local d
  for d in "$root"/*(N/); do
    if [[ -d "$d/.git" ]]; then
      repos+=("$d")
    fi
  done

  if (( ${#repos} == 0 )); then
    echo "github-session: no git repos found under $root" >&2
    return 1
  fi

  # Sort tabs by most recent commit (descending)
  local -a scored
  local repo ts
  local delim=$'\x1f'
  for repo in $repos; do
    ts=$(git -C "$repo" log -1 --format=%ct 2>/dev/null)
    if [[ -z "$ts" ]]; then
      ts=0
    fi
    scored+=("${ts}${delim}${repo}")
  done

  local -a sorted
  sorted=(${(f)"$(printf '%s\n' "${scored[@]}" | LC_ALL=C sort -t "$delim" -k1,1nr -k2,2)"})

  repos=()
  local line
  for line in $sorted; do
    repos+=("${line#*${delim}}")
  done

  # Dans WezTerm : même logique via `wezterm cli`.
  if _in_wezterm; then
    local _wez_ws _wez_win _wez_titles _wez_first _wez_placeholder
    _wez_ws_begin "github" || return 1
    for repo in $repos; do
      _wez_has_tab "${repo:t}" && continue
      _wez_tab "$repo" "${repo:t}" zsh -ic 'nvim; exec zsh -i'
    done
    if [[ -z "$_wez_win" ]]; then
      echo "github-session: failed to create any tabs via wezterm cli" >&2
      return 1
    fi
    _wez_ws_finish
    return 0
  fi

  # If running inside kitty, use remote control to create tabs in the
  # current OS window (no new kitty process, no hard exit).
  if [[ -n "${KITTY_WINDOW_ID:-}" ]] && kitty @ ls >/dev/null 2>&1; then
    local created=0
    local repo name
    for repo in $repos; do
      name="${repo:t}"
      if kitty @ launch --type=tab --location=last --cwd "$repo" --tab-title "$name" --keep-focus --no-response --copy-env \
        zsh -ic 'nvim; exec zsh -i' >/dev/null 2>&1; then
        (( created++ ))
      fi
    done

    if (( created > 0 )); then
      # Close the tab we launched from to leave only the generated tabs.
      kitty @ close-tab --match "window_id:${KITTY_WINDOW_ID}" >/dev/null 2>&1 || true
    else
      echo "github-session: failed to create any tabs via kitty remote control" >&2
      return 1
    fi

    return 0
  fi

  {
    echo "# Autogenerated by github-session"
    echo "# Root: $root"
    local repo name
    for repo in $repos; do
      name="${repo:t}"
      echo
      echo "new_tab \"$name\""
      echo "cd $repo"
      echo "launch --copy-env zsh -ic 'nvim; exec zsh -i'"
    done
  } >| "$session"

  nohup kitty --session "$session" >/dev/null 2>&1 &
  disown
  return 0
}

# Helper générique : ouvre un onglet kitty par worktree d'un dépôt (dossiers
# qui partagent le .git du dépôt principal). Titre de l'onglet = nom du dossier.
# Les worktrees mergés/supprimés disparaissent naturellement de la session.
# Onglets : dépôt principal (nvim) → racine atelier (shell nu) → worktrees (nvim).
# Chaque onglet nvim est splitté : nvim ~70% en haut, terminal ~30% en bas.
#   Usage : _marvin_wt_session <label> <main_repo> <wt_root>
_marvin_wt_session() {
  local label="$1"
  local main_repo="$2"
  local wt_root="$3"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/kitty"
  local session="$state_dir/${label}.conf"

  if [[ ! -d "$wt_root" ]]; then
    echo "${label}: directory not found: $wt_root" >&2
    return 1
  fi

  mkdir -p "$state_dir" 2>/dev/null || true

  # Collecte les worktrees : un worktree partage le .git du dépôt principal,
  # donc son .git est un *fichier* (pas un dossier). On teste -e, pas -d.
  local -a worktrees
  local d
  for d in "$wt_root"/*(N/); do
    if [[ -e "$d/.git" ]]; then
      worktrees+=("$d")
    fi
  done

  # Trie les worktrees par date du dernier commit (décroissant).
  if (( ${#worktrees} > 0 )); then
    local -a scored
    local repo ts
    local delim=$'\x1f'
    for repo in $worktrees; do
      ts=$(git -C "$repo" log -1 --format=%ct 2>/dev/null)
      if [[ -z "$ts" ]]; then
        ts=0
      fi
      scored+=("${ts}${delim}${repo}")
    done

    local -a sorted
    sorted=(${(f)"$(printf '%s\n' "${scored[@]}" | LC_ALL=C sort -t "$delim" -k1,1nr -k2,2)"})

    worktrees=()
    local line
    for line in $sorted; do
      worktrees+=("${line#*${delim}}")
    done
  fi

  # Liste finale : dépôt principal (main) d'abord, puis la racine des worktrees
  # (onglet "atelier" pour lancer new-worktree.sh / rm-worktree.sh), puis les
  # worktrees triés. La racine reçoit un shell nu ; le reste ouvre nvim.
  local -a repos
  if [[ -e "$main_repo/.git" ]]; then
    repos+=("$main_repo")
  fi
  repos+=("$wt_root")
  if (( ${#worktrees} > 0 )); then
    repos+=("${worktrees[@]}")
  fi

  if (( ${#repos} == 0 )); then
    echo "${label}: aucun worktree sous $wt_root (et pas de dépôt principal à $main_repo)" >&2
    return 1
  fi

  # Dans WezTerm : un workspace par session ("de", "ms"), onglets manquants
  # seulement. Le split se fait directement en 70/30 (--percent 30 en bas).
  if _in_wezterm; then
    local _wez_ws _wez_win _wez_titles _wez_first _wez_placeholder name
    _wez_ws_begin "${label%-session}" || return 1
    for repo in $repos; do
      if [[ "$repo" == "$wt_root" ]]; then
        name="atelier"
      else
        _wez_short_title "$_wez_ws" "${repo:t}"
        name="$REPLY"
      fi
      _wez_has_tab "$name" && continue
      if [[ "$repo" == "$wt_root" ]]; then
        _wez_tab "$repo" "$name"
      elif _wez_tab "$repo" "$name" zsh -ic 'nvim; exec zsh -i'; then
        _wez_split_bottom "$REPLY" "$repo" 30
      fi
    done

    if [[ -z "$_wez_win" ]]; then
      echo "${label}: échec de création des onglets via wezterm cli" >&2
      return 1
    fi
    _wez_ws_finish
    return 0
  fi

  # Dans kitty : remote control pour créer les onglets dans la fenêtre courante
  # (pas de nouveau process kitty, pas d'exit brutal).
  if [[ -n "${KITTY_WINDOW_ID:-}" ]] && kitty @ ls >/dev/null 2>&1; then
    local created=0
    local repo name top_id bottom_id rows dec
    for repo in $repos; do
      name="${repo:t}"
      if [[ "$repo" == "$wt_root" ]]; then
        # Onglet atelier : un shell nu plein écran pour lancer les scripts.
        if kitty @ launch --type=tab --location=last --cwd "$repo" --tab-title "$name" --keep-focus --no-response --copy-env >/dev/null 2>&1; then
          (( created++ ))
        fi
      else
        # Haut : nvim. On capture le window_id pour cibler ensuite cet onglet.
        top_id=$(kitty @ launch --type=tab --location=last --cwd "$repo" --tab-title "$name" --keep-focus --copy-env \
          zsh -ic 'nvim; exec zsh -i' 2>/dev/null)
        if [[ -n "$top_id" ]]; then
          (( created++ ))
          # Hauteur de nvim tant qu'il est seul = hauteur totale de l'onglet.
          rows=$(kitty @ ls 2>/dev/null | jq -r --argjson wid "$top_id" 'first(.[].tabs[].windows[] | select(.id==$wid) | .lines) // empty' 2>/dev/null)
          # Passe l'onglet en layout splits, puis ajoute le terminal en bas.
          kitty @ goto-layout --match "window_id:$top_id" splits >/dev/null 2>&1
          bottom_id=$(kitty @ launch --location=hsplit --match "window_id:$top_id" --cwd "$repo" --keep-focus --copy-env 2>/dev/null)
          # Le split est 50/50 ; on réduit le terminal de ~20% pour viser 30/70.
          if [[ -n "$bottom_id" && "$rows" == <-> ]] && (( rows > 0 )); then
            (( dec = rows / 5 ))
            (( dec < 1 )) && dec=1
            kitty @ resize-window --match "id:$bottom_id" --axis vertical --increment "-$dec" >/dev/null 2>&1
          fi
        fi
      fi
    done

    if (( created > 0 )); then
      # Ferme l'onglet de lancement pour ne laisser que les onglets générés.
      kitty @ close-tab --match "window_id:${KITTY_WINDOW_ID}" >/dev/null 2>&1 || true
    else
      echo "${label}: échec de création des onglets via kitty remote control" >&2
      return 1
    fi

    return 0
  fi

  # Hors kitty : on écrit un fichier de session et on lance un nouveau kitty.
  {
    echo "# Autogenerated by ${label}"
    echo "# Worktrees: $wt_root"
    local repo name
    for repo in $repos; do
      name="${repo:t}"
      echo
      echo "new_tab \"$name\""
      echo "cd $repo"
      if [[ "$repo" == "$wt_root" ]]; then
        echo "launch --copy-env"
      else
        # Onglet splitté : nvim en haut, terminal (même dossier) en bas.
        echo "layout splits"
        echo "launch --copy-env zsh -ic 'nvim; exec zsh -i'"
        echo "launch --location=hsplit --copy-env"
      fi
    done
  } >| "$session"

  nohup kitty --session "$session" >/dev/null 2>&1 &
  disown
  return 0
}

# Worktrees data-engineering (dossiers de-* sous data-engineering-wt/).
de_session() {
  _marvin_wt_session "de-session" \
    "${DE_MAIN_DIR:-$HOME/Documents/github/marvin/data-engineering}" \
    "${DE_WT_DIR:-$HOME/Documents/github/marvin/data-engineering-wt}"
}

# Worktrees marvin-suite (dossiers ms-* sous marvin-suite-wt/).
ms_session() {
  _marvin_wt_session "ms-session" \
    "${MS_MAIN_DIR:-$HOME/Documents/github/marvin/marvin-suite}" \
    "${MS_WT_DIR:-$HOME/Documents/github/marvin/marvin-suite-wt}"
}

alias vim='nvim'
alias g='git'

alias marvin-session='marvin_session'
alias github-session='github_session'
alias de-session='de_session'
alias ms-session='ms_session'

alias gs='git status'
alias gd='git diff'

# Debian/Ubuntu-style command names
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  alias fd='fdfind'
fi

if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  alias bat='batcat'
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Auto-switch Node version on directory change when an .nvmrc is present.
# Adapted from https://github.com/nvm-sh/nvm#zsh
if typeset -f nvm_find_nvmrc >/dev/null 2>&1; then
  autoload -U add-zsh-hook
  load-nvmrc() {
    local nvmrc_path nvmrc_node_version
    nvmrc_path="$(nvm_find_nvmrc)"
    if [[ -n "$nvmrc_path" ]]; then
      nvmrc_node_version=$(nvm version "$(cat "$nvmrc_path")")
      if [[ "$nvmrc_node_version" == "N/A" ]]; then
        nvm install
      elif [[ "$nvmrc_node_version" != "$(nvm version)" ]]; then
        nvm use
      fi
    elif [[ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ]] && [[ "$(nvm version)" != "$(nvm version default)" ]]; then
      echo "Reverting to nvm default version"
      nvm use default
    fi
  }
  add-zsh-hook chpwd load-nvmrc
  load-nvmrc
fi

# micromamba (only if installed)
if [[ -x "$HOME/.micromamba/bin/micromamba" ]]; then
  export MAMBA_EXE="$HOME/.micromamba/bin/micromamba"
  export MAMBA_ROOT_PREFIX="$HOME/micromamba"
  __mamba_setup="$($MAMBA_EXE shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__mamba_setup"
  fi
  unset __mamba_setup
fi

# pyenv (only if installed)
if [[ -x "$HOME/.pyenv/bin/pyenv" && ":$PATH:" != *":$HOME/.pyenv/bin:"* ]]; then
  export PATH="$HOME/.pyenv/bin:$PATH"
fi

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  if pyenv commands 2>/dev/null | command grep -qx "virtualenv-init"; then
    eval "$(pyenv virtualenv-init -)"
  fi
fi

# Added by flyctl installer
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# opencode
opencode_bin="$HOME/.opencode/bin"
if [[ -d "$opencode_bin" && ":$PATH:" != *":$opencode_bin:"* ]]; then
  export PATH="$opencode_bin:$PATH"
fi

# Optional Zsh enhancements (installed by ./script/bootstrap)
if [[ -f "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  source "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh"
fi

if [[ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [[ -f "$ZSH_PLUGIN_DIR/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
  source "$ZSH_PLUGIN_DIR/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

# Shell extensions from dotfiles (aliases for opencode, claude, etc.)
for _f in "$HOME/.zshrc.d"/*.zsh; do [[ -r "$_f" ]] && source "$_f"; done
unset _f

# Per-machine overrides (not tracked)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Modern terminal tools configuration

# eza: modern replacement for ls with icons and colors
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto'
  alias ll='eza -l --icons=auto'
  alias la='eza -la --icons=auto'
  alias lt='eza --tree --icons=auto'
  alias llt='eza -l --tree --icons=auto'
fi

# zoxide: smarter cd command with fuzzy matching
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  # Wrap zoxide's z so `cd documents` resolves case-insensitively to
  # `Documents` in the current directory even when it's not yet in zoxide's
  # frecency database. Preserves zoxide behaviour for '-', bare 'cd', and
  # existing paths; falls back to fuzzy frecency lookup for everything else.
  cd() {
    if [[ $# -eq 0 ]] || [[ "$1" == -* ]] || [[ -d "$1" ]]; then
      __zoxide_z "$@"
      return
    fi
    setopt localoptions nocaseglob nullglob
    local -a matches
    matches=( "${1}"(/) )
    if (( ${#matches[@]} == 1 )); then
      __zoxide_z "${matches[1]}"
      return
    fi
    __zoxide_z "$@"
  }
  alias cdi='zi'
fi

# delta: syntax-highlighting pager for git and diff output
if command -v delta >/dev/null 2>&1; then
  export GIT_PAGER=delta
  export DELTA_FEATURES='side-by-side line-numbers decorations'
fi

# bottom: modern system monitor (btm)
if command -v btm >/dev/null 2>&1; then
  alias top='btm'
  alias htop='btm'
fi

# Scaleway CLI autocomplete initialization.
eval "$(scw autocomplete script shell=zsh)"
eval "$(direnv hook zsh)"
