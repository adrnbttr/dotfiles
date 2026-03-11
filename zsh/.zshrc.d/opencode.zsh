# OpenCode dotfiles management aliases

alias ochelp='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode help }'
alias ocstatus='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode status }'
alias ocdoctor='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode doctor }'
alias ocmem='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode memory monitor }'
alias ocsetup='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode setup apply }'
alias ocenv='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode setup env }'
alias ocpush='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode sync push }'
alias ocpull='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode sync pull }'

# Full command shorthand (runs from repo root)
oc() {
  local repo_root="$HOME/Documents/GitHub/dotfiles"
  cd "$repo_root" && ./script/opencode "$@"
}

# Zsh completion for oc()
if [[ -n ${ZSH_VERSION-} ]]; then
  _oc() {
    local -a main_cmds setup_cmds memory_cmds sync_cmds
    main_cmds=(setup memory sync status doctor help)
    setup_cmds=(apply reset env help)
    memory_cmds=(monitor cleanup restart stats optimize help)
    sync_cmds=(push pull help)

    case "$words[2]" in
      setup)  compadd -a setup_cmds ;;
      memory) compadd -a memory_cmds ;;
      sync)   compadd -a sync_cmds ;;
      *)      compadd -a main_cmds ;;
    esac
  }
  compdef _oc oc
fi

# Source env.sh if it has content
if [[ -f "$HOME/.config/opencode/env.sh" ]]; then
  source "$HOME/.config/opencode/env.sh"
fi
