# GitHub CLI helpers
# Alias, fonctions et autocomplétion pour `gh`.

if ! command -v gh >/dev/null 2>&1; then
  return 0
fi

# --- Autocomplétion ---------------------------------------------------------
eval "$(gh completion -s zsh)" 2>/dev/null || true

# --- Alias courts -----------------------------------------------------------
alias ghwho='gh auth status'
alias ghprs='gh pr list'
alias ghprc='gh pr create'
alias ghprv='gh pr view --web'
alias ghco='gh pr checkout'
alias ghissues='gh issue list'
alias ghissuec='gh issue create'
alias ghrepo='gh repo view --web'
alias ghrepos='gh repo list'
alias ghclone='gh repo clone'
alias ghruns='gh run list'
alias ghrunw='gh run watch'
alias ghnew='gh repo create'

# --- Aide -------------------------------------------------------------------
ghhelp() {
  print -P '%B%FGitHub CLI — raccourcis%f%b'
  print '  ghwho       état de connexion'
  print '  ghprs       liste des pull requests'
  print '  ghprc       créer une pull request'
  print '  ghprv       ouvrir la PR dans le navigateur'
  print '  ghco        checkout d une PR'
  print '  ghissues    liste des issues'
  print '  ghissuec    créer une issue'
  print '  ghrepo      ouvrir le dépôt dans le navigateur'
  print '  ghrepos     liste de mes dépôts'
  print '  ghclone     cloner un dépôt'
  print '  ghruns      liste des workflows'
  print '  ghrunw      suivre un workflow'
  print '  ghnew       créer un dépôt'
}
