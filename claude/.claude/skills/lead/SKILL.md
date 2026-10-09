---
name: lead
description: "Conduit un chantier multi-tâches en mode lead : plan découpé, délégation à worker/scout, relecture adverse par reviewer, rapport final. À lancer par Adrien au début d'un chantier. Arguments : [factory|dev] [--autonome] [--max-iterations N]."
argument-hint: "[factory|dev] [--autonome] [--max-iterations N]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/lead-start.sh:*)
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash "$HOME/.claude/skills/lead/hooks/stop-lead.sh"
---

# Chantier en mode lead

## 0. État de la session

!`"${CLAUDE_SKILL_DIR}/scripts/lead-start.sh" --session "${CLAUDE_SESSION_ID}" "$ARGUMENTS"`

Si le modèle attendu ne correspond pas à celui qui te fait tourner, dis-le maintenant et attends
qu'Adrien tranche (`/model …`) avant de continuer. En mode autonome, continue avec le modèle
courant et note l'écart dans le rapport final.

## 1. Comprendre et planifier

- L'exploration passe par `scout`, jamais par toi : pose-lui une question précise, lis ensuite
  toi-même les fichiers qu'il cite.
- Écris le plan dans `~/.claude/plans/<slug>.md` (ou complète celui qui existe : ajoute en tête,
  « reprendre ici » pour le reste). Si l'écriture y est refusée, écris-le dans le scratchpad de
  la session et dis-le. Pour chaque tâche : numéro, objectif, fichiers touchés,
  critère d'acceptation vérifiable, dépendances, et si elle est parallélisable (fichiers disjoints).
- Les tâches sont petites : un `worker` doit pouvoir la finir et la prouver en un seul passage.

## 2. Validation

Hors mode autonome : présente le plan et attends la validation. Une fois validé, propose à Adrien
de fermer cette session et de reprendre par `/lead <scénario>` avec le fichier de plan : le
contexte accumulé ici coûte à chaque tour et n'est plus utile.

En mode autonome : pas de validation ; le plan fait foi, et tout ce qui n'est pas dans le plan
n'est pas fait.

## 3. Déléguer

Un brief autonome par tâche, sur ce gabarit :

```
Tâche <n> — <objectif en une phrase>
Contexte : <ce que le worker doit savoir, chemins absolus, conventions du projet>
Fichiers : <à modifier / à ne pas toucher>
Contraintes : <périmètre, interdits, style>
Critère d'acceptation : <commande et résultat attendu>
Retour attendu : fait / fichiers / commandes et résultats / non vérifié
```

- `worker` (Sonnet) par défaut ; `model: "opus"` seulement avec la justification dans le brief.
- Un worker à la fois, ou en parallèle quand les fichiers sont disjoints. Même branche, même
  worktree, sauf décision contraire écrite dans le plan.
- À chaque retour : lis le diff réel (`git diff`), pas le résumé. Si tu ne valides pas,
  re-délègue avec le défaut précis. Ne corrige pas toi-même.
- Commit local par tâche acceptée, si le plan l'autorise.

## 4. Tests

Lance toi-même la suite du projet (ou la commande prévue par le plan) après le dernier lot.
Un worker qui dit « vert » ne remplace pas ce passage.

## 5. Relecture adverse

Confie à `reviewer` le diff complet et les critères d'acceptation, sans le raisonnement des
workers ni tes conclusions. Pour chaque défaut rendu : correction par `worker`, puis relance
toi-même le test d'attaque. Une liste vide du reviewer se note telle quelle dans le rapport.

## 6. Rapport final

Trois sections, courtes : fait (avec les preuves), non vérifié (et pourquoi), restes. Mets la
mémoire à jour si le chantier a appris quelque chose de durable.

## Mode autonome

- Interdits sans accord écrit dans le plan : `git push`, toute action sur prod ou databox, tout
  envoi externe (mail, Slack, ticket).
- Le hook Stop te relance tant que tu n'as pas livré la promesse. Tu termines ton message par
  la ligne `<promise>LEAD DONE</promise>`, seule sur la dernière ligne (ailleurs elle ne compte
  pas, et tu ne la cites jamais dans une phrase), **uniquement** quand toutes ces conditions
  sont vraies : toutes
  les tâches du plan sont acceptées, la suite de tests est passée par toi, la relecture adverse
  a été faite et ses défauts corrigés, le rapport final est écrit. Jamais pour sortir d'une
  impasse : décris l'impasse dans le rapport et laisse le plafond d'itérations faire son travail.
- Pour couper la boucle à la main : `/lead-stop`.
