# OpenCode dotfiles management aliases

alias ochelp='(cd ~/Documents/github/perso/dotfiles && ./script/opencode help)'
alias ocstatus='(cd ~/Documents/github/perso/dotfiles && ./script/opencode status)'
alias ocdoctor='(cd ~/Documents/github/perso/dotfiles && ./script/opencode doctor)'
alias ocmem='(cd ~/Documents/github/perso/dotfiles && ./script/opencode memory monitor)'
alias ocsetup='(cd ~/Documents/github/perso/dotfiles && ./script/opencode setup apply)'
alias ocenv='(cd ~/Documents/github/perso/dotfiles && ./script/opencode setup env)'
alias ocpush='(cd ~/Documents/github/perso/dotfiles && ./script/opencode sync push)'
alias ocpull='(cd ~/Documents/github/perso/dotfiles && ./script/opencode sync pull)'

# Full command shorthand (runs from repo root)
oc() {
  (cd "$HOME/Documents/github/perso/dotfiles" && ./script/opencode "$@")
}

# Zsh completion for oc()
_oc() {
  local -a main_cmds setup_cmds memory_cmds sync_cmds
  main_cmds=(setup memory sync status doctor help)
  setup_cmds=(apply reset env help)
  memory_cmds=(monitor cleanup restart stats optimize help)
  sync_cmds=(push 'pull' 'pull --force' help)

  case "$words[2]" in
    setup)  compadd -a setup_cmds ;;
    memory) compadd -a memory_cmds ;;
    sync)   compadd -a sync_cmds ;;
    *)      compadd -a main_cmds ;;
  esac
}
compdef _oc oc

# Source env.sh if it has content
if [[ -f "$HOME/.config/opencode/env.sh" ]]; then
  source "$HOME/.config/opencode/env.sh"
fi
