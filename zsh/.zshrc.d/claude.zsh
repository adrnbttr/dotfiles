# Claude Code dotfiles management aliases

# Sync shortcuts
alias ccpush='() { cd ~/Documents/GitHub/dotfiles && ./script/claude sync push }'
alias ccpull='() { cd ~/Documents/GitHub/dotfiles && ./script/claude sync pull }'

# Status / health
alias ccstatus='() { cd ~/Documents/GitHub/dotfiles && ./script/claude status }'
alias ccdoctor='() { cd ~/Documents/GitHub/dotfiles && ./script/claude doctor }'
alias cchelp='() { cd ~/Documents/GitHub/dotfiles && ./script/claude help }'

# Full command shorthand (runs from repo root)
cc() {
  local repo_root="$HOME/Documents/GitHub/dotfiles"
  cd "$repo_root" && ./script/claude "$@"
}

# Start claude, installing if missing
claude-start() {
  if command -v claude >/dev/null 2>&1; then
    claude
  else
    echo "claude CLI not found — installing..."
    cd ~/Documents/GitHub/dotfiles && ./script/install-claude
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
  echo "  Model   : claude-4.6-sonnet (via opencode)"
  echo ""
  echo "Claude Code (Official CLI)"
  echo "  Keymaps : <leader>z prefix"
  echo "  Commands: cchelp, ccstatus, ccpush, ccpull"
  echo "  Model   : claude-4.6-sonnet (direct, browser auth)"
  echo ""
  echo "Neovim keymaps:"
  echo "  <leader>at / <leader>zt   Toggle split"
  echo "  <leader>aa / <leader>za   Ask (input / selection)"
  echo "  <leader>ab / <leader>zb   Send buffer"
  echo "  <leader>zp                Paste selection"
  echo "  <leader>zh                Focus Claude split"
}
