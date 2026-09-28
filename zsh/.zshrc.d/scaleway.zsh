# Scaleway CLI helpers
# Alias et fonctions pour `scw`. AUCUN secret ici : le dépôt dotfiles est public.
# Les identifiants restent dans ~/.config/scw/ (hors dépôt, chmod 600).

# Garde : ne rien définir si scw n'est pas installé (comme les autres modules).
if ! command -v scw >/dev/null 2>&1; then
  return 0
fi

# --- Valeurs par défaut non sensibles ---------------------------------------
export SCW_DEFAULT_ZONE="${SCW_DEFAULT_ZONE:-fr-par-1}"
export SCW_DEFAULT_REGION="${SCW_DEFAULT_REGION:-fr-par}"

# --- Secrets locaux (hors dépôt) --------------------------------------------
# Fichier : ~/.config/scw/secrets.env  (chmod 600)
# Sur une nouvelle machine : décommente et renseigne les variables.
if [[ -f "$HOME/.config/scw/secrets.env" ]]; then
  source "$HOME/.config/scw/secrets.env"
fi

# --- Alias courts -----------------------------------------------------------
alias scwls='scw instance server list'
alias scwproj='scw account project list'
alias scworg='scw account organization list'
alias scwimg='scw instance image list'
alias scwvol='scw instance volume list'
alias scwip='scw instance ip list'

# --- Fonctions --------------------------------------------------------------
# Liste des serveurs : nom, état, zone, IP publique (via jq).
scwservers() {
  scw instance server list -o json \
    | jq -r '.[] | [.name, .state, .zone, (.public_ip.address // "-")] | @tsv'
}

# Démarrer / arrêter / SSH (acceptent un nom ou un id, zone par défaut).
scwstart() { scw instance server start "$@"; }
scwstop()  { scw instance server stop  "$@"; }
scwssh()   { scw instance ssh "$@"; }

# Aide résumée des raccourcis.
scwhelp() {
  print -P '%B%FScaleway CLI — raccourcis%f%b'
  print '  scwls            liste des serveurs'
  print '  scwservers       liste en tableau (jq)'
  print '  scwstart/stop    <serveur> démarrer/arrêter'
  print '  scwssh           <serveur> connexion SSH'
  print '  scwproj/scworg/scwimg/scwvol/scwip'
  print '  profils          scw -p <profil> <commande>'
  print '  config           ~/.config/scw/config.yaml'
}
