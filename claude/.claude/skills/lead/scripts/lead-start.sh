#!/bin/bash
# Démarrage du mode /lead : affiche l'état de la session et, avec --autonome,
# écrit le fichier d'état lu par le hook Stop (hooks/stop-lead.sh).
# Sortie stdout injectée dans le contexte de Claude : rester court.
# Toujours exit 0 : une erreur d'argument ne doit pas casser le skill.

set -euo pipefail

SCENARIO="none"
AUTONOME=0
MAX_ITER=10
SESSION_ARG=""
SESSION_SEEN=0
WARNINGS=()

# Le skill passe les arguments en UNE chaîne quotée (anti-injection shell) :
# on découpe chaque élément sur les blancs avant le parsing.
ARGS=()
for a in "$@"; do
  read -ra PARTS <<< "$a" || true
  ARGS+=("${PARTS[@]+"${PARTS[@]}"}")
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# Vrai si le jeton est un drapeau ou un mot-clé connu (jamais pris comme valeur).
est_connu() {
  case "$1" in
    --autonome|--session|--max-iterations|factory|dev) return 0 ;;
    *) return 1 ;;
  esac
}

# Parsing des arguments, ordre libre.
while [[ $# -gt 0 ]]; do
  case "$1" in
    factory|dev)
      if [[ "$SCENARIO" != "none" ]] && [[ "$SCENARIO" != "$1" ]]; then
        WARNINGS+=("⚠ scénarios contradictoires, le dernier gagne : $1")
      fi
      SCENARIO="$1"
      shift
      ;;
    --autonome)
      AUTONOME=1
      shift
      ;;
    --session)
      if [[ $# -ge 2 ]] && [[ "$2" != -* ]] && ! est_connu "$2"; then
        if [[ $SESSION_SEEN -eq 1 ]]; then
          WARNINGS+=("⚠ --session en double ignoré")
        else
          SESSION_ARG="$2"
        fi
        SESSION_SEEN=1
        shift 2
      else
        WARNINGS+=("⚠ --session sans valeur, repli sur CLAUDE_CODE_SESSION_ID")
        shift
      fi
      ;;
    --max-iterations)
      if [[ $# -ge 2 ]] && ! est_connu "$2"; then
        # Validation par regex : 1 à 99999, sans zéro de tête.
        if [[ "$2" =~ ^[1-9][0-9]{0,4}$ ]]; then
          MAX_ITER="$2"
        else
          WARNINGS+=("⚠ --max-iterations attend un entier ≥ 1 (reçu : $2), défaut 10 conservé")
        fi
        shift 2
      else
        WARNINGS+=("⚠ --max-iterations sans valeur, défaut 10 conservé")
        shift
      fi
      ;;
    *)
      WARNINGS+=("⚠ argument ignoré : $1")
      shift
      ;;
  esac
done

case "$SCENARIO" in
  dev)     MODELE="Opus 5.5" ;;
  factory) MODELE="Sonnet 5.5" ;;
  *)       MODELE="non précisé (dis à Adrien quel scénario tu supposes)" ;;
esac

# --session prime sur la variable d'environnement.
SESSION_ID="${SESSION_ARG:-${CLAUDE_CODE_SESSION_ID:-}}"
STATE_DIR="$HOME/.claude/lead-state"
STATE_FILE=""
ID_VALIDE=0
REPLACED=0
SUPPRIME=0

if [[ -n "$SESSION_ID" ]] && [[ "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  ID_VALIDE=1
  STATE_FILE="$STATE_DIR/$SESSION_ID.md"
fi

if [[ $AUTONOME -eq 1 ]]; then
  if [[ -z "$SESSION_ID" ]]; then
    WARNINGS+=("⚠ mode autonome impossible : CLAUDE_CODE_SESSION_ID est vide")
    AUTONOME=0
  elif [[ $ID_VALIDE -eq 0 ]]; then
    WARNINGS+=("⚠ mode autonome impossible : identifiant de session invalide")
    AUTONOME=0
  elif [[ -e "$STATE_FILE" ]] && [[ ! -f "$STATE_FILE" ]]; then
    WARNINGS+=("⚠ mode autonome impossible : $STATE_FILE n'est pas un fichier ordinaire")
    AUTONOME=0
  fi
fi

if [[ $AUTONOME -eq 1 ]]; then
  if mkdir -p "$STATE_DIR" 2>/dev/null; then
    [[ -f "$STATE_FILE" ]] && REPLACED=1
    TMP="$STATE_FILE.tmp.$$"
    if {
      cat <<STATE
---
iteration: 1
max_iterations: $MAX_ITER
scenario: $SCENARIO
session_id: $SESSION_ID
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---
Boucle /lead autonome : reprends le plan à la première tâche non acceptée (en factory, le plan a d'abord été challengé par \`challenger\`), puis tests, relecture adverse par \`reviewer\`, rapport final. Écris <promise>LEAD DONE</promise> uniquement quand tout est vrai.
STATE
    } > "$TMP" 2>/dev/null && mv "$TMP" "$STATE_FILE" 2>/dev/null; then
      :
    else
      rm -f "$TMP" 2>/dev/null || true
      WARNINGS+=("⚠ mode autonome impossible : écriture de $STATE_FILE échouée")
      AUTONOME=0
    fi
  else
    WARNINGS+=("⚠ mode autonome impossible : création de $STATE_DIR échouée")
    AUTONOME=0
  fi
fi

# Mode non autonome : un état laissé par un lancement précédent ferait relancer
# le hook alors que la sortie dit « autonome : non ». On le supprime.
if [[ $AUTONOME -eq 0 ]] && [[ $ID_VALIDE -eq 1 ]] && [[ -f "$STATE_FILE" ]]; then
  if rm -f "$STATE_FILE" 2>/dev/null; then
    SUPPRIME=1
  fi
fi

for w in "${WARNINGS[@]+"${WARNINGS[@]}"}"; do
  echo "$w"
done

echo "Mode /lead"
echo "- scénario : $SCENARIO → modèle attendu : $MODELE"
if [[ $AUTONOME -eq 1 ]]; then
  echo "- autonome : oui, plafond $MAX_ITER itérations"
  if [[ $REPLACED -eq 1 ]]; then
    echo "- état précédent remplacé (nouveau départ, itération 1)"
  fi
  echo "- état : $STATE_FILE (couper : /lead-stop)"
else
  echo "- autonome : non"
  if [[ $SUPPRIME -eq 1 ]]; then
    echo "- état autonome précédent supprimé"
  fi
fi

exit 0
