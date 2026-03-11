# OpenCode dotfiles management aliases
# Add convenient shortcuts for managing opencode configuration

alias ochelp='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode help }'
alias ocstatus='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode status }'
alias ocdoctor='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode doctor }'

# Quick memory check
alias ocmem='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode memory monitor }'

# Setup shortcuts
alias ocsetup='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode setup apply }'
alias ocenv='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode setup env }'

# Sync shortcuts
alias ocpush='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode sync push }'
alias ocpull='() { cd ~/Documents/GitHub/dotfiles && ./script/opencode sync pull }'

# Complete command with auto-completion
oc() {
  local repo_root="$HOME/Documents/GitHub/dotfiles"
  cd "$repo_root" && ./script/opencode "$@"
}

# Auto-completion for oc command
_oc_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  
  main_commands="setup memory sync status doctor help"
  setup_commands="apply reset env help"
  memory_commands="monitor cleanup restart stats optimize help"
  sync_commands="push pull help"
  
  case "${prev}" in
    oc)
      COMPREPLY=( $(compgen -W "${main_commands}" -- "${cur}") )
      return 0
      ;;
    setup)
      COMPREPLY=( $(compgen -W "${setup_commands}" -- "${cur}") )
      return 0
      ;;
    memory)
      COMPREPLY=( $(compgen -W "${memory_commands}" -- "${cur}") )
      return 0
      ;;
    sync)
      COMPREPLY=( $(compgen -W "${sync_commands}" -- "${cur}") )
      return 0
      ;;
    *)
      ;;
  esac
}

# Register completion if available
if [[ -n ${ZSH_VERSION-} ]]; then
  autoload -U +X compinit && compinit
  compdef _gnu_generic oc 2>/dev/null || true
elif [[ -n ${BASH_VERSION-} ]]; then
  complete -F oc oc
fi

# Export environment variables if env.sh exists
if [[ -f "$HOME/.config/opencode/env.sh" ]]; then
  source "$HOME/.config/opencode/env.sh"
fi