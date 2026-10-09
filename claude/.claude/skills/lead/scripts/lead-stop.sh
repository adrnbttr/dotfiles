#!/bin/bash
# Coupe la boucle /lead autonome de la session : supprime son fichier d'état.
# Usage : lead-stop.sh [--session <id>]  (repli : CLAUDE_CODE_SESSION_ID)
# N'écrit/supprime que dans $HOME/.claude/lead-state/. Toujours exit 0.

set -euo pipefail

SESSION_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session)
      if [[ $# -ge 2 ]] && [[ "$2" != -* ]]; then
        SESSION_ARG="$2"
        shift 2
      else
        echo "⚠ --session sans valeur, repli sur CLAUDE_CODE_SESSION_ID"
        shift
      fi
      ;;
    *)
      echo "⚠ argument ignoré : $1"
      shift
      ;;
  esac
done

SESSION_ID="${SESSION_ARG:-${CLAUDE_CODE_SESSION_ID:-}}"

if [[ -z "$SESSION_ID" ]] || [[ ! "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "⚠ identifiant de session absent ou invalide : rien à couper."
  exit 0
fi

STATE_FILE="$HOME/.claude/lead-state/$SESSION_ID.md"
if [[ -f "$STATE_FILE" ]]; then
  rm -f "$STATE_FILE" || true
  echo "Boucle /lead autonome coupée pour la session $SESSION_ID."
else
  echo "Aucune boucle /lead active pour la session $SESSION_ID."
fi

exit 0
