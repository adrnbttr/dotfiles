# Fly.io CLI helpers
# Alias, fonctions et autocomplétion pour `fly` / `flyctl`.

if ! command -v fly >/dev/null 2>&1; then
  return 0
fi

# --- Autocomplétion ---------------------------------------------------------
# fly génère la complétion pour `flyctl` ; on l'associe aussi à `fly`.
if [[ -o interactive ]]; then
  eval "$(fly completion zsh)" 2>/dev/null || true
  compdef _flyctl fly 2>/dev/null || true
fi

# --- Alias courts -----------------------------------------------------------
alias flywho='fly auth whoami'
alias flyapps='fly apps list'
alias flymp='fly machine list'
alias flystatus='fly status'
alias flylogs='fly logs'
alias flyssh='fly ssh console'
alias flysecrets='fly secrets list'
alias flyvolumes='fly volumes list'
alias flydeploy='fly deploy'

# --- Aide -------------------------------------------------------------------
flyhelp() {
  print -P '%B%FFly.io CLI — raccourcis%f%b'
  print '  flywho       compte connecté'
  print '  flyapps      liste des applications'
  print '  flymp        liste des machines'
  print '  flystatus    statut d une application'
  print '  flylogs      journaux'
  print '  flyssh       console SSH'
  print '  flysecrets   variables secrètes'
  print '  flyvolumes   volumes'
  print '  flydeploy    déployer'
}
