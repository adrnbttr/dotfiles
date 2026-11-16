---
description: Exécute UNE étape d'une campagne deck dans le worktree courant, puis termine par `deck done`
---

Tu exécutes UNE étape d'une campagne orchestrée par deck. Arguments : $ARGUMENTS

- $1 : le manifeste (`00-plan.md`). $2 : le fichier d'étape (`NN-étape.md`).
- Sans argument, le fichier d'étape est celui cité dans le prompt de deck :
  « Lis d'abord le fichier d'étape : <chemin> ». Le manifeste est alors `00-plan.md`, dans le même dossier.

Cadre :

- Les variables `DECK_*` sont déjà dans l'environnement. Ne les invente jamais, ne les modifie jamais.
- Reste dans ce worktree. N'en sors pas, ne touche aucun autre dépôt ni checkout.
- Pas de boucle automatique de relance (`--autonome`, hook `Stop`) : elle empêcherait de t'arrêter pour poser une question.
- Ne t'arrête jamais sans avoir lancé `deck done`, sauf pour poser une question (voir 6).

Séquence :

1. Lis le manifeste puis le fichier d'étape. L'étape est le plan validé : ne demande aucune validation. Réalise exactement ce qu'elle demande.
2. Exécute selon les règles de AGENTS.md :
   - code : délègue à `implementer` (une tâche par appel), `chore` si mécanique ;
   - exploration : `explore` ;
   - lance toi-même les tests finaux ;
   - étape non triviale : fais relire par `challenger` avant de conclure, et corrige ses défauts.
3. Commite sur la branche courante. Jamais de `git push`, jamais de PR.
4. Termine par la commande :
   `deck done --status ok --summary "<fait / non vérifié / restes>"`
5. Traite le code de sortie de `deck done` :
   - `0` : accepté. Tu as fini.
   - `1` : refus (garde-fou git, contexte absent). Lis le motif sur stderr, corrige (arbre sale, commit manquant…), puis relance `deck done`.
   - `2` : démon injoignable ou muet. La commande a pu être appliquée : relance-la une fois, lis stderr.
   - Si le motif n'est pas corrigeable : pose la question à Adrien et arrête-toi.
6. Blocage ou décision à prendre : pose la question et arrête-toi. deck voit alors l'état `waiting`. Ne lance pas `deck done` dans ce cas.
7. Étape impossible : `deck done --status failed --summary "<motif>"`. Traite son code de sortie comme en 5.
