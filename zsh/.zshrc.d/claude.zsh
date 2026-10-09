# Claude Code dotfiles management aliases

# Modèle de la session seule, sans toucher au réglage persistant (/model)
cc-factory() { claude --model opus "$@"; }   # import client : factory new, pipeline, databox, prod
cc-dev()     { claude --model fable "$@"; }  # nouveau développement, refonte, architecture

# Status / health
alias ccstatus='(cd ~/Documents/github/perso/dotfiles && ./script/claude status)'
alias ccdoctor='(cd ~/Documents/github/perso/dotfiles && ./script/claude doctor)'
alias cchelp='(cd ~/Documents/github/perso/dotfiles && ./script/claude help)'

# Full command shorthand (runs from repo root)
cc() {
  (cd "$HOME/Documents/github/perso/dotfiles" && ./script/claude "$@")
}

# Start claude, installing if missing
claude-start() {
  if command -v claude >/dev/null 2>&1; then
    claude
  else
    echo "claude CLI not found — installing..."
    (cd ~/Documents/github/perso/dotfiles && ./script/install-claude)
  fi
}

# Side-by-side overview of both AI assistants
ai-summary() {
  echo "AI Coding Assistants"
  echo "===================="
  echo ""
  echo "OpenCode (opencode.nvim)"
  echo "  Keymaps : <leader>a prefix"
  echo "  Commands: ochelp, ocstatus, ocpush, ocpull"
  echo "  Model   : user-chosen (model.json)"
  echo ""
  echo "Claude Code (Official CLI)"
  echo "  Keymaps : <leader>z prefix"
  echo "  Commands: cchelp, ccstatus, ccdoctor, cc-factory, cc-dev"
  echo "  Model   : fable par défaut ; cc-factory = opus, cc-dev = fable"
  echo "  Skills  : /lead, /lead-stop"
  echo ""
  echo "Neovim keymaps:"
  echo "  <leader>at / <leader>zt   Toggle split"
  echo "  <leader>aa / <leader>za   Ask (input / selection)"
  echo "  <leader>ab / <leader>zb   Send buffer"
  echo "  <leader>zp                Paste selection"
  echo "  <leader>zh                Focus Claude split"
}
