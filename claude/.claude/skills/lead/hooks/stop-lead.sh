#!/bin/bash
# Hook Stop du skill /lead : relance Claude tant que la promesse
# <promise>LEAD DONE</promise> n'est pas livrée et que le plafond n'est pas atteint.
# Patron : plugin Ralph. Écrit uniquement dans $HOME/.claude/lead-state/.
# Règle : ne jamais planter ni bloquer sans pouvoir raisonner → exit 0 partout.

set -euo pipefail

HOOK_INPUT=$(cat || true)

# 1. jq indispensable ; sans lui, on laisse passer.
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠ Boucle /lead : jq absent, hook inactif" >&2
  exit 0
fi

SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
# Identifiant vide ou suspect (pas de chemin) : rien à faire.
if [[ -z "$SESSION_ID" ]] || [[ ! "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  exit 0
fi

# 2. Pas de fichier d'état : session sans boucle (ou autre session).
STATE_FILE="$HOME/.claude/lead-state/$SESSION_ID.md"
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Premier bloc de frontmatter uniquement (le texte de relance peut contenir ---).
FRONTMATTER=$(awk '/^---$/{i++; next} i==1' "$STATE_FILE" 2>/dev/null || true)
fm_get() { printf '%s\n' "$FRONTMATTER" | grep "^$1:" | head -n1 | sed "s/^$1: *//" || true; }

# F. Tâche en arrière-plan en cours : le lead attend un sous-agent, pas une fin.
EN_COURS=$(printf '%s' "$HOOK_INPUT" | jq -r '[.background_tasks[]? | select(.status == "running")] | length' 2>/dev/null || echo 0)
if [[ "$EN_COURS" =~ ^[0-9]+$ ]] && [[ "$EN_COURS" -gt 0 ]]; then
  exit 0
fi

# 3. Validation numérique.
ITERATION=$(fm_get iteration)
MAX_ITERATIONS=$(fm_get max_iterations)

if [[ ! "$ITERATION" =~ ^[0-9]{1,9}$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]{1,9}$ ]]; then
  echo "⚠ Boucle /lead : état corrompu (iteration='$ITERATION', max_iterations='$MAX_ITERATIONS'), boucle arrêtée. Relance /lead --autonome." >&2
  rm -f "$STATE_FILE" || true
  exit 0
fi
ITERATION=$((10#$ITERATION))
MAX_ITERATIONS=$((10#$MAX_ITERATIONS))

# 4. Plafond.
if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Boucle /lead : plafond de $MAX_ITERATIONS itérations atteint, arrêt."
  rm -f "$STATE_FILE" || true
  exit 0
fi

# 5. Dernier message assistant : champ direct, sinon repli sur le transcript.
LAST_OUTPUT=$(printf '%s' "$HOOK_INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)

if [[ -z "$LAST_OUTPUT" ]]; then
  TRANSCRIPT_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Chaque bloc de contenu est une ligne JSONL distincte : on borne aux
    # 100 dernières lignes assistant, on parse ligne à ligne (une ligne cassée
    # est ignorée) et on garde le dernier bloc texte.
    LAST_OUTPUT=$( (grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null || true) | tail -n 100 \
      | jq -R -n -r '[inputs | fromjson? | (.message.content // [])[]? | select(type == "object" and .type == "text") | .text] | last // ""' 2>/dev/null || true)
  fi
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "⚠ Boucle /lead : dernier message assistant illisible, pas de relance" >&2
  exit 0
fi

# 6. Promesse : seule la DERNIÈRE ligne non vide compte (espaces normalisés).
# Texte passé par stdin : --arg échoue sur les très gros messages.
PROMESSE=$(printf '%s' "$LAST_OUTPUT" | jq -R -s -r '
  split("\n") | map(gsub("\\s+"; " ") | gsub("^ | $"; "")) | map(select(length > 0))
  | (last // "") | test("^<promise> ?LEAD DONE ?</promise>$")
' 2>/dev/null || echo false)

if [[ "$PROMESSE" == "true" ]]; then
  echo "✅ Boucle /lead : promesse livrée, arrêt."
  rm -f "$STATE_FILE" || true
  exit 0
fi

# 7. Relance : texte après le second --- (les --- suivants en font partie).
PROMPT_TEXT=$(awk 'i>=2{print; next} /^---$/{i++}' "$STATE_FILE" 2>/dev/null || true)
if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠ Boucle /lead : état corrompu (texte de relance absent), boucle arrêtée." >&2
  rm -f "$STATE_FILE" || true
  exit 0
fi

# Incrément atomique, limité à la ligne iteration: du premier frontmatter.
NEXT=$((ITERATION + 1))
TMP_FILE="${STATE_FILE}.tmp.$$"
if awk -v it="$NEXT" '
     i>=2 { print; next }
     /^---$/ { i++; print; next }
     i == 1 && /^iteration:/ { print "iteration: " it; next }
     { print }
   ' "$STATE_FILE" > "$TMP_FILE" 2>/dev/null \
   && mv "$TMP_FILE" "$STATE_FILE" 2>/dev/null; then
  :
else
  rm -f "$TMP_FILE" 2>/dev/null || true
  echo "⚠ Boucle /lead : mise à jour de l'état impossible, pas de relance" >&2
  exit 0
fi

jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg reason_suffix "Itération $NEXT/$MAX_ITERATIONS." \
  --arg msg "🔄 /lead autonome, itération $NEXT/$MAX_ITERATIONS — couper : /lead-stop" \
  '{decision: "block", reason: ($prompt + "\n\n" + $reason_suffix), systemMessage: $msg}' \
  || true

exit 0
