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

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git autojump jump fzf)

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

marvin_session() {
  local session="$HOME/.config/kitty/marvin-session.conf"
  nohup kitty --session "$session" >/dev/null 2>&1 &
  disown
  exit
}

github_session() {
  local root="${GITHUB_DIR:-$HOME/Documents/GitHub}"
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

alias vim='nvim'
alias g='git'

alias github-session='github_session'

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
  alias cd='z'
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
