---
name: lead-stop
description: "Coupe la boucle autonome lancée par /lead --autonome dans cette session. Le hook Stop laisse alors Claude s'arrêter normalement."
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/../lead/scripts/lead-stop.sh:*)
---

!`"${CLAUDE_SKILL_DIR}/../lead/scripts/lead-stop.sh" --session "${CLAUDE_SESSION_ID}"`

Confirme en une ligne que la boucle est coupée, puis termine ton tour. Ne reprends aucun
travail du chantier sans nouvelle consigne.
