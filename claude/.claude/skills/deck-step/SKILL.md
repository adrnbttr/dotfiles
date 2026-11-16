---
name: deck-step
description: "Exécute UNE étape d'une campagne deck dans le worktree courant : lit le manifeste et l'étape, exécute, commite, puis termine par `deck done`. Lancé par deck dans tmux, pas par Adrien. Arguments : [<00-plan.md> <NN-étape.md>]."
argument-hint: "[<00-plan.md> <NN-étape.md>]"
disable-model-invocation: true
---

# Étape d'une campagne deck

Tu exécutes UNE étape d'une campagne orchestrée par deck. Arguments : `$ARGUMENTS`

- `$0` : le manifeste (`00-plan.md`). `$1` : le fichier d'étape (`NN-étape.md`).
- Sans argument, le fichier d'étape est celui cité dans le prompt de deck :
  « Lis d'abord le fichier d'étape : <chemin> ». Le manifeste est alors `00-plan.md`, dans le même dossier.

## Cadre

- Les variables `DECK_*` sont déjà dans l'environnement. Ne les invente jamais, ne les modifie jamais.
- Reste dans ce worktree. N'en sors pas, ne touche aucun autre dépôt ni checkout.
- La boucle `--autonome` de `/lead` (hook `Stop` qui relance) n'est PAS utilisée. Elle empêcherait de t'arrêter pour poser une question.
- Ne t'arrête jamais sans avoir lancé `deck done`, sauf pour poser une question (voir 6).

## Séquence

1. **Lire** le manifeste puis le fichier d'étape. L'étape est le plan validé : ne demande aucune validation, ne contrôle pas le modèle. Réalise exactement ce qu'elle demande.
2. **Exécuter** selon la doctrine habituelle :
   - délègue le code et les tests aux sous-agents `worker` ;
   - exploration : `scout` ;
   - lance toi-même les tests finaux ;
   - fais relire par `reviewer` avant de conclure, et corrige ses défauts.
3. **Commiter** sur la branche courante. Jamais de `git push`, jamais de PR.
4. **Terminer** par la commande :
   `deck done --status ok --summary "<fait / non vérifié / restes>"`
5. **Traiter le code de sortie de `deck done`.**
   - `0` : accepté. Tu as fini.
   - `1` : refus (garde-fou git, contexte absent). Lis le motif sur stderr, corrige (arbre sale, commit manquant…), puis relance `deck done`.
   - `2` : démon injoignable ou muet. La commande a pu être appliquée : relance-la une fois, lis stderr.
   - Si le motif n'est pas corrigeable : pose la question à Adrien et arrête-toi.
6. **Blocage ou décision à prendre** : pose la question et arrête-toi. deck voit alors l'état `waiting`. Ne lance pas `deck done` dans ce cas.
7. **Étape impossible** : `deck done --status failed --summary "<motif>"`. Traite son code de sortie comme en 5.
